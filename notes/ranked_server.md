# Ranked ELO server system (2026-10-16, [RANKED])

Edward's ranked rules **v2** (`notes/ranked_design.md` "Edward's rules v1" + the lead's v2 message; the reference implementation is
`tools/ranked_table.py`, commit b7ddd07, and `notes/ranked_elo_table.md` is generated from it). Built in the working copies only:
lobby `Tacticals_rebuild.rbxl` (studio 829eb64d) and match place `match_place_ref.rbxl` (studio 331cb3a0). **Not saved.**
UI requests: `notes/ranked_ui_requests.md`.

## 1. Pieces
| Piece | Where | What |
|---|---|---|
| `RankedCore` | `ReplicatedStorage.Modules.Shared.RankedCore` (both places; the client may require it) | Read-only maths: config flags, ladder lookup (`TierOf`, `Info`), `Gain` / `Loss` / `Delta`, `Window` / `PairOk` / `PickGroup`, `Migrate`, `ShieldReady`, `DecayDue`, `LadderKey`. No side effects. |
| `RankedServer` | `ServerScriptService.Shared.RankedServer` (both) | The unified record (read, lazy migration, write through the player's replica), `ApplyResult`, decay, the Rank* attributes, the leaderboard (OrderedDataStore or memory mock), admin helpers. |
| `RankedService` | `ServerScriptService.RankedService` (Script, both) | Boots RankedServer: join migration + attributes, decay, the leaderboard refresh loop. Studio only: `ServerStorage.RankedTestHook` (BindableFunction for the tests). |
| Admin commands | `ServerScriptService.AdminFramework.Commands.Ranked` (both) | `;setelo`, `;rankreset`, `;rankinfo` (`;elo`), `;simrank`. Source `scripts/admin/Commands/Ranked.lua`. |
| [RANKED] edits | match `Managers.RoundManager`; lobby `Managers.MatchmakingManager`, `Data.DataManager.Template` (comment), `Data.PlayerStore` (`PlayerStore.Ranked`) | See section 6. |

Sources: `scripts/ranked/{RankedCore,RankedServer,RankedService.server}.lua`, `scripts/admin/Commands/Ranked.lua`.
Install: `python tools/ranked_build.py --run lobby|match [UNDO]` (embeds the sources into `fix/ranked_install.lua` and runs it; idempotent;
backups `ServerStorage._RebuildRemoved.RANKED_<name>_Orig`; new objects carry attribute `RankedInstall`).
**Order:** match place `match_place_build` -> `data_release` -> **ranked**; lobby `lobby_duels` -> `admin` -> `data_release` -> **ranked**.
`tools/match_place_build.py` rewrites RoundManager wholesale: re-run data_release and then ranked after it.
`tools/admin_build.py` and `tools/match_place_build.py` now also embed `Commands/Ranked` (same file; whichever installer runs last writes it).

## 2. The rules as built
- **Ladder:** tier index 0..20 = Bronze 1 .. Commander 3; tier t starts at (t+1) x 100 ELO (Bronze 1 = 100, Silver 1 400, Gold 1 700,
  Platinum 1 1000, Diamond 1 1300, Elite 1 1600, Commander 1 1900, Commander 3 2100). Floor 100: ELO never drops below it.
  2200+ stays tier 20 (Commander 3) for the maths; **Warlord** = ELO >= 2200 and (no cutoff, or ELO >= the cutoff).
- **ELO per match** = `tools/ranked_table.py` exactly: base W/L interpolated by tier between the rank values (Bronze 30/10 .. Commander
  10/25); d = (oppTier - myTier) / 3; win vs stronger x sqrt(2)^d, vs weaker x sqrt(0.4)^-d; loss to stronger x sqrt(0.5)^d; loss to
  weaker: g = -d, L + (60 - L) g / 2 up to g = 2, then 60 + 40 (g - 2) / 4 (100 at g = 6); round like Python (`round`, halves to even:
  8 of the 882 tier pairs differ from a half-up round), clamp 1..100.
- **Team modes (proposal, `TeamOpponent = "AverageTier"`):** each player's change uses their own tier vs the other team's **average
  tier** (fractional), so teammates of different ranks gain / lose different amounts.
- **Draw:** `DrawDelta = 0` (nothing changes; no win / loss counted; LastPlayed updated).
- **Window (tiers either side):** 2 at 0 s, linear to 6 at 5 min, linear to 18 at 60 min, then 18. A pair is valid only when the tier gap
  is inside **both** players' windows; a 2v2 / 3v3 group needs every pair valid. The pick is oldest-first ("quickest match first"):
  the longest-waiting player anchors and the others are taken in queue order. Then the old snake draft by ELO splits the teams.
- **Casual:** unchanged (no ELO). Lobby pads stay casual (`MatchConfig.DuelRanked = false`, `LobbyConfig.RankedBays` empty).
- **Bots / admin end:** live, a match with a test bot or ended by `;endmatch` changes no ELO. Studio test bots do when
  `Config.StudioBotRanked` (the bot's ELO = StudioTeleportData `BotElo`, else `Config.StudioBotElo`, else the other side's tier).

## 3. Data: the unified record
`Ranked[<ladder key>] = { V = 1, Elo, Peak, Placed, Wins, Losses, Streak, ShieldDay, LastPlayed, Decayed, Rating }`
- ladder key = the mode (`"1v1" / "2v2" / "3v3"`) or `"All"` with a shared ladder (`RankedCore.LadderKey(mode)`).
- `Streak` +n wins in a row / -n losses; `ShieldDay` = UTC day number the shield was last used; `LastPlayed` os.time of the last ranked
  result; `Decayed` = idle days already charged since LastPlayed; **`Rating` = a mirror of Elo** for the old readers (LobbyUIController /
  PlayScreen "SR", admin `;stats`). If anything else writes `Rating` (old code, `;setstat Rating1v1`), Elo follows it on the next read.
- **Lazy migration** (`RankedCore.Migrate`, on the first read in either place, written back): the lobby's `{Rating, Wins, Losses}` and the
  match place's `{Rating, Played, Wins}` (Losses = Played - Wins) -> Elo = 100 + (Rating - 1000) x 1, floor 100 (so an untouched 1000 = 100,
  1350 = 450); wins / losses kept; Peak = Elo; Placed = min(Placements, wins + losses). No entry -> a new player's record (100).
