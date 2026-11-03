# Source-generated exploration world

Scope authorized 2026-11-03: enlarge the environment while retaining the Training slice and its pending runtime gates. This environmental expansion does not add scored routes, unlocks, rewards or purchases.

## Acceptance contract (before implementation)

- Generate an approximately 920×920-stud landscape containing four visibly different, explorable regions: Willow Meadow/forest, Tidal Coast/lagoon, Redstone Heights and Frostpeak Uplands.
- Connect every region to the depot with broad continuous walking paths, gentle ramps and bridges. Exploration starts from the hub's sides; the four Training gates and shortcut remain intact.
- Keep terrain and scenery out of the course's protected fall corridor. Falling from Training must cross the configured recovery height before reaching any new ground.
- Keep spawn, parcel station and their approach clear. Station geometry and prompt range derive from `Config.pickup`; route origin derives from `Config.route.depot`.
- Author the complete world in deterministic numeric layout plus anchored Roblox parts. Replace only `Workspace.SwitchbackWorld`; never clear Roblox Terrain or other workspace content. Water is a decorative noncollidable blue glass surface with shore/dock access, not a swimming simulation.
- Use original geometry and Roblox built-in materials only; no uploaded assets or third-party licenses. Bound generation to a fixed number of parts, with no per-frame world loop.
- Automated checks establish finite world bounds, connected region access, path width/grade/continuous endpoints, distinct elevations, protected fall clearance, and spawn/station clearance. Compile all Luau and run the pinned build checks.
- Required Studio checks remain separate: walk each region and the complete loop; inspect ramp seams/bridges/shore, pickup visibility from spawn and E/touch activation, run the four-gate delivery and both shortcut/safe paths, intentionally fall, reset and repeat with two clients; inspect Output and target mobile performance. Pending checks mean AWAITING_VALIDATION.

## Source ownership

`src/shared/WorldLayout.luau` is the pure numeric source for terrain, paths, scenery and navigation landmarks. `src/server/TerrainWorld.luau` materializes it under the existing generated model; `src/server/World.luau` retains the Training course and parcel interaction. Studio edits to generated geometry are temporary: translate changes into these sources, rerun automated checks, rebuild and repeat affected Studio checks before accepting them. Preserve unrelated Studio assets outside `SwitchbackWorld`.

## Validation evidence

- Four region landmarks cover a 920×920-stud declared footprint (physical land reaches x ±450 and z −450 to +430). Landmark elevations span −2 to 64.4 studs. A southern bridge and northern high bridge form a connected exploration loop; the coast has a separate lagoon dock branch.
- Land is 12 fixed slabs; roads are 25 authored links materialized as 49 segments. Sloped links have 16-stud flat approaches to prevent crossing ramps forming walls. No collidable flat junction pads are added. Bridge posts are spaced at most 24 studs apart; scenery is 39 deterministic prop specifications. Generation has no random seed, voxel edit, streaming generator or per-frame task. Runtime part count and actual device performance still require Studio measurement.
- `tests/world.luau`: **7 cases pass**, testing bounded finite geometry, landmark reachability/elevation, connected path widths/grade, player-width terrain clearance, actual segmented ramp/crossing heights, course fall clearance, and prop/sign/spawn/pickup clearance. The sampler caught and led to fixes for entry-plaza ramp walls and trees/palms on paths. The crossing check also covers the junction slab concern identified during integration review.
- Integrated automated suite: **94 cases pass** (20 gameplay, 37 persistence, 13 lifecycle, 17 pickup entrypoint adapters, 7 world); all **18 Luau files compile**. Coordinator reran the pinned build/source smoke and byte-identical repeated-build check after integration: PASS. Final place SHA256: `f7d00c35df3a1687e01e2642ac21098fce54ebff00cf004269ff06ce9b9d9eb9`.
- Required Studio exploration/pickup/fall/touch/multiplayer/performance checks are **PENDING**. Source and automated checks are not runtime evidence. No upload, playtest or release-ready claim is made.
