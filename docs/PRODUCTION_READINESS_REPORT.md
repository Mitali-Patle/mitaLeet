# mitaLeet — Production Readiness Report

Audit and remediation: 2026-10-18 · Branch `prod-readiness` (`git log main..prod-readiness`; base `main` @ `8a8caef`) · Companion documents: [SECURITY_FINDINGS](SECURITY_FINDINGS.md), [DEPLOYMENT_GUIDE](DEPLOYMENT_GUIDE.md), [OPERATIONS_RUNBOOK](OPERATIONS_RUNBOOK.md), [CHECKLIST](PRODUCTION_READINESS_CHECKLIST.md), [SCALABILITY_AND_COST_PLAN](SCALABILITY_AND_COST_PLAN.md), [PRODUCT_GROWTH_AND_MONETIZATION](PRODUCT_GROWTH_AND_MONETIZATION.md).

**Verdict: READY FOR STAGING.** The code on this branch builds, passes 96 automated tests (90 e2e + 5 unit on the server, 1 mobile widget test), and fixes every Critical issue found. It is **not yet production-verified**: it isn't deployed, the database's backup status is unknown, and alerting and a privacy policy are missing. Details are in §9.

## 1. Condition before the audit

The app demoed well but couldn't safely face real users:
- **The production build had failed on every push since `809d14f`.** TS7006 broke `nest build`, so production is still serving an older deploy, and CI was red.
- **The core product could be gamed.** A squad owner could mint 2,000,850 XP in three calls, race finishes paid out on every repeat call, the extension endpoint accepted invented solves, and anyone could claim anyone's LeetCode account.
- **Authorization holes:** non-members could read private squads (including invite codes) and stream their live events. Logout didn't invalidate tokens. There was no rate limiting.
- **Broken features:** the friends list returned 500, re-friending returned 500, race live updates were never delivered, onboarding and Create Squad were stubs (onboarding also trapped new users), streaks used UTC days, and the mobile app didn't compile on Flutter 3.44.
- **No tests at all**, a lint script calling an ESLint that wasn't installed, and migrations configured to run up to three times per deploy.

## 2. Technology and architecture (confirmed from the code)

| Part | Stack |
|---|---|
| API | NestJS 11 (TypeScript), Prisma 6, PostgreSQL 16, Socket.IO 4, `@nestjs/schedule`, `@nestjs/throttler`, helmet, class-validator, firebase-admin (FCM) |
| Auth | Google ID token (mobile) / Firebase ID token (web) → manual RS256 verification → server-issued JWT (15 min) + rotating refresh token (hashed, 30 days), with the session checked on every request |
| Mobile and web | Flutter 3.44 / Dart, Riverpod, go_router, Dio, socket_io_client, flutter_secure_storage, google_sign_in, firebase_auth, flutter_timezone |
| Extension | Plasmo (Chrome MV3), React 18 |
| External services | LeetCode GraphQL (unofficial), Google/Firebase identity, FCM |
| Hosting (observed) | API on Render (behind Cloudflare), Flutter web on Netlify, database provider **unknown** |

**Request flow:**

```
Flutter app / web ─┐                         ┌─> Postgres (Prisma)
Chrome extension ──┼─HTTPS─> Render ─> NestJS ┤
                   └─WSS (Socket.IO)─────────┘─> LeetCode GraphQL (sync / verify)
NestJS pipeline:  request-id → helmet → CORS → JWT guard (+ session check)
                  → extension-scope guard → rate limiter → ValidationPipe (DTOs)
                  → controller → service → Prisma
                  → TransformInterceptor / HttpExceptionFilter (+ request id)
Background (same process): 30-min LeetCode sync, hourly streak check,
                  5-min leaderboard broadcast (each under a Postgres advisory lock)
Solve pipeline:   LeetCode recentAcSubmissions → SyncService (only writer of Solve)
                  → onNewSolves → XPService / RaceService / ChallengeService
```

**Main user journeys:** Google sign-in → onboarding (username) → link LeetCode (verification code) → automatic or extension-triggered sync → streaks, XP and achievements → friends and squads → live feed, squad leaderboards and challenges → races.

## 3. Baseline (before changes)

| Check | Result | Category |
|---|---|---|
| Server `npm ci`, `prisma validate/generate` | pass | — |
| Server `tsc` / `nest build` | **fail** (TS7006 ×2, `main.ts:41`) | existing defect |
| Server lint / test | could not run (`eslint`, `jest` not installed; no tests) | missing dependencies |
| Server `npm audit --omit=dev` | 26 vulnerabilities (2 critical, 14 high) | supply chain |
| Migrations on an empty Postgres 16 | pass, no drift | — |
| Untracked duplicate migration | breaks `migrate deploy` (`type "UserStatus" already exists`) | existing defect (removed) |
| Extension build / tsc | build pass, tsc 3 errors | existing defect |
| Mobile `flutter test` | **fails to compile** (`phosphor_flutter` vs final `IconData`) | dependency compatibility |
| Mobile `flutter analyze` | 89 issues: 0 errors, **22 warnings** (unused imports/variable), 67 infos. Analyze exits non-zero on warnings. | existing defect |
| Secrets scan (gitleaks, full history) | no real secrets | — |
| CI on GitHub | red on every recent push | existing defect |
| Exploit reproduction (local) | **21 of 21 suspected issues confirmed** | see SECURITY_FINDINGS |

