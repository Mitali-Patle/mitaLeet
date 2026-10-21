# mitaLeet — Product, Growth and Monetization

There is no user data yet, so **everything about demand below is a hypothesis to test**, not a finding. Facts about what the product does come from the code.

## What the product is (from the code)

mitaLeet turns solitary LeetCode practice into a **social, competitive habit for small friend groups**:
- verified LeetCode solves feed **streaks, XP, levels, ranks and achievements**
- **squads** (invite-code groups) with leaderboards, a live activity feed and timed squad **challenges**
- **live 1v1–4 races** on one problem
- **friends**, presence (online or solving), analytics, and a Chrome extension that reports "Accepted" instantly

**Core value proposition (hypothesis):** *"You'll actually keep grinding LeetCode because your friends can see whether you did."* The product sells accountability and friendly competition, not content.

**Likely first audience (hypothesis):** CS students and early-career developers preparing for placements and interviews, in friend groups or college coding clubs. Indian users are a plausible early market, given the timezone work and the context, but this needs checking.

## Strongest existing features and the main friction

| Strength | Why it matters |
|---|---|
| Squads with invite codes | Built-in viral loop: every squad brings 3–10 people |
| Verified solves (since `d65be56`) | Leaderboards are trustworthy, the precondition for competition and for anything paid |
| Races | A distinctive, shareable moment |
| Streaks in the user's own timezone | The daily habit hook |

| Friction | Fix |
|---|---|
| LeetCode linking needs an "About me" code | Necessary for trust. Keep the copy-paste flow smooth and explain why it's needed. |
| Push notifications aren't wired | **Highest-impact next feature (B-04):** "Priya solved Two Sum", streak-at-risk reminders |
| Free hosting sleeps (about 1 min cold start) | Stage-1 hosting before launch (about $13/month) |
| Android only, not yet in the Play Store | Closed test (12 testers × 14 days) can start now |

## Metrics (keep the list small)

Track these with privacy-respecting product analytics, for example PostHog. Disable session recording, avoid sending names or emails, and use the user ID only.

| Metric | Definition | Initial target to aim for (hypothesis) |
|---|---|---|
| **Activation rate** | % of new sign-ups who, within 48 h, link LeetCode **and** join or create a squad **and** get one verified solve | 40% |
| **Week-1 retention** | % of an activated weekly cohort with ≥1 verified solve in days 7–13 | 35% |
| **WAU** | Users with ≥1 verified solve in the last 7 days | grow week over week |
| Squad health | % of squads with ≥3 members where ≥2 solved this week | 50% |
| Viral coefficient | Squad joins per squad created | > 2 |
| Extension adoption | % of WAU with an active extension token | 25% |
| Reliability | 5xx rate, sync failure rate | < 0.5%, < 5% |

Events to send:
- `signed_up`
- `leetcode_link_started` / `leetcode_linked`
- `squad_created` / `squad_joined`
- `solve_verified` (with source: sync or extension)
- `race_started` / `race_finished`
- `challenge_completed`
- `streak_extended` / `streak_broken`
- `extension_token_created`

## Growth plan

**Product changes (build these):**
1. **Push notifications (B-04).** Friend-solve alerts (batched, with mute settings) and a streak-at-risk reminder in the user's local evening. This is the retention engine.
2. **Shareable weekly recap card.** "Squad Grinders: 47 problems this week, Priya #1". It's an image, built for WhatsApp, Instagram and LinkedIn.
3. **Faster first value.** Pre-fill the LeetCode handle from onboarding (done), auto-join a squad from an invite link (deep link), and show history-import XP immediately after linking.
4. **Squad templates for college clubs:** a "75-day DSA challenge" made of pre-set squad challenges.

**Marketing experiments (test cheaply, measure activation):**
1. **Campus seeding.** Give 5 coding clubs a free "club squad" plus a weekly leaderboard post. Measure activation and week-1 retention for each club.
2. **Communities:** r/leetcode, r/developersIndia, LinkedIn build-in-public posts, and Discord study servers. Lead with the race feature and a recap image.
3. **Referral nudge:** "Invite 2 friends to unlock the squad leaderboard". Check that it raises the viral coefficient without hurting activation.

## Monetization hypotheses

**Don't build billing yet.** First validate that people return weekly (week-1 retention ≥ 30%), then test willingness to pay with the experiments below.

| Model | Target customer | What they'd pay for | Pricing hypothesis | Free vs paid line | Cost to serve | Complexity / risk |
|---|---|---|---|---|---|---|
| **A. Individual "Pro"** | Serious interview-preppers | Streak freezes (the `streakFreezes` field already exists in the schema), full history and deeper topic analytics, custom race rules, profile cosmetics | ₹99–149 / $3–5 per month (test) | Free: everything social. Pro: convenience and depth, never "see your friends" | Very low per user | Low–medium; **Google Play requires Play Billing for in-app digital subscriptions** |
| **B. Club / cohort plan** | College coding clubs, bootcamps, placement cells | Admin dashboard, cohort progress reports and CSV export, scheduled challenge series, large squads | ₹1,000–3,000 / $15–40 per cohort per month (test) | Free: squads up to N members. Paid: bigger squads plus reports | Low | Medium (invoicing, sales); best fit for B2B |
| **C. Institution licence** | Training companies, universities | Placement-prep tracking at scale, SSO, data export | Annual contract | — | Medium (support) | High (sales cycle, privacy agreements) |

**Recommended first experiment:** the **club plan (B)**. It sells to one decision-maker who already runs a group, and needs no payment code. Offer three coding clubs a manual "pilot" (weekly CSV and leaderboard report generated by script) for a token fee or a signed letter of intent. If 2 of 3 say yes, build the admin dashboard. In parallel, run a **fake-door "Pro" button** (tap → "coming soon, join the waitlist") to measure click-through among WAU, with no charge.

**When payments are built:** use Stripe or Razorpay for web and club plans, and **Google Play Billing** for in-app Android subscriptions. Verify on the server with signed webhooks only (never trust a client "success"), handle webhooks idempotently by event ID, keep entitlements in the database, and handle refunds, cancellations and failed renewals. Get local tax advice (GST in India).

## The biggest business risk

The product depends on **LeetCode's unofficial GraphQL API** and on reading profiles. LeetCode could rate-limit, block or change it, and its terms may restrict this use, **especially once you charge money**. Before monetizing:
- get a short legal review of LeetCode's terms of service for this use case
- reduce dependence: the extension captures solves on the user's own machine; add platforms with official APIs (for example Codeforces) so the product is "competitive coding with friends", not "a LeetCode wrapper"
- consider asking LeetCode about a partnership once there are users

None of this guarantees users or revenue. It's a plan to find out cheaply.
