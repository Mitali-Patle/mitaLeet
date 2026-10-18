# mitaLeet — Production Readiness Checklist

Status as of 2026-10-18, branch `prod-readiness`. ✅ done and verified · ⏳ done in code, not yet verified in production · ❌ not done · 🔒 needs owner action or access.

## Release gates

| # | Gate | Status | Evidence |
|---|---|---|---|
| 1 | Functionality: critical journeys work | **NOT VERIFIED** (passes locally) | 90 server e2e tests cover sign-in, sessions, linking, sync, XP, squads, friends, races, challenges, timezone, deletion. Mobile: analyze clean, 1 widget test. No on-device or production run yet. |
| 2 | Security: no unresolved Critical; High fixed or accepted | **BLOCKED** | All 4 Critical fixed with tests. High: 8 fixed; **SEC-13 (GitHub token in local git remote) needs you to rotate it**. See SECURITY_FINDINGS.md |
| 3 | Data safety: migrations, backups, recovery | **BLOCKED** | Migrations: applied from scratch, no drift (CI-checked); this release adds none. **Database provider and plan unknown; no backup restored.** A Free Render Postgres database would expire after 30 days. |
| 4 | Quality: tests pass, build succeeds | **NOT VERIFIED** (local PASS) | Local: typecheck, build, 5 unit + 90 e2e, extension build + tsc, Flutter analyze + test all pass. New CI workflow not yet run on GitHub. Android APK build not run locally (disk space). |
| 5 | Configuration: secrets and env handled safely | **NOT VERIFIED** | No secrets in git (gitleaks, full history). Env vars documented in `render.yaml` and DEPLOYMENT_GUIDE §2. Production env values not inspected (no access). |
| 6 | Deployment: documented, repeatable, verified | **NOT VERIFIED** | Runbook written; production Docker image verified locally (non-root, migrates, healthy). Branch not deployed. |
| 7 | Operations: logs, health, error monitoring, recovery | **FAIL** | Done: DB-aware `/health`, request IDs, JSON logs, security warnings. **Missing: error tracking and uptime alerting** (B-03). |
| 8 | Performance: critical paths tested against targets | **NOT VERIFIED** | No load test yet (plan in SCALABILITY_AND_COST_PLAN.md). Concurrency limits verified in tests. |
| 9 | Privacy: collection, retention, disclosures | **FAIL** | Done: in-app account deletion, minimal logging. **Missing: privacy policy and terms; Play data-safety form** (B-09). |
| 10 | Release: rollback and post-deploy checks | **NOT VERIFIED** | Rollback procedure documented (Render rollback; no migrations in this release). Smoke tests written, not yet run against production. |

## Before going live (P0)

- [ ] 🔒 Find the production database host and plan; upgrade off Free Postgres if that's what it is (DEPLOYMENT_GUIDE §1)
- [ ] 🔒 Take a `pg_dump` backup and **restore it into a scratch database** (DEPLOYMENT_GUIDE §7)
- [ ] 🔒 Revoke the GitHub token embedded in the local `origin` URL (SEC-13)
- [ ] 🔒 Web service on Starter ($7/month) or higher, so cron jobs run and there's no cold start
- [ ] 🔒 Set env vars from DEPLOYMENT_GUIDE §2; make sure `ENABLE_DEV_LOGIN` is **absent**
- [ ] ⏳ Push the branch; GitHub Actions CI green
- [ ] ⏳ Merge to `main`; deploy; smoke tests pass (DEPLOYMENT_GUIDE §5)
- [ ] ❌ Uptime monitor on `/health` with phone alerts (B-03)
- [ ] ❌ Privacy policy and terms published; link them from the app and store listings (B-09)

## Security

- [x] ✅ Server-side authorization on every squad, challenge, race, device and socket room (e14a0b3, 8131a93)
- [x] ✅ XP only from LeetCode-verified solves; race and challenge completion once only (d65be56)
- [x] ✅ LeetCode ownership proof before linking (e91a870)
- [x] ✅ Logout revokes; 15-minute access tokens; hashed refresh tokens; atomic rotation (82ebe8d)
- [x] ✅ Rate limiting per user or IP; strict on auth and joins (23c0fd3)
- [x] ✅ Input validation and bounded pagination everywhere (98fdd00)
- [x] ✅ dev-login impossible in production (82ebe8d; verified in the production image)
- [x] ✅ Scoped, revocable extension tokens (0ae7b58)
- [x] ✅ Dependency audit: 0 critical; the rest accepted with reasons (423de10)
- [x] ✅ Container runs as non-root; DB/Redis ports local-only (54a8bf4)
- [ ] ❌ CSP and security headers for the Netlify web app (B-10)
- [ ] ❌ Restrict Firebase API keys; enable App Check (SEC-28)
- [ ] ❌ Re-verify grandfathered LeetCode links (B-07)

## Reliability and data

- [x] ✅ Readiness/liveness endpoints; Render health check uses the DB-aware one (54a8bf4)
- [x] ✅ Graceful shutdown: in-flight syncs finish; timers cleared; stranded races recovered (93e1416)
- [x] ✅ One migration step per deploy, advisory-locked (54a8bf4)
- [x] ✅ Scheduled jobs run once across instances (68bc194)
- [x] ✅ LeetCode calls time out (10 s) and are paced (fb7a01c, 68bc194)
- [ ] 🔒 Backups confirmed and a restore drill done
- [ ] ❌ Activity table retention job (when it passes about 1M rows)

## Product correctness

- [x] ✅ Friends list and requests work; re-friending works (9ec739a)
- [x] ✅ Race live updates reach participants (8131a93, 7748ea9)
- [x] ✅ Streaks and "today" follow the user's timezone; the app sends it (c11c4c6, cf907d9)
- [x] ✅ Onboarding saves and exits; Create Squad really creates (cf907d9)
- [x] ✅ Token refresh is single-flight; sockets reconnect with fresh tokens (2f5a754, 6926af7)
- [ ] ❌ Push notifications: friend solves, streak reminders (B-04)

## Mobile and extension release

- [x] ✅ Builds on Flutter 3.44 (vendored Phosphor icons) (cf907d9)
- [x] ✅ Account deletion in the app (b7f4d42)
- [ ] ❌ Release signing key and build flavors (B-06)
- [ ] ❌ Play closed test: 12 testers for 14 days, then a production application (B-06)
- [ ] ❌ Chrome Web Store listing with privacy disclosure (B-09)

## Observability

- [x] ✅ Request IDs, failure logging, JSON logs (d5e8e76)
- [ ] ❌ Sentry (server) and Crashlytics (mobile) (B-03)
- [ ] ❌ Alerts: uptime, 5xx rate, sync failure rate (B-03)
