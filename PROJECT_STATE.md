# Project state

Updated: 2026-11-03 (Europe/Warsaw). Platformer adventure expansion implemented; automated and scoped real Studio tests pass. Broader runtime/device/release gates remain pending.

## Repository and milestone
- Repository: https://github.com/mfx-aristocrat/rollboxgame (PUBLIC, preserved); active GitHub account mfx-aristocrat.
- Working branch: develop. User merged PR #1; local main and origin/main verified at 260d22c90e57a43bf318b24a4b3353397823238a. Main now includes the earlier terrain/pickup/startup repairs. This user merge is not evidence that previously pending runtime gates passed.
- Expansion code **800d793ef72e442e6b881229e7ce0dbba350c028** committed/pushed to develop; both remote heads verified with ls-remote. [Draft PR #2](https://github.com/mfx-aristocrat/rollboxgame/pull/2) targets main. This evidence-only documentation checkpoint follows; inspect Git for the final documentation HEAD.
- Current task: M03-R2 AWAITING_VALIDATION. This explicit user request authorizes new platformer content alongside the earlier pending M03/M03-R1/M04 gates. M05 scored-route/purchase expansion and M06 release remain unfinished.
- Original brief preserved at Roblox_Game_Creation_Instructions.md. Design/scope before implementation: docs/platformer_expansion.md. Authoritative roadmap: game_creation_steps.md.

## Implemented expansion
- Six connected regions, adding Sunpetal Gardens and Cloudstep Mesa/crown. Bounds x[-560,560], z[-460,900]: 1120×1360 studs. Layered grassy cliffs, rounded hills, oversized flowers, cottages, clouds, arches and pennants. Original Training course and protected fall corridor retained.
- 30 golden tokens, four free fixed-reward crates, six landmark pennants, four spring pads. Source builders produce 603 landscape Parts and 120 adventure Parts, within 1100/240 caps; all scenery original, no external asset IDs or paid imports.
- Per-player, once-per-session exploration: token 1 / crate 5 / landmark 10 points, separate from coins/completions/profile. Death preserves finds; leaving resets. Server checks live character, range, duplicates and cooldowns; no new client reward remote.
- Springs use bounded speed 70 and two-second cooldown, preserve bounded horizontal motion, and refuse active scored delivery runs. Existing reward/movement validation remains.
- Source-built 24-part courier: red cap with parcel badge, red shirt, blue overalls, gloves, boots, eyes/nose/moustache. Idempotent R6/R15 attachments, massless/noncolliding, no movement/stat changes. Live character only; account avatar unaffected.
- EXPLORE HUD and personal collectible fading. Terra source review's compact row overlap fixed, session points clarified, CoreUISafeInsets explicit. Original E/Q/shop/delivery guidance retained.
- Practice saving remains disabled by default; profile schema/economy unchanged. No active purchases, game HTTP/security changes, cloud save/publish or public release.

## Verified checks and evidence
- [CI 41679099759](https://github.com/mfx-aristocrat/rollboxgame/actions/runs/41679099759), exact code head 800d793ef72e442e6b881229e7ce0dbba350c028: **Windows and Ubuntu SUCCESS**, repaired/expanded place artifacts uploaded. Draft PR remains unmerged; main is unchanged.
- Pinned Rojo 7.7.1 / Lune 0.11.1 archive hashes verified. scripts/check.ps1 PASS: 29 Luau compile, 121 standalone cases (37 persistence, 13 lifecycle, 20 gameplay, 18 pickup, 19 adventure, 8 world, 6 adventure-layout), Python driver syntax, serialized source/static Workspace property, two byte-identical builds.
- Current build: build/RollboxGame.rbxlx; SHA256 **48f48739bc345d2dc4a7285881065c014a6ba0575b92aae861f66aa53719a3a5**. Build version 0.4.0-platformer-adventure. No Luau type analysis or real-device performance claimed.
- Real Studio pickup suite: **14/14 assertions PASS**, E/Running/HUD/sustained parcel/no errors. Separate expansion suite: **21/21 PASS**, actual walking collection, stable duplicate score, far E/no crate reward, native E crate 5 points once, unchanged delivery economy, spring physics, outfit and death/respawn with collection preserved. Both suites cleaned exact tagged fixtures and verified absence.
- Real spring sample: upward speed≈42.70, maximum root Y≈16.49 from pad center Y=0.6; sampling occurs after the fixed 70 launch. This is not a performance benchmark.
- Initial expansion run failed two token assertions because the fixture sampled before walking/replication completed. Corrected fixture waits for actual root proximity and snapshot; first/duplicate snapshots now both 1 point. No gameplay scoring change for that timing correction.
- Sanitized initial/pass traces: docs/validation/platformer-adventure-initial.json, platformer-adventure-pass.json, platformer-pickup-pass.json. Full commands, per-gate limits: docs/studio_validation.md A01–A07.
- Normal Windows F5 desktop preview visibly showed cap/shirt/overalls/boots, grassy course, parcel prompt and readable exploration HUD. Front-angle outfit, all-region traversal, phone/gamepad, two-client isolation/fading and live scored-spring exclusion remain pending.
- Studio source synchronization preflight compared all changed existing scripts and editor buffers to repository base; originals backed up under ignored .tools/studio-pre-platformer.json. New/changed scripts read back after scoped Studio history edits. Full generated artifact separately checked. No unsaved unrelated source overwritten.

## Tools, delegation and session recovery
- Studio executable: LOCALAPPDATA/Roblox/Versions/version-7062aec9dbe74b14/RobloxStudioBeta.exe. Connected package robloxstudio-mcp 2.6.0, matching hash-verified plugin, loopback 127.0.0.1:58741; 69 tools, one discoverable Edit. Place 101188910650353 / universe 10774439666; visibility unverified, no publishing.
- Edit VM is separate from live tests. Use StudioTestService.EditModeActive for idle status; real server/client fixtures return evidence via EndTest. Empty MCP logs alone do not prove startup. Windows computer-use capture/F5 works this session; earlier denial is historical. Do not change security/privacy settings to obtain access.
- A local file-lock blocked checkout of Main.client.luau. Verified it exactly matched preserved develop, backed it up under .tools, renamed the locked file, then safely fast-forwarded main/develop. No user changes lost; no force push/reset.
- platformer_design requested Astra/xhigh but hit an account usage limit before edits; main completed the bounded design as fallback. platformer_world and platformer_gameplay requested Sol/high and completed disjoint source/tests. platformer_ui_review requested Terra/medium and completed source-only review. Overrides accepted; internal model identity not independently exposed. Main session settings were not changed.
- Previous M01/M02 completed; prior repair 77caa65 CI 41633735629 passed Windows/Ubuntu. Earlier research, persistence/security audit and pickup diagnosis remain in docs/Git history.

## Outstanding gates and exact next actions
0. Normal F5 preview was started after fixture cleanup. User input was detected during attempted camera review; avoid competing input. Rediscover/check actual Studio state before further source edits or tests, preserve unsaved work. Current source is in Studio Edit and local build; no cloud save claimed.
1. Run remaining A01–A07 checks: front camera, six-region walking loop/ramps/bridges, personal fade with two clients, live scored-run spring exclusion, phone landscape/portrait and gamepad controls. See docs/studio_validation.md; inspect actual Output and record outcomes.
2. Continue original R01–R06/S01–S09 delivery/fall/reward/mobile/multiplayer gates. Five unfamiliar testers (two touch): require 4/5 first delivery <3 minutes and correct explanation, 3/5 voluntary retry. Do not treat automated collection as those observations.
3. Private test experience/API configuration still needed for enabled persistence P01–P05. Follow docs/persistence.md with real distinct test/production universe IDs; keep production disabled. Named baseline phone/desktop, eight-player and memory/frame-time targets remain unmeasured.
4. Keep expansion on develop/draft PR until required gates pass; then validate and merge according to AGENTS. User's prior merge does not auto-pass pending tests. Public publishing or paid spending still needs explicit approval.
