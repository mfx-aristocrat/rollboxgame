# Cannon mushroom, ocean and landscape expansion

User-authorized M03-R4 scope, defined before implementation, 2026-11-03. The full project brief remains `Roblox_Game_Creation_Instructions.md`; earlier runtime/release gates remain pending.

## Player experience

- A second, orange mushroom crate on the east trail unlocks an original cartoon cannon. The west mushroom continues to grant double jump. Both are independent, per-player session abilities, retained through respawn and reset on leaving.
- Aim and fire at colorful practice targets. Keyboard/mouse, gamepad and a visible touch action must have clear controls. Projectiles do not hurt players, award currency or alter the delivery economy.
- Native Terrain water lies below the floating landscape. Falling into it permits ordinary Roblox swimming. Four marked docks and gentle shore ramps connect the ocean to land. A server-validated return-to-shore action provides another way back.
- Falling below the course cancels an active delivery instead of teleporting immediately to a checkpoint. Earned coins remain. Wrong-gate recovery remains unchanged. This explicitly supersedes the old fall recovery behavior.
- Original source-built shoreline rocks, flowers, reeds, piers and landmarks improve the view without blocking the course or shared trails. No imported assets, paid content or account-avatar changes.

## Acceptance and required checks

1. Cannon: locked before collecting, live nearby player only, once per player; death retains and leaving resets. Server derives projectile origin, validates finite unit aim, applies cooldown and per-player/global caps. Segment raycasts prevent tunnelling. No player damage, knockback, economy grant or client-supplied hits/origins. Projectiles and connections clean up on leave/shutdown.
2. Controls: mouse/F, gamepad trigger and touch Fire action; focus, menus and shop suppress firing. HUD states show the two distinct unlocks and target hits. Existing native parcel/mushroom prompts remain usable.
3. Water: actual native Swimming state and movement after a fall; terrain solids and pre-existing water preserved by bounded air-only voxel updates. No global Terrain clear. Walk/swim up a connected ramp to safe grass. Return action rejects dry/dead/out-of-bounds/flood requests and resets jump approvals before teleporting to a fixed shore.
4. Falling delivery: cancelled before entering water, no reward or checkpoint skip; ability unlocks and earned coins preserved. Original pickup, gates, completion, double jump, respawn and floor separation still work.
5. Visuals: four identifiable shore exits, bounded scenery part count, no new coplanar walking faces or obstructed landing/collectible locations; inspect actual Studio view. Source and Rojo remain authoritative.

Automated: new pure/adapter cannon and shore rules tests; source-built water/scenery checks, air-only/idempotence preservation; existing suites; Luau compilation; two matching Rojo builds and CI. Studio evidence is separate: actual native E crate, live projectile/target hit and cooldown/locked rejection, fall-to-Swimming and horizontal motion, shore ramp traversal, return/cancellation, existing delivery/power-up regressions, captured client/server errors and fixture cleanup. Actual touch/gamepad and multiplayer checks remain pending until observed; do not infer them from adapters.

## Technical sources

- [Roblox Terrain](https://create.roblox.com/docs/reference/engine/classes/Terrain): bounded 4-stud ReadVoxels/WriteVoxels, native water.
- [Roblox Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid): Swimming state and normal swimming behavior.
- [Environmental terrain](https://create.roblox.com/docs/parts/terrain): native voxel terrain and water authoring.

Implementation details, exact bounds and observed results will be recorded after integration. No public publishing or stable-main promotion is implied by local builds.

## Implemented behavior and verified evidence

- Source version `0.6.0-cannon-ocean`. East orange crate `(92,11.625,24)` is independent of the west double-jump mushroom. Native E/ButtonX/touch prompt grants the per-player session cannon. Orange crate fades only for its owner; other players retain their opportunity. Three striped targets record session hits, without health/currency effects.
- Mouse click/F, gamepad R2, touch Fire action; mouse aim subtracts CoreUI inset, and controller/touch aims at the displayed crosshair's actual center. Separate CannonFire remote accepts exactly one aim vector. Server validates entitlement, life, finite near-unit direction, 0.4-second cooldown, six owner/48 global projectile caps; speed90/range150. Root-to-muzzle and continuous swept rays stop thin-wall tunnelling and exclude all player characters.
- Water fills only empty liquid channels in aligned 128-stud chunks over x[-640,640], z[-560,1000], y[-52,-12]. Existing solid material/occupancy and partial liquid remain unchanged. Four exits use level shore approaches before outboard ramps, grade<=0.25. Native water, 200 additional scenic Parts under350 budget, no global Terrain presentation changes. Props include rocks/reeds/flowers/picnic arrangements/lighthouse.
- Water rescue checks finite server root position and native liquid occupancy, uses fixed nearest shore locations and two-second cooldown, and is available before persistence restrictions. A 0.5-second admission interval bounds voxel reads. The deepest water probe stays inside the liquid slab so seafloor swimmers can still return. Teleports invalidate pending double-jump approvals. Swimming never counts as ground for jump recharge.
- Automated: **54 Luau compilation and 186 cases PASS**. Includes actual adapter firing/caps/cleanup, malformed/flood/life/range tests, input focus and aim inset, compact Shells/Fire separation, source floor separation, bounded geometry, mixed-channel preservation/idempotence, fall cancellation/rescue entrypoint and water jump reset. Repeated Rojo build source/mapping checks PASS. Build hash and Git/CI are in PROJECT_STATE.md.
- Real Studio single-client suite **27/27 PASS**. Native mushroom E, held cannon model present, native aimed F hit, invalid/focus/cooldown protection, no economy grant, projectile cleanup, actual walk off the Training shortcut, fall cancellation followed by Swimming and movement, R return, four shore traversals and respawn retention. Native mixed solid/partial liquid survives the production writer; empty cell fills once; deepest-water query passes. No captured server/client errors; exact owned fixtures cleaned. Trace: validation/cannon-ocean-pass.json.
- Initial failures are retained, not counted as passing: far E at depot accidentally started delivery before fixture teleport; default controls interrupted MoveTo; a direct path hit the parcel station; assertions sampled before the fall crossed the cancellation height; virtual cursor delivery needed one-frame settling before F. Corrected fixture drives actual Humanoid movement after default controls and waits for native Swimming. Source review also fixed real aim-inset and compact action overlap defects. Narrow native aim diagnostic is green (validation/cannon-aim-pass.json).
- Unit red/green caught a seafloor query sampling below water; source clamp and native seafloor-water probe now pass. The native channel test's first restore passed the extra ReadVoxelChannels `Size` metadata as a channel; fixture restore now lists only the three supported channels. Gameplay writer always wrote LiquidOccupancy only.

Actual controller/touch device, multiplayer cannon isolation/no-PvP and named-device performance remain pending. Adapter checks are not those tests. Existing earlier slice/persistence/five-tester/release gates also remain pending. This milestone is **AWAITING_VALIDATION**, retained on develop and draft PR; no main merge or cloud publishing.

Existing gameplay regressions on the cannon/ocean source: **23/23 power-up** (including complete powered25-coin delivery) and **22/22 adventure/floor** runtime assertions PASS, with no captured errors and fixtures cleaned. Traces: validation/cannon-powerups-regression.json and cannon-adventure-regression.json.
