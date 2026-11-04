# Project state

Updated 2026-11-04 (Europe/Warsaw). Cannon/ocean implementation and single-client runtime checks are verified. The user has now authorized a graphics overhaul and requested `graphic_improvement_plan.md`; that is now the active task, tracked in `graphic_improvement_plan.md` (G01 IN_PROGRESS).

## Repository and delivery

- Repository `mfx-aristocrat/rollboxgame`, PUBLIC visibility reverified and preserved. Active branch develop. Main/origin/main remain `260d22c90e57a43bf318b24a4b3353397823238a` (user-merged PR #1).
- Previous develop checkpoint `8feabd4cfd85947abae24d697181ecc6aaa6d29b`; mushroom code `b82ab2114a07a7494e1a7a30c2e87f3fd6ffd1a2`, Windows/Ubuntu CI41726985838 passed. Earlier floor/expansion/persistence evidence remains in feature docs and Git history.
- Cannon/ocean code **e06982b478b425c1db33266291398ae9d1c5e87c** committed/pushed to develop; both remote heads verified. Windows/Ubuntu CI **41817684416** (push) and41817678860 (PR) both SUCCESS for that exact head. [Draft PR #2](https://github.com/mfx-aristocrat/rollboxgame/pull/2) remains OPEN/DRAFT develop→main. No merge while required device/multiplayer/broader release gates remain pending.
- Roadmap M03-R4 **AWAITING_VALIDATION**, as are earlier M03/M03-R1/R2/R3 and M04 gates. M05/M06 release work remains gated. A passing build is not a runtime/device/release pass.
- Full project brief: `Roblox_Game_Creation_Instructions.md`; roadmap: `game_creation_steps.md`; current feature contract: `docs/cannon_ocean_expansion.md`. AGENTS already references the full brief and requires no correction.

## Verified implementation

- Version `0.6.0-cannon-ocean`: independent east orange mushroom crate `(92,11.625,24)` unlocks original three-part held practice cannon. Per-player/session, survives respawn, leave resets. Mouse/F, gamepad R2, touch action; proper pointer/crosshair coordinate spaces; compact action slots separated. Three targets count hits, no PvP/damage/knockback/coins/profile changes.
- Server-origin projectiles: finite unit direction only; exact one-argument remote, admission/cooldown, six owner/48 global cap, speed90/range150, root-to-muzzle and swept collision rays, all characters excluded, cleanup on death/leave/shutdown. Independent firing limiter preserves Q/jump controls.
- Native ocean x[-640,640],z[-560,1000],y[-52,-12]. Bounded liquid-channel-only writes into empty cells preserve authored solids/partial liquid, rebuild idempotent. Four real shore exits with level approaches then grade<=0.25 ramps. 200 original scenic Parts (budget350): rocks, reeds, flowers, piers/buoys, lighthouse, picnic props. No global terrain presentation reset.
- Falling below course cancels active delivery and permits swimming; earned coins/abilities stay. Wrong-polarity checkpoint recovery unchanged. R/Y/Return to shore checks actual native water, fixed nearest landing, two-second cooldown/admission; available before save restrictions, invalidates pending jump approvals. Seafloor water probe stays within liquid slab.
- Existing red mushroom remains separate: one server-approved owner-applied double jump, nonce/epoch/character checks, no water-as-ground recharge, reset on Swimming. Nine Grass course tops,144 safe decorative blades, zero exposed conflicting floor planes. Six exploration regions,30 tokens/four crates/six flags/four springs, per-session score separate from coins. Training remains25 coins exactly.
- Practice saving stays disabled; no purchases, external imported assets, cloud publishing, experience visibility changes or security setting changes.

## Validation evidence

- `scripts/check.ps1`: **54 Luau compile,186 standalone cases PASS**, Python driver syntax, source mapping/static Workspace property, two byte-identical Rojo builds. Rojo7.7.1/Lune0.11.1 archive hashes verified. 1Script/1LocalScript/29ModuleScripts.
- Build `build/RollboxGame.rbxlx` SHA256 **aae06e0fbd0152b2af146610817dd137b729458bf4b3236d43f24f6bdbc342aa**. No type-analysis or hardware-performance claim.
- New real single-client Studio **27/27 PASS**: native orange-crate E/F target hit, locked/far/malformed/focus/cooldown, no reward, projectile retirement, actual Training shortcut fall then native Swimming/movement, R return, four shore traversals, respawn retention, native mixed-channel preservation/idempotence and seafloor probe. Client/server errors empty; exact owned fixtures CLEANED. `docs/validation/cannon-ocean-pass.json`.
- Regressions on cannon/ocean source: **23/23 power-ups PASS**, including full powered Training delivery exactly25 coins; **22/22 adventure/floor PASS**. Both captured no client/server errors and cleaned fixtures. `docs/validation/cannon-powerups-regression.json`, `cannon-adventure-regression.json`.
- Initial failures/diagnosis retained separately: depot E unintentionally started delivery in fixture; client MoveTo interfered with controls; a direct route hit depot; fall sampled before Y threshold; virtual mouse requires settled delivery before F. Narrow native aiming diagnostic3/3 passed. Review fixed real aim-inset and compact action overlap; unit red/green fixed seafloor probe. Feature docs separate fixture errors from gameplay defects.
- Desktop views inspected grass/course, native water, outfit/HUD and shore approach during live tests. Actual phone/gamepad/multiplayer/performance remains pending. Previous mushroom two-client run verified independent unlocks but aggregate input failed due background VirtualInput and Player2 CoreGui ChatScript initialization; do not claim complete multiplayer pass.

## Studio, source and delegation

- Studio executable under LOCALAPPDATA/Roblox/Versions/version-7062aec9dbe74b14. Place101188910650353/universe10774439666. No publishing; experience visibility unverified. Old robloxstudio-mcp2.6.0 loopback127.0.0.1:58741, Editinstance b85122d2-bf0e-42d0-9915-9e167561003e.
- Added official Studio MCP now discoverable; instance d0deec7a-347b-463c-a8e0-41032d2023c3, identity/state must be checked before use. Native material generation/live VM access may support graphics task; no generation results claimed yet.
- Existing Studio source/editor buffers matched repository base before initial16-script scoped sync; exact originals backed up under ignored `.tools/studio-pre-ocean.json`. Subsequent client/shore diffs reviewed, captured and applied only if unchanged; full source/editor readback verified. Unrelated Studio work preserved. Generated maps remain source-authoritative; never set restricted Workspace destroy height from runtime scripts.
- Cannon modules/tests and ocean/scenery modules/tests delegated with requested Sol/high overrides (accepted). Design/security and integration review requested Astra/xhigh (accepted); found and resolved aim/compact issues. Internal model identity not independently exposed. Main settings unchanged. Parent integrated, tested, maintained docs/Git. No fallback needed this revision.
- Prior delegates/limits and detailed historical repair evidence remain in Git history/feature docs. Existing original security/persistence constraints still apply.

## Exact next actions

1. Verified cannon/ocean code e06982b is pushed and CI green; update draft PR #2/state with the graphics scope as it progresses. Keep stable main unchanged while mandatory gates remain pending.
2. Execute new user graphics task: create `graphic_improvement_plan.md` with observable sequential milestones and iteration criteria, inspect actual tools/materials/current renders, preserve gameplay, then implement and compare real Studio views. Record provenance and source export for generated materials; no invented asset IDs or unsupported quality claims.
3. Complete O05/O06/O07: actual controller/touch shooting/aim/swim/return, multiplayer independent unlock/fade/no-PvP, named-device rendering/startup/frame/memory. Earlier jump/device/six-region traversal, full multiplayer, five unfamiliar testers (two touch), private persistence P01–P05, eight-player/performance/release gates remain pending.
4. Final handoff must record running/idle Studio state and zero owned test fixtures, current source/build/commits and exact next actions. At this checkpoint regression tests finished and cleaned; inspect current Studio before further mutations.

Public release and paid spending still require explicit approval; user-authorized reversible game/graphics/source work proceeds autonomously.
