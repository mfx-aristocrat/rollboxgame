# Asset register

Initial baseline used source-generated geometry, UI, colors, lighting and effects. The graphics revision below adds original generated meshes/textures. Roblox built-in UI fonts remain in use; no third-party asset rights are assumed.

Grass/mushroom update: Roblox built-in Grass material on nine course decks, muted meadow colors and 144 original primitive grass blades. Mushroom crate, stem, cap and spots are original engine Part geometry in PowerupWorld. No image, clothing, model or audio upload or external asset ID is required.

Record origin URL, author, license/permission, asset ID and purpose here before adding externally authored assets. Tool binaries are development dependencies pinned in tools.lock.json, not shipped game assets.

2026-11-03 platformer expansion: terrain terraces, flowers, hills, clouds, cottages, arches, pennants, tokens, crates and springs are original procedural Part geometry in WorldLayout/TerrainWorld/AdventureLayout/AdventureWorld. The courier's red cap with parcel badge, moustache, shirt, blue overalls, gloves and boots are original welded Part geometry in CourierAppearance. No external model, image, clothing, audio or asset ID was imported. The requested classic-platformer inspiration is expressed through palette, silhouettes, scenery and gameplay; no Nintendo asset files are included. Existing Roblox avatars are restyled only inside the running experience; account appearance is unaffected.

## Cannon and ocean revision

Original source-built orange mushroom, three-part held practice cannon, neon balls, striped target boards and 200 shoreline/water-exit scenic Parts. Native Roblox Terrain water, built-in materials/fonts only; no external asset IDs, imported scripts, paid assets or third-party character art. Source: `BlasterWorld`, `Blaster`, `OceanWorld`, and their shared configs. Runtime voxel generation writes only liquid occupancy in empty bounded cells; authored terrain remains preserved.

## Natural graphics revision — 2026-11-04

Original RollboxGame art direction generated through Roblox Studio Assistant under the signed-in creator account. No purchased Creator Store assets or copied character art. Native generation created Roblox asset IDs; this is separate from publishing an experience. See [material provenance](graphics/material_provenance.json), [mesh provenance](graphics/mesh_provenance.json) and [actual native dimensions](graphics/native_mesh_dimensions.json).

- Six MaterialVariants use four curated PBR families: short turf, coastal stone, weathered timber and mossy paving. Twelve unique color/normal/roughness images; nonmetallic. Sandstone/Wood slots reuse those maps while retaining their base material physics.
- Palm model99418412771534; coastal boulder105256037377845; composite coastal broadleaf tree uses accepted bark/branches from90422131268703 plus five scaled clusters of the accepted palm foliage. Five unique mesh IDs and five generated mesh color images; existing roughness maps reused on10 template MeshParts. The internal template name Oak denotes the composite, not a botanical accuracy claim.
- Source XML templates under assets/visuals are normalized, anchored, noncolliding, nonqueryable and nontouching. PackageLinks and all code excluded. The rejected cube canopy and unverified oak98186504146203 are absent from shipped source.
- Generated files and asset references are reproducible through Rojo. Mesh scale metadata must include captured InitialSize; do not reconstruct it from scaled Part.Size. Material JSON attributes use Properties.Attributes with typed values.

Local clean Studio loading passed for17/17 unique effective images, and every mesh retains nonzero source dimensions. Platform usage remains subject to Roblox asset moderation/permissions; grants to the eventual private experience and a non-owner published-client check remain required. No independent third-party license is asserted for generated outputs. Source-generated flowers, courier and gameplay cues remain original engine geometry.
