# mitaLeet — Security Findings

Audit date: 2026-10-18 · Branch: `prod-readiness` · Scope: `apps/server`, `apps/mobile`, `apps/extension`, CI and deploy config.

**How findings were verified.** Each "Confirmed" finding was reproduced against a locally running server (Postgres 16 in Docker, `NODE_ENV=development`) before it was fixed, and each fix has an automated regression test in `apps/server/test/` that fails on the old code and passes on the new code. No production systems were attacked: against production the audit made only read-only `GET` requests (`/health`, an unauthenticated `/api/v1/users/me`).

**Severity.** Critical: compromises the product's core integrity or many users' data with trivial effort. High: unauthorized access or account/session compromise. Medium: limited exposure or abuse. Low / Info: hardening and context.

**Summary.** 30 findings: 4 Critical, 9 High, 10 Medium, 4 Low, 3 Informational. **All 4 Critical and 8 of the 9 High findings are fixed and regression-tested.** SEC-13 is open and needs your action (rotating a token). No real secrets were found in the git history.

## Findings

| ID | Severity | Finding | Evidence | Status / fix |
|---|---|---|---|---|
| SEC-01 | Critical | **Arbitrary XP minting through squad challenges.** `createChallenge` took `@Body() body: any`, so validation was skipped and the body was spread into Prisma. Any squad owner could set `xpReward: 1000000` and then self-complete the challenge. | Reproduced: 0 → 2,000,850 XP in 3 API calls. `gamification.controller.ts` (`body: any`), `challenge.service.ts` (`...data`) | **Fixed** `d65be56`. A DTO bounds `xpReward` to 10–150 and rejects unknown fields. Completion requires a LeetCode-verified solve inside the window and happens at most once. Test: `xp-integrity.e2e-spec.ts` |
| SEC-02 | Critical | **Unlimited XP from races.** `submitSolve` had no "already finished" check and no proof of a solve, so every repeat call paid out. | Reproduced: 4 calls → 4×201, 475 XP | **Fixed** `d65be56`. Finishing needs a verified solve made after the race start, can only happen once (atomic claim), and is ranked by LeetCode's own timestamp. Repeat calls get 409. |
| SEC-03 | Critical | **Fake solves through the extension endpoint.** `extension-solve` trusted the client's slug and timestamp (including future dates) and awarded XP and streaks. | Reproduced: a future-dated, unverified solve earned XP | **Fixed** `d65be56`. The endpoint is now only a hint: the server re-reads the user's accepted submissions from LeetCode. `SyncService` is the only code that writes `Solve` rows. |
| SEC-04 | Critical | **Claiming someone else's LeetCode account.** Linking (and `PUT /users/me/profile`) set `leetcodeVerified: true` with no proof of ownership, so a user could inherit a strong coder's solves and XP. | Reproduced via the profile endpoint | **Fixed** `e91a870`. A two-step flow puts a per-user HMAC code in the LeetCode "About me". The profile endpoint can no longer set the username. **Residual:** accounts linked before this change are grandfathered (see backlog B-07). |
| SEC-05 | High | **IDOR on squads.** Non-members could read a private squad's **invite code**, member list, leaderboard and activity. | Reproduced: `GET /groups/:id` returned `code` to an outsider | **Fixed** `e14a0b3`. `assertGroupMember()` returns 404 for non-members. Test: `authorization.e2e-spec.ts` |
| SEC-06 | High | **Subscribing to any squad's live events.** The socket `join_group` handler had no membership check. | Reproduced: an outsider received `activity_created` | **Fixed** `e14a0b3` (membership check before joining the room) |
| SEC-07 | High | **Joining another squad's challenge.** | Reproduced: 201 for a non-member | **Fixed** `e14a0b3` |
| SEC-08 | High | **Logout didn't log out.** Access tokens (7-day lifetime in `.env.example`) kept working after logout and logout-all, and sockets were never re-checked. | Reproduced: `/users/me` returned 200 after logout | **Fixed** `82ebe8d`. Every request and every socket handshake checks the session. Access tokens are 15 minutes. |
| SEC-09 | High | **No rate limiting anywhere.** Brute force against refresh tokens, squad invite codes and race codes, plus LeetCode scraping amplification. | Reproduced: 60 rapid requests, zero 429s | **Fixed** `23c0fd3`. Throttler keyed per user, else per IP. Strict limits on auth, joins, linking and sync. `trust proxy` is configured. On Render the client IP comes from Cloudflare's `CF-Connecting-IP` (be2b30a); verified live: 30 allowed, then 429, forged headers refused by Cloudflare. **Residual:** limits are in memory per instance (see SCALABILITY plan). |
| SEC-10 | High | **Refresh tokens stored in plaintext, and concurrent refreshes returned 500.** | Reproduced: statuses `200,500,500` | **Fixed** `82ebe8d`. 256-bit tokens stored only as SHA-256 hashes, atomic rotation; legacy rows are migrated on first use. |
| SEC-11 | High | **dev-login failed open.** Passwordless login (any username) was disabled only when `NODE_ENV` was exactly `production`. `railway.toml` doesn't set it. | Code review (`auth.service.ts`) | **Fixed** `82ebe8d`. Requires `ENABLE_DEV_LOGIN=true` and is never available in production. Verified in the production Docker image: 404. |
| SEC-12 | High | **Vulnerable dependencies:** 26 in production deps (2 critical, 14 high), including `ws`, `engine.io`, `socket.io-parser`, `websocket-driver`, `proxy-addr`, `multer`, `node-forge`, `protobufjs`. | `npm audit --omit=dev` | **Fixed** `423de10`: now 0 critical, 3 high, 8 moderate. The remaining items are accepted, see "Accepted risks" below. |
| SEC-13 | High | **A GitHub personal access token is embedded in the local git remote URL** (`.git/config` of the development machine). It isn't in repository history, but it's stored in plaintext and appeared in a tool log during this audit. | `git remote -v` | **Fixed (2026-10-18):** the token was removed from the remote, and GitHub now rejects it ("Invalid username or token"). Recommended anyway: check GitHub → Settings → Developer settings and delete it if it still appears. Original advice: revoke the token (GitHub → Settings → Developer settings → Personal access tokens), then run `git remote set-url origin https://github.com/Mitali-Patle/mitaLeet.git` and authenticate with `gh auth login` or a credential helper. |
| SEC-14 | Medium | **Deleting another user's push token** (`DELETE /users/me/devices/:token` had no owner filter). | Reproduced | **Fixed** `e14a0b3` |
| SEC-15 | Medium | **Unbounded queries and user enumeration.** `limit=100000000` was accepted, and an empty search returned every user. | Reproduced | **Fixed** `98fdd00`. Every list is capped at 100; search needs 2–50 characters and returns at most 50 results. |
| SEC-16 | Medium | **Unvalidated profile fields.** A 50 KB `displayName` and a `javascript:` `avatarUrl` (rendered by other users' clients) were accepted. | Reproduced | **Fixed** `98fdd00`: name 1–50 characters, avatar must be an `https` URL. |
| SEC-17 | Medium | **Google/Firebase token verification gaps.** `email_verified` wasn't checked, there was no algorithm allow-list, Firebase accepted any sign-in provider, and certificates were fetched on every login with no timeout. | Code review | **Fixed** `82ebe8d`: RS256 only, `email_verified` required, Firebase provider must be Google, certificates cached per `Cache-Control` with a 5 s timeout. Tests sign real RS256 tokens. |
| SEC-18 | Medium | **Self-reported race status `ACCEPTED`.** | Code review | **Fixed** `d65be56` (status is an enum without `ACCEPTED`) |
| SEC-19 | Medium | **Security logging gaps (OWASP A09).** No request IDs; failed requests and auth rejections weren't logged. | Code review | **Partly fixed** `d5e8e76`: request IDs, 401/403/429 logged with IP, JSON logs. **Open:** alerting and error tracking (backlog B-03). |
| SEC-20 | Medium | **Flutter web keeps tokens in browser storage.** `flutter_secure_storage` on web uses `localStorage`, so an XSS bug on the Netlify site could steal sessions. | Package behaviour | **Open.** Add a strict CSP on Netlify (backlog B-10); consider moving web sessions to httpOnly cookies later. |
| SEC-21 | Medium | **The extension used the app's own session token.** A full-power token was copied into the extension. | Code review | **Fixed** `0ae7b58`: scoped, revocable 90-day extension tokens, which get 403 on all other routes. |
| SEC-22 | Medium | **Inconsistent and failing timestamp handling caused 500s** (for example `solvedAt: "garbage"`). | Reproduced (V1) | **Fixed** `d65be56` (DTO validation → 400) |
| SEC-23 | Medium | **Privacy defaults.** The global leaderboard, user search and `GET /users/:username` expose every user's name, avatar and stats. Fine for a public product, surprising for a "private squads" product. | Code review | **Open: product decision** (backlog B-12) |
| SEC-24 | Low | **Socket.IO gateway has `cors: { origin: '*' }`.** Auth uses a bearer token in the handshake, not cookies, so cross-site socket hijacking isn't possible. | `events.gateway.ts` | Open, low. Restrict to the HTTP CORS allow-list when convenient. |
| SEC-25 | Low | **Race codes come from `Math.random`**, and a collision would cause a 500. | Code review | Open, low (retry on unique conflict; backlog) |
| SEC-26 | Low | **The container ran as root, and Compose published Postgres/Redis on all interfaces.** | `Dockerfile.local-only`, `docker-compose.yml` | **Fixed** `54a8bf4`: non-root `node` user, ports bound to 127.0.0.1 |
| SEC-27 | Low | **Error responses echoed full query strings in `path`.** | Code review | **Fixed** `d5e8e76`. Stack traces were never returned to clients (verified). |
| SEC-28 | Info | **Firebase client API keys in `firebase_options.dart`.** These are public identifiers by design, not secrets. | gitleaks | Recommend restricting them in Google Cloud (Android/iOS app and HTTP-referrer restrictions) and enabling Firebase App Check. |
| SEC-29 | Info | **The secrets scan found only placeholders** (`"..."` private keys in `.env.example` and the README) besides SEC-28. | gitleaks over full history | No action |
| SEC-30 | Info | **The product depends on LeetCode's unofficial GraphQL API.** That's a terms-of-service risk, and LeetCode could block the server's IP. | Architecture | Mitigated by pacing and rate limits (`68bc194`). Consider a legal review before monetizing (see PRODUCT doc). |

## Accepted risks (dependencies)

| Package chain | Severity | Why accepted | Revisit when |
|---|---|---|---|
| `prisma` (CLI) → `@prisma/config` → `deepmerge-ts` | High | Build-time and migration tooling that merges trusted local config. Not reachable from HTTP input. Already on the latest Prisma 6. | Prisma publishes a patched 6.x, or you upgrade to Prisma 7 |
| `firebase-admin` → `@google-cloud/firestore`, `@google-cloud/storage`, `google-gax`, `uuid` | Moderate | npm's only proposed "fix" is a major *downgrade* to firebase-admin 12. The `uuid` issue needs v3/v5/v6 with a caller-supplied buffer, which this app never uses (it uses v4). Firestore and Storage aren't used, only FCM. | firebase-admin ships updated Google Cloud deps |

## Validation

- Server: `npm run test:e2e` → **13 suites, 90 tests, all passing** (run repeatedly; one flaky timing case was traced to a real bug and fixed in `7748ea9`).
- Production Docker image checked locally: runs as non-root, migrates, `/health` reports the database ok, dev-login returns 404 with `NODE_ENV=production`.
- **Not verified:** these fixes aren't deployed yet (see `DEPLOYMENT_GUIDE.md`). There has been no third-party penetration test.

Security is an ongoing process. This report describes what was found and verified on 2026-10-18; it isn't a guarantee that no other issues exist.
