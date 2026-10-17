# Mobile / touch controls (2026-10-17)
Edward: "now its time to do the ui for mobile", RIVALS-style. Reference screenshots: `notes/ref_mobile/4-16.webp`
(4-6 HUD, 7 Layout Editor, 8-16 Settings > Touch tab).

Split (Edward: "send all of that to ui"):
- **UI session**: touch HUD, Layout Editor (3 slots + import, drag/resize, reset), Touch settings tab (Left Handed, Opaque,
  Transparency, Camera Sinking, Show Ammo, per-button Enabled/Custom, Double Tap To Attack + window 0.25, Auto Jump,
  Easy Slide, Slide off by default), layouts persisted in SettingsConfig.
- **Map/lead session (here)**: `ReplicatedStorage.Modules.Shared.InputActions` (scripts/touch/InputActions.lua),
  installed in the lobby + match copies by `python tools/touch_build.py --run lobby|match` (UNDO supported).
  Buttons call Press/Release/Tap; controllers listen with Bind / BindCAS next to their ContextActionService binds.

State before this: no touch support anywhere (only Icon checks TouchEnabled).
Hooks: the UI session adds the [TOUCH] hooks itself in all its [SET] controllers.
Also mine: `StarterPlayerScripts.TouchFire` (double tap on free screen within Config.DoubleTapWindow, second finger held = Fire held)
and `InputActions.CameraShouldUse(input)` (joystick-zone touches and non-sinking button touches never turn the camera).
Action names: Fire Aim Reload Inspect Jump Crouch Slide Dash Cover QuickMelee QuickUtility ThrowGadget Equip1-3 Scoreboard CameraSwap
(Tacticals has 3 slots, no Ability/Emote).
Was open: who adds the [TOUCH] hooks in CameraController / CoverController / HotbarController (UI-owned); the touch camera
(aim follows the swipe, button camera-sinking) and the double-tap-to-fire detector.
