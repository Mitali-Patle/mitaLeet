# mitaLeet

A social, competitive layer on top of LeetCode for small friend groups. Your **verified** LeetCode solves turn into streaks, XP, levels, ranks and achievements; you compete in **squads** (invite-code groups) with leaderboards, a live activity feed and timed challenges, and in **live races** on a single problem.

```
apps/
  server/      NestJS 11 + Prisma 6 + PostgreSQL 16 + Socket.IO   (API, port 3000)
  mobile/      Flutter 3.44 + Riverpod                            (Android, iOS, web)
  extension/   Plasmo (Chrome MV3)                                (reports "Accepted" on leetcode.com)
packages/
  shared/      Shared TypeScript types
docs/          Production readiness, security, deployment, operations, scaling, product
```

**Status:** see [docs/PRODUCTION_READINESS_REPORT.md](docs/PRODUCTION_READINESS_REPORT.md). The older `audit_report.md` is superseded by the `docs/` folder.

## How it works

- **Sign-in:** Google. Mobile sends a Google ID token; web uses a Firebase Auth popup and sends a Firebase ID token. The server verifies either (RS256 against Google's certificates) and issues its own 15-minute access token plus a rotating 30-day refresh token. Every request checks that the session still exists, so logout is immediate.
- **Solves are verified:** the server reads the user's accepted submissions from LeetCode's GraphQL API, every 30 minutes and on demand when the extension reports "Accepted". Clients can't create solves or award XP.
- **LeetCode linking** needs proof of ownership: put a one-time code in your LeetCode profile "About me", then tap Verify.
- **Days follow your timezone:** streaks and "today" use the device timezone the app sends.

## Prerequisites

| Tool | Version |
|---|---|
| Node.js / npm | 20 |
| Flutter | 3.44 (see `apps/mobile/.metadata`) |
| Docker + Compose | recent (local Postgres) |
| Android Studio / Xcode | for device builds |

External services you provision:
- A **Google Cloud OAuth Web client** (its ID is the server's `GOOGLE_CLIENT_ID`) and an Android OAuth client (`com.mitaleet.app` plus your debug SHA-1)
- A **Firebase project**, used for **web sign-in** (Firebase Auth) and **push** (FCM): `google-services.json` / `GoogleService-Info.plist` (gitignored), plus an Admin SDK service account for push

## Local setup

### 1. Database

```bash
docker compose up -d postgres redis      # Postgres on 127.0.0.1:5432 (Redis is not used yet)
```

### 2. Server

```bash
cd apps/server
cp .env.example .env                     # fill in values; see the comments in the file
npm ci
npx prisma migrate dev
npm run start:dev                        # http://localhost:3000
curl localhost:3000/health               # {"success":true,"data":{"status":"ok","database":"ok",...}}
```

Key variables (full list and production notes in [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md#2-environment-variables)):

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Postgres connection string |
| `JWT_SECRET` | `openssl rand -base64 48` |
| `JWT_ACCESS_EXPIRATION` / `JWT_REFRESH_EXPIRES_IN` | `15m` / `30d` |
| `GOOGLE_CLIENT_ID`, `FIREBASE_PROJECT_ID` | Token verification |
| `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | Push (optional locally; keep the `\n` sequences) |
| `ENABLE_DEV_LOGIN` | `true` **locally only**; enables the passwordless dev login. Ignored in production. |
| `CORS_ORIGINS`, `TRUST_PROXY_HOPS` | Production web origins; proxy hops (Render = 1) |

The whole stack in Docker (production image, no hot reload): `docker compose up --build`.

### 3. Mobile

```bash
cd apps/mobile
flutter pub get
flutter run
```

The API URL is set in `lib/core/constants/app_constants.dart` (defaults to production). For local work use `http://10.0.2.2:3000` on the Android emulator, or your machine's LAN IP on a physical device. Google Sign-In on a device needs your debug keystore's SHA-1 registered on the Android OAuth client; otherwise use **Dev Login** (debug builds only, needs `ENABLE_DEV_LOGIN=true` on the server).

### 4. Extension

```bash
cd apps/extension
npm ci
npm run dev          # uses .env.development  -> http://localhost:3000
npm run build        # uses .env.production   -> https://mitaleet.onrender.com
```

Load `build/chrome-mv3-dev` (or `-prod`) via `chrome://extensions` → Developer mode → Load unpacked. In the app, go to **Profile → Extension token** to generate a token (valid 90 days, can only report solves) and paste it into the extension popup.

## Testing

```bash
cd apps/server
# a separate database whose URL contains "test" (the suite resets it)
docker run -d --name mltest-pg -p 127.0.0.1:55432:5432 \
  -e POSTGRES_USER=ml -e POSTGRES_PASSWORD=ml -e POSTGRES_DB=ml_test postgres:16-alpine
npm run typecheck
npm test             # unit
npm run test:e2e     # 13 suites against real Postgres; LeetCode is faked
```

```bash
cd apps/mobile && flutter analyze && flutter test
cd apps/extension && npm run build && npx tsc --noEmit
```

CI (`.github/workflows/ci.yml`) runs all of these on every push and pull request, plus a migration drift check and a debug APK build.

## Deployment

API on Render (`render.yaml`), web app on Netlify. Follow **[docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)**: it covers environment variables, migrations, smoke tests, rollback and backups. Operating it: [docs/OPERATIONS_RUNBOOK.md](docs/OPERATIONS_RUNBOOK.md).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `/health` returns 503 `database: unreachable` | `DATABASE_URL` wrong or the database is down (runbook §3) |
| First request takes about 1 minute in production | Render Free instance waking up; use Starter |
| Google Sign-In fails on a device with no detail | Debug SHA-1 not registered on the Android OAuth client |
| LeetCode verify says "code not found" | Save the code in LeetCode → Edit Profile → Summary, then retry |
| Race or challenge "complete" returns 409 | LeetCode doesn't show the accepted submission yet; wait for the sync or tap again |
| `npm run build` leaves `dist/` empty | Fixed: builds are no longer incremental. Delete stray `*.tsbuildinfo` if you're on an old checkout |
| Tests refuse to run | The test database URL must contain "test" (safety check) |

## Documentation

- [Production readiness report](docs/PRODUCTION_READINESS_REPORT.md): status, changes, backlog, verdict
- [Security findings](docs/SECURITY_FINDINGS.md)
- [Deployment guide](docs/DEPLOYMENT_GUIDE.md) · [Operations runbook](docs/OPERATIONS_RUNBOOK.md)
- [Release checklist](docs/PRODUCTION_READINESS_CHECKLIST.md)
- [Scalability and cost plan](docs/SCALABILITY_AND_COST_PLAN.md)
- [Product growth and monetization](docs/PRODUCT_GROWTH_AND_MONETIZATION.md)
