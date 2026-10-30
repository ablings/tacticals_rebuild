# Motion style guide: READY (animation trainer, 2026-10-30)

The two animator tasks can start.

- **Style:** Grounded Tactical, vault `05 Animation/Animation Styles/Grounded Tactical.md` (the catalogue folder is
  `Animation Styles`, not `Styles`). Weight and balance, anticipation / follow-through, an easing table (which EasingStyle for
  which beat; Blender's interpolation modes have the same names), overshoot, hold frames, recoil per gun class (clip peak, push,
  spring for the tail), reload rhythm and gun-part timing (hand-driven vs spring-driven parts), off hand, head lead, hip sway,
  must-not list.
- **Targets:** `notes/anim_style_targets.md`: every clip of `notes/animation_list.md` plus the new ones (SMG / Rifle / Shotgun /
  Sniper sets, Draw / Holster / Inspect per prefix, tactical vs empty reloads, gun-butt QuickMeleeBash, knife heavy / backstab,
  Bat / Katana / RiotShield, FragPinPull + FragCook + FragThrow, FlashThrow, LandminePlace, MedkitUse, armed locomotion, sprint
  gun-low, start / stop / turn, hard landing, MoveSlide loop, DiveAim, directional flinches, headshot, explosion stagger,
  burning, limp, 5 deaths, 3 fidgets, calm / heavy breathing, RoundReady / Victory / Defeat, DoorOpen). Lengths from the code,
  beats in frames at 60 fps, easing per segment, markers, gun-part keys.
- **Rig:** Starter Blocky (R15 names). Guns: gun-part names and pivots at the top of the targets page; keep the remodel's Motor6D
  names matching (`Slide`, `MagBase`, `Cylinder`, `Hammer`, `Mag`, `CockingKnob`, `ChargingHandle`, `Pump`, `BoltArm` + `BoltKnob`).
- **Systems follow-ups** (end of the targets page): ReloadEmpty timing, shotgun shell loop, new prefixes, Grip / Holstered markers,
  knife heavy config, frag cook flow, landmine place path, breathing as a code layer, DiveAim root pitch.
- **Not done:** no reference footage was captured this round (fast brief); the numbers come from real handling, the game's
  config and the finished pull-up / lean clips. The card is `status: developing` until a reference is measured.
