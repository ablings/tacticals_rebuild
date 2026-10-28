# House exterior trees: done (2026-10-28)

Replaces the faceted `Tree_XX` blobs in `H_Exterior.fbx` and softens the front hedge. H_Exterior, H_House and the furniture kit are untouched.

## Files
- `fbx/H_Trees.fbx`: plan coordinates, same exporter as H_Exterior (centimetres, embedded textures), `K_ScaleCube` (10 studs) at (0, -120, 30) and `K_Marker` at (12, -120, 25): the same spots as in H_Exterior, so the same import scale and offset apply.
- `house_trees.json`: every object with its form, tris, plan bbox, plan location and the H_Exterior objects it `replaces`.
- `tex/H_Trees_color.png`, `H_Trees_normal.png` (OpenGL), `H_Trees_rough.png`: one 1024 atlas for the whole set, no alpha.
- `house_trees.blend`; generators `tools/make_tree_atlas.py` (plain Python) and `tools/build_trees.py` (Blender, one run); `tools/render_trees.py` renders the old and new versions from the same cameras.
- Renders: `captures/house/trees/cmp_*.png` (old vs new, window cameras), `trees_sheet.png` (the four forms), `check/` (proof check).

## For the map builder
1. Hide `Tree_NN`, `Tree_NN_Leaves` and `Tree_NN_LeavesDark` (NN 01-15), plus `Ext_Yard_Hedge`, in the H_Exterior import.
2. Import H_Trees.fbx, measure `K_ScaleCube`, and place it with the same transform as H_Exterior. Objects: `Tree_01..Tree_15` (trunk + limbs), `Tree_01_Crown..Tree_15_Crown`, `Hedge_Front`.
3. Give every object one SurfaceAppearance: ColorMap / NormalMap / RoughnessMap = the three H_Trees images, no MetalnessMap, AlphaMode Overlay (nothing transparent). Set CanCollide off (they are scenery).
4. **Tree_14 and Tree_15** have trunk bases (-20, 92) / (20, 92) inside the footprints of the two houses behind (y 90-126), the same as the old trees. They are built where ordered, but suggest moving them to y ≈ 83 (the neighbours' back gardens) or hiding them.

## Numbers
- 15 trees, 50,046 tris (broadleaf 3.85-4.16k, conifer 2.31-2.42k); hedge 1,034; total 51,080.
- Forms: round (Tree_01/05/10), oval (02/07/12), spread (03/09/15), spruce (04/08/13), fir (06/11/14).
- Crowns facing a neighbour's facade, and conifers by our fences, are squeezed smoothly so they stay 0.5 off it (Tree_04/05/06/07/11).
- `blender_check.py`: 31 objects, 0 FAIL, 33 WARN. The WARNs are A1b (organic multi-part meshes) and A8 (a twig face within 0.12 of a clump inside the crown, not visible).
