# Studio validation evidence and procedure

No Studio runtime tests have been performed. All rows start PENDING. Fill actual outcomes, build SHA, tester/device, date, Output logs and screenshots; record failures before revisions. Automated checks are recorded separately in PROJECT_STATE.md.

## M03 slice gates

Build/open: run `./scripts/check.ps1`, then open `build/RollboxGame.rbxlx` in Studio. Confirm Explorer contains ServerScriptService/Server/Main, ReplicatedStorage/Shared and StarterPlayerScripts/Client/Main. Start a playtest; the source-generated scene/UI should appear without manually inserted assets.

| ID | Action | Expected observation | Result |
| --- | --- | --- | --- |
| S01 | Join as a new player, read HUD, start the training delivery | Clear next action; character and camera usable; parcel state and next gate shown | PENDING |
| S02 | Traverse all four ordered gates, switching with Q | Matching polarity passes; wrong polarity recovers to the previous safe checkpoint; no skipped gate reward | PENDING |
| S03 | Finish delivery, then complete a second run | Exactly 25 coins per run, total 50; one earned cosmetic can be bought/equipped; faster best time updates | PENDING |
| S04 | Reset/die mid-route and start again | Run abandoned safely, no completion reward, existing earned coins preserved, free restart available | PENDING |
| S05 | Start server with two clients; progress at different rates | Independent polarity/checkpoints/rewards, no player can block another, UI stays personal | PENDING |
| S06 | Use phone landscape and portrait Device Simulator; repeat loop with touch | Switch/action targets readable and reachable, no overlap with movement/jump or Roblox controls, no clipping | PENDING |
| S07 | Send invalid action payloads / spam actions from a local test client | Server ignores invalid/rate-limited actions, no invented rewards or negative coins; test tooling excluded from release | PENDING |
| S08 | Watch Output throughout join/loop/death/two-client play | No runtime errors, stuck yields or orphaned UI/connections | PENDING |
| S09 | Five unfamiliar testers, at least two touch; no spoken instruction | At least 4 deliver within 3 minutes and explain polarity; at least 3 voluntarily retry | PENDING |

S09 is a small-sample concept gate, not proof of retention. Record time-to-start, time-to-first-delivery, wrong-gate attempts, voluntary retries and quotations without personal information. If thresholds fail, revise the slice mechanic/onboarding before expanding content.

## M04 persistence gates

Use a private test experience with explicit test store/environment. Confirm no production store access. Check docs/persistence.md for current adapter API/configuration before running.

| ID | Action | Expected observation | Result |
| --- | --- | --- | --- |
| P01 | Earn rewards/equip a cosmetic, leave, reconnect after save | Coins/completions/equipment/best time retained exactly once | PENDING |
| P02 | Deny API access or inject a load failure in a separate test copy | Clear failure state, no writable default, no accidental overwrite | PENDING |
| P03 | Two test servers contend for the same test user key through a controlled harness | Only one owner; stale owner cannot save after expiry/takeover | PENDING |
| P04 | Inject save failures then restore service in a separate test copy | Visible unsaved state, bounded retry, successful recovery; no claim of save until confirmed | PENDING |
| P05 | Respawn, disconnect during loading, and close private server with active players | Cleanup and bounded shutdown saving; returning data consistent | PENDING |

## M05/M06 release gates

Runtime content expansion is gated on S01–S09. Later validate configured cosmetic pass success/cancellation/rejoin/service failure; never use real paid tests without approval. Measure the game on an identified real lower-end mobile device (target >=30 FPS) and desktop (target >=60 FPS), with at least two clients; record hardware and actual memory/frame timing. Emulation only tests layout/input, not real mobile memory/performance. Ensure a 15-minute session has no growing connection/UI/object count or material frame degradation.

Those two-client/15-minute checks are preliminary smoke tests. Final release targets from game_design.md require **eight players**, p95 client frame time <=33.3 ms on the named baseline phone and <=16.7 ms on the named desktop over ten minutes, plus a 20-minute repeated-loop memory-growth check. Report measurements; average FPS alone does not establish a p95 frame-time target.

## Access attempt record

2026-11-03: the user installed/signed into Studio. Its executable exists, and computer-use listed its open window. `get_window_state` was refused with **“Computer Use was not approved to use Roblox Studio”** after the user's explicit retry request. No window screenshot, source execution, new-player run or playtest result was obtained. Enable Studio in computer-use permissions, or run the procedures manually and record actual evidence. Opening Studio alone did not clear this restriction.

## M03-R1 — Feedback revision checks

User observation on 2026-11-03: the game starts, but E did not appear to pick up the visible box. This is useful launch/interaction feedback, not a pass for the complete loop. Source diagnosis is recorded in pickup_diagnosis.md. A fresh Studio capture attempt after this report was still refused by computer-use permissions.

Stop the old playtest, reopen the rebuilt `build/RollboxGame.rbxlx` (or synchronize the updated source with Rojo), then start F5. Generated scenery appears when the server runs; keeping an older open place does not load rebuilt scripts automatically. Do not overwrite unrelated Studio work to open the new local build.

| ID | Action | Expected observation | Result |
| --- | --- | --- | --- |
| R01 | Approach the parcel box from both sides, including the 12-stud range boundary; try E, native prompt and Take parcel | HUD, prompt and server agree on actual box range; one front-held parcel appears, HUD says CARRYING PARCEL | PENDING |
| R02 | Move out of range; then spam pickup while carrying; try with chat/shop focused | Out-of-range feedback; no duplicate parcel/reward or timer reset; no unintended pickup while typing/in modal | PENDING |
| R03 | Two clients take parcels from the same station | Shared station remains; each receives its own parcel/run and clear HUD | PENDING |
| R04 | Walk from hub side exits through Meadow, Coast, Redstone and Frostpeak, including both connecting bridges | Continuous paths/ramps, readable signs, no trapped movement or obstructed spawn/station; distinct explorable terrain | PENDING |
| R05 | Complete all original Training gates, safe detour and shortcut; fall at several points, reset and retry | Gate order/reward unchanged; falling recovers before any new terrain catches the runner | PENDING |
| R06 | Use phone landscape/portrait and gamepad prompt; inspect pickup/box/camera and expanded map performance | Input and carried box remain readable/usable; no errors; record actual frame/memory measurements rather than inferring performance from part count | PENDING |

R01–R06 are required before accepting this revision's runtime behavior. Existing S01–S09 and persistence/release gates still apply.

Account eligibility, maximum player count, private access, maturity questionnaire, actual pass ownership and private published app testing remain external configuration gates. Use docs/deployment.md. No public release is authorized.
