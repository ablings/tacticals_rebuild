# Body animations: what the code must do (anim-body -> systems, 2026-10-30)

Sources are installed by `art/anim/body/install_sources.lua` into `ReplicatedStorage.Repository.AnimationSources` (names below).
All clips key only the joints they own (other poses are Weight 0), so they layer by priority without resetting the hips.

## Cover (CoverController / CoverConfig)
1. **Shuffle direction.** CoverShuffleTall / CoverShuffleCrouch step toward the character's LEFT (cover.side > 0). Add
   `ShuffleTallRight` / `ShuffleCrouchRight` to `CoverAnimations` and pick by cover.side (side < 0 => Right). Today moving right
   plays the left-stepping clip (feet slide backwards). Shuffles now have 6 Footstep markers per cycle (quick step-close lanes:
   zero foot slide at 8 studs/s needs it), not 2.
2. **Crouched head-look.** Add `LookPosCrouch` / `LookNegCrouch` to `CoverAnimations`; play them instead of LookPos/Neg when `low`
   (the standing Look replaces the crouch's chest/head pitch and lifts the head over the cover).
3. **Brace.** (a) The per-frame weights loop stops every coverTracks entry not in `weights`, so Brace dies one frame after
   Suppress plays it: keep Brace out of that loop (or weights.Brace = 1 until it ends). (b) Look and Brace are both Action4 on
   chest + head and average 50/50: set the Look weight to 0 while Brace plays. (c) Add `BraceCrouch` and play it when low.
4. **Blind fire round a corner.** Facing along the wall, the blocky body is ~2 studs wide to the arm edge but sits 0.85 from
   the wall, so the clip shifts the hips 0.95 away from the wall (root translation in the clip). Better: offset the HRP ~0.6 off
   the wall while blind-firing and slide to the edge clamp (blind fire is allowed up to 2.75 from the edge, where no arm reaches
   round it).
5. **Vault clearance.** The clip is authored on the code's own path (Bezier, top + VaultClearance 1.8). Blocky legs swung over
   need ~0.5 more: `VaultClearance = 2.3` removes the last 0.2-0.35 of thigh-in-crate. `Land` marker = touchdown (f32).
6. **DiveAim (new).** `MoveAnimations.DiveAim` -> source `CoverDiveAim`; play it while aiming mid-dive (fade 0.08), stop into
   the Roll. Authored for the code's aimed root pitch (DivePitch x 0.25): keep that factor. Note BodyAnimController loads it at
   Action3 (the source says Action4): either is fine as long as it beats the Hold's legs.
7. **Roll** is a diagonal shoulder roll now; `Land` marker at 0.333 s of clip time.

## Movement (MovementController / a new locomotion layer)
8. New gun locomotion (priority Movement, legs + hips + chest counter-rotation; the weapon Hold keeps the arms): `MoveRun`
   (10 studs/s), `MoveWalkAim` (6), `MoveStrafeLeft` / `MoveStrafeRight` (10), `MoveBackpedal` (7.5), `MoveSprint` (20, rifle
   arms) / `MoveSprintPistol` (20, pistol arms). Play with `AdjustSpeed(speed / authored)`; blend by move direction (all 0.70 s
   except WalkAim 1.0 / Sprint 0.50). Footstep markers on every contact.
9. `MoveStart` (0.25), `MoveStop` (0.35), `TurnInPlaceLeft` / `Right` (0.5: the clip expects the code to turn the root 90 deg
   over f4-f20, Cubic InOut; feet step, never spin), `MoveLandHard` (0.45, Land f0; cancellable into movement from f10),
   `MoveLimp` (low health, authored 4 studs/s).
10. MoveSlide is now a real 0.5 s loop (Slide.Time 0.75 = 1.5 cycles; fade in 0.08 / out 0.15).

## Hits, deaths, life
11. Reactions own chest + head only (Action4, fade in 0, out 0.1): `HitFlinch` (= F), `HitFlinchF/B/L/R` by hit direction
    relative to facing, `HitHeadshot`, `HitBurning` (loop while burning), `HitExplosionStagger` (owns hips + legs: stands a
    crouched player up on purpose; turn the root to face the blast first).
12. Deaths (Action4, whole body, last frame static): `DeathForward` (shot from behind), `DeathBackward` (from the front),
    `DeathCrumple` (generic), `DeathHeadshot`, `DeathExplosion` (switch to the ragdoll at the `Ragdoll` marker, f12),
    `DeathCover` (killed while in cover, slides down the wall). Markers: `DropGun` (the gun leaves the hand: drop / physics it),
    `Ground` (body hits the floor: sound / dust).
13. Idle: `IdleFidgetShift` (Idle), `IdleFidgetGunCheck` (Action, arms), `IdleFidgetLook` (Idle) on a 6-12 s random timer when
    standing still. Breathing over a weapon Hold has to be a code layer on the Waist (the Hold keys the torso): use the
    `BreatheCalm` (4.0 s, chest +1.2 deg) / `BreatheHeavy` (1.5 s, +3 deg) curves; the clips themselves are for unarmed / lobby.
14. `RoundReady` (1.2, `Tap` marker), `Victory` (3.0) / `Defeat` (2.5) hold their last pose on the results screen,
    `DoorOpen` (0.8, `Push` marker = the door starts moving; off arm only, the gun stays on line).
15. `BotLeanLeft` / `BotLeanRight` (Action2) now key hips, legs, chest and head (a real lean with planted feet); bots should
    not play the cover shuffle at MoveTo speed 10 without `AdjustSpeed(10/8)`.
16. Ragdoll notes: deaths hand off cleanly to a ragdoll at any frame after `DropGun`; DeathExplosion expects it at `Ragdoll`.