- Both places read and write it only through `RankedServer` (match place: the replica if present, else the raw profile table, like the
  other match rewards). `PlayerStore.Ranked(player, mode)` in the lobby returns it. Every player gets all three records at join.

## 4. Interface for the UI
### Player attributes (set at join, after every ranked result / admin change, on a leaderboard refresh, and when MM_Queue changes)
Flat attributes describe **one ladder** = `RankMode`: in the match place the match's mode; in the lobby the ranked queue the player is
searching (`MM_Queue` R1v1/R2v2/R3v3), else `DefaultMode` ("1v1").
| Attribute | Type | Meaning |
|---|---|---|
| `RankMode` | string | the ladder key the flat attributes describe ("1v1", or "All" when shared) |
| `RankElo` | int | current ELO (>= 100) |
| `RankPeak` | int | best ELO on this ladder |
| `RankTier` | string | rank name: Bronze, Silver, Gold, Platinum, Diamond, Elite, Commander, **Warlord** |
| `RankTierIndex` | int | 0..20 (0 = Bronze 1 ... 20 = Commander 3; 2200+ stays 20) |
| `RankDivision` | int | 1..3; **0 for Warlord** |
| `RankName` | string | display name: "Gold 2", "Commander 3", "Warlord", "Warlord #12" |
| `RankFloor` | int | ELO where this tier starts (Warlord: the cutoff, or 2200) |
| `RankNextFloor` / `RankNextName` | int / string | the next tier's floor and name (Commander 3: 2200 / "Warlord"; nil for Warlord) |
| `RankWarlord` | bool | Warlord now |
| `RankPlace` | int? | leaderboard place when in the cached top 200 at 2200+ |
| `RankPlaced` / `RankPlacements` | int / int | placement matches played / required (0 = placements off; show the emblem when RankPlaced >= RankPlacements) |
| `RankShield` | bool | the daily shield is ready (always false while `ShieldEnabled` is off) |
| `RankedAll` | JSON | every ladder: `{ "<key>": { elo, peak, tier, rank, division, name, floor, nextFloor, nextName, warlord, place, placed, wins, losses, streak, shield } }` |

The ladder maths for drawing (tier names, floors, progress) can come from `require(ReplicatedStorage.Modules.Shared.RankedCore)`:
`RankedCore.Tiers[t] = {Tier, Rank, Division, Name, Floor}`, `RankedCore.Info(elo, cutoff, place)`, `RankedCore.Ranks`.

