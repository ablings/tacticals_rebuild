# Body / movement animations: DONE (anim-body, 2026-10-30)

Final body set on the Starter Blocky rig (Blender -> JSON -> KeyframeSequences), style Grounded Tactical. Source of every
clip: `art/anim/body/blender/clips/b1_cover.py .. b5_life.py`; install all sources (with PublishedId) by running
`art/anim/body/install_sources.lua` in Studio (Edit mode). Published under the group **gunsy funsy** (102028987),
each id read back from economy.roblox.com (AssetType 24, Creator group). Code wiring: `art/anim/body/HANDOFF_systems.md`.

Batch grades (roblox-animation-grader, xhigh; pass 8.0, max 4 rounds): 1 cover core 7.9 (r4, final); 2 cover actions 7.2 (r4, final); 3 locomotion pending; 4 transitions + hits 7.5 (r3; no change after); 5 deaths + life pending

| Clip | Id | Len | Loop | Priority | Markers (s) | Grade |
|---|---|---|---|---|---|---|
| CoverIdleTall | rbxassetid://107919974947086 | 1.00 | yes | Action3 | - | 8.6 |
| CoverIdleTallLeft | rbxassetid://89825449450442 | 1.00 | yes | Action3 | - | 8.6 |
| CoverCrouch | rbxassetid://124832453155823 | 1.00 | yes | Action3 | - | 7.6 |
| CoverCrouchLeft | rbxassetid://112818189818941 | 1.00 | yes | Action3 | - | 7.6 |
| CoverCrouchPeek | rbxassetid://89536713819196 | 1.00 | yes | Action3 | - | 8.3 |
| CoverCrouchPeekLeft | rbxassetid://70445628915689 | 1.00 | yes | Action3 | - | 8.3 |
| CoverLookPos | rbxassetid://134408081619717 | 1.00 | yes | Action4 | - | 8.6 |
| CoverLookNeg | rbxassetid://83092379873846 | 1.00 | yes | Action4 | - | 8.6 |
| CoverLookPosCrouch | ready to publish | 1.00 | yes | Action4 | - | 7.7 |
| CoverLookNegCrouch | ready to publish | 1.00 | yes | Action4 | - | 7.7 |
| CoverShuffleTall | ready to publish | 0.60 | yes | Action4 | Footstep 0.000, Footstep 0.100, Footstep 0.200, Footstep 0.300, Footstep 0.400, Footstep 0.500 | 8.4 |
| CoverShuffleTallRight | ready to publish | 0.60 | yes | Action4 | Footstep 0.000, Footstep 0.100, Footstep 0.200, Footstep 0.300, Footstep 0.400, Footstep 0.500 | 8.4 |
| CoverShuffleCrouch | ready to publish | 0.72 | yes | Action4 | Footstep 0.000, Footstep 0.117, Footstep 0.233, Footstep 0.367, Footstep 0.483, Footstep 0.600 | 8.0 |
| CoverShuffleCrouchRight | ready to publish | 0.72 | yes | Action4 | Footstep 0.000, Footstep 0.117, Footstep 0.233, Footstep 0.367, Footstep 0.483, Footstep 0.600 | 8.0 |
| CoverBrace | ready to publish | 0.75 | no | Action4 | - | 7.2 |
| CoverBraceCrouch | ready to publish | 0.75 | no | Action4 | - | new after r4 (not graded) |
| CoverBlindCorner | ready to publish | 1.00 | yes | Action4 | - | 8.0 |
| CoverBlindCornerLeft | ready to publish | 1.00 | yes | Action4 | - | 8.0 |
| CoverBlindCornerCrouch | ready to publish | 1.00 | yes | Action4 | - | 7.2 |
| CoverBlindCornerCrouchLeft | ready to publish | 1.00 | yes | Action4 | - | 7.2 |
| CoverBlindOver | ready to publish | 1.00 | yes | Action4 | - | 5.8 |
| CoverBlindOverLeft | ready to publish | 1.00 | yes | Action4 | - | 5.8 |
| CoverDash | ready to publish | 0.48 | yes | Action3 | Footstep 0.000, Footstep 0.233 | 8.0 |
| CoverSneak | ready to publish | 1.20 | yes | Action | Footstep 0.000, Footstep 0.300, Footstep 0.600, Footstep 0.900 | 8.5 |
| CoverRoll | ready to publish | 0.50 | no | Action4 | Land 0.333 | 6.5 |
| CoverVault | ready to publish | 0.55 | no | Action4 | EdgeGrab 0.100, Land 0.550 | 6.0 |
| CoverDiveAim | ready to publish | 1.00 | yes | Action4 | - | 8.6 |
| MoveRun | ready to publish | 0.70 | yes | Movement | Footstep 0.000, Footstep 0.350 | - |
| MoveWalkAim | ready to publish | 1.00 | yes | Movement | Footstep 0.000, Footstep 0.250, Footstep 0.500, Footstep 0.750 | - |
| MoveStrafeLeft | ready to publish | 0.70 | yes | Movement | Footstep 0.000, Footstep 0.350 | - |
| MoveStrafeRight | ready to publish | 0.70 | yes | Movement | Footstep 0.000, Footstep 0.350 | - |
| MoveBackpedal | ready to publish | 0.70 | yes | Movement | Footstep 0.000, Footstep 0.350 | - |
| MoveSprint | ready to publish | 0.50 | yes | Movement | Footstep 0.000, Footstep 0.250 | - |
| MoveSprintPistol | ready to publish | 0.50 | yes | Movement | Footstep 0.000, Footstep 0.250 | - |
| MoveCrouchIdle | ready to publish | 1.00 | yes | Action | - | - |
| MoveCrouchWalk | ready to publish | 1.20 | yes | Action | Footstep 0.000, Footstep 0.300, Footstep 0.600, Footstep 0.900 | - |
| MoveSlide | ready to publish | 0.50 | yes | Action4 | - | - |
| MoveStart | ready to publish | 0.25 | no | Movement | Footstep 0.133 | 8.0 |
| MoveStop | ready to publish | 0.35 | no | Movement | Footstep 0.000, Footstep 0.167 | 8.5 |
| TurnInPlaceLeft | ready to publish | 0.50 | no | Movement | Footstep 0.233, Footstep 0.400 | 6.5 |
| TurnInPlaceRight | ready to publish | 0.50 | no | Movement | Footstep 0.233, Footstep 0.400 | 6.5 |
| MoveLandHard | ready to publish | 0.45 | no | Action | Land 0.000 | 8.5 |
| MoveLimp | ready to publish | 0.84 | yes | Movement | Footstep 0.000, Footstep 0.467 | 7.5 |
| HitFlinch | ready to publish | 0.30 | no | Action4 | - | 8.0 |
| HitFlinchF | ready to publish | 0.30 | no | Action4 | - | 8.0 |
| HitFlinchB | ready to publish | 0.30 | no | Action4 | - | 8.0 |
| HitFlinchL | ready to publish | 0.30 | no | Action4 | - | 8.0 |
| HitFlinchR | ready to publish | 0.30 | no | Action4 | - | 8.0 |
| HitHeadshot | ready to publish | 0.25 | no | Action4 | - | 8.5 |
| HitExplosionStagger | ready to publish | 0.90 | no | Action4 | Footstep 0.233, Footstep 0.733 | 8.0 |
| HitBurning | ready to publish | 1.20 | yes | Action4 | - | 7.5 |
| DeathForward | ready to publish | 1.20 | no | Action4 | DropGun 0.100, Ground 0.667 | - |
| DeathBackward | ready to publish | 1.10 | no | Action4 | DropGun 0.067, Ground 0.600 | - |
| DeathCrumple | ready to publish | 1.40 | no | Action4 | DropGun 0.200, Ground 0.833 | - |
| DeathHeadshot | ready to publish | 0.80 | no | Action4 | DropGun 0.033, Ground 0.500 | - |
| DeathExplosion | ready to publish | 0.90 | no | Action4 | DropGun 0.017, Ragdoll 0.200, Ground 0.500 | - |
| DeathCover | ready to publish | 1.20 | no | Action4 | DropGun 0.083, Ground 0.500 | - |
| IdleFidgetShift | ready to publish | 2.50 | no | Idle | - | - |
| IdleFidgetGunCheck | ready to publish | 3.00 | no | Action2 | - | - |
| IdleFidgetLook | ready to publish | 3.00 | no | Idle | - | - |
| BreatheCalm | ready to publish | 4.00 | yes | Idle | - | - |
| BreatheHeavy | ready to publish | 1.50 | yes | Idle | - | - |
| RoundReady | ready to publish | 1.20 | no | Action2 | Tap 0.533 | - |
| Victory | ready to publish | 3.00 | no | Action2 | - | - |
| Defeat | ready to publish | 2.50 | no | Action2 | - | - |
| DoorOpen | ready to publish | 0.80 | no | Action2 | Push 0.200 | - |
| BotLeanLeft | ready to publish | 1.00 | yes | Action2 | - | - |
| BotLeanRight | ready to publish | 1.00 | yes | Action2 | - | - |
