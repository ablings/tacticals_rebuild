# Lobby UI rebuild (UI session, from 2026-10-16)

Edward: bring what was learned in the RIVALS replica (`rivals_practice/ui`, vault "RIVALS UI Practice") into this
lobby. RIVALS = how it behaves and how it feels (chunky, readable, 3D viewmodel icons, instant feedback, one menu at a
time, the HUD pushed aside by menus). Tacticals = its own look, so nothing reads as a RIVALS copy. Every setting works.
Placeholders (fake requests, fake queues) only appear when a real player is actually on a pad.

## Fundamentals that differ from RIVALS
- **One gun.** Loadout = Weapon + Gadget + Melee (LobbyConfig.Slots). No primary / secondary split.
- **Scissors** are the currency (data.Credits), never keys. Icon = the 3D scissors model.
- **Viewmodels, not images:** icons are ViewportFrames of the real meshes (LobbyUIController/Icons, UIKit/ViewIcons).
- **Pads are lobby queues** (QueueManager, bays with Open / Countdown / Deploying), PLAY is online
  (MatchmakingManager, MM_* attributes). The match runs in another place (LobbyConfig.MatchPlaceId).
- **Training room** is in this place (TrainingManager, TrainingGate, swap bins).

## Look (distinct from RIVALS)
- Palette from UITheme / Tac: bone (236,232,218), field grey (150,156,140), olive (107,122,58) / olive hi (138,156,74),
  gunmetal (26,29,26), deep (12,14,11), red (196,52,46). No RIVALS purple / gold / lime.
- Shapes: squared corners with corner brackets (Tac.brackets), olive side bar on headers, stencil Oswald headings,
  chevrons for progress. RIVALS uses rounded white pills: we use squared "deployment board" plates.
- Same feel: hover grows / lifts, presses squash, menus slide the HUD off, toasts drop in from the top.

## Order
1. Menu manager: one full-screen menu at a time (today Kit / Shop / Missions / Settings stack on each other); HUD pushed
   aside while a menu is open; Esc / X close.
2. Pads (Edward's first complaint): the "MATCH FOUND · DEPLOYING" panel goes. On a pad: the HUD hides and a bottom box
   shows your bay (your slot, your team's slots, the other team's, "Invite" a friend), countdown in the box when full.
   Elsewhere: a small VS / Join box per bay that has a real player on it (none when the pads are empty).
3. Lobby HUD: scissors pill top centre, missions widget left, nav bar bottom (Kit / Shop / Missions / Settings / Codes,
   viewmodel icons), play row with party, notifications, world prompts in our style.
4. PLAY: modes + Training + Ranked lock, searching pill with timer + cancel, loading/teleport screen.
5. Settings: audit every row against SettingsConfig.Apply; make each one do what it says.
6. Training room UI: picker for the gun (one slot) / gadget / melee, range HUD (presets from Settings), leave key.
7. Shop, Missions, Kit polish against the replica; Codes.

Each step: built in a sandbox Studio (a read-only copy of the file), playtested, then deployed into the working copy
(8ef4e21a) in a window agreed with the Tacticals session. Sources live in `tacticals_rebuild/ui/`.

## Progress
- 2026-10-16 **Pads** (`ui/pads/PadUI.client.lua`): on-pad box (your slot + level, team slots, VS -> countdown, Invite),
  deploy screen only when really deploying, JOIN boxes only for bays with a real player. Old PadQueueUI disabled.
  Patch: LobbyConfig `StudioSoloStart = false` (it started a bay with one player in Studio = the "match found" screen).
- 2026-10-16 **Lobby HUD** (`ui/hud/LobbyHudController.lua`, `ui/hud/PublicStats.server.lua`): scissors pill top centre
  (ViewIcons scissors, count, + opens the Scissors shop), DAILY MISSIONS widget (real daily quests, progress, red flag
  when claimable, click = Missions) with TO PADS (teleports to the duel hall facing pad A), OPERATORS board (level, wins,
  you in olive; Tab toggles; replaces the Roblox player list). Old top-left card hidden. Hides with menus / Kit room /
  pads / Training. Sheet: `notes/ui_phase3_hud.png`.
- Deployed to the working copy (8ef4e21a) 2026-10-16 after the Tacticals session cleared it; NPC_OpensPanel guard kept. Not saved yet.