### ReplicatedStorage attributes (leaderboard; refreshed every `LeaderboardRefresh` = 120 s in both places)
- `RankedTop_<key>`: JSON array, best first, at most 200, only ELO >= 2200: `[{ "userId": 1, "name": "ocxa", "elo": 2450 }, ...]`.
- `RankedCutoff_<key>`: the Warlord threshold ELO (the 200th entry's ELO) or **nil** when fewer than 200 are at 2200+ (then every 2200+
  player is Warlord). Before the first refresh nobody shows as Warlord.
- `RankedLadders` (JSON list of keys), `RankedRefreshedAt` (server time), `RankedMock` (true when the memory mock is used).
Per-key names (not one `RankedTop`) because ladders are per mode by default; with a shared ladder the key is `All` (`RankedTop_All`).

### MatchResults payload (`Events.Match.MatchResults:FireClient(player, summary)`, match place, ranked matches)
All old fields are kept (`Won, Draw, Score, Kills, ..., RatingChange` = the delta). Added when ELO changed:
`eloBefore, eloAfter, delta` (signed; 0 for a shield), `shieldUsed, promoted, demoted` (booleans; tier or Warlord change), `rankBefore,
rankAfter` (display names), `tierBefore, tierAfter` (0..20), `ladder`, `placed, placements`, `draw`. Absent for casual, admin-ended and
live bot matches.

## 5. Config flags (`RankedCore.Config`) and defaults
| Flag | Default | Note |
|---|---|---|
| `PerModeLadders` | **true** (one ladder per mode, `Ranked[mode]`) | false = one shared ladder `Ranked.All` (the one-line switch; the first read adopts the best per-mode record). OPEN |
| `StartElo` / `MigrateOldRating` / `OldStart` / `MigrateScale` | 100 / **true** / 1000 / 1 | new players 100; an old Rating maps to 100 + (Rating - 1000). OPEN |
| `Placements` / `PlacementMultiplier` | **0 (off)** / 2 | when > 0: the first N ranked matches count double and RankPlaced < RankPlacements tells the UI to hide the emblem. OPEN |
| `ShieldEnabled` / `ShieldBelowElo` | **false** / 1600 | first ranked loss per UTC day costs 0 below Elite 1. OPEN |
| `DecayEnabled` / `DecayFromElo` / `DecayIdleDays` / `DecayPerDay` | **false** / 2200 / 7 / 50 | applied at join; never below 2200. OPEN |
| `TeamOpponent` | "AverageTier" | the proposal in section 2. OPEN |
| `DrawDelta` | 0 | OPEN |
| `WarlordFrom` / `WarlordCount` | 2200 / 200 | |
| `LeaderboardWriteMin` | 0 (write every ELO) | every ranked result writes, so the board and the cutoff are complete; set 2200 to write only the top band |
| `LeaderboardRefresh` / `LeaderboardVersion` | 120 s / "v1" | store `Ranked_<key>_v1` |
| `Window0/Window5/Time5/WindowMax/TimeMax` | 2 / 6 / 300 / 18 / 3600 | tiers / seconds |
| `StudioBotRanked` / `StudioBotElo` | true / nil | Studio tests only |

## 6. [RANKED] edits
- **match RoundManager** (5): requires RankedCore / RankedServer; ratings per side = the side's average tier from the unified record
  (Studio bot sides: BotElo); `award` calls `RankedServer.ApplyResult(player, mode, otherSideTier, won, draw)` and copies the payload
  into the summary (`RatingChange = delta`), also for Studio bot matches; the bot / aborted early return keeps those fields; the old K32
  write to `data.Ranked[mode]` is gone. `MatchCore.eloDelta` and `MatchConfig.Rewards.RankedK` are no longer used by the match place.
- **lobby MatchmakingManager** (6): requires; `ratingOf` = `RankedServer.EloOf`; queue entry gets `k` = tier (also on the refresh
  re-create and in `searching[player].tier`); `pickGroup` for ranked returns `RankedCore.PickGroup(pool, need, now)` (the old rating-gap
  code below it is unreachable; `LobbyConfig.RatingWindow` is unused). Casual queues unchanged.
- **lobby Template** (comment only: the new record shape) and **PlayerStore** (`PlayerStore.Ranked`).

