# Exfil helicopter: survey of the current model (read-only, 2026-10-16)

Studio 8ef4e21a (`Tacticals_rebuild.rbxl`), Edit mode, nothing written. Capture of the old model: `out/heli/old_34.jpg`.

## The model
- Path **`Workspace.LobbyMap.Heli`** (Model). **No PrimaryPart**; WorldPivot `CFrame(133, -0.1, 0)` turned -90 deg about Y
  (model X = world +Z). Bounding box centre (133, 5.66, 4.50), size 37.0 (world z) x 11.3 (y) x 27.2 (world x, the rotor disc):
  world x 119.4..146.6, y -0.1..11.2, z -14.1..23.1. **Nose at -Z, tail at +Z**; starboard = +X, port = -X (the hangar side).
- Model attributes: `Mast` = (133, -0.1, 0), `TailHub` = (132.35, 8.9, 20.6), `TailAxis` = (-1, 0, -4.4e-8). No tags.
- 13 MeshParts (+ 11 `LobbyBake` SurfaceAppearances). No Attachments, Welds, Motor6Ds, constraints, prompts, lights or scripts.

| Part | Centre | Size | Material | Collide | Hook |
|---|---|---|---|---|---|
| U_HeliRotor__case_poly | (133, 10.20, 0) | 27.21 x 0.14 x 27.21 | SmoothPlastic | off, Box | `Rotor = "Main"` |
| U_HeliRotor__paint_bone | (133, 10.20, 0) | 27.22 x 0.16 x 27.22 | SmoothPlastic | off, Box | `Rotor = "Main"` |
| U_HeliRotor__dark_metal | (133, 9.55, 0) | 0.70 x 0.70 x 0.67 | SmoothPlastic | off, Box | `Rotor = "Main"` |
| U_HeliRotor__steel | (133, 10.15, 0) | 1.70 x 0.50 x 1.70 | Metal | off, Box | `Rotor = "Main"` |
| U_HeliTail__case_poly | (132.35, 8.90, 20.60) | 4.79 x 1.84 x 0.10 | SmoothPlastic | off, Box | `Rotor = "Tail"` |
| U_HeliTail__steel | (132.35, 8.90, 20.60) | 0.50 x 0.50 x 0.40 | Metal | off, Box | `Rotor = "Tail"` |
| U_Heli__olive_paint | (132.84, 5.80, 4.19) | 36.39 x 10.20 x 6.92 | SmoothPlastic | on, PreciseConvexDecomposition | |
| U_Heli__dark_metal | (132.88, 5.60, 7.47) | 29.47 x 11.21 x 7.15 | SmoothPlastic | on, PCD | |
| U_Heli__emit_white | (133, 8.63, 7.80) | 28.70 x 5.37 x 7.16 | Neon 160,158,148 | on, PCD | attr GlowBase |
| U_Heli__glass | (132.86, 4.96, -2.30) | 19.40 x 2.93 x 7.12 | Glass T0.3 | off | |
| U_Heli__steel | (131.73, 4.47, -2.59) | 8.88 x 8.05 x 4.95 | Metal | off | |
| U_Heli__canvas | (135.27, 3.70, 0) | 5.20 x 2.40 x 1.15 | Fabric | on, PCD | |
| U_Heli__case_poly | (135.48, 3.75, 0) | 6.00 x 5.40 x 1.15 | SmoothPlastic | on, PCD | |
| U_Heli__paint_bone | (133, 5.55, 13.80) | 1.60 x 0.60 x 2.20 | SmoothPlastic | on, PCD | |

All carry `PrevFidelity = Automatic` (from LobbyMerge). Triangle counts are not readable from Luau (mesh assets); the old model is a
Huey-like block: skids, a faceted cockpit box, a black cabin box, a thin tail boom and a flat rotor disc mesh (two 27-stud discs).
What reads "crazy": the cabin is a separate black crate stuck on the side, skids under a Black-Hawk-sized body, a faceted cone nose,
flat panels with no bevels, an emissive white stripe the length of the body, and a rotor that is a disc mesh, not blades.

