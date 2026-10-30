# Clip plan: Tacticals final BODY / MOVEMENT set (animator anim-body, 2026-10-30)

Rig: Starter Blocky rig (art/anim/rig copy, steps from art/anim/PIPELINE.md). Style: vault Grounded Tactical +
notes/anim_style_targets.md (lengths below are the code's; targets may tighten new clips). Source names = what the code finds
(`ReplicatedStorage.Repository.AnimationSources.<Name>`). Existing names, lengths and Loop flags are kept.
Aim is procedural (AimPoseController bends Waist/shoulders/Neck; HeadLookController owns the neck): animate at level aim,
keep the neck light. `...Left` = mirror of the right-handed clip. Root motion never in clips (code moves the root).

Columns: length s | loop | priority | markers | cancel | how

## Batch 1: cover core (existing names)
| Clip | Len | Loop | Prio | Markers | Notes |
|---|---|---|---|---|---|
| CoverIdleTall (+Left) | 1.0 | yes | Action3 | - | back to tall cover, gun low across body, moving hold (breath) |
| CoverCrouch (+Left) | 1.0 | yes | Action3 | - | crouched behind low cover, hips under the top |
| CoverCrouchPeek (+Left) | 1.0 | yes | Action3 | - | crouched, shoulders out past the edge, legs set for the lean clips on top |
| CoverLookPos / CoverLookNeg | 1.0 | yes | Action3 | - | head + shoulders to the left / right edge, light neck |
| CoverShuffleTall | 0.60 | yes | Action3 | Footstep x2 | legs only side step, feet planted on contact |
| CoverShuffleCrouch | 0.72 | yes | Action3 | Footstep x2 | crouched side step |
| CoverBrace | 0.75 | no | Action3 | - | flinch in 2-3 f, tuck, recover (cancellable from 0.35) |

## Batch 2: cover actions
| CoverBlindCorner (+Left) | 1.0 | yes | Action3 | - | gun arm around tall edge, body hidden |
| CoverBlindCornerCrouch (+Left) | 1.0 | yes | Action3 | - | same crouched |
| CoverBlindOver (+Left) | 1.0 | yes | Action3 | - | half rise, gun over the top, off hand braced on top |
| CoverDash | 0.48 | yes | Action4 | Footstep x2 | crouched sprint cycle |
| CoverSneak | 1.2 | yes | Action4 | Footstep x2 | slow crouched walk, heel-toe |
| CoverRoll | 0.50 | no | Action4 | Land | tuck, shoulder roll, up to crouch |
| CoverVault | 0.55 (played at VaultTime 0.34) | no | Action4 | HandPlant, Land | one fast vault |
| CoverDiveAim (NEW) | 0.6 loop-able hold | yes | Action4 | - | airborne flat body, both arms forward aiming; blends into CoverRoll |

## Batch 3: locomotion with a gun (NEW unless named)
MoveCrouchIdle 1.0 loop, MoveCrouchWalk 1.2 loop (Footstep), MoveSlide loop 0.6, MoveWalkGun ~1.0 loop, MoveRunGun ~0.7 loop,
MoveStrafeLeft / MoveStrafeRight ~1.0 loop, MoveBackpedal ~1.0 loop, MoveSprintGunLow ~0.66 loop, MoveStart 0.25, MoveStop 0.3,
MoveTurnLeft / MoveTurnRight 0.4, MoveLandHard 0.45. Footstep markers on every contact. Priority Movement (Core for lower
layers where the weapon Hold must win the arms).

## Batch 4: hits and deaths
HitFlinch 0.30 (kept) + HitFlinchFront/Back/Left/Right 0.3, HitHeadshot 0.35, HitExplosion 0.9, HitBurning 1.0 loop,
MoveLimp 1.1 loop (Footstep), DeathFront / DeathBack / DeathLeft / DeathRight / DeathCover / DeathHeadshot ~1.0-1.4 (marker
Ragdoll at the hand-off frame). Hits additive-style: torso/head only so legs and aim keep running. Action2.

## Batch 5: life + bots
IdleFidget1/2/3 2-3 s, BreathCalm 3.0 loop, BreathHeavy 1.6 loop (UpperTorso + shoulders only, Core so it layers), RoundReady
1.0, Victory 2.5, Defeat 2.5, DoorOpen 0.6 (marker Push), BotLeanLeft / BotLeanRight 1.0 loop (Action2, full proper lean).

## Proof per batch
Import into out/anim_body/anim_body.rbxl; capture first + third person at 1x and 0.25x, flat ground + stairs, real avatar;
roblox-animation-grader at xhigh; fix; <= 4 rounds; BATCH_<n>_DONE.md.