## 7. Tests (2026-10-16)
- **Unit** (`python tools/ranked_test.py lobby|match`; `scripts/ranked/tests/unit_tests.lua` + `fixture_v2.lua` generated from
  `tools/ranked_table.py`): **100 passed, 0 failed** in both places. Edward's 11 checks of the script (11/11), the lead's three in-between
  examples (Gold 2 vs Gold 1 +20 / -23, Gold 2 beats Gold 3 +27), the **full 21 x 21 table (882 values) equal to the Python reference**,
  Python rounding, clamp 1 / 100 at both ends, floor (105 - 10 -> 100), ladder names / floors / Warlord rules, window at 0 / 150 s / 5 /
  32.5 / 60 min / 2 h (2 / 4 / 6 / 12 / 18 / 18), pair rule incl. the one-sided case, PickGroup (1v1 and a 2v2 group), migration from
  both old shapes + nil + the unified record + an external Rating write, MigrateOldRating off, placements count, shield and decay flags,
  ladder keys.
- **Play, match place** (StudioTeleportData `{"Mode":"1v1","Ranked":true,"BotElo":1000,"Teams":{"A":["me"],"B":["bot",99998]}}`, the
  absent 99998 keeps Loading open so the profile can be seeded first; kills through MatchTestHook):
  - run 1: profile seeded with the match place's old shape `{Rating 1690, Played 10, Wins 6}`; 3-0 win vs the Platinum 1 bot ->
    migrated 790 (Gold 1), **+35 -> 825 Gold 2, promoted**, record `{V1, Elo 825, Wins 7, Losses 4, Streak 1, Peak 825, LastPlayed}`, attrs
    `RankElo 825, RankName Gold 2, RankDivision 2, RankTierIndex 7` (server and client); console `[Ranked] ocxa 1v1 win: 790 -> 825 (+35)`.
  - run 2 (ShieldEnabled on via the hook, 805 Gold 2): 0-3 loss -> **shieldUsed, delta 0**, RankShield false afterwards; the client's
    MatchResults had every old field (Won, Score, Kills, Deaths, XP 0, TestMatch, RatingChange 0, ...) plus `eloBefore 805, eloAfter 805,
    delta 0, shieldUsed true, promoted false, demoted false, rankBefore/After Gold 2`. A second loss the same day (hook `apply`): -13 ->
    792, **demoted** to Gold 1.
- **Admin** (both places, AdminBindable console): `;simrank 700 1000 win` A +35 / B -39; `;simrank 700 100 loss` -60 / +60;
  `;simrank 2100 100 loss` -100 / +100; `;setelo me 2300` / `;setelo me 40 2v2` (-> 100); `;rankinfo me`; `;rankreset me 1v1` asks for
  confirm, then resets; `;cmds rankinfo`.
- **Leaderboard, mock store** (Studio): 250 fake entries 2600..2351 -> refresh: 200 kept, cutoff 2401, me at 2300 = Commander 3;
  me at 2500 -> cutoff 2402, **Warlord #101**; 50 fakes only -> cutoff nil, me at 2300 = **Warlord #51**; `RankedTop_1v1` JSON 51 long.
- **Lobby Play:** join attributes for all three ladders; the lobby's old shape `{Rating 1350, W5, L1}` -> 450 Silver 1 written back;
  `FindMatch R1v1` answers "offline" (MatchmakingManager loads with the edits; MemoryStore is unavailable in an unpublished place).
- **Install / UNDO**: both places: install -> second run "already in" -> UNDO (every edited script "matches its backup", new objects
  removed) -> install again.

Not tested (Studio can't): the real MemoryStore queues (pair pick only by unit test), the real OrderedDataStore and
`GetUserInfosByUserIdsAsync` names, two real players / 2v2 with real teams, decay over real days, a real save across places.

## 8. Open questions for Edward
1. One ladder per mode (default) or one shared ladder?
2. Start / carry-over: everyone starts at Bronze 1 = 100 (default), and an old Rating carries as 100 + (Rating - 1000). Or reset everyone to 100?
3. Placements: off (default). If on: how many (RIVALS 10), and what should they do (double changes is the built option)?
4. Daily shield (built, off) and decay at 2200+ (built, off: 7 idle days free, then -50 per day, never below 2200): turn on? numbers?
5. Team rank: own rank vs the other team's average tier (built proposal) OK?
6. Draws give 0 (built). Leaving a ranked match: today the leaver is not paid (no record write, so no ELO loss either). Should a leaver lose?
7. Leaderboard: all ELOs are written (so a full board exists for a future "top players" screen); only 2200+ counts for Warlord.
