# Gun mesh upload (2026-10-30)
- Scratch place: out/gun_upload/upload.rbxl (own blank baseplate). Studio Import Queue (Home > Import), Creator = gunsy funsy per row.
- Uploaded 8 guns under group 102028987 (110 meshes, every id checked on economy.roblox.com/v2/assets/<id>/details):
  Pistol, SilencedPistol (= "Suppressed"), DualPistols, Revolver, MiniUzi, AutoRifle, PumpShotgun, SemiAuto.
- Sniper: first upload landed on the personal account (User 281164661) even though the row read "gunsy funsy" when Start Import
  was pressed. Those 22 ids are NOT used. Re-uploaded 05:40 under the group (22 meshes, all group-owned).
- 05:40 also uploaded the 11 melee/gadget items (Knife, Katana, Bat, RiotShield, Fists, Frag, Smoke, Flash, StickyGrenade, Landmine,
  Medkit; 60 meshes), all group-owned, same scale (1000-stud cube) and same 180 deg Y turn. Total 20 models, 192 meshes.
- B1: ScaleCube imports as 1000 studs: the FBX is in centimetres (100x). Set MeshPart.Size = manifest size.
- B2: all 132 parts' sizes and relative positions match the manifest to 0.0001 only under (x, y, z) -> (-x, y, -z): the imported mesh
  data is turned 180 deg about Y against the manifest frame (Orientation reads 0,0,0). Build each MeshPart at
  CFrame.new(bbox_centre) * CFrame.Angles(0, math.pi, 0).
- Asset Privacy: not granted here (no universe access step in Import 3D); the publishing session's "Grant Permissions" covers it.
- Lesson: after a batch Import Queue run, check every mesh's owner on the economy API; the Creator dropdown can show the group and still
  upload a row as Me. Set the dropdowns slowly (1.5 s between clicks); fast clicks picked a wrong group once.
- Shared screen: the stage waiter lost the race 6 times in a row (about 70 min) to other agents' Studios; a background retry loop of
  `screen.ps1 stage -wait 9` got it. Plan uploads in one batch per stage.
