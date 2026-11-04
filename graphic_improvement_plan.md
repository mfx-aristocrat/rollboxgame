# Graphic improvement plan

Started 2026-11-04 (Europe/Warsaw). User brief: improve the game's graphics and texture realism to the highest quality achievable with available tools; rebuilding the presentation is allowed. Follow the full [project brief](Roblox_Game_Creation_Instructions.md), [AGENTS](AGENTS.md), [roadmap](game_creation_steps.md) and [project state](PROJECT_STATE.md).

## Direction and boundaries

Create a natural coastal adventure: detailed grass and soil, weathered stone and timber, clear warm sunlight with cool shadows, layered planting, irregular rocks and convincing water. Keep the original courier, mushrooms, collectibles and Amber/Cyan gates readable. Preserve all gameplay, map connectivity, collision surfaces, pickups, jump physics, water exits and rewards. A graphics overhaul is not permission to discard working gameplay.

Highest achievable quality means inspected in-game results, sensible texture scale and coherent art direction, rather than maximum numerical settings. Iterate while an observable visual defect remains. Device limits, asset moderation/access and unavailable tools must be recorded honestly. No paid spending or public publishing. Source/Rojo remain authoritative; export every accepted Studio-generated asset.

## Sequential steps and acceptance

Execute these in order. Independent research/review may run in parallel; integrate and validate each step before advancing. Revisit an earlier step when later screenshots expose a defect. Statuses: TODO, IN_PROGRESS, AWAITING_VALIDATION, DONE.

| Step | Status | Work | Required evidence before advancing |
| --- | --- | --- | --- |
| G01 — Baseline and tool audit | IN_PROGRESS | Check Git/source/Studio and existing assets, preserve unsaved work; retain the verified cannon/ocean checkpoint. Capture consistent cameras at depot, meadow, coast/lighthouse, rock heights, snow, gardens and mesa. Record geometry, current lighting/materials and available generation/render tools. | Exact source/build baseline; before views actually inspected; camera coordinates and quality context recorded; capability failures explicit. |
| G02 — Lighting foundation | TODO | Reproducible Realistic lighting, sun direction, balanced ambient/specular light and restrained atmosphere/color correction/bloom. Compare at the depot and coast before broader changes. | Surface depth improves; snow/stone retain detail; gates/parcel/courier remain readable; no fog wall, clipped highlights or gameplay blur; source/build readback. |
| G03 — High-quality material library | TODO | Generate/reuse a compact PBR set for grass/soil, weathered stone/cliff, timber and paving. Compare scale/tiling at player height and distance. Inspect available project/built-in assets before generation. Export selected MaterialVariants, map IDs, base materials, tiling and provenance into tracked Rojo assets. | All maps load in the rebuilt place; inspect color/normal/roughness and optional metalness, seams, tiling, highlights. Preserve base-material/physical behavior. No guessed IDs or unsupported claims. If generation is unavailable, document it and improve the actual running game using supported materials while continuing useful work. |
| G04 — Depot and east-shore hero area | TODO | Apply approved textures/palette and replace simplistic visual silhouettes with layered tree canopies, branching trunks, irregular rock clusters and composed botanical details. Start with one coherent area. New decorative geometry has no collision/query/touch effects. | Matched before/after player-height and wide views visibly improve texture, shape and depth; crate/target/route silhouettes stay clear; floors/collisions and reward layout unchanged. Review and iterate before regional rollout. |
| G05 — Six-region rollout | TODO | Apply the accepted presentation system to meadow, coast, redstone, snow, gardens and mesa. Give each region a consistent distinct palette, foliage/rock treatment and material scale. Add detail within explicit part/texture budgets. | Inspect every region plus shore approaches; no floating vegetation, obstructed signs, repetitive giant spheres, tiled texture distraction or floor flicker. Record part counts and assets. |
| G06 — Render review and refinement | TODO | Compare identical cameras and player views. Review near/mid/far textures, sky/water, sunlight/shadow, clutter, UI and interaction contrast. Iterate targeted defects and record each decision. | Real Studio screenshots/readback, with a reviewer pass. At least one complete comparison round; repeat as needed. No cinematic-only settings that break ordinary gameplay. |
| G07 — Performance and compatibility | TODO | Measure startup, frame-time distribution, instance counts and available memory/render stats against the baseline on this desktop. Exercise quality levels/emulation where supported; reduce costly detail/shadows when measured. | Measured local before/after numbers, not invented FPS. Keep low-end/mobile/controller/hardware limitations explicit; avoid unbounded particles, transparency layers, unique maps or loops. |
| G08 — Gameplay regression | TODO | Run all meaningful automated/build checks, floor/grass/geometry/material validations and native pickup/adventure/power-up/cannon/ocean regressions. Verify asset loading, source export, respawn and cleanup. | Reproducible build, exact native results/errors, no changed collision/reward/pickup/water behavior. Pending mandatory device/multiplayer checks mean AWAITING_VALIDATION. |
| G09 — Git and handoff | TODO | Update assets register, README as needed, this plan, roadmap and PROJECT_STATE; commit/push develop; verify CI and remote heads; update draft PR. Promote to main only when required gates pass. | Exact commits/build hash/CI; current Studio state; remaining defects/limits and exact next actions. Preserve visibility; no cloud release implied. |

## Implementation ownership

- Coordinator: integrate, validate renders/runtime, source/assets, state and Git.
- Astra/xhigh requested for art direction/architecture/material pipeline research and difficult issues; Sol/high for presentation builders/Luau/checks; Terra/medium for screenshot/player-facing review. Use the AGENTS fallbacks only when unavailable, and record accepted assignments rather than claiming internal model identity.
- Proposed source seam: `VisualConfig` for scoped roles/palette/cameras and `WorldPresentation` for deterministic presentation of source-owned world objects. Serialized MaterialService variants and Lighting configuration travel with Rojo. Never globally override unrelated user assets/avatars or silently edit engine/security settings.

## Iteration log

1. Baseline code `e06982b478b425c1db33266291398ae9d1c5e87c`: cannon/ocean27, double-jump/delivery23, adventure/floor22 native assertions pass; 186 standalone cases and matching builds. Windows/Ubuntu CI41817684416 and41817678860 pass. Main remains260d22c.
2. Initial visual audit: previous ambient170/180/206 flattens depth; large uniform plates and single-sphere scenery need better material scale and silhouettes. Direction reviewed before graphics implementation.
3. Capability audit: official Studio MCP instance initially reports `Place is not open`; previous bridge timed out. Studio start-window inspection is underway. No generated materials or graphics results claimed yet.

## Primary references

- [Global lighting](https://create.roblox.com/docs/environment/lighting)
- [Outdoor PBR and lighting tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments)
- [Materials](https://create.roblox.com/docs/parts/materials)
- [MaterialVariant API metadata](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MaterialVariant.yaml)
- [Performance guidance](https://create.roblox.com/docs/performance-optimization/improve)

Generated material creation is not a passed graphics step. Asset readback, tracked source/export, rebuilt-place loading and an inspected render are required.