## 4. Changes implemented (on `prod-readiness`)

| Commit | Change |
|---|---|
| `c96fb51` | Fix the production build (typed CORS callback) |
| `b969f44`, `93e1416` | Graceful shutdown: intervals and timers cleared, in-flight syncs awaited, stranded race countdowns recovered |
| `db215aa` | Test harness: Jest + supertest e2e against real Postgres; `FakeLeetCodeClient`; `.env` ignored in tests |
| `e14a0b3` | Squad membership enforced on REST and sockets; device tokens owner-only |
| `d65be56` | XP only from LeetCode-verified solves; one XP authority with atomic increments; verified, once-only race and challenge completion; validated DTOs |
| `e91a870` | LeetCode ownership proof (HMAC code in "About me"), plus mobile two-step flow |
| `82ebe8d` | Session-checked tokens, hashed refresh tokens, atomic rotation, dev-login lockdown, stricter Google/Firebase verification, cached certificates |
| `2f5a754`, `6926af7` | Mobile: single-flight refresh, return to login on expiry, fresh token on socket reconnect |
| `23c0fd3` | Rate limiting (per user or IP) + trust proxy |
| `98fdd00` | Bounded queries, keyset feed pagination, profile validation |
| `9ec739a` | Friends: no more 500s; re-request works |
| `8131a93`, `7748ea9` | Race live events delivered; socket auth moved into the handshake (race condition) |
| `c11c4c6` | Timezone-aware streaks, today and daily stats |
| `e3348f6` | Extension targets the production API; manifest permissions narrowed; tsc clean |
| `423de10` | Dependency security fixes (critical 2 → 0, high 14 → 3); broken lint script removed |
| `cf907d9` | Mobile builds on Flutter 3.44 (vendored icons); real onboarding and Create Squad; sends device timezone |
| `8f4c260` | CI: typecheck, build, unit + e2e on Postgres, drift check, extension, Flutter analyze/test/APK; read-only permissions |
| `54a8bf4` | DB-aware `/health` + `/health/live`; one migration step; real non-root Dockerfile; documented `render.yaml` |
| `b7f4d42` | Account deletion (API + app) |
| `d5e8e76` | Request IDs, failure logging, JSON logs; fix empty incremental rebuilds |
| `68bc194`, `fb7a01c` | Sync concurrency actually enforced; LeetCode calls paced and time-limited; crons run once across instances |
| `0ae7b58` | Scoped, revocable 90-day extension tokens |

No migrations were added, so this release can be rolled back by code alone. The only breaking API changes, all intentional:
- linking is now two-step
- challenge, race and extension bodies are validated
- race and challenge completion returns 409 until LeetCode confirms the solve
- `PUT /users/me/profile` no longer accepts `leetcodeUsername`

## 5. Testing

