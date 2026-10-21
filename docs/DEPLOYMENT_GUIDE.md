# mitaLeet — Deployment Guide

How to ship the `prod-readiness` branch to real users, verify it, and roll back. Commands are exact; secret *values* never appear here.

## 0. Current state (verified 2026-10-18)

There are **two** deployments. The project owner (Mitali) controls only the second.

| | Legacy (co-founder's accounts) | **Current, owned** |
|---|---|---|
| API | `https://mitaleet.onrender.com`: old build from before `809d14f`, Free tier (42 s cold start) | **`https://mitaleet-97q2.onrender.com`**: branch `prod-readiness`, Render, Singapore |
| Database | Neon (`us-east-1`), old data plus whatever the legacy server still writes | **Neon (`ap-southeast-1`, Postgres 18.6)**: verified copy of the legacy DB taken 2026-10-18 (every table's exact row count matched) |
| Web app | `https://mitaleet.netlify.app` (calls the legacy API) | not yet: Firebase authorized domains are managed in the co-founder's Firebase project (§4) |
| Mobile / extension | — | defaults now point to the owned API (`API_ORIGIN`, `.env.production`) |

**Smoke tests on the owned API** (§5), 2026-10-18:
- `/health` 200 with `database: ok` (2 ms); `/health/live` 200
- unauthenticated 401; dev-login 404
- HSTS, CSP, nosniff and `x-request-id` present
- CORS allows `https://mitaleet.netlify.app` and rejects other origins; a malformed Google token gives a clean 401
- **Rate limit:** 30 refresh attempts allowed, then 429. Requests with a forged `CF-Connecting-IP` are refused by Cloudflare at the edge (error 1000) and never reach the app.

Still unverified there: a real Google sign-in, LeetCode sync and sockets from a device, and push notifications.

**Why there were two copies:** the original Render, Railway, Netlify and Neon accounts belong to a co-founder who couldn't be reached. Ask them to add you to (or transfer) those accounts, then decide which deployment is canonical and switch the legacy one off. Two servers running old and new code on separate databases don't interfere with each other.

## 1. Before deploying: answer three questions in the Render dashboard

1. **Where does `DATABASE_URL` point?** Open Dashboard → `mitaleet-server` → Environment and look at the host part only:
   - `…render.com` → Render Postgres. Then check Dashboard → your database → plan. **A Free Render Postgres database expires 30 days after creation** ([Render docs](https://render.com/docs/free)). If that's yours, upgrade it to a paid plan ($6/month, `basic-256mb`) *before* anything else, then export a backup (§7).
   - `neon.tech`, `supabase.co`, or another host → note the provider and confirm backups are on in its console.
2. **What instance type is the web service?** Dashboard → `mitaleet-server` → Settings → Instance Type. On **Free**, the service sleeps after 15 minutes idle and the 30-minute sync and hourly streak jobs **don't run while it sleeps**. Use **Starter ($7/month)** for real users ([pricing](https://render.com/pricing)).
3. **Is the service managed by the Blueprint (`render.yaml`)?** If yes, merging will apply `render.yaml`. If it was created by hand, set the variables in §2 manually.

## 2. Environment variables

Set these in Render → Environment. Never commit values to git.

| Variable | Required | Value / notes |
|---|---|---|
| `NODE_ENV` | yes | `production` (turns on JSON logs; dev-login can never work in production) |
| `DATABASE_URL` | yes | Postgres URL from your provider. Use the *pooled* URL if the provider offers one. |
| `JWT_SECRET` | yes | ≥ 48 random bytes, e.g. `openssl rand -base64 48`. Changing it signs everyone out. |
| `JWT_ACCESS_EXPIRATION` | yes | `15m` |
| `JWT_REFRESH_EXPIRES_IN` | yes | `30d` |
| `GOOGLE_CLIENT_ID` | yes | Google OAuth **Web** client ID (the audience of mobile ID tokens) |
| `FIREBASE_PROJECT_ID` | yes | Needed to verify Firebase ID tokens from the web app |
| `CORS_ORIGINS` | yes | `https://mitaleet.netlify.app` (comma-separated if you add a custom domain) |
| `CLIENT_IP_HEADER` | yes (Render) | `cf-connecting-ip`. Cloudflare (in front of every `*.onrender.com` service) puts the real client IP there and overwrites client-sent values. Without it, rate limits never trigger on Render (verified on the live service). |
| `TRUST_PROXY_HOPS` | yes | `2` on Render. Only a fallback for logs when `CLIENT_IP_HEADER` is absent; proxy-hop counting alone proved unreliable on Render. |
| `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | for push | Service-account values; keep the `\n` sequences in the key. Push is disabled when absent. |
| `LEETCODE_RATE_LIMIT_MS` | no | Default `2000` (gap between scheduled syncs) |
| `LEETCODE_QUICK_SYNC_INTERVAL_MS` | no | Default `15000` (per-user on-demand check throttle) |
| `ENABLE_DEV_LOGIN` | **never** | Must be absent in production |

Remove unused leftovers if present: `JWT_EXPIRES_IN`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_CALLBACK_URL`, `REDIS_URL`.

## 3. Release procedure (API)

The API builds with `npm ci --include=dev && npm run build` and starts with `npm run start:prod`, which runs `prisma migrate deploy` and then the server.

1. **Make sure CI is green** on the `prod-readiness` branch (GitHub → Actions). The workflow runs typecheck, build, unit and e2e tests on Postgres, the migration drift check, the extension build, and the Flutter analyze/test/APK steps.
2. **Back up the database** (§7).
3. **Set or confirm the environment variables** (§2). In particular `JWT_ACCESS_EXPIRATION=15m`, `CLIENT_IP_HEADER=cf-connecting-ip` and `TRUST_PROXY_HOPS=2`.
4. **Merge** `prod-readiness` → `main` with a pull request. Render auto-deploys `main`; if auto-deploy is off, use Dashboard → Manual Deploy → Deploy latest commit.
5. **Watch the deploy log.** Expect `prisma migrate deploy` with "No pending migrations to apply" (this branch adds **no** migrations), then `Nest application successfully started`. Render only switches traffic once `/health` returns 200, and `/health` now checks the database.
6. **Run the smoke tests** (§5).

### What changes for existing users when this deploys

- **Sessions:** old refresh tokens keep working and are re-saved hashed on first use. Nobody is forced to log out. Access tokens become 15-minute and refresh silently in the app.
- **XP:** existing XP values are kept. The every-30-minute recalculation that overwrote XP is removed. From now on XP only goes up through verified solves, races and challenges.
- **LeetCode links:** already-linked accounts keep working (grandfathered). New links need the "About me" verification code.
- **Browser extension:** tokens pasted before this release are app access tokens and stop working within 15 minutes. Users generate an extension token in Profile → Extension token (new mobile build).
- **Old app versions** keep working, except: linking LeetCode needs the new two-step flow, and challenge/race "complete" now returns 409 until LeetCode shows the accepted submission.

## 4. Web app (Netlify)

```bash
cd apps/mobile
flutter build web --release
# deploy apps/mobile/build/web (Netlify UI drag-and-drop, or)
npx netlify-cli deploy --dir=build/web --prod
```

The app uses hash routing (`/#/…`), so no SPA redirect rules are needed. Recommended: add a `netlify.toml` with security headers and a CSP (backlog B-10). The API URL is compiled in from `apps/mobile/lib/core/constants/app_constants.dart`.

## 5. Smoke tests (run after every deploy)

```bash
API=https://mitaleet-97q2.onrender.com
curl -s $API/health            # {"success":true,"data":{"status":"ok","database":"ok",...}}
curl -s $API/health/live       # {"success":true,"data":{"status":"ok",...}}
curl -s -o /dev/null -w "%{http_code}\n" $API/api/v1/users/me                     # 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST -H 'content-type: application/json' \
     -d '{"username":"x"}' $API/api/v1/auth/dev-login                                # 404 (must never be 200)
curl -sI $API/api/v1/users/me | grep -i x-request-id                                  # present
```

Then, in the app: sign in with Google → profile loads → link LeetCode (code flow) → "Sync now" → a solve appears → open a squad → live activity arrives → sign out → the old token gets 401.

## 6. Rollback

- **Code:** Render Dashboard → `mitaleet-server` → Events → pick the last good deploy → **Rollback**. On free plans only the two most recent previous deploys are available.
- **Database:** this branch adds no migrations, so rolling the code back is safe. For future releases, keep migrations additive (add → backfill → remove in a later release) so a code rollback never needs a schema rollback.
- **Bad config:** revert the env var in Render; it triggers a redeploy.

## 7. Backups and restore

Targets (see `OPERATIONS_RUNBOOK.md`): **RPO ≤ 24 h now, ≤ 5 min once on a paid plan with PITR; RTO ≤ 2 h.**

```bash
# Manual logical backup (run from a trusted machine; URL from the dashboard, never pasted into files)
pg_dump --format=custom --no-owner --dbname "$DATABASE_URL" --file mitaleet-$(date +%F).dump
# Restore drill into a scratch database (never into production)
createdb mitaleet_restore_test
pg_restore --no-owner --dbname mitaleet_restore_test mitaleet-$(date +%F).dump
psql mitaleet_restore_test -c 'select count(*) from "User"; select count(*) from "Solve";'
```

Paid Render Postgres includes point-in-time recovery (3-day window on the Hobby workspace plan, 7 days on Pro, per [Render pricing](https://render.com/pricing)). **A backup has not been restored during this audit (no database access), so recovery is unverified.**

## 8. Mobile release (Android first)

Still to do (backlog B-06):
1. Create an upload keystore. Add `android/key.properties` (gitignored) and a release `signingConfig`; the app is currently signed with the debug key.
2. Pass the API URL with `--dart-define` flavors instead of the hardcoded constant.
3. `flutter build appbundle --release` → Play Console internal testing.
4. New personal Play accounts must run a **closed test with ≥ 12 testers for 14 days** before production ([Google Play help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)).
5. Store listing: privacy policy URL, data-safety form (email, name, LeetCode username, activity), and the in-app account deletion (done: Profile → Delete account).

## 9. Chrome extension

```bash
cd apps/extension
npm ci && npm run build && npm run package   # build/chrome-mv3-prod.zip
```

Upload to the Chrome Web Store developer dashboard. It needs a privacy policy, a single-purpose description, and a justification for the `storage`, `activeTab` and `scripting` permissions plus host access to leetcode.com and the API.

## 10. Local development (for reference)

```bash
docker compose up -d postgres redis            # Postgres on 127.0.0.1:5432
cd apps/server && cp .env.example .env         # fill in values
npm ci && npx prisma migrate dev && npm run start:dev
# tests (separate DB whose URL must contain "test"):
docker run -d --name mltest-pg -p 127.0.0.1:55432:5432 -e POSTGRES_USER=ml -e POSTGRES_PASSWORD=ml -e POSTGRES_DB=ml_test postgres:16-alpine
npm run test:e2e
```
