# Market research and concept decision

Decision date: **2026-11-03, Europe/Warsaw**. Research clock check: 2026-11-02 23:12:54 UTC, which is 2026-11-03 locally. This is bounded desk research, not a player study. The recommendation is **provisional until the vertical slice passes the playtest gates in [game_design.md](game_design.md)**.

## Evidence and limits

Sources were accessed on 2026-11-03 local time. A retrieval date does not make an indexed metric live. Only primary Roblox pages, creator-authored store descriptions and the store platform's own review aggregate inform the decision. No competitor retention, conversion, revenue or acquisition cost was available.

| ID | Source and period | Verified observation | What it can establish |
| --- | --- | --- | --- |
| S1 | [Roblox Charts, all devices/locations](https://www.roblox.com/charts?SortFilter=default&TimeFilter=0&nl=true). Search index marked **crawled last week**; exact sample timestamp absent. Direct text fetch only returned a JavaScript-required shell. | Indexed Top Playing Now included Steal An Egg 1.2M, Murder Mystery 2 462.5K, Brookhaven 247.6K, RIVALS 166.1K, 99 Nights in the Forest 158.6K, and Blox Fruits 142.1K. The same snapshot also listed escape/climbing, fishing and dress-up titles. | Rounded, delayed concurrent-player observations, not live counts, visits, sales or a complete market share estimate. Current chart positioning is accessible only with this limitation. |
| S2 | [Roblox 2025 Replay](https://about.roblox.com/newsroom/2025/12/roblox-replay-decoded-search-style), December 2025. Search methodology: Jan 1–Nov 9, 2025; top-search analysis used a 1% random sample. | Brookhaven, Grow a Garden and Steal a Brainrot led searches; older and newer games appeared across genres. Mobile searches leaned toward horror, escape and obby content. The report also discusses multiplayer searches and seasonal Halloween demand. | Historical platform search interest and device preference; no proof of a new game's audience, player retention or spending. |
| S3 | [Roblox discovery announcement](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), published June 15, 2026. | Roblox announced expansion from a 7-day to a 28-day recommendation view, including day 8–28 behavior. | Current strategic direction favors lasting player value; does not disclose a guaranteed distribution threshold. |
| S4 | [Creator Hub: Discovery](https://create.roblox.com/docs/discovery), living documentation, fetched for this decision. | Signals include early bounce, play days, playtime, intentional co-play and spending. Roblox recommends accurate original metadata and says closely resembling existing games can reduce visibility. | Build comprehensible, replayable gameplay and truthful original presentation; monetization alone is insufficient evidence of quality. |
| S5 | [PEAK on Steam](https://store.steampowered.com/app/3527290/PEAK/), creator-authored description and Valve review display, fetched for this decision. Released June 16, 2025. | Describes solo/co-op climbing and changing challenges; displayed 94% positive among 6,399 reviews in the rolling last 30 days. | An adjacent-platform signal for social traversal and mastery with continuing review activity. Reviews are not sales, CCU or retention; PC willingness to pay does not transfer to Roblox mobile. |
| S6 | [Creator Hub: Design for performance](https://create.roblox.com/docs/performance-optimization/design), living documentation. | Recommends a real baseline low-end device and cautions that Studio device emulation does not reproduce its memory behavior. | Mobile performance must be measured on hardware; a small primitive-based world reduces scope but is not proof of performance. |
| S7 | [Creator Hub: Passes](https://create.roblox.com/docs/production/monetization/passes), living documentation. | Passes support one-time privileges, with server handling and ownership lookup. | A permanent cosmetic pass fits the proposed release without repeatable consumable fulfillment. |

Roblox Investor Relations returned HTTP 403 during this research. Search surfaced third-party copies of a 2026 quarterly letter, which were **not used as verified platform totals**. A guessed session-locking documentation URL was inaccessible and is not used as an authority. This avoids treating a secondary extract or a broken link as checked primary evidence.

### Metrics must remain distinct

- **CCU** counts simultaneous players at a moment; event spikes can dominate it.
- **Visits/plays** are cumulative or period-specific starts, including return visits. They are not unique users.
- **DAU** counts distinct daily players; a platform average does not size a new game's addressable market.
- **Likes/reviews** are votes from a self-selecting group. They do not measure return behavior.
- **Retention** measures a defined cohort returning after a defined interval. None was available for competitors.
- **Revenue, bookings and Robux spending** have different definitions and periods. None can be inferred from chart rank or CCU; no revenue estimate is made here.

### Interpretation

**Observation:** social worlds, collection/progression, survival and action coexist in S1/S2. Some names appear in both the 2025 search report and the recent indexed chart. **Inference:** those broad motivations have more durable support than any single meme. This overlap is not a longitudinal retention study. The recent chart is heavily competitive, and post-Halloween sampling may overstate horror demand.

**Design hypothesis:** short, readable traversal with a learnable extra action, visible mastery and optional shared play can serve part of the mobile obstacle audience. A concise visual hook is easier to demonstrate in a truthful thumbnail or short creator clip than a complex economy. Neither creator reach nor discovery impressions are forecast.

**Scope implication:** avoid competing on enormous pet inventories, licensed characters, shooter fidelity, live admin events or constant resource inflation. A solo developer can instead validate one reusable mechanic and a small course before committing to ongoing content production.

## Four feasible original concepts

All names are working titles; originality here means the proposed mechanic/theme combination, not a trademark or exhaustive prior-art clearance. Assumption: one developer, no paid assets, no established audience, no recurring live-operations staff. All concepts support free solo play and optional cosmetic spending.

| Concept | Audience, evidence and one-sentence hook | Loop and first session | Replay, differentiation and monetization | Difficulty and main risks |
| --- | --- | --- | --- | --- |
| **Switchback Couriers** | Mobile/desktop obstacle players; S2's mobile obby interest and S5's adjacent traversal signal. **Deliver a power parcel by switching its Amber/Cyan polarity to pass a sequence of matching gates.** | Pick up a job, read the next symbol, switch, cross gates, deliver, earn coins, equip a parcel shell. First tutorial job teaches both polarities; the next course offers a safer path and a faster jump line. | Improve route times and medal results; unlock two harder routes by deliveries, buy cosmetic shells. The parcel/gate state creates a timing and route-reading decision, beyond walking through checkpoints. One optional permanent cosmetic pass. | Medium: server gate sequence/timing and forgiving recovery, three compact authored routes. Main risk: toggling feels trivial, or touch control plus jumping feels overloaded. |
| **Tiny Tidal Garden** | Collection/cozy players; simulation searches in S2 and collection titles in S1. **Arrange floating planters so the next predictable tide waters a useful chain.** | Place a planter, inspect a water forecast, rearrange, harvest, buy a new planter shape. First session teaches a two-planter chain and unlocks one visual theme. | Reusable placement puzzles and cosmetic raft themes, permanent decoration pass. Differentiation is spatial planning instead of waiting for a timer. | Medium: placement UI, persistent layouts and expansion balancing. Strong incumbent competition; content/economy may overwhelm the puzzle; less social action. |
| **Beacon Crew** | Small-group survival/co-op players; 99 Nights in S1/S2, co-op traversal in S5. **Carry portable light between safe islands before a shared fog closes the route.** | Choose a salvage route, manage light, retrieve parts, return and upgrade camp visuals. Solo scaling is mandatory; first session completes one short expedition. | Route modifiers, cooperation and camp cosmetics; optional lantern appearance pass. No horror IP or player theft. | High relative to solo capacity: group state, fog readability, failure/rejoin logic, solo balance. Strong hook but larger testing and operational burden. |
| **Conveyor Café** | Puzzle/management players; broad simulation demand in S2, indirect rather than direct evidence. **Flip conveyor junctions to deliver snack orders through a compact rooftop kitchen.** | Read an order, switch two junctions, serve, get coins, improve a score and decorate. First session solves one static layout then a timed order wave. | Pattern mastery and three layouts; decorative kitchen/pass. Spatial timing distinguishes it from simple tap-to-serve. | Medium: server item movement and touch targeting, layout authoring. Split attention may be hard on phones; resemblance to existing kitchen management games and weak direct demand evidence. |

## Weighted decision matrix

Scale: 1 = poor fit/high risk, 3 = workable with material uncertainty, 5 = strongest fit/lowest risk. Higher is always better. Total = sum(weight × score / 5), maximum 100. Scores are judgment, **not measured market probabilities**.

| Criterion | Weight | Switchback Couriers | Tiny Tidal Garden | Beacon Crew | Conveyor Café |
| --- | ---: | ---: | ---: | ---: | ---: |
| Solo delivery feasibility | 25 | 4 | 4 | 2 | 4 |
| Evidence of audience demand | 20 | 3 | 4 | 4 | 3 |
| Replay/mastery without large content output | 20 | 4 | 3 | 4 | 4 |
| Distinctive demonstrable hook | 15 | 5 | 3 | 4 | 3 |
| Mobile clarity/accessibility | 10 | 4 | 5 | 3 | 4 |
| Optional fair monetization fit | 5 | 4 | 4 | 3 | 4 |
| Low ongoing operational burden | 5 | 5 | 3 | 2 | 4 |
| **Weighted total / 100** | **100** | **80** | **74** | **65** | **73** |

Feasibility receives the largest weight because unfinished games cannot test demand. Demand and replay together receive 40% so cheap implementation does not dominate usefulness. Differentiation matters for a crowded catalog, while a small pass catalog can be added after fun is demonstrated. The weakest evidence is concept-specific demand; no sources directly validate these original concepts.

**Sensitivity:** reducing Couriers' differentiation score by one point yields 77, still ahead. Reducing both its feasibility and differentiation by one yields 72, below Garden and Café. Thus a technically awkward or uninteresting polarity mechanic invalidates the recommendation; do not compensate by adding more courses. Test a simplified switch cadence or reconsider the runner-up.

## Recommendation and decision gate

Select **Switchback Couriers** for the early vertical slice. It fits the existing repository's obstacle-game starting point while adding a central state-changing mechanic, keeps production to source-generated geometry, and gives a concrete skill progression without paid power. The selected design and acceptance criteria are in [game_design.md](game_design.md).

Build **one route, one mechanic, one reward-to-cosmetic cycle first**. Observe five first-time testers, at least two using touch, before substantial content expansion. Require four to deliver a parcel within three minutes without spoken instruction, four to explain polarity correctly, and at least three to voluntarily retry. These are small-sample product gates, not statistically significant market validation. Record failures and revisions. Do not promise popularity, retention or revenue.

After a private pilot, inspect onboarding completion, early exits, session length and return cohorts separately. Report sample sizes and acquisition sources. Collect at least 100 new-player sessions before drawing directional funnel conclusions; inspect day-1/day-7 return cohorts only after their windows mature. Use results to decide whether to revise, expand or stop. There is no fabricated industry retention benchmark or discovery guarantee.

## Research provenance

The delegated research task was assigned `gpt-6-astra` with `xhigh` reasoning by the coordinating agent. This document records that assignment, not an independently inspected model runtime or a change to the main chat's settings. Research used official pages through web retrieval; no gameplay, runtime playtest, paid purchase or public publishing occurred as part of this task.
