# Switchback Couriers — initial release design

Decision: 2026-11-03, Europe/Warsaw. Working title, subject to name availability. Selection and evidence: [market_research.md](market_research.md). This is the intended behavior and acceptance contract; **it is not a claim that implementation or playtests are complete**. The roadmap and project state track actual delivery.

## Scope and player promise

Deliver bright power parcels across rooftop routes by switching between **Amber / sun** and **Cyan / moon** to match the next gate. Read ahead, choose a safer crossing or a faster jump, recover quickly, and improve your own delivery time. Earn parcel appearances through play. Purchase cosmetics only if desired.

Assume one developer, no advertising budget, no external artist, and original geometry/UI generated from source. Use ordinary Roblox character movement and one extra action. The game must be enjoyable alone; up to **8 players** share the hub and routes asynchronously. Other players cannot steal parcels, block a gate, change another player's polarity or reset their progress. Avatar collisions should not obstruct runners. Visible peers and trying routes together provide light social play; party systems and co-op-dependent puzzles are deferred.

## Central mechanic and run lifecycle

1. At a route's depot, interact to take a parcel. The server creates a unique run ID, records route/start time, sets polarity to Amber, and expects gate 1.
2. Press **Q** or the large **Switch** touch button to toggle Amber/Cyan. Both show a symbol and text as well as color. Server enforces a **0.5-second cooldown**; this is not a resource and never costs currency.
3. Cross gates in their authored order with matching polarity. A gate is a visible frame/trigger, not a client-controlled unlock. The server verifies the expected gate, alive character, position, polarity and feasible timing before advancing.
4. Wrong polarity returns the character to the preceding safe checkpoint with an explanatory message and brief feedback. The timer continues. A fall also returns to the last safe checkpoint without deleting the parcel; a full character reset/death abandons the current run and offers a free restart.
5. Reach the destination after all gates to deliver. Server awards **25 coins**, increments completedRuns once, updates the route's personal best, and shows the result. The run becomes complete before another completion request can grant anything.
6. Retry immediately, choose another unlocked route, or equip/buy a cosmetic using earned coins. Coins never run out in a way that blocks play.

Every route has a safe path. One optional shortcut between two mandatory gates trades a harder jump for a shorter time; both paths reconverge before the next gate. No gate can be skipped for a valid delivery. The first route teaches polarity with safe landings before later routes ask for faster reading. Avoid blind jumps or forcing a first-time player to switch in mid-air.

Practice and scored attempts use the same controls. A route taking more than **3,600 seconds** is ended without a time record or delivery reward; restart is free. No stamina, paid retries, offline production, RNG loot, trading or real-money power. Timer precision may be finer internally, but UI displays readable seconds. Medal targets are configurable per route and must be tuned after actual playtests, not presented as measured difficulty.

## First minute and first ten minutes

| Time | Intended experience | Evidence to capture |
| --- | --- | --- |
| 0–10 seconds | Spawn facing a lit depot; see “Take a parcel. Match the gate.” and a clear interaction prompt. No shop or purchase popup. | Time until the player moves toward the correct object; first-input delay. |
| 10–25 seconds | Take the training parcel, see Amber/sun on parcel and first gate, cross it and receive immediate confirmation. | Pickup and first-gate completion. |
| 25–60 seconds | Next gate shows Cyan/moon; one contextual hint explains Q/Switch. Player changes polarity and experiences the remaining course or a recoverable mistake. | Correct toggle, confused attempts, fall/recovery. Target first delivery around a minute; acceptance allows three minutes. |
| 1–4 minutes | Complete two deliveries, receive 50 coins and buy/equip Mint for 50 coins. Best-time feedback makes improvement visible. | One complete action → reward → cosmetic progression cycle. |
| 4–10 minutes | Third delivery unlocks Rooftops in the full release. Try its route choice, improve a time, or keep practising Training; optional friends play alongside. | Voluntary retry, route choice, understanding of the next unlock. No forced ten-minute session. |

Short-term goals: next gate, complete a delivery, beat a personal time, earn the first shell. Longer-term goals: unlock all three routes, earn route medals and complete the three earned cosmetic shells. The first release is deliberately finite; replay comes from mastery and friends, not an obligation to log in daily. Future daily challenges must avoid lost-streak punishment.

## Content, controls and presentation

