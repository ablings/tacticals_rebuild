# Gun mesh upload (2026-10-30)
- Scratch place: out/gun_upload/upload.rbxl (own blank baseplate). Studio Import Queue (Home > Import), Creator = gunsy funsy per row.
- Uploaded 8 guns under group 102028987 (110 meshes, every id checked on economy.roblox.com/v2/assets/<id>/details):
  Pistol, SilencedPistol (= "Suppressed"), DualPistols, Revolver, MiniUzi, AutoRifle, PumpShotgun, SemiAuto.
- Sniper: first upload landed on the personal account (User 281164661) even though the row read "gunsy funsy" when Start Import
  was pressed. Those 22 ids are NOT used; re-upload under the group pending.
- B1: ScaleCube imports as 1000 studs: the FBX is in centimetres (100x). Set MeshPart.Size = manifest size.
- B2: all 132 parts' sizes and relative positions match the manifest to 0.0001 only under (x, y, z) -> (-x, y, -z): the imported mesh
  data is turned 180 deg about Y against the manifest frame (Orientation reads 0,0,0). Build each MeshPart at
  CFrame.new(bbox_centre) * CFrame.Angles(0, math.pi, 0).
- Asset Privacy: not granted here (no universe access step in Import 3D); the publishing session's "Grant Permissions" covers it.
- Lesson: after a batch Import Queue run, check every mesh's owner on the economy API; the Creator dropdown can show the group and still
  upload a row as Me. Set the dropdowns slowly (1.5 s between clicks); fast clicks picked a wrong group once.
