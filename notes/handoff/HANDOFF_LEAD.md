# Handoff: Tacticals lead session, Shadow PC -> main PC, 2026-10-21 ~19:50

Repo `ablings/tacticals_rebuild` (master), last lead commit after port 32. `git pull` first. The UI session STAYS on the Shadow PC
(its handoff: top of `notes/handoff/HANDOFF_UI.md`); only the lead moves. Coordinate Studio with it through the play lock
(`tools/play_lock.py take map` as its own command) and messages ("UI session").

## State
- **Live: port 32** (2026-10-21 ~19:35-19:50, all four places: tacticals lobby, Tutorial, Matchmaking, Ranked; every copy checked with
  `out/c32.lua`, all true; match places read back from the cloud). Details: `notes/port_manifest.md` "Live port 32".
- **Working copies equal live** (both saved, committed). Shadow PC studio ids: lobby `2b143295-5bef-4a32-bb3e-ab91aeb7c756`,
  match `9b3009a8-db27-4432-bd33-118ae8ac218f` (they change on every reopen).
- Today's queue with every item's state and test notes: `notes/lead_queue_2026-10-21.md` (items 1-17 + afternoon additions).
  Weapon-feel brief + RIVALS measurements: `notes/feel_brief_2026-10-21.md`, `notes/feel_ref/`.

## What shipped in ports 31-32 (lead side)
- Port 31: crouch/slide tracks load after the body's Ready; no Ready button (3rd pick = ready); [PREROUND] 5 s countdown, kit locks at
  Live, no aim / melee before Live; utility in RoundEnd + cleared each countdown; MaxHoldTime 5; D-pad up = dash (Settings = hold
  View/Select, Training picker = D-pad down); map vote on the solid backdrop; [CLIMB] (deep / blocked / head-high cover).
- Port 32:
  - Mobile join: phones wait <= 5 s for assets; Training picker tiles built on first InTraining; lobby **StreamingEnabled**
    (`fix/streaming.lua`: pads / Heli / Showroom pinned, Showroom Folder -> Model; LobbyFX + SettingsEffects catch streamed parts).
  - [HITINFO] HitConfirm 6th arg { pos, victim, dealt, source, weapon, pellet, backstab } for every source (UI draws numbers / flash).
  - [COOK] Frag fuse starts on press (2 s), explodes in hand; CookStart / CookFuse attributes. [RTHROW] RIVALS throw math for every
    throwable (tap = roll, hold = 100 studs/s at the crosshair, gravity x0.1875 until first touch, arc while held). [TTRAIL] white
    trail. [THROWANIM] overhand SmokeHold / SmokeThrow / SmokeThrowLeft.
  - Animations uploaded to gunsy funsy today (whitteguy is now group Admin): CoverClimb 137843743816822, SmokeHold 103260577057488,
    SmokeThrow 103332896416040, SmokeThrowLeft 119020533976457 (PublishedId on the sources in both copies).
  - [FEEL] `ui/set/WeaponFeel.lua` (child of WeaponController): equip bounce (RIVALS spring 0.625 / 12.5), camera-turn sway, bob,
    recoil kick, reload roll - own character only, layered on Motor6D.Transform in PreSimulation.
  - [WRAPS] v1: `scripts/wraps/WrapConfig.lua` + `WrapManager.server.lua` via `tools/wraps_install.py`; 8 static wraps (5 owned by
    default; Hazard / Woodland / Carbon locked, "Coming soon" - Edward: not unlockable yet); template parts tagged WrapChannel A/B,
    WrapSkip; profile data.Wraps; Equip / Favorite remotes. Textures `art/wraps/` (Python-made, uploaded under whitteguy).
  - [TRASHCAN] the 9 Training swap bins are red cans ("Trash Can / Change Weapons", F; the crate stays invisible under it - a prompt
    moved onto a new part stopped showing).
  - [CALLOUT] Instructor barks on the tutorial's dark plate (UI rounds 4/6 sizes folded in). [AUTOPAY] tasks pay out by themselves
    (~3 s, the existing "Task Completed" RN banner). [BOARDS] LobbyTopKills / LobbyTopStreak / LobbyTopLevel next to LobbyTopWins.