| Item | Early slice | Initial release after slice validation |
| --- | --- | --- |
| Environments/routes | One compact rooftop Training route (`training`), four gates Amber/Cyan/Amber/Cyan | Same environment extended to three routes: Training (4 gates), Rooftops (`rooftops`, 6), Skybridge (`skybridge`, 8). Distinct layouts and skyline color areas reuse assets. |
| Route unlock | Training available immediately | Rooftops after 3 completed deliveries; Skybridge after 10. Unlocks derive from completedRuns. |
| Cosmetics | Default and Mint, fully equipable | Default, Mint, Sunset, Aurora; optional Supporter pass shell. |
| UI | Pickup/current gate, polarity/cooldown, timer, coins, next unlock, result/retry and one cosmetic cycle | Route selection, complete cosmetic catalog, personal bests/medals and settings. |
| Saving | Session-only slice may display Practice mode explicitly | Versioned persistent profile and clear load/save failure behavior required. |

Desktop: default movement/jump/camera, E or normal prompt activation for depots, Q to switch. Touch: default movement/jump plus one at least **64×64 UI-unit** Switch button placed away from the jump/camera controls; use touch-compatible prompts and tap buttons. Large hit areas, readable text, responsive safe-area layout and no hover-only actions. Verify landscape phone at 640×360 and 844×390 and desktop at 1280×720; UI units are layout targets, not guarantees of physical finger size.

Amber is always accompanied by sun/“A”; Cyan by moon/“C”. Use shape/text markers even if lighting or color perception changes. Preserve normal camera freedom; avoid strobe effects, forced camera shake or tiny timing-only instructions. Feedback: parcel glow, short gate pulse, completion banner, unobtrusive cooldown fill. Provide reduced-effects and sound toggles if effects/audio are added. No audio asset is required for understanding or completion. Initial sound may remain off until original/licensed clips exist; no unverified asset IDs.

Visual direction: clean toy-scale rooftops, bold courier signage, pale sky, charcoal walkways and clear safety rails. Author parts, materials, lighting and vector/text UI in code. No Toolbox imports, third-party characters, branded imagery or dependency on uploaded art. Later asset additions require origin and license records.

## Economy and persistence contract

All values are centralized configuration and can be tuned after the slice. Earned coins buy appearance only; nobody pays to unlock a route or improve movement, timer, payout or polarity cooldown.

| Cosmetic ID | Cost/access | Benefit |
| --- | --- | --- |
| `default` | Free, always owned | Base parcel shell |
| `mint` | 50 coins | Mint shell; first full progression cycle in two successful deliveries |
| `sunset` | 150 coins | Sunset shell |
| `aurora` | 300 coins | Aurora shell |
| `supporter` | Optional permanent pass | Exclusive shell appearance only; no multiplier or badge of gameplay superiority |

Profile schema v1: `coins` and `completedRuns` non-negative integers capped at 1,000,000,000; `tutorialComplete` boolean; `cosmetics` an allowlisted ownership map; `equippedCosmetic` an allowlisted owned ID; `bestTimes` an allowlisted route-ID map of finite positive **seconds**, maximum 3,600. Keep schemaVersion/session metadata in the storage envelope. Default is always owned. Pass entitlement is verified independently with Roblox; a cached profile entry alone must not authorize the Supporter shell.

Persist tutorial completion, earned coins, completed deliveries, earned ownership/equipment and personal bests. Do not persist active runs, cooldowns or character positions. A reconnect starts at the hub without a pending reward. Purchases of earned cosmetics debit and grant in one profile mutation. Cosmetic purchases require loaded writable data; repeated purchase requests cannot double-charge.

Use a server-only persistence adapter with version checks, validated profile data, bounded retry/backoff and `UpdateAsync` session ownership. A stale server must never overwrite a newer owner's progress. Unknown schemas or malformed profiles fail closed instead of becoming empty defaults. Only a genuinely absent record becomes a new profile. Test and production use separate experience/store configuration; Studio access belongs to a private test experience. Roblox documents that Studio can otherwise access live stores and that calls can fail. ([Data stores](https://create.roblox.com/docs/cloud-services/data-stores))

Load failure: clearly labeled unsaved Practice mode or retry screen, with saved progression/cosmetic transactions disabled; never write defaults over inaccessible data. Save failure: show that progress is not confirmed saved, retry within a bounded policy and stop further progression if ownership is lost. Define and disclose the autosave recovery window (target ≤60 seconds); never claim absolute zero loss across a server crash. Normal leave/shutdown attempts a final save without blocking forever. Tests must distinguish clean disconnect, crash loss window, failed save and stale-session takeover.

## Optional Robux product and enablement gate

Only one proposed product: **Supporter Parcel**, permanent game pass, cosmetic-only, configured as `SupporterPassId`. Default ID is **0 / disabled**, with no active purchase button. Price is a Creator Dashboard decision, not a hard-coded fictitious number. Query current product metadata for display. Do not prompt automatically or during onboarding/failure recovery.