## Hooks (every one the new model must keep)
| # | Hook | Who reads it | How | Keep |
|---|---|---|---|---|
| 1 | `LobbyMap.Heli` (name) | `StarterPlayerScripts.ExfilFX` (`FindFirstChild("Heli")` every Heartbeat), `HeliRotorFX` (`WaitForChild("Heli")`, **infinite**), `LobbyUIController` (`WaitForChild("Heli", 30)` then `HeliTrigger`) | name lookup | the Model stays, same name, same parent |
| 2 | Heli attributes `Mast`, `TailHub`, `TailAxis` (world Vector3s) | ExfilFX | main rotor spins about the world **vertical** axis through `Mast`; tail rotor about `TailAxis` through `TailHub` | Mast stays (133, -0.1, 0); TailHub/TailAxis are **rewritten** to the new tail rotor hub / canted axis (originals kept for UNDO) |
| 3 | attribute `Rotor = "Main"` / `"Tail"` on any **descendant** BasePart | ExfilFX | spin (9 rad/s idle, 22 lifting; tail 18 / 40) | new rotor meshes carry it; the main rotor must be centred on x 133, z 0 |
| 4 | every BasePart under Heli (descendants) | ExfilFX | recorded once (`base[p] = p.CFrame`) and lifted with `liftT` during the cutscene, restored after | old meshes leave the model (moved to `ServerStorage._RebuildRemoved.Heli_Old`, not deleted) so they are not lifted invisibly |
| 5 | direct children with `SpinAxis` / `SpinCenter` / `RPS` | `HeliRotorFX` | idle spin (client) | **none today: inert**. Do not add these attributes (it would double-spin with ExfilFX) |
| 6 | `Heli.HeliTrigger` | `LobbyUIController` (old "range isn't open" toast) | WaitForChild 30 s | already missing (dormant): do not add |
| 7 | `Exfil.HatchPoint` (126.8, 3, -0.2) and `Exfil.CabinPoint` (132.4, 4.2, 0.4), CabinPoint faces **-X** (out of the port door) | ExfilFX | jump arc p0 -> HatchPoint (+4.5 up), tween to CabinPoint, CabinPoint = lift pivot | not moved. The new port door must be open around z 0.4 with the floor near y 1.2 (R15 feet when the root is at 4.2) and >= 5.3 studs of clear height |
| 8 | ExfilFX camera | ExfilFX | start `lookAt((120, 9, -18), (133, 4, 2))`; lift camera `(120, 9 + 1.5e, -18 - 2e)` looking at `liftT * CabinPoint`, e = 0..2.6 | nothing of the heli may cross it; main rotor radius must stay under ~21 (camera is 22.2 from the mast in plan) |
| 9 | Lift transform | ExfilFX | `CFrame.new(e^2 * 3.2, min(e,4)^1.5 * 2.2, 0) * Angles(0, 0, -min(0.06e, 0.18))` about CabinPoint: the heli moves **+X and up**, rolls | sweep checked against the map in `fix/check_heli.lua` |
| 10 | `ExfilBarrier` tag (Exfil.ExfilBarrier, x 127.5, y 0..13, z -12..12) | ExfilFX Touched | trigger | untouched; nothing of the new heli may sit in it (the rotor passes over it at y 10.3, CanTouch false) |
| 11 | `LobbyRotor` tag | `LobbyFX` (attr `base` CFrame, `speed`) | spins tagged Models | **not the heli**: only the two `Props.Rotor` fans (hidden by overlap_fix). The heli rotors are driven only by ExfilFX (#3) |
| 12 | Training/hangar constants | TrainingManager, LobbyFallCatch | HANGAR (112, 3.5, 0) | not near the heli |
| 13 | check scripts | `fix/check_rooms3.lua` (Mast/TailHub/TailAxis present, rotor count, pivot, heli parts excluded from route casts), `check_polish_exfil.lua` (same + lift sweep vs Polish parts), `check_hub1.lua` (Heli folder present) | read only | keep attributes + pivot; they read every BasePart under Heli |
| 14 | `ServerStorage._DevTools.LobbyMerge` | dev tool, not runtime | set Heli CastShadow / collision on merge | ignore |
| 15 | `AssetCheck` | client + server | preloads every MeshPart under LobbyMap | new meshes are just more entries |

Neighbours that bound the new model: pad markings `Rooms3.E_Helipad` (centre (137, 0, 0), 17 x 17, top y 0.08-0.12), hangar roof
y 20-21 over x 104..126, pad walls z +-26, clip wall x ~151.4, `Polish.Exfil` tie-downs at (131, +-9.6) / (137, +-9.6) / (143, +-9.6),
drum truck x 131.3..134, z 21.2..23.4, y 0..2.6 (north wall), cargo dolly at (133.2, -23.1). Floor top under the heli ~0.05-0.12.
