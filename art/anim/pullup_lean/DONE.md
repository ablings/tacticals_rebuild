# PullUp + Lean animations: DONE (animator, 2026-10-29)

All five are R15 KeyframeSequences, **published under the group gunsy funsy (102028987)**; ownership read back from
`economy.roblox.com/v2/assets/<id>/details` (AssetType 24 Animation, Creator Group 102028987) for every id.

| Config key | Source (`ReplicatedStorage.Repository.AnimationSources.`) | Asset id | Length | Loop | Priority | Markers |
|---|---|---|---|---|---|---|
| MoveAnimations.PullUp | CoverPullUp | rbxassetid://105938022338716 | 0.70 s | no | Action4 | `EdgeGrab` 0.10 s, `TopReached` 0.50 s |
| CoverAnimations.LeanLeft | CoverLeanLeft | rbxassetid://127076882923530 | 1.20 s | yes | Action4 | none |
| CoverAnimations.LeanRight | CoverLeanRight | rbxassetid://121823634742999 | 1.20 s | yes | Action4 | none |
| CoverAnimations.LeanLeftCrouch | CoverLeanLeftCrouch | rbxassetid://135867304208492 | 1.20 s | yes | Action4 | none |
| CoverAnimations.LeanRightCrouch | CoverLeanRightCrouch | rbxassetid://85469112434832 | 1.20 s | yes | Action4 | none |

Get the sources into a place copy: run `art/anim/pullup_lean/install_sources.lua` in Studio (command bar or MCP
execute_luau). It (re)creates the five KeyframeSequences with `PublishedId`, markers and (PullUp) `RootKeys`. Same content as
`out/anim_pullup_lean/anim_pullup_lean.rbxl` (this PC only). Group animations don't load in a local file under whitteguy
(known): test in Studio with the KeyframeSequence fallback (clear PublishedId on the client), live they play from the id.

## Leans (LeanLeft / LeanRight / LeanLeftCrouch / LeanRightCrouch)
- **Pose from frame 0.** The clip is the full lean at t = 0, so the blend is only the track fade: `Play(0.1)` (0.08-0.12)
  in, `Stop(0.1)` out. At the end of the fade the body and gun are fully out: safe to gate "can shoot" on fade end
  (e.g. `track.WeightCurrent >= 0.99` or `fadeTime` elapsed).
- **What moves:** torso rolls 16 deg out over the hip (7 at the hips, 9 at the waist) plus a 0.12 hip slide and a 0.12 chest
  slide; head moves out **0.88 studs**; gun (pistol/rifle muzzle) moves out **0.86** (lean away from the gun hand) / **0.74**
  (lean to the gun-hand side); feet stay exactly planted (solver error 0.000). Moving hold: +0.8 deg of roll and 0.02 sink
  at 0.6 s, seamless loop.
- **Keys only LowerTorso, UpperTorso and the legs.** Arms/hands/head come from the weapon Hold (Action) and Fire (Action2)
  tracks and the procedural aim, so aim and fire recoil work while leaning. Action4 so the legs beat CoverCrouch /
  CoverCrouchPeek (Action3).
- **Crouch versions** are built on the CoverCrouchPeek leg pose: play them over CoverCrouchPeek (or crouch idle).
- Left / right = the character's left / right (LeanLeft moves the head to the character's -X).
- Gun-hand note: on the gun-hand side the gun also drops 0.56 studs (the roll swings the outstretched arm down; the barrel
  stays level and points the same way). Fixing it needs arm keys, which would block the Fire recoil, so it's left.
  Left-handed players (gun in the left hand) get the mirror of this with the same clips.
- Stop the lean track before Vault / Climb / PullUp / Roll (also Action4) so two Action4 tracks don't blend.
  CoverLookPos/Neg and the melee clips also key UpperTorso at Action4: stop the lean or they blend 50/50.

## PullUp
- **Timing:** 0.00 take-off (moving on frame 1: knees bent, forearms up, muzzle up) -> 0.05 reach over the lip ->
  **0.10 `EdgeGrab`** (both hands on the edge: off hand palm on the top, gun hand a fist with the gun level above the top) ->
  0.24 pull (elbows bend, chest to the edge) -> 0.355 right knee over the lip -> 0.37 press (hands release, right foot set on
  the top) -> 0.40-0.44 left leg trails over -> **0.50 `TopReached`** (both feet land, low crouch) -> 0.62 rise -> 0.70
  standing (gun in a low ready; the weapon Hold takes over as the clip fades out).
