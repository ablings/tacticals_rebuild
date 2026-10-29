# Animation plan: PullUp + cover leans (movement rework, Edward 2026-10-29)

Style: Weighty Tactical (grounded, no overshoot, moving holds) with Tacticals' fast cover feel. Rig: R15 (Motor6D), no rig changes.
Conventions: source names follow the loader rule `AnimationSources.Cover<Name>`; config keys `PullUp` (MoveAnimations) and
`LeanLeft` / `LeanRight` / `LeanLeftCrouch` / `LeanRightCrouch` (CoverAnimations).

| Clip | Length | Priority | Loop | Markers | Cancel | Source of motion |
|---|---|---|---|---|---|---|
| CoverPullUp | 0.70 s | Action4 | no | EdgeGrab 0.10, TopReached 0.50 | after TopReached (recovery) | clip + root motion in code (RootKeys) |
| CoverLeanLeft / Right | 1.20 s loop | Action4 | yes | none | any time (fade out 0.08-0.12 s) | clip (full pose from frame 0; the fade is the blend) |
| CoverLeanLeftCrouch / RightCrouch | 1.20 s loop | Action4 | yes | none | any time | clip on the CoverCrouchPeek leg base |

Joints keyed:
- Leans: LowerTorso, UpperTorso and both legs only. Arms, hands and head are left to the weapon Hold/Fire tracks and the
  procedural aim (AimPoseController bends C0, HeadLookController owns the neck), so aiming and firing layer on top.
- PullUp: every joint (full override while it plays).

Build order used: key poses from numbers -> FK solver (feet planted, palms on the edge) -> baked keys -> playback check at
60 fps in edit mode (Animator:StepAnimations) -> FK puppet captures -> publish to gunsy funsy.
