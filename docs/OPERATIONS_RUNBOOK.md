# mitaLeet — Operations Runbook

For whoever is on call (today: the founder). Keep it short, keep it current.

## What exists today

| Signal | Where | Status |
|---|---|---|
| Readiness `/health` (checks Postgres, 3 s timeout → 503) | Render health check | Live after this branch deploys |
| Liveness `/health/live` | Any uptime monitor | Live after deploy |
| Structured JSON logs: one line per request with `rid` (request id), `uid`, status, latency; 401/403/429 warnings with IP; 5xx with stack | Render → Logs | Live after deploy |
| `X-Request-Id` on every response and in every error body (`requestId`) | Clients, support | Live after deploy |
| Error tracking (Sentry / Crashlytics) | — | **Not set up** (backlog B-03) |
| Uptime alerting | — | **Not set up** (backlog B-03) |
| Metrics / dashboards | Render service metrics (CPU, memory, bandwidth) | Built-in only |

### Set up first (about 30 minutes, free tiers)

1. **Uptime alert:** in UptimeRobot or Better Stack, monitor `https://mitaleet.onrender.com/health` every 5 minutes and alert your phone after 2 failures. This also stops a free instance from sleeping (cron jobs only run while the instance is awake), but upgrading the instance is the real fix.
2. **Error tracking:** add a Sentry project with `@sentry/nestjs` for the server and Firebase Crashlytics for Flutter. Report only 5xx and crashes, and scrub request bodies.
3. **Render notifications:** turn on email/Slack for deploy failures (Settings → Notifications).

## Alerts worth acting on

| Alert | Threshold | First action |
|---|---|---|
| `/health` failing | 2 consecutive checks (10 min) | §1 Outage |
| 5xx rate | > 1% of requests over 15 min, or any burst > 20/min | §2 Failed requests |
| p95 latency | > 1.5 s for 15 min | §4 Slowness |
| 429 spike from one IP or user | > 300/hour | §6 Suspicious activity |
| Sync failures | > 20% of `SyncJob` rows `FAILED` in an hour | §5 LeetCode sync |

Don't page on CPU blips or single 500s.

## 1. Service outage

1. Open `https://mitaleet.onrender.com/health`.
   - **No response or a Render error page:** check Render status (status.render.com) and the service's Events tab. On the Free plan, the first request after 15 idle minutes takes about a minute; that's not an outage.
   - **503 with `database: unreachable`:** go to §3.
2. If a deploy happened in the last hour: **roll back first, debug second** (Render → Events → previous deploy → Rollback).
3. Check Logs for `ERROR` lines around the start time, and use the `rid` to follow one request.
4. Afterwards, write a five-line postmortem: what happened, impact, root cause, fix, and what prevents a repeat.

## 2. Investigating a failed request

A user reports an error. Ask for the time, or for the `requestId` shown in the error body.

1. Render → Logs → search for `rid=<requestId>`. That gives method, path, status, latency and user ID.
2. For 5xx, the line just before it has the stack trace (`HttpExceptionFilter`).
3. For 4xx, the response `message` explains it. Common cases:
   - 409 on race or challenge completion: LeetCode doesn't show the accepted submission yet. Wait for sync or tap again.
   - 429: rate limited.
   - 401: the session ended. The app refreshes automatically; if refresh fails, the user signs in again.
4. Reproduce locally against the test database with `npm run test:e2e`, then add a regression test with the fix.

## 3. Database problems

- **Symptoms:** `/health` returns 503 `database: unreachable`; logs show `PrismaClientInitializationError`, `P1001` or `P1017`, or `Too many connections`.
- **Checks:**
  1. The provider's status page and console: is the database up, and is storage full?
  2. Connection count: Render `basic-256mb` allows 100 connections, and each app instance opens a Prisma pool. On the Free plan, check that the database hasn't hit the **30-day expiry**.
  3. Has `DATABASE_URL` changed? (Env change → redeploy.)
- **Too many connections:** lower the pool size (`?connection_limit=10` on `DATABASE_URL`) or use the provider's pooled endpoint.

