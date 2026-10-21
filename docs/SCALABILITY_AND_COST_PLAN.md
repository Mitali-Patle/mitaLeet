# mitaLeet — Scalability and Cost Plan

**Principle:** run the smallest setup that is reliable, and move up a stage only when a measured trigger fires. The app hasn't been load-tested against production, so **no user capacity is claimed here.** The numbers below are planning estimates, labeled as such.

Prices are from [render.com/pricing](https://render.com/pricing) and [render.com/docs/free](https://render.com/docs/free), fetched 2026-10-18. Check them before buying.

## How the system spends resources

| Driver | Where | Scales with | Notes |
|---|---|---|---|
| Scheduled LeetCode sync | `SyncService.scheduledSync` every 30 min | **linked users** | About 3 LeetCode calls plus some DB writes per user per run. Max 5 concurrent, 2 s gap between starts (`68bc194`). |
| On-demand verification | extension-solve, race and challenge completion | active solvers | Throttled to once per user per 15 s; requests share one in-flight check |
| Leaderboard broadcast | every 5 min, all squads | number of squads | One query per squad, then a socket emit |
| Hourly streak check | every hour | users with a streak > 0 | One timezone lookup and one update per user |
| API requests | all clients | DAU × screens | Cheap indexed queries. `GET /analytics` reads all of one user's solves. |
| WebSockets | presence, live feed, races | concurrently online users | One persistent connection per open app |
| Database connections | Prisma pool per instance | instances | `basic-256mb` allows 100 connections |

### The first bottleneck: LeetCode, not the server

The scheduled sync processes users one after another, paced for politeness. With roughly 3–5 s per user, 5 at a time and a 2 s gap between starts (an estimate, not measured), one 30-minute run covers on the order of 900 users before the next run starts. Somewhere beyond a few hundred linked users:

1. Sync runs start to overlap with their own schedule.
2. The server IP will likely be rate-limited by LeetCode, since this is an unofficial API.

**Mitigations, in order:** sync active users more often and dormant users less (for example skip users with no app activity in 7 days, or sync them every 6 h); rely on extension-triggered verification for real-time updates; cache problem metadata (already done); only after that, consider a worker per region or IP.

## Stages

| Stage | When | Setup | Monthly cost (list price) |
|---|---|---|---|
| **0 — today (risky)** | — | Render Free web service (sleeps after 15 min idle, about 1 min to wake, so cron jobs don't run while asleep), database unknown (**Free Render Postgres expires after 30 days**) | $0 |
| **1 — launch** | Before inviting real users | Render **Starter** web service (512 MB, 0.5 CPU) **$7** · Render Postgres **basic-256mb** (100 connections, 1 GB SSD, PITR) **$6** · Netlify free for Flutter web · UptimeRobot/Sentry free tiers | **about $13** |
| **2 — growing** | Any trigger below | Web service 1 CPU / 2 GB **$25** · Postgres 1 GB tier **$19** | about $44 |
| **3 — multi-instance** | One instance can't keep up even after stage 2 | 2+ web instances (horizontal *autoscaling* is listed as a Pro-workspace feature; check whether manual instance counts suit you) + Redis-compatible Key Value + a separate worker service for sync | Price at the time |

Bandwidth: the Hobby workspace includes 5 GB/month, then $0.15/GB. API payloads are small JSON, so this is unlikely to be the first cost.

### Upgrade triggers (measure first, then move)

- **To stage 1:** before real users. This isn't optional: sleeping instances skip cron jobs, and a free database can expire.
- **To stage 2 (web):** p95 latency > 800 ms for a day at normal load, sustained CPU > 70%, or memory > 80% / OOM restarts.
- **To stage 2 (database):** storage > 70%, connections > 70 of 100, or slow queries > 200 ms in logs.
- **To stage 3:** stage-2 limits are hit *and* profiling shows the web process (not the database or LeetCode) is saturated.

### Prerequisites already done for horizontal scaling

- Stateless HTTP auth: JWTs plus DB-backed session checks, no in-process sessions.
- Scheduled jobs run once per tick across instances (Postgres advisory locks, `68bc194`).
- Migrations are safe with several instances (`prisma migrate deploy` is advisory-locked).
- Health checks for load balancers: `/health` (readiness, checks the DB) and `/health/live`.
- Graceful shutdown on SIGTERM (`93e1416`).

### Still needed before running more than one instance (backlog B-08)

| In-memory today | Problem with N instances | Fix |
|---|---|---|
| Socket presence map; `emitToUser` uses it | Events for a user connected to another instance are lost | `@socket.io/redis-adapter` and emitting to the existing `user:{id}` rooms |
| Rate-limit counters | Limits become N× looser | `@nestjs/throttler` Redis storage |
| Leaderboard cache (5 min) | Each instance computes its own | Acceptable, or move to Redis |
| Race countdown timers | Countdown lost if that instance dies (recovered at startup, `93e1416`) | Acceptable; or schedule via the DB or a queue |
| Quick-sync throttle and in-flight map | Per instance, so slightly more LeetCode calls | Acceptable |

**Redis is not needed at stages 1–2.** Add it only for stage 3.

## Cost controls to set up now

- **Render:** Workspace → Billing → set a spend notification. Keep autoscaling **off** until stage 3.
- **Database:** turn on storage alerts. Each `Activity` row is small, but the feed grows forever. Add a retention job (for example delete activities older than 180 days) once the table passes about 1M rows.
- **External APIs:** the LeetCode API is free but rate-limited (see above). FCM is free. Google Sign-In is free.
- **Sentry:** keep it on the free tier with a sample rate ≤ 0.2 for performance events.
- **CI minutes:** the workflow builds a debug APK on every push. If minutes become a concern, run it on PRs only.

## Load-testing plan

Never test against production or LeetCode. Use a staging service with its own database, plus `FakeLeetCodeClient`-style stubs (`LEETCODE_GRAPHQL_URL` can point at a mock server).

1. **Tool:** [k6](https://k6.io/) (or Artillery). Seed 1,000 users with squads, friends and solves.
2. **Scenarios** (ramp 10 → 50 → 100 → 200 virtual users over 10 min each, then back down):
   - Browse: `GET /users/me`, `/leetcode/stats`, `/activities/feed`, `/gamification/leaderboard/friends`
   - Social: friend search, squad detail and leaderboard
   - Realtime: 200 socket connections joining squad rooms; measure fan-out latency of `activity_created`
   - Sync storm: trigger `scheduledSync` with 1,000 linked users against the mock LeetCode server
3. **Measure:** requests/s, p50/p95/p99 latency, error rate, CPU and memory, DB connections, slowest queries (`pg_stat_statements`), and recovery time after the ramp ends.
4. **Targets for launch:** p95 < 500 ms for reads, < 1 s for writes, error rate < 0.5% at the expected peak (assume 10% of users online at once).
5. Record the first bottleneck and add the next step to the backlog.