After private publishing, create the pass under Creator Dashboard → Creations → this game → Monetization → Passes, upload an original icon, describe the cosmetic benefit, configure its price/sale status, and copy its real ID into the central server configuration. Verify the correct game's ID and entitlement behavior before enabling. Server checks ownership on join and refreshes it after a matching completed prompt. Ownership lookups can fail; keep the cosmetic unavailable and offer retry rather than trusting a client claim. Passes use ownership handling, not developer-product receipt fulfillment. ([Passes](https://create.roblox.com/docs/production/monetization/passes))

No consumables/developer products in the initial release. If added later, scope durable receipt-ID deduplication, product/player validation, atomic persisted grants, retries and failure tests using server `ProcessReceipt`; a prompt-completion event alone is insufficient. ([Developer products](https://create.roblox.com/docs/production/monetization/developer-products))

Monetization stays disabled until success, cancellation, duplicate prompt events, reconnect, ownership service failure and unavailable profile behavior are tested in supported Roblox flows. No paid test spending or public release is implied by implementation. Free content can be validated while account-dependent purchase checks remain pending; a product-enabled release cannot.

## Architecture and authority

Use Luau, a pinned Rojo project and a reproducible `.rbxlx` artifact. Source-generated world/UI/configuration is authoritative; Studio edits must be translated back into source before they are part of a release. Use the repository's pinned toolchain and test commands rather than undocumented global versions. No third-party runtime framework is necessary.

| Boundary/module | Responsibility and contract |
| --- | --- |
| Shared configuration | Immutable route IDs/layouts/gate sequences, economy, cosmetic allowlist, cooldowns and message shapes. Clients may read presentation values; server remains authoritative. |
| Pure run/progression rules | Run state transitions, next-gate validation, completion idempotency, time/medal rules, unlocks and atomic cosmetic purchases. Runnable without Roblox services for deterministic tests. |
| World builder | Reproduce hub, routes, gate frames/triggers, safe checkpoints, depots, signs and destination from source. Geometry and config must share the same route/gate IDs. |
| Server gameplay adapter | Player lifecycle, active run and monotonic timer; trusted spatial checks, safe recovery, server-owned polarity and reward grants; sends sanitized snapshots. |
| Profile/persistence boundary | Validated versioned profile, ownership lock, retry/save/release and in-memory fake adapter for failure tests. Only this boundary talks to DataStoreService. |
| Purchase boundary | Marketplace ownership verification and disabled-ID gate; no gameplay advantage and no client-authorized entitlement. |
| Client input/UI | Keyboard/touch input, readable prompts/HUD/result/cosmetic controls, local visual feedback. Sends intents, never a reward amount or an authoritative completion/time. |

States: `Idle → Running → Completed → Idle`; abort/reset returns to Idle. Wrong gate/polarity does not advance Running. Bind interactions to a live character and active run; clean connections/state on leave and respawn. Use explicit identifiers, reject unknown/oversized/malformed payloads and rate-limit every client-triggerable operation, including prompts. Initial intent limits: switch accepted at most twice/second, start/equip/purchase at most twice/second with a small bounded burst; tune only when UX evidence requires it.

Validate ordered gates, depot/destination proximity, server elapsed time and plausible movement. Roblox character movement may be client-owned, so `Touched` or a proximity prompt alone is not proof of a valid delivery. Use server spatial sampling/validated crossings and elapsed-distance checks with generous latency tolerance; reject/reset an invalid run without automatic bans. Gate triggers must not award duplicate progress when several body parts touch. This is a bounded anti-abuse foundation, not a claim of cheat-proof movement. Roblox explicitly requires validation of client inputs, context and timing. ([Client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary))

Prefer event-driven work with a bounded shared spatial sampler where needed; avoid an unbounded loop per object. Keep the first environment compact and mostly anchored. Diagnostics record run validation failures, save failure categories and lifecycle errors without credentials or raw purchase secrets. Later production analytics may record pickup, first correct switch, first delivery, retry and cosmetic equip; do not fabricate analytics availability before the experience is configured.

## Early slice gate — before substantial content

Build Training, the four ordered gates, one shortcut, switching/recovery, essential UI, delivery reward and Mint purchase/equip. This is the smallest complete representative loop. Integrate persistence through the adapter independently, but do not let it delay the first playable mechanic.

Required automated checks: toggle cooldown; wrong/correct/out-of-order gate; early/duplicate destination; one reward per run; route unlock thresholds; 50-coin Mint purchase and duplicate/insufficient balance requests; malformed/spammed intents; reset/leave cleanup; repeatable build and expected script hierarchy.

Required Studio checks: fresh profile completes pickup → switch → delivery twice → Mint equip; incorrect polarity/fall recovers; reset cancels safely; two clients have independent runs/rewards/polarity; touch and keyboard complete the course; no errors in Output. Then observe **five first-time testers, at least two on touch**: four deliver within three minutes without spoken instruction, four can explain polarity, and three voluntarily retry. Record counts and observations rather than inventing statistical confidence. Execute and record these checks in [studio_validation.md](studio_validation.md). The coordinator may use structured manual instructions when account access is unavailable, but instructions are not test results.

If clarity or interest fails, revise gate spacing, switch feedback, shortcut value or control placement and repeat the affected tests. Reduce the mechanic if touch overload is the cause. Do not add routes or cosmetics to hide a failed central loop. Keep M03 `AWAITING_VALIDATION` until runtime and player-observation gates pass.

## Measurable initial-release acceptance

| Gate | Required evidence |
| --- | --- |
| Complete free game | All three routes and all four free shells work; a fresh player can unlock routes without Robux; correct polarity/ordered gates matter; all routes offer free recovery and retry. |
| Progression and abuse | Automated boundary tests pass; malformed, duplicate, out-of-order and rate-exceeding requests cannot add coins, unlock content, shorten a valid recorded time or change another profile. |
| Persistence | Fake-store migration/load/save/retry/ownership/conflict tests pass; published private new/returning player tests retain coins, runs, cosmetics and best times; failed load never overwrites data; stale owner cannot save. |
| Multiplayer/lifecycle | Two-client runtime tests pass for independent progress, simultaneous gates, leave/rejoin, death/reset, and one player's disconnect during another's delivery; eight-player load smoke test has no repeated errors or stuck runs. |
| Mobile usability | New-player loop passes on touch emulator and at least one real baseline phone; 640×360, 844×390 and 1280×720 show essential HUD with no overlap/clipped buttons; symbol/text identification works without relying on color. |
| Performance | Name the actual phone/OS and connection in evidence. Target p95 client frame time ≤33.3 ms during a ten-minute eight-player session on that phone; p95 ≤16.7 ms on the named desktop target. No out-of-memory/crash, no sustained memory growth over a 20-minute repeat loop. Measure real hardware: emulator is not memory proof. ([Performance guidance](https://create.roblox.com/docs/performance-optimization/design)) |
| First impression | Slice observation thresholds pass; later route expansion adds no forced tutorial/shop interruption. First interactable appears within ten seconds after character spawn on tested devices. |
| Optional purchase | Disabled configuration exposes no working purchase action. Enabling Supporter requires verified ID/metadata, ownership/cancel/reconnect/failure tests, correct cosmetic-only grant and no duplicate grant side effects. |
| Reproducibility/deployment | Clean pinned setup/build succeeds; generated place opens in Studio; private published smoke test passes; content maturity/audience settings and current publishing eligibility are verified for the owner. New games default to restricted access; public release requires explicit approval. ([Publishing](https://create.roblox.com/docs/production/publishing/publish-games-and-places)) |
| Handoff | Required checks and limitations recorded in project state/roadmap; release commit/build checksum recorded; validated work pushed and merged according to the Git workflow. |

Performance numbers are **project targets**, not Roblox requirements or achieved results. If a device fails, optimize or formally narrow supported hardware with evidence; do not mark the same gate passed by substituting a desktop test. If Studio, account configuration or testers are unavailable, independent implementation may continue but the associated milestone and release readiness stay pending.

After private launch testing, record early bounce, first delivery, voluntary replay and day-1/day-7 returns with cohort sizes and source. These are product learning measures, not additional invented “industry standard” release numbers. Re-evaluate the demand hypothesis before advertising expenditure or a large expansion.

## Deferred expansion and planning transition

Backlog: further routes, alternate polarity patterns, cooperative relay mode, ghosts/leaderboards, original sound/music, cosmetic events and carefully scoped localization. Excluded now: pets, inventories of hundreds of items, trading, procedural worlds, custom avatar physics, PvP, paid skips, randomized paid items, subscriptions, daily streak penalties and consumable products.

Concept, architecture and slice plan are established by this document. Routine gameplay work can use `gpt-6.1-sol` / `high`; the main chat's setting changes only through the client. Persistence, purchase processing, security and difficult multiplayer diagnosis should use the project's requested `gpt-6-astra` / `xhigh` delegation where available. The coordinating agent records actual accepted assignments and fallback limits.
