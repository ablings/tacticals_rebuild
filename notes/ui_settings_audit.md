# Settings audit (UI session, 2026-10-16)

Edward: "make all the settings work and translate correctly every ui element". `UIKit.SettingsData` is a near-copy
of RIVALS' list. Saving works (`SaveSettings` -> `SettingsConfig.Sanitize`), and `SettingsConfig.Apply` turns the
active profile into player attributes (`Setting_<Name>`, `Bind_<Action>`, `AimSensitivity`) plus SoundService
group volumes. But almost nothing reads them: in the lobby only `AimSensitivity`, `Setting_InvertedY`,
`Setting_GunHand`, `Bind_FreeCursor` and `Bind_QuickMelee` are used (CameraController, CameraConfig).
Every key is hard-coded in the configs (WeaponConfig, CameraConfig, CoverConfig, MovementConfig, HotbarConfig,
MeleeConfig, GadgetConfig).

Verdicts: **works**, **wire** (keep the row, make the game read it), **translate** (rename / reshape it for
Tacticals), **drop** (RIVALS-only; Tacticals has no such thing).

## Video
| Row | Verdict | How |
|---|---|---|
| Optimized Lighting | wire | client: Lighting shadows off + no Lobby_Bloom / Lobby_DOF, workspace attribute LobbyFXLow (LobbyFX already has a low mode) |
| Optimized Textures | wire | client: hide SurfaceAppearance / Texture / Decal on LobbyMap parts (keep a list to restore) |
| Optimized Wraps | wire | client: other players' weapon wraps hidden (needs the wrap applier to check it) |
| Sensitivity | works | AimSensitivity |
| While Aiming / While Scoped | wire | CameraController / ScopeController multiply by `Setting_WhileAiming/WhileScoped` / 100 |
| Horizontal / Vertical | wire | CameraController: separate x / y multipliers |
| Inverted X | wire | CameraController (Inverted Y already works) |
| Camera Shake | wire | ExplosionController / FlashController / CameraController shakes scaled to 0 when off |
| Hide HUD | wire | client: every ScreenGui with our HUD (LobbyHud, PlayRowUI, LobbyUI dock, match HUD) hidden |
| Hide Side Tasks | translate -> "Hide Missions Widget" | LobbyHudController hides DAILY MISSIONS |
| Padded HUD | wire | the HUD canvases get a safe-area inset (Scale) when on / when a gamepad is the last input |
| Lobby Data | translate | options "Level", "Wins" (no ELO in casual; "Rating" if ranked shows it); drives the stat above heads + the player list default |
| Weapon Inking | wire | Highlight outline on viewmodel / held gun |
| Hide Muzzle Flashes | wire | WeaponEffects skips the flash |
| Weapons Background | drop | RIVALS green-screen backdrop; the Kit room has its own scene |
| Damage Flashing (+ Base / Flash Color) | wire | the hit flash on players (training dummies + match) |
| Dark Blinds | wire | FlashController: black instead of white |

## Audio
| Row | Verdict | How |
|---|---|---|
| Master / Music / SFX | wire | Apply sets SoundService groups "Music" / "Effects", which **don't exist**: create the SoundGroups and put lobby music + gun / footstep sounds in them |
| Finisher Volume / Mute Other Finishers | translate -> "Takedown Volume" | only if finishers (Kit room "Finisher") play sound; else drop |
| Emote Volume / Mute Other Emotes | drop | no emotes in Tacticals |

## Game
| Row | Verdict | How |
|---|---|---|
| Damage Numbers (+ colours) | wire | combat hit feedback (training dummies, match) |
| Signals | drop / later | no ping system yet |
| Hide Teammate Display | wire (match place) | match HUD |
| Aiming Animation | wire | AimPoseController skips the raise |
| Smooth Projectiles | drop | no slow projectiles (smoke arc is client-drawn already) |
| Weapon Picker | drop | one gun: there's nothing to pick between |
| Gameplay HUD | translate | options "Default", "Minimal" -> match HUD |
| Shop Hover | works? | ShopScreen reads it (check) |
| Toggle Aim | wire | CameraController aim input |
| Toggle Crouch | wire | MovementController (crouch is already a toggle: the row picks hold vs toggle) |
| Toggle Sprint / Auto Sprint | wire | MovementController |
| Easy Slide | drop | no slide in Tacticals (crouch-sprint strides instead) |
| Easy Quick Attack / Quick Attack Keeping / Keep Window | translate -> "Gun Bash" rows | MeleeConfig.QuickMelee is the quick attack |
| Scroll Equip | wire | HotbarController: wheel cycles gun / melee / gadget |
| Gun Hand | works | CameraController shoulder |
| Aim Assist / Pull Strength / Auto Shoot / Reaction Time | drop (keep Aim Assist for touch / pad later) | no aim assist exists |
| Third Person Camera | drop | Tacticals is always over-the-shoulder |
| Joystick Deadzone | wire | gamepad thumbstick reads |
| Control Scheme | wire | prompts / HUD hints follow it |

## Hotkeys (translate to Tacticals' real actions; every controller reads `Bind_<Action>` with the config as fallback)
| Tacticals action | Default PC | Default pad | Read by |
|---|---|---|---|
| Fire | MouseButton1 | ButtonR2 | WeaponController (Keybinds.Fire) |
| Aim | MouseButton2 | ButtonL2 | CameraConfig.Keybinds.Aim |
| Reload | R | ButtonX | WeaponController |
| Shoulder Swap | V | DPadDown | CameraConfig |
| Take Cover | Q | ButtonB | CoverConfig |
| Vault / Jump | Space | ButtonA | CoverConfig / Humanoid |
| Dash | E | ButtonY | CoverConfig |
| Crouch | C | ButtonR3 | MovementConfig / CoverConfig |
| Sprint | LeftShift | ButtonL3 | MovementConfig |
| Gun Bash | F | ButtonR1 | MeleeConfig.QuickMelee |
| Throw Gadget | G | ButtonL1 | GadgetConfig |
| Gun / Melee / Gadget slot | One / Two / Three | DPad | HotbarConfig.Keys |
| Cycle Weapon | Z | | WeaponConfig.SelectWeapon |
| Free Cursor | LeftAlt | | CameraController (works) |
| Player List | Tab | | LobbyHudController |
| Hide HUD | | | (new client applier) |
Dropped binds: Ability, Inspect, Quick Utility, Slide, Equip Primary / Secondary / Utility / Next / Previous, Emote,
Quick Emote 1-8, Signal, Switch Weapons, Leave Duel, Stop Spectating, Spectate Next / Previous (re-add the
spectate ones when the match place has spectating).

## Account
| Row | Verdict | How |
|---|---|---|
| Delivery Mode | wire | toasts (Notify) queue or drop |
| Challenge Requests / Party Invites | drop until those exist (pads are open, invites are Roblox's) |
| Receive Gifts | drop until gifting exists |

## Plan
1. Translate `SettingsData` (rows above). Saved data is safe: `Sanitize` drops unknown keys and fills new ones.
2. New client applier `UIKit.SettingsApply` (lobby-side effects: lighting / textures / HUD / missions widget / volume
   groups / damage flash colours) + a shared `Modules.Shared.Binds` helper (`Binds.Key(player, "Reload")`).
3. Gameplay controllers read `Binds` and the `Setting_*` attributes (Weapon, Camera, Cover, Movement, Hotbar, Gadget,
   Scope, Flash, Explosion). These are shared gameplay scripts: agree the edit with the Tacticals session first.
4. The match place needs the same (it calls `SettingsConfig.Apply`); list for the Tacticals session.
