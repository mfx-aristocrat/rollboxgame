# Natural graphics revision

Source version `0.7.0-natural-graphics`; execution plan: [graphic_improvement_plan.md](../../graphic_improvement_plan.md). This changes presentation around the existing courier/platformer game. Gameplay geography, rewards, controls and all 155 original colliders remain authoritative.

## Render comparisons

Ten identical cameras are recorded in VisualConfig. `before` is the cannon/ocean checkpoint; `hero` is the first depot/coast iteration, including defects subsequently corrected; `hero_refined` records the grounded-palm revision; `after` is the corrected source-built final pass. Native screenshot exports are 1590×1080; editor guide/hover lines may appear in edit captures and are not game geometry.

| View | Before | After |
| --- | --- | --- |
| Depot | [before](before/depot.png) | [after](after/depot.png) |
| Meadow | [before](before/meadow.png) | [after](after/meadow.png) |
| Coast | [before](before/coast.png) | [after](after/coast.png) |
| Redstone | [before](before/redstone.png) | [after](after/redstone.png) |
| Snow | [before](before/snow.png) | [after](after/snow.png) |
| Gardens | [before](before/gardens.png) | [after](after/gardens.png) |
| Mesa | [before](before/mesa.png) | [after](after/mesa.png) |
| Grass detail | [before](before/grassClose.png) | [after](after/grassClose.png) |
| Depot at player height | [before](before/depotPlayer.png) | [after](after/depotPlayer.png) |
| Shore at player height | [before](before/shorePlayer.png) | [after](after/shorePlayer.png) |

The review rejected the initial cube canopy, slab-like rocks, oversized paving, apparent palm gaps and broad black water reflections. Iterations introduced a composite coastal broadleaf canopy, textured boulders, smaller paving, inset palm roots, matte roughness maps and lower water reflectance. Warm regional tints prevent Redstone/Mesa becoming uniform grey. Thirty-five tree templates, 27 boulders and planting total 403 added decorative Parts within a 700-Part cap; 133 obsolete source decorations are hidden. Broad suspended terrain slabs and small source-built gameplay/flower/cottage props retain their platformer shapes. Native shadows still darken water directly beneath slabs.

## Source and reproduction

Run `scripts/check.ps1`, then open `build/RollboxGame.rbxlx` in Studio and Play. Reopening the generated file is supported; no generator plugin is needed to play it. Roblox network access is needed to load referenced image/mesh assets.

- VisualConfig owns palette, regional tints, lighting, water appearance and review cameras. PresentationLayout defines deterministic, grounded decoration pockets away from paths/items.
- WorldPresentation changes only source-owned colors/material variants and obsolete noncolliding scenery visibility. Its new geometry is anchored/noncolliding/nonqueryable/nontouching, with no per-frame presentation loop. Templates use automatic mesh fidelity and primitive fallbacks when absent/unsafe.
- `assets/materials/*.model.json` and `assets/visuals/*.rbxmx` are tracked Rojo assets. Generated Studio candidates are inspected as data, stripped of package links/code, normalized to an invisible ground pivot, and exported. Every mesh must preserve native InitialSize, scaled Size/CFrame, UV image references and SourceHeight. Never infer InitialSize from a resized Part.
- Accepted Studio edits must return to those files before rebuilding. Verify clean-file dimensions/materials/rendering after export; a working unsaved scene does not prove export correctness. See [mesh export diagnosis](mesh_export_diagnosis.md).
- Modern lighting settings are serialized with Technology=Future for Studio migration compatibility. Ordinary runtime scripts must not set Technology, LightingStyle or PrioritizeLightingQuality. LightingPresentation only applies supported runtime light/effect/water properties and preserves unrelated post effects. Water appearance is global to Terrain; voxel occupancy and swimming mechanics are unchanged.

## Evidence and limits

Automated: 201 standalone cases, 61 Luau files including the performance probe, 5 official-adapter checks, exact script/asset mapping and byte-identical Rojo builds. [Native readback](native_readback.json) confirms 35 tree / 27 rock templates, zero fallback/transform failures and nonzero dimensions on all 10 template MeshParts. [Typed image preload](asset_loading.json): 17/17 unique effective images Success in the clean local place. [Provenance](mesh_provenance.json), [material selections](material_provenance.json), [asset register](../assets.md).

Real gameplay regressions are separate: [pickup](pickup_runtime.json) 14/14 and [adventure/floor](adventure_runtime.json) 22/22 pass on this graphics build, with empty client/server error lists and exact fixture cleanup. [Mushroom/powered delivery](powerups_runtime.json) 23/23 and [cannon/ocean](ocean_runtime.json) 27/27 also pass, for 86/86 total. All fixtures/result markers were removed and absence verified. Fixture installation/build success alone is not a playtest. See PROJECT_STATE for the final native assertions and cleanup.

Measured warm single-client desktop A/B on Intel Iris Plus Graphics 655, viewport 1277×674, three Studio processes open, 180 frames/view. Lighting stayed Realistic in both; assets stayed resident, so this isolates appearance/geometry imperfectly and is not a cold original-game benchmark.

| View | Original appearance mean FPS | Graphics mean FPS | Graphics p95 frame ms |
| --- | ---: | ---: | ---: |
| Depot | 34.4 | 44.1 | 39.7 |
| Meadow | 38.0 | 33.6 | 46.2 |
| Coast | 38.0 | 36.7 | 45.3 |

Graphics Stats total memory 786.7–852.5MiB; texture memory 41.59MiB. A low-quality coast sample averaged 60.1 FPS/p95≈19.0 ms. Automatic quality was restored. [Raw warm A/B](performance_warm_ab.json), [low-quality desktop sample](performance_low_quality.json). Edit source-world generation took≈0.779 s; this is not end-to-end player startup latency.

An earlier Level21 editor preview encountered a D3D11 driver hang (`DXGI_ERROR_DEVICE_HUNG`) on this GPU. The precise trigger was not isolated. Automatic quality is retained and the unverified second oak asset is excluded. No gameplay code forces user graphics quality. Process-isolated startup/frame/memory, sustained load, actual mobile/controller hardware, multiplayer rendering and private published-client asset grants remain pending. The project is AWAITING_VALIDATION and is not a release-ready or universal 60 FPS claim.

Primary references: [lighting](https://create.roblox.com/docs/environment/lighting), [materials](https://create.roblox.com/docs/parts/materials), [MeshSize](https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart#MeshSize), [water appearance](https://create.roblox.com/docs/reference/engine/classes/Terrain#WaterReflectance), [asset permissions](https://create.roblox.com/docs/projects/assets/privacy), [lighting migration issue 637](https://github.com/rojo-rbx/rbx-dom/issues/637), [capability issue 665](https://github.com/rojo-rbx/rbx-dom/issues/665).

An isolation follow-up saved and closed the two diagnostic Studio processes. The remaining viewport was minimized and the Windows helper rejected restoration, so no valid foreground-render result was obtained. Minimized-window callback samples are excluded from the FPS table. The probe was cleaned and Play stopped; visible-render isolation remains pending.