- **Root motion is in code** (Roblox never applies it). The clip is authored for a ledge whose top is **4.5 studs** above
  the start feet and whose face is **1.6 studs** ahead of the start HRP. Move the HRP piecewise-linearly through these keys
  (y = HRP height above the start floor, z = forward, negative = toward/over the ledge; also stored on the source as
  attribute `RootKeys`, every key):

  | t | 0.00 | 0.05 | **0.10** | 0.24 | 0.37 | 0.43 | **0.50** | 0.62 | 0.70 |
  |---|---|---|---|---|---|---|---|---|---|
  | y | 2.80 | 3.22 | 3.35 | 4.35 | 6.05 | 7.05 | 7.00 -> 6.70 | 7.30 | 7.46 |
  | z | 0 | -0.30 | -0.60 | -0.90 | -1.45 | -2.30 | -2.70 | -2.70 | -2.70 |

  (exact per-key values incl. the baked in-between keys: `RootKeys`.) At EdgeGrab the wrists sit **1.22 ahead** of the
  HRP, the off hand **1.27 above** it and the gun hand **1.70 above** it at that
  moment (the face is 1.0 ahead of the HRP; the palms land 0.22 past it). **Other ledge heights** (top h studs above the
  feet): add (h - 4.5) to every y from 0.10 on, and blend that offset in linearly over 0.00-0.10 (the hop). Then the hands
  meet the edge at EdgeGrab and the feet meet the top at TopReached. **Valid range h = 4.0 to 5.1** (about chest to head
  height): below 4.0 the HRP would have to dip under standing height at the grab and the hanging legs would go into the
  floor, so lower walls should use Vault / Climb, or ask the animator for a low "step-up" variant. A different start
  distance: shift every z from 0.10 on by (D - 1.6) the same way.
  Sync: use `GetMarkerReachedSignal("EdgeGrab")` / `("TopReached")` to snap the root to the authored key positions, or drive
  the root from `track.TimePosition`. If you speed the clip (like Climb: `AdjustSpeed(track.Length / climbTime)`), scale the
  root timeline the same way.
- **Contact checks at 60 fps with that root path:** hands stay on the edge within 0.06 studs from 0.10 to 0.34 s; feet on
  the top within 0.01 after landing; no body part enters the ledge block beyond contact (0.17-0.19: shin corners inside the
  blocky feet while crouched on the top, the belly brushing the lip at 0.30); a held **pistol** never enters the block or
  the floor (max 0.08 = contact).
- **Weapons:** pistol and melee stay in the gun hand (fist on the edge, gun level above the top). A held **primary**
  touches the face at take-off (0.33 studs, magazine) and points low after landing, so **sling the primary** (hide it or
  move it to the back) from start to TopReached, as the brief allows.
- Feedback: the first frame already differs from standing (take-off crouch), so with `Play(0.05)` the move shows within
  3 frames. Recovery after TopReached is cancellable (fade out 0.1).

## Captures (`captures/anim/`)
- `pullup_lean_keys_pullup.png`: PullUp key poses, side and front, pistol and rifle.
- `pullup_lean_keys_lean.png`: all four leans, front / gameplay camera / side, pistol and rifle.
- `pullup_strip_{Pistol,AutoRifle}_{side,game}.png`: PullUp at 15 fps with the root path applied.
- `lean_review_stand.png`, `lean_review_crouch.png`: lean vs neutral.
Frames are an anchored FK copy of the posed rig (exact joint maths; edit-mode parts lag a frame). Rifles still use the
placeholder Pistol hold set (notes/animation_list.md), so the rifle sits in the pistol pose.

## Rebuild
Scripts in `art/anim/pullup_lean/src/` (lib.lua = clip builder, FK, 2-bone solver, edit-mode playback; lean.lua; pullup.lua
with its contact checks; capture helpers). They expect `workspace.AnimRig` (R15) and the capture stage from stage.lua.