| Suite | Executed | Passed | Failed | Notes |
|---|---|---|---|---|
| Server e2e (13 suites, real Postgres) | 90 | 90 | 0 | Run repeatedly. One intermittent failure was a real socket race, fixed in `7748ea9`; another was a timestamp-precision bug, fixed in `d65be56`. |
| Server unit (timezone helpers) | 5 | 5 | 0 | |
| Mobile widget test | 1 | 1 | 0 | Signed-out launch reaches login |
| Mobile analyze | — | 0 errors; the 22 existing warnings were removed after CI caught them (my local filter had hidden them) | — | Style infos remain |
| Extension tsc + build | — | pass | — | |
| Production Docker image smoke | manual | pass | — | Non-root, migrates, healthy, dev-login 404 |
| Android APK build (debug) | CI | pass | — | GitHub Actions run 39126927617 (PR #3) |

**Coverage areas:** auth lifecycle (including real RS256 token verification), authorization (REST and WS), XP integrity, linking, rate limits, validation and pagination, friends, races (WS), timezone, account deletion, background jobs and concurrency.
**Known untested areas:** analytics and insights endpoints, notifications (not wired), group admin actions (promote/demote/transfer: code reviewed only), mobile screens beyond the smoke test, extension runtime on leetcode.com, behaviour under load.

## 6. Deployment status

**Classification: D, "operational in a limited or unverified environment".** The old build answers at `https://mitaleet.onrender.com` (health 200 after a 42 s cold start; auth guard active), and the Flutter web app is served at `https://mitaleet.netlify.app`. This branch isn't deployed, and no production URL has been verified against the new checks. Steps: [DEPLOYMENT_GUIDE](DEPLOYMENT_GUIDE.md).

## 7. Prioritized backlog

Effort: S (< ½ day), M (1–2 days), L (3–5 days).

| ID | Priority | Item | Why | Effort | Depends on | Validation |
|---|---|---|---|---|---|---|
| B-01 | **P0** | Deploy this branch and run the smoke tests | Nothing here is live | S | B-02, B-13 | DEPLOYMENT_GUIDE §5 green |
| B-02 | **P0** | Identify the DB plan; upgrade off Free if needed; back up and **restore-drill** | Possible 30-day expiry; recovery unverified | S | Render access | Restored row counts match |
| B-13 | **P0** | Revoke the GitHub token in the local git remote (SEC-13) | Credential exposure | S | — | Old token rejected by GitHub |
| B-05 | **P0** | Starter instance ($7) or higher | Free tier sleeps, so cron jobs don't run | S | — | `/health` fast after idle; sync jobs every 30 min |
| B-03 | P1 | Sentry + Crashlytics; uptime and 5xx alerts | Detect failures before users report them | M | B-01 | Test error appears in Sentry; alert fires |
| B-09 | P1 | Privacy policy, terms, Play data-safety form, Chrome Web Store disclosure | Legal and store requirement | M | — | Published URLs linked in app and stores |
| B-04 | P1 | Push notifications: friend solves (batched, mutable), streak-at-risk reminders, FCM token registration in the app | Main retention lever (user-requested) | L | B-01; Firebase service account | Notification received on device; mute works |
| B-06 | P1 | Android release signing, `--dart-define` flavors, closed test (12×14 days) | Store release | M | B-09 | Play internal track build installs |
| B-07 | P1 | Re-verify grandfathered LeetCode links (prompt, then expire) | Residual of SEC-04 | S | B-01 | Unverified links stop earning XP after the grace period |
| B-08 | P2 | Redis adapter for sockets and throttler storage | Needed only before running more than one instance | M | traffic | Two-instance e2e: cross-instance events delivered |
| B-10 | P2 | `netlify.toml` with CSP and security headers; restrict Firebase keys; App Check | Web token theft via XSS (SEC-20) | S | — | securityheaders.com grade A; app still works |
| B-11 | P2 | ESLint + Prettier in CI | Maintainability | S | — | CI lint step green |
| B-12 | P2 | Privacy settings (hide from global leaderboard and search) | "Private squads" promise (SEC-23) | M | — | Hidden users absent from search and global board |
| B-14 | P2 | Load test on staging (SCALABILITY plan) | No capacity evidence | M | staging | p95 / error targets met or the bottleneck identified |
| B-15 | P2 | Sync scheduling by activity (skip dormant users) | LeetCode rate-limit headroom | S | — | LeetCode calls per hour drop |
| B-16 | P3 | Slim the Docker image (870 MB) | Faster deploys | S | — | Image < 400 MB |
| B-17 | P3 | Activity retention job; race-code collision retry (SEC-25); restrict socket CORS (SEC-24) | Hygiene | S | — | Tests |
| B-18 | P3 | iOS build and TestFlight | Second platform | L | B-06 | TestFlight install |

## 8. Product, scaling and cost (summary)

- **Cost:** a reliable launch setup is about **$13/month** (Render Starter web + `basic-256mb` Postgres). The first bottleneck will be **LeetCode's rate limits**, not the server. Redis and multiple instances aren't needed yet. See [SCALABILITY_AND_COST_PLAN](SCALABILITY_AND_COST_PLAN.md).
- **Growth:** the squad invite loop and races are the distinctive strengths; push notifications are the missing retention engine.
- **Monetization:** test a **club/cohort plan** with coding clubs before building billing, and get a legal review of the LeetCode dependency before charging anyone. See [PRODUCT_GROWTH_AND_MONETIZATION](PRODUCT_GROWTH_AND_MONETIZATION.md).

## 9. Production readiness scorecard

| Gate | Status | Evidence |
|---|---|---|
| 1 Functionality | NOT VERIFIED | 90 e2e tests pass locally; not run on devices or in production |
| 2 Security | BLOCKED | 0 open Critical; 1 open High needs your action (SEC-13) |
| 3 Data safety | BLOCKED | DB plan unknown; no restore verified |
| 4 Quality | PASS | GitHub Actions run 39126927617 on PR #3: server (typecheck, build, unit, 90 e2e, drift check), extension, Flutter analyze/test/APK all green |
| 5 Configuration | NOT VERIFIED | Documented and secrets clean; production values not inspected |
| 6 Deployment | NOT VERIFIED | Documented; Docker image verified locally; not deployed |
| 7 Operations | FAIL | No error tracking or alerting yet |
| 8 Performance | NOT VERIFIED | No load test |
| 9 Privacy | FAIL | Deletion done; no privacy policy yet |
| 10 Release | NOT VERIFIED | Rollback documented; smoke tests not yet run in production |

**Verdict: READY FOR STAGING.** Ship this branch to a staging (or a carefully watched production) environment once B-02, B-05 and B-13 are done. Declare production-ready only after the gates above turn PASS with evidence. No system is "completely secure"; this report records what was checked and fixed on 2026-10-18.