### Restore from backup (RTO target ≤ 2 h)

1. Restore into a **new** database: Render PITR (Dashboard → database → Recovery) or `pg_restore` of the latest dump (DEPLOYMENT_GUIDE §7).
2. Spot-check row counts (`User`, `Solve`, `Group`).
3. Point `DATABASE_URL` at it; that triggers a redeploy, and migrations run idempotently.
4. Keep the broken database until you've verified the new one.

**Targets:** RPO ≤ 24 h (daily dump) today; ≤ 5 min with paid-plan PITR. **Run a restore drill once a quarter.** A backup that has never been restored doesn't count.

## 4. Slowness and unexpected resource use

1. Render Metrics: is CPU or memory pinned? Memory creeping up and then a restart suggests a leak. The in-memory leaderboard cache and presence maps are bounded by user count.
2. Logs: sort slow `HTTP` lines by latency. Known heavy endpoints are `GET /analytics` (reads all of a user's solves) and the global leaderboard for non-`alltime` periods (`groupBy` over solves).
3. Large spikes at :00 and :30 are the scheduled LeetCode sync (5 users at a time, a 2-second gap between starts) and the 5-minute leaderboard broadcast.
4. A 512 MB instance (Starter) is the floor; see SCALABILITY_AND_COST_PLAN for the next step.

## 5. LeetCode sync problems

- `SyncJob` rows marked `FAILED`, with errors in `error`; nobody's solves update.
- **LeetCode may be blocking or rate-limiting the server IP.** Logs show `LeetCode API 403/429`. Raise `LEETCODE_RATE_LIMIT_MS` (for example to 5000) and wait. Don't hammer it.
- **Unofficial API changes** show up as GraphQL errors in logs (`LeetCode GraphQL error`). The queries live in `apps/server/src/modules/leetcode/leetcode.client.ts`.
- Rows stuck in `RUNNING` older than 30 minutes are from an instance that died mid-sync. They're harmless, and new syncs aren't blocked after 10 minutes.

## 6. Suspicious activity

- Search logs for `429` and `401`/`403` warnings, grouped by `ip=` and `uid=`.
- **Credential stuffing:** this isn't possible (Google sign-in only). Refresh-token guessing is limited to 30/min per IP.
- **XP anomalies:** XP now only comes from verified solves, races and challenges. Investigate with:
  ```sql
  select "userId", count(*) from "Activity" where type in ('CHALLENGE_COMPLETED','LEVEL_UP') and "createdAt" > now() - interval '1 day' group by 1 order by 2 desc limit 20;
  ```
- **Compromised user session:** revoke it with SQL `delete from "UserSession" where "userId" = '<id>';`. That signs them out everywhere, including extension tokens, immediately.
- **Leaked `JWT_SECRET`:** rotate it in Render (everyone has to sign in again), then review the logs.

## 7. Failed deploys

1. Render → Events → the failed deploy → build log.
   - **`nest build` / TypeScript errors:** CI should have caught them. Run `npm run typecheck` locally.
   - **`prisma migrate deploy` failed:** read the error. A failing migration leaves the old version serving traffic. **Never** run `prisma migrate reset` against production. Fix the migration in a new commit, or resolve with `prisma migrate resolve` after checking the database by hand.
2. A deploy whose `/health` never returns 200 is never switched to, so the old version keeps serving.

## 8. Routine

| When | Task |
|---|---|
| Weekly | Skim errors and 429s, check `SyncJob` failure rate, review user feedback |
| Monthly | Merge Dependabot updates after CI passes; run `npm audit --omit=dev`; review costs |
| Quarterly | Database restore drill; rotate any shared credentials; re-read this runbook |
| Every release | Smoke tests (DEPLOYMENT_GUIDE §5) |

## Incident checklist

- [ ] Acknowledge and note the start time
- [ ] Roll back if a deploy happened recently
- [ ] Is `/health` up, and is the database up?
- [ ] Post a short status note to users if the outage lasts more than 15 minutes
- [ ] Fix, verify with the smoke tests
- [ ] Postmortem (5 lines) plus one preventive task in the backlog
