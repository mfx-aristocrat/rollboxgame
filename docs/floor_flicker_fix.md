# Floor flicker repair — 2026-11-03

The user reported green/stone floor blinking while running. The complete production world builder reproduced **27 exposed pairs of different-color/material floor faces sharing a plane**. This is z-fighting: coincident faces compete to render as the camera moves.

The affected geometry included DepotRoof/plazas/side paths, Cloudstep Mesa and its crown, mixed bridge/garden/trail junctions, the lagoon boardwalk and an exposed Meadow/Gardens foundation seam. Raising every path by one identical amount would have left mixed-style junction conflicts; changing lighting would not separate those planes. A single production-built world was sufficient to reproduce the failure; duplicate-world generation was not needed.

## Fix and acceptance

- Canonical path surface lifts in WorldLayout: trail/plaza 0.125, garden 0.25, bridge 0.375 studs. TerrainWorld moves each whole segment and its bridge fittings together, preserving slope/end alignment.
- Plazas and the exposed Gardens foundation are 0.25 studs lower. Two depot pavers beneath the crossing path were omitted; the four forward delivery pavers remain. This avoids a newly discovered 0.005-stud path/tile gap.
- Acceptance: zero exposed conflicting near-coplanar floor pairs in the rendered world, ordinary walking support/step differences bounded to 0.5 studs, items within collection reach, springs remain usable, no reward/profile change.
- Native geometry regression builds the actual World/TerrainWorld/AdventureWorld source using Lune Roblox datatypes. It intersects projected top-face polygons, checks matching planes and exposed edges/centers, and ignores buried intersections. This checks the generated scene rather than just asserting configured offsets.

## Validation

`./scripts/check.ps1`: **30 Luau compile, 123 standalone cases PASS**, including two new floor checks. **27 conflicting pairs before → 0 after**. Walking center/side corridors, item reach and spring inset pass against actual generated planes. The highest path lift is 0.375 studs. The fixed crate at the coast junction remains reachable with its bottom inset 0.375 studs into the raised path; native crate activation is separately exercised by the Studio suite.

Fixed reproducible place SHA256: **0d3dd8f50d1a97ff506ac3b6dcf4b1aa57f21e47e76cbaf3177e25ab989f8c35**. Source authority remains Rojo/Luau; existing Studio scripts were equality-checked/backed up before scoped synchronization and read back afterward. No cloud publishing or setting change.

The real Studio adventure regression now individually raycasts collidable floors at eight affected locations, measuring the distance between the visible top floor and the nearest differently styled layer. The original build returned **0 at all eight**; the fixed build returns **0.125–0.375 studs**, and all **22/22 engine assertions pass**, including walking collection, crate/pickup, spring motion and respawn, with no captured errors. JSON evidence: validation/floor-engine-before.json and validation/floor-engine-after.json. [Official raycasting reference](https://create.roblox.com/docs/workspace/raycasting).

A temporary Studio-only camera/walking preview visited the hub, Mesa and crown. Two inspected crown views, including subsequent Windows movement/zoom input, showed a consistent stone path against the grass. This is scoped desktop visual evidence, not a whole-map/device or pixel-by-pixel video test. The preview script was removed with exact-source ownership checks after returning to Edit; the normal game can run without diagnostics.

Standalone checks, real engine checks and visual observations are separate evidence. This repair does not complete the expansion's remaining touch/gamepad, multiplayer, full-map and release gates.
