# Handoff: Tacticals lead session (map, mechanics, server), 2026-10-19

Repo: `tacticals_rebuild.bundle` beside this file (HEAD 83d6997, includes all lead commits up to 91d5d7d).
Clone it to `Documents\tacticals_rebuild` on the Shadow PC.

## State
- **Live:** port 20 published to tacticals (lobby), Tutorial, Matchmaking and Ranked at ~12:45. It carries weapon abilities
  phases 1-3 and the 8 new items. See `notes/port_manifest.md` "Live port 20".
- **Working copies:** `Tacticals_rebuild.rbxl` (lobby) and `match_place_ref.rbxl` (match), saved 12:36 (fa7da81).
- **Queued in the repo, not yet deployed or published (UI session):**
  - f27a2d4 / ed50188: match clock, no ROUND/FIGHT banners
  - 474a994: Kit blur
  - 83d6997: Pump Shotgun / Bat / Riot Shield model fixes
- **Weapon abilities:**
  - Spec and status: `notes/weapon_abilities.md`.
  - Code: `fix/weapon_abilities.lua` (phase 1) and `fix/abilities_install.lua`, built by `tools/abilities_build.py --run both`.
  - That install embeds `scripts/abilities/Abilities.lua` and `AbilityController.lua`. The [ABILITY]/[ABILITY2] edits live in `ui/set/*`.

## Open items (lead)
- Dual Pistols: real left-hand grip (the left gun is welded 1.1 studs off the right hand).
- Bat / Katana / Riot Shield: real animations (MeleeSlash / MeleePunch placeholders).
- Bots don't use the new kit.
- Not yet tested with real input: Dual Pistols' faster fire while moving, Bat hold-to-charge with the mouse.
- Waiting on Edward's new fix list.

## Rules that carry over
- Publish only on Edward's go in the lead's OWN chat. A go relayed by the UI session doesn't count.
- Don't open Studio or take focus while Edward is using the PC. Saves use `tools/save_studio.ps1`, which refuses when another
  window is in front (Firefox counts).
- Mute Studio (`tools/mute_studio.ps1`). Use the play lock (`tools/play_lock.py take|release map`).
- Studio ids change on every reopen. Run `list_roblox_studios`, then update SIDS in `tools/*.py`.
- Publish steps: `notes/port_manifest.md`, plus `tools/port_prep.sh <Kind> <prevTitle>` (BRING_ARGS=-secondary on a two-monitor
  machine). Click positions depend on the monitor, so take a screenshot before each click.
- Source patches: never append a `-- comment` to a replaced line, because it can swallow a trailing `end` / `do`.
- Vault lessons: `roblox-build-workflow/4 Gameplay Layer.md`. Project log: `building-practice/tacticals/Tacticals Lobby Rebuild.md`.