## Needs Edward / a live check
- Feel live: climb + throw animations (they never play in local Studio), streaming on a phone, sway / bob / reload roll (not measured).
- Stray asset: CoverClimb uploaded to whitteguy by mistake (136099030362295) - unused, deletable.
- Daily tasks pool unchanged (Edward: keep it). Skins: Edward builds them (keep stats from WeaponConfig, wraps work on skin models).
- Not built: an in-hand grenade (for RIVALS' "next one rises from below"); bots-to-fill-matches is parked (Edward).

## Shadow PC gotchas learned today
- The Claude app window can sit topmost over Studio and eat computer-use clicks (screenshots hide it): ask Edward to minimize it.
- Group asset uploads need a role that can create group assets; Studio only lists such groups in the Creator dropdown.
- `RunService.PreSimulation` passes only deltaTime. ProximityPrompts moved onto a freshly built part may stop showing - keep them on
  the original part. Edit-mode `require` caches (check sources, not module values). execute_luau runs in a plugin VM with its own
  module cache (DataManager:Get is nil there - test through the game's remotes). Health goes negative on a killing TakeDamage.
- `port_prep.sh` has aroki paths; on the Shadow PC use a copy with Shadow paths. The Ranked window lists as "Game" in MCP at first.

---

# Handoff: Tacticals lead session (map, mechanics, server), main PC -> Shadow PC, 2026-10-21 ~12:15

Repo: GitHub `ablings/tacticals_rebuild`, branch `master`. Run `git pull` in `Documents\tacticals_rebuild` on the Shadow PC.
Push after every commit. Vault: Obsidian Remotely Save. Pages: `wiki/building-practice/tacticals/Tacticals Lobby Rebuild.md`
(project log) and `wiki/log.md`.

## State
- **Live: port 30**, published to tacticals (lobby), Tutorial, Matchmaking and Ranked at about 12:05 on 2026-10-21. See
  `notes/port_manifest.md` "Live port 30". Nothing is queued: the working copies equal what's live.
- **Working copies:**
  - `Tacticals_rebuild.rbxl` (lobby), saved 02:32:55 by the UI session.
  - `match_place_ref.rbxl` (match), saved 02:34:46.
  - Both are committed. No Studio is open on the main PC: a GPU reset (3rd in 2 days) killed them all.
- **Studio ids change on every reopen.** Run `list_roblox_studios`, then update `SIDS` in `tools/*.py`. Last ids:
  lobby `835403f5-1c18-4451-b6da-d25ee5c2f672`, match `221cdf09-8c72-40c3-83ef-afb3ad146aac` (both dead now).

## Done since the last handoff (ports 26-30)
- Practice Range map from Edward's floor plan:
  - Open-roof whitebox, all white with the training grid texture.
  - 1v1/2v2/3v3, per-map spawns and lighting (`fix/map_practice_range.lua`, now `fix/map_arena.lua`: the map is the Arena since 2026-10-26; `fix/map_env.lua`).
- Draw-from-holster animations (4 ids in the working copies).
- [ROUNDFLOW] (`fix/round_flow.lua`):
  - The weapon swaps at once until you move more than 2 studs or fire; after that the pick is queued to the round end (KitLocked).
  - Guns fire during RoundEnd and deal no damage.
- [KILLFEED] Kill payload weapon + noscope. [STATS] results Assists / DamageDealt / DamageTaken.
- [GADGETTHROW] then [THROWNOW] (`fix/gadget_throw.lua`, `fix/throw_instant.lua`):
  - Every gadget except the Medkit is thrown at full strength on press: TapTime 0, ChargeTime 0.01, MaxHoldTime 0.02, speeds 36-105.
  - The Landmine is thrown and arms where it lands.
  - Frag fuse 2 s (Edward: "make the full windup for the grenade 2 seconds").
- Hub settings as server attributes (HubSettingsBridge, lobby only), player attribute Device (DeviceBridge, both places).
- [REMATCHEARLY] (`fix/rematch_early.lua`): a Rematch pressed during the results screen counts (it used to be dropped).
- [DUALGRIP] (`scripts/abilities/DualGrip.server.lua`, installer `fix/dual_grip_install.lua`):
  - The Dual Pistols' left gun is welded to the LeftHand while the tool is held.
  - It uses a Weld with C0. A WeldConstraint does NOT replicate the offset.
- [TUTSTUDIO] (`fix/tutorial_studio_duel.lua`): Studio no longer auto-starts the tutorial while `StudioTeleportData` simulates a duel.
- `fix/abilities_install.lua` re-runs cleanly again (drifted edits count as applied). Rebuild it with `tools/abilities_build.py`.
- Overnight playtest report: `notes/playtest/2026-10-21_overnight.md` (method + results + screenshots).

## Open items (lead)
- RoundEnd shots: the "no damage" branch isn't proven. The test shot was refused by the server's wall check first. Retest with a
  clear line of sight: bot right in front, shot ids above the last one, inside the 3 s RoundEnd.
- Bots (`BotManager`, only used by the Tutorial's scripted lessons) still use only the Pistol + Smoke. Only worth changing if
  Edward wants a vs-bots practice mode.
- Bat / Katana / Riot Shield: real animations (placeholders).
- Ask Edward to look at the Riot Shield holster (on the back) and the Dual Pistols in-hand pose in a real match:
  `notes/playtest/2026-10-21_*.png`.
- UI's: the tutorial "LEAVE COVER" box overlaps the hotbar on 4:3 during the tutorial itself.

## How to test a match in Studio (works; see the playtest report)
- `ReplicatedStorage.StudioTeleportData` = `{"Mode":"1v1","Teams":{"A":["me"],"B":["bot"]},"StudioTimes":{...}}`
  (`out/pt_set.lua`). Clear it with `out/pt_clear.lua` BEFORE saving. `out/pre.lua` checks for leftovers.
- Hooks:
  - `ServerStorage.MatchTestHook:Invoke("kill", -1, myId, headshot)`. The test bot is userId -1, model MatchBot_2.
  - `"config", key, value` (e.g. RoundsToWin, RoundTime).
  - `"profile", userId, {Owned = ...}` (test picks need owned items).
  - `PlayerScripts.GadgetTestHook:Invoke("Press" / "Release")`.
- `tools/srv.py <place> -e code [Client]` runs in the Play VM. Connections made there live until Play stops, so test changed code
  from a fresh Play after a real install.
- Client recorder of every RemoteEvent: `out/pt_rec.lua`.

## Rules that carry over
- Publish only on Edward's go in the lead's OWN chat. A go relayed by the UI session doesn't count.
- Play lock: `python tools/play_lock.py take map` as its OWN command. Check it printed "taken by map" before ANY Studio action.
  Never chain with `;` (that slipped twice on 2026-10-21).
- Mute Studio (`tools/mute_studio.ps1`). Don't take focus while Edward uses the PC.
- Saving:
  - Use `tools/save_studio.ps1 "\Tacticals_rebuild.rbxl"` / `"match_place_ref"`.
  - Save after every block of edits: GPU resets come without warning.
- Publish steps:
  - `notes/port_manifest.md` plus `tools/port_prep.sh <Kind> <prevTitle>` (BRING_ARGS=-secondary on two monitors).
  - Check every copy with `out/c30.lua` + `out/pre.lua`.
  - Publish As rows on the main PC: lobby y562, Tutorial 442, Matchmaking 381, Ranked 502 (x386). Click positions differ on
    the Shadow PC, so take a screenshot before each click.
- Source patches:
  - Never append a `-- comment` to a replaced line.
  - Make Lua string edits with the Edit tool. A Python heredoc through Bash turned `\\n` into real newlines.
- Commit attribution: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
