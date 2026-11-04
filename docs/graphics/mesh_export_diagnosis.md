# Mesh export regression

The first clean graphics build `f015e144...` loaded all17 image assets, but its MeshParts rendered much larger than their Part bounds. The working Studio scene rendered the same asset IDs correctly.

Native minimal assertion on the rebuilt Boulder failed: `MeshSize=0,0,0`. A native template clone/ScaleTo/PivotTo test reached its requested pivot exactly, ruling out the transform helper in that minimal test. Imported working templates had nonzero source dimensions, captured in `native_mesh_dimensions.json`.

The hand-built XML export retained Size, MeshContent and TextureContent but omitted source mesh scale metadata. Add the captured dimensions as serialized InitialSize fields. `tests/build_smoke.py` failed before the fix and passes afterward, verifying every axis against actual native dimensions. A second clean Studio opening must establish nonzero MeshSize and correct silhouettes before accepting the result. No runtime setter of hidden/read-only properties is used.

During inspection the disposable generated World also acquired an editor translation. Its Tree31 source attributes remained150/240 while its pivot moved to-355/-327; DepotRoof moved from0/8.5/2 to-505/54.5/-565. Preserve that local scene, and use a fresh source-built scene for validation. This editor transform is separate from the mesh export problem.

Primary API reference: [TriangleMeshPart.MeshSize](https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart#MeshSize) describes Size divided by MeshSize as the rendering scale; [rbx-dom format documentation](https://dom.rojo.space/xml.html) explains that serialized property names can differ from public names. Corrected native readback is recorded with the graphics validation results.

Corrected fresh Studio readback passed on2757de44: all10 source MeshParts now retain their captured dimensions; matched coast/meadow/rock views show the intended silhouettes. Native readback and image fetch evidence are in native_readback.json and asset_loading.json.
