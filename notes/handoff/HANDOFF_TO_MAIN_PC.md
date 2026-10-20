# Handoff: Shadow PC lead -> main PC lead (2026-10-19 ~22:45, Edward: "hand off to the main pc and let them work it from there")

The Shadow PC stops driving Tacticals. Everything is committed and pushed (github.com/ablings/tacticals_rebuild master, at or after
bb595d2). Both working copies (`Tacticals_rebuild.rbxl`, `match_place_ref.rbxl`) are saved with everything below. No Studio is open on the
Shadow PC, the play lock is free, nothing is half-applied.

## Live now (published from the Shadow PC on Edward's go, each diffed vs the previous port and read back; see notes/port_manifest.md)
- Port 21: match clock, Kit blur, connected Pump Shotgun / Bat / Riot Shield.
- Port 22: Dual Pistols fire L/R (both muzzles named), Training TrialItem picker for every slot.
- Port 23: Edward's movement spec ([MOVE2] fix/movement_spec.lua), DrawTime + server draw check + Xhair countdown attributes, TrialKit,
  UI crosshair ring + picker flow.
- Port 24: reload cancel, base speeds -20%, map vote drops to 5 s once everyone voted (MatchCore.waitVote), rematch fix (no series cap,
  votes reset every game), MM_FailReason + UI MatchFoundGate.
- Port 25: holstered kit on the body (scripts/holster/HolsterManager.server.lua, installed with tools/install_localscript.py --server).

## In the working copies, NOT live yet
- Draw from the holster: fix/draw_animations.lua builds KeyframeSequences DrawHip / DrawHipLeft / DrawBack / DrawBackLeft in
  ReplicatedStorage.Repository.AnimationSources; WeaponConfig.DrawAnimation (in fix/movement_spec.lua) picks one per gun; WeaponController
  plays Draw instead of Equip, sped to DrawTime. Works in Studio.
  **Blocked on upload:** Save to Roblox with Creator = gunsy funsy fails with HTTP 403 from the Shadow account (whitteguy can't create
  group assets). To finish: open Tacticals_rebuild.rbxl with Edward's account, select each of the 4 sources, right-click > Save / Export >
  Save to Roblox > Creator gunsy funsy > Save (leave Delete Local Instances off), set attribute PublishedId = "rbxassetid://<id>" on each
  source in BOTH working copies (run fix/draw_animations.lua first in the match copy if it isn't there: it keeps an existing PublishedId),
  save, publish as port 26. Until then live falls back to the Equip animation (safe).

## Open items (Edward)
- Riot Shield holster: I put it flat on the back (too big for the front waist he asked for). Ask Edward.
- Lead items still open from before: Dual Pistols real left-hand grip, real Bat / Katana / Shield animations, bots using the new kit,
  real-input tests (Dual Pistols moving fire rate, Bat hold-to-charge).
- Not verified by eye: the vault arc at the new speed (0.34375 s).

## Gotchas found on the way (worth knowing before the next port)
- Live scripts have drifted from some installer files: LobbyDuelManager (lobby) and RoundManager's SERIES block (match) were patched in
  place by later installers, so fix/lobby_duels_install.lua / fix/postmatch_install.lua no longer match live. I patched only the exact
  spots live (vote block; rematch lines). Don't re-run those installers blindly.
- tools/split_build.py, run_luau_at.py, install_localscript.py now find mcpcli.py under ~ (were hard-coded to C:\Users\aroki).
- The "reopened cloud place" windows after Publish As hang on "Applying script changes" when closed; they hold no edits, kill them.
- Opening ~8 Studio windows shows a "Low System Resources" dialog on the last one: click Proceed.
- The UI session (Shadow PC, "UI session") works in the same repo folder on the Shadow PC; it has its own client work queued.
