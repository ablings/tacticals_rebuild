# Ranked ELO server system (2026-10-16, [RANKED]; **v3 2026-10-17 = Edward's answers**)

Edward's ranked rules **v2** (`notes/ranked_design.md` "Edward's rules v1" + the lead's v2 message; the reference implementation is
`tools/ranked_table.py`, commit b7ddd07, and `notes/ranked_elo_table.md` is generated from it) **+ Edward's answers 2026-10-17**
(`notes/ranked_design.md` "Edward's answers", authoritative). Built in the working copies only: lobby `Tacticals_rebuild.rbxl`
(studio 829eb64d) and match place `match_place_ref.rbxl` (studio 331cb3a0). **Not saved.** UI requests: `notes/ranked_ui_requests.md`.

## 0. What changed in v3 (2026-10-17) - read this first, UI session
| Rule (Edward) | Built as | Interface change for the UI |
|---|---|---|
| One rank / ELO across 1v1 / 2v2 / 3v3, one Warlord top 200 | `PerModeLadders = false`: one record `Ranked.All`, one leaderboard `Ranked_All_s1` | `RankMode` is always **"All"**; `RankedAll` JSON has one key `"All"`. Leaderboard: **`ReplicatedStorage.RankedTop` / `RankedCutoff`** (new plain names) and `RankedTop_All` / `RankedCutoff_All` (same data; RankedScreen already reads `"RankedTop_" .. SharedKey`). **No `RankedTop_1v1/2v2/3v3` any more.** `Ranked["1v1"/"2v2"/"3v3"]` in the profile are now mirrors `{ Mirror = "All", Rating, Wins, Losses }` (so the old "SR" labels in LobbyUIController / PlayScreen show the shared ELO). |
| Reset: everyone starts at Bronze 1 = 100, old ratings don't carry | `Season = 1`, `MigrateOldRating = false`: any record without `S = 1` (every v2 record, every old shape) starts again at 100, 0 W / 0 L, placed 0, the old numbers in `rec.Prev`. Bumping `Season` resets everyone again. Leaderboard store renamed `_v1` -> `_s1`. | none (everyone shows Bronze 1 / placements 0/10 after their first join) |
| 10 placements, rank hidden, ELO x2 from 100, revealed after 10 | `Placements = 10`, `PlacementMultiplier = 2` | `RankPlaced` / `RankPlacements` (10): hide the emblem / name / ELO while `RankPlaced < RankPlacements` (RankedScreen already does). MatchResults: new `placement` (this match was a placement) and **`revealed`** (true on the 10th: show the reveal). |
| Daily shield: first loss each day costs 0, below Elite only, never a leave | `ShieldEnabled = true` (below 1600; not during placements) | `RankShield` now really turns true (after placements, below Elite, unused today). |
| Decay: Elite+ after 7 idle days, -25 per idle day, never below Elite 1 | `DecayEnabled = true`, `DecayFromElo = 1600`, `DecayPerDay = 25`, applied at join (both places) | none (RankElo just drops at join) |
| Leaving a ranked match = normal loss + 25, no shield | Leave button: charged at once; disconnect: `rec.Pending` set at match start, charged at the next join (either place) | MatchResults is **not** sent to a leaver; the payload (in `RankedServer._last`) has **`leave = true`**, `why = "leave" / "disconnect"`. A post-match "you left: -N ELO" message would have to come from the attributes (RankElo drops). |
| Queue window: full +-6 ranks at 60 / 30 / 15 min, +-2 ranks at 5 / 2.5 / 1.25 min | `WindowSpeed = { 1v1 = 1, 2v2 = 2, 3v3 = 4 }` (waited time x speed); lobby MatchmakingManager passes the queue's mode | none |
| A team queues at its average tier | `RankedCore.PickGroup` takes party entries (`v.n` players, `v.k` = `PartyTier` = average tier). The lobby has no parties yet: every entry is one player. | none |
| Team ELO: effective tier = (own tier + own team's average tier) / 2 vs the other team's average tier | `TeamOpponent = "Blend"`, `RankedCore.Delta(elo, oppTier, won, draw, ownTeamTier)`; RoundManager passes both sides' average tiers | `RankedCore.Delta` has a 5th argument (UI previews: pass own team's average tier) |
| Draws stay 0 | `DrawDelta = 0` (unchanged) | none |

## 1. Pieces
| Piece | Where | What |
|---|---|---|
| `RankedCore` | `ReplicatedStorage.Modules.Shared.RankedCore` (both places; the client may require it) | Read-only maths: config flags, ladder lookup (`TierOf`, `Info`), `Gain` / `Loss` / `TeamTier` / `Delta` / `LeaveDelta`, `Window` / `PairOk` / `PartyTier` / `PickGroup`, `Migrate`, `ShieldReady`, `DecayDue`, `LadderKey`. No side effects. |
| `RankedServer` | `ServerScriptService.Shared.RankedServer` (both) | The unified record (read, season reset, write through the player's replica + the per-mode mirrors), `ApplyResult`, `ApplyLeave`, `MarkPending` / `ClearPending` / `SettlePending`, decay, the Rank* attributes, the leaderboard (OrderedDataStore or memory mock), admin helpers. |
| `RankedService` | `ServerScriptService.RankedService` (Script, both) | Boots RankedServer: join (record, settle a pending leave, decay, attributes), the leaderboard refresh loop. Studio only: `ServerStorage.RankedTestHook` (BindableFunction: `attrs raw setraw record last config seed clearboard refresh apply leave pending settle decay`). |
| Admin commands | `ServerScriptService.AdminFramework.Commands.Ranked` (both) | `;setelo`, `;rankreset`, `;rankinfo` (`;elo`), `;simrank`. Source `scripts/admin/Commands/Ranked.lua` (the mode argument no longer matters: one ladder). |
| [RANKED] edits | match `Managers.RoundManager`; lobby `Managers.MatchmakingManager`, `Data.DataManager.Template` (comment), `Data.PlayerStore` (`PlayerStore.Ranked`) | See section 6. |

Sources: `scripts/ranked/{RankedCore,RankedServer,RankedService.server}.lua`, `scripts/admin/Commands/Ranked.lua`.
Install: `python tools/ranked_build.py --run lobby|match [UNDO]` (embeds the sources into `fix/ranked_install.lua` and runs it; idempotent;
backups `ServerStorage._RebuildRemoved.RANKED_<name>_Orig`; new objects carry attribute `RankedInstall`).
**Order:** match place `match_place_build` -> `data_release` -> **ranked** -> split; lobby `lobby_duels` -> `admin` -> `data_release` ->
**ranked** -> split (`notes/place_split.md` section 6: UNDO split first, then ranked, then split again).
**Changing an edit's text** (v2 -> v3 did): UNDO with the OLD installer first (`git show <old commit>:fix/ranked_install.lua`, set
`UNDO = true`, run it through `execute_luau`), then install the new one. A new module source alone needs no UNDO (it is overwritten).
`tools/match_place_build.py` rewrites RoundManager wholesale: re-run data_release and then ranked after it.
`tools/admin_build.py` and `tools/match_place_build.py` also embed `Commands/Ranked` (same file; whichever installer runs last writes it).

## 2. The rules as built (v3)
- **Ladder:** tier index 0..20 = Bronze 1 .. Commander 3; tier t starts at (t+1) x 100 ELO (Bronze 1 = 100, Silver 1 400, Gold 1 700,
  Platinum 1 1000, Diamond 1 1300, Elite 1 1600, Commander 1 1900, Commander 3 2100). Floor 100: ELO never drops below it.
  2200+ stays tier 20 (Commander 3) for the maths; **Warlord** = ELO >= 2200 and (no cutoff, or ELO >= the cutoff). **One ladder for all modes.**
- **ELO per match** = `tools/ranked_table.py` exactly: base W/L interpolated by tier between the rank values (Bronze 30/10 .. Commander
  10/25); d = (oppTier - myTier) / 3; win vs stronger x sqrt(2)^d, vs weaker x sqrt(0.4)^-d; loss to stronger x sqrt(0.5)^d; loss to
  weaker: g = -d, L + (60 - L) g / 2 up to g = 2, then 60 + 40 (g - 2) / 4 (100 at g = 6); round like Python (halves to even); clamp 1..100.
- **Team modes:** myTier = (own tier + own team's average tier) / 2 (fractional), oppTier = the other team's average tier
  (`tools/ranked_table.py team()`). Edward's check, 2v2 Commander 1 + Bronze 1 vs Platinum 1 x2: Commander +8 / -50, Bronze +45 / -8
  (from 100 the -8 is floored to 0). Even teams = the solo numbers (all 441 tier pairs tested). 1v1: own team = you, so unchanged.
- **Placements:** the first 10 ranked results (wins, losses, leaves) count x2 (clamp 1..200), from 100. No shield during placements.
- **Shield:** the first ranked loss of each UTC day costs 0 while placed and below 1600. Never on a leave (a leave also leaves it unused).
- **Leave:** from the match's start (after Loading, when the match object exists) until its results, a Leave costs the normal loss
  (team maths; x2 in placements) + 25, never shielded, counted as a loss. Loading-phase no-shows still cancel with "no penalty".
  Disconnect: `rec.Pending = { mode, opp, own, t, job }` is written to every player's record when the match starts; the results
  (`ApplyResult`) or a Leave clear it; a profile that leaves with it pays the same leave at its next join in either place
  (`SettlePending`; not on the same server: a JobId match is a reconnect). Admin `;endmatch` / live bot matches clear it at the end
  for everyone still there. Known edge: a match server that crashes, or an admin end after someone disconnected, charges a leave.
- **Decay:** above 1600 (Elite+), after 7 idle days since the last ranked result, -25 per further idle day, never below 1600; at join, idempotent (`Decayed`).
- **Draw:** `DrawDelta = 0` (nothing changes; no win / loss counted; LastPlayed updated).
- **Window (tiers either side):** 2 at 0 s, linear to 6 at 5 min, linear to 18 at 60 min, then 18, for 1v1; 2v2 runs twice and 3v3 four
  times as fast (6 at 2.5 / 1.25 min, 18 at 30 / 15 min). A pair is valid only when the tier gap is inside **both** windows; a 2v2 / 3v3
  group needs every pair valid. Oldest-first pick; party entries (`v.n`, `v.k` = average tier) fill `n` slots. Then the old snake draft splits the teams.
- **Casual:** unchanged (no ELO). Lobby pads stay casual.
- **Bots / admin end:** live, a match with a test bot or ended by `;endmatch` changes no ELO. Studio test bots do when
  `Config.StudioBotRanked` (the bot's ELO = StudioTeleportData `BotElo`, else `Config.StudioBotElo`, else the other side's tier). Bots
  don't count toward their team's average tier.

## 3. Data: the unified record
`Ranked.All = { V = 1, S = 1, Elo, Peak, Placed, Wins, Losses, Streak, ShieldDay, LastPlayed, Decayed, Rating, Pending?, Prev? }`
- `S` = season; `Streak` +n wins in a row / -n losses; `ShieldDay` = UTC day number the shield was last used; `LastPlayed` os.time of
  the last ranked result; `Decayed` = idle days already charged since LastPlayed; **`Rating` = a mirror of Elo**; `Pending` = a ranked
  match in progress (see leave); `Prev = { S, Elo, Peak, Wins, Losses }` = the record this season replaced (for rewards later).
- `Ranked["1v1" / "2v2" / "3v3"]` = **mirrors** `{ Mirror = "All", Rating, Wins, Losses }`, rewritten with every write of `All` (old
  readers: LobbyUIController / PlayScreen "SR", admin `;stats`). Never read back. `;setstat Rating1v1` no longer changes ELO (use `;setelo`).
- **Season reset** (`RankedCore.Migrate`, on the first read in either place, written back): no record or any record without `S = Season`
  -> a fresh record at 100. The first read of `All` adopts the best old per-mode record only to fill `Prev`.
- Both places read and write it only through `RankedServer` (match place: the replica if present, else the raw profile table).
  `PlayerStore.Ranked(player, mode)` in the lobby returns it (any mode -> `All`).

## 4. Interface for the UI
### Player attributes (set at join, after every ranked result / leave / admin change / decay, on a leaderboard refresh, and when MM_Queue changes)
| Attribute | Type | Meaning |
|---|---|---|
| `RankMode` | string | the ladder key: **always "All"** now |
| `RankElo` | int | current ELO (>= 100). **Hide while in placements.** |
| `RankPeak` | int | best ELO this season |
| `RankTier` | string | rank name: Bronze, Silver, Gold, Platinum, Diamond, Elite, Commander, **Warlord** |
| `RankTierIndex` | int | 0..20 (0 = Bronze 1 ... 20 = Commander 3; 2200+ stays 20) |
| `RankDivision` | int | 1..3; **0 for Warlord** |
| `RankName` | string | display name: "Gold 2", "Commander 3", "Warlord", "Warlord #12" |
| `RankFloor` | int | ELO where this tier starts (Warlord: the cutoff, or 2200) |
| `RankNextFloor` / `RankNextName` | int / string | the next tier's floor and name (Commander 3: 2200 / "Warlord"; nil for Warlord) |
| `RankWarlord` | bool | Warlord now |
| `RankPlace` | int? | leaderboard place when in the cached top 200 at 2200+ |
| `RankPlaced` / `RankPlacements` | int / int | placement matches played / required (**10**). Rank hidden while `RankPlaced < RankPlacements`. |
| `RankShield` | bool | the daily shield is ready (placed, below Elite, not used today) |
| `RankedAll` | JSON | `{ "All": { elo, peak, tier, rank, division, name, floor, nextFloor, nextName, warlord, place, placed, wins, losses, streak, shield } }` |

Ladder maths for drawing: `require(ReplicatedStorage.Modules.Shared.RankedCore)`: `RankedCore.Tiers[t] = {Tier, Rank, Division, Name, Floor}`,
`RankedCore.Info(elo, cutoff, place)`, `RankedCore.Ranks`, `RankedCore.Config.PerModeLadders` (false) / `SharedKey` ("All").

### ReplicatedStorage attributes (leaderboard; refreshed every `LeaderboardRefresh` = 120 s in both places)
- **`RankedTop`**: JSON array, best first, at most 200, only ELO >= 2200: `[{ "userId": 1, "name": "ocxa", "elo": 2450 }, ...]`.
- **`RankedCutoff`**: the Warlord threshold ELO (the 200th entry's ELO) or **nil** when fewer than 200 are at 2200+ (then every 2200+
  player is Warlord). Before the first refresh nobody shows as Warlord.
- `RankedTop_All` / `RankedCutoff_All`: the same values (kept because RankedScreen reads `"RankedTop_" .. SharedKey`). The per-mode
  `RankedTop_1v1` / `_2v2` / `_3v3` are **gone**.
- `RankedLadders` (`["All"]`), `RankedRefreshedAt` (server time), `RankedMock` (true when the memory mock is used).

### MatchResults payload (`Events.Match.MatchResults:FireClient(player, summary)`, match place, ranked matches)
All old fields are kept (`Won, Draw, Score, Kills, ..., RatingChange` = the delta). Added when ELO changed:
`eloBefore, eloAfter, delta` (signed; 0 for a shield), `shieldUsed, promoted, demoted`, `rankBefore, rankAfter` (display names),
`tierBefore, tierAfter` (0..20), `ladder` ("All"), `placed, placements`, `draw`, **new in v3:** `placement` (this match counted x2),
`revealed` (true on placement 10: reveal the rank), `leave` (false here; a leaver gets no MatchResults). Absent for casual,
admin-ended and live bot matches. **During placements `rankBefore / rankAfter / eloAfter` are real values: hide them unless `revealed`.**

## 5. Config flags (`RankedCore.Config`) and defaults (v3 = Edward's answers)
| Flag | Default | Note |
|---|---|---|
| `PerModeLadders` / `SharedKey` / `MirrorModes` | **false** / "All" / true | one ladder; per-mode mirrors for old readers |
| `Season` / `StartElo` / `MigrateOldRating` | **1** / 100 / **false** | bump Season to reset everyone again |
| `Placements` / `PlacementMultiplier` | **10** / 2 | |
| `ShieldEnabled` / `ShieldBelowElo` | **true** / 1600 | |
| `DecayEnabled` / `DecayFromElo` / `DecayIdleDays` / `DecayPerDay` | **true** / **1600** / 7 / **25** | |
| `LeavePenalty` | **25** | added to the normal loss |
| `TeamOpponent` | **"Blend"** | "AverageTier" = the v2 rule (own tier only) |
| `DrawDelta` | 0 | |
| `WarlordFrom` / `WarlordCount` | 2200 / 200 | |
| `LeaderboardWriteMin` | 0 (write every ELO) | |
| `LeaderboardRefresh` / `LeaderboardVersion` | 120 s / **"s1"** | store `Ranked_All_s1` |
| `Window0/Window5/Time5/WindowMax/TimeMax` / `WindowSpeed` | 2 / 6 / 300 / 18 / 3600 / **{1v1 1, 2v2 2, 3v3 4}** | tiers / seconds |
| `StudioBotRanked` / `StudioBotElo` | true / nil | Studio tests only |

## 6. [RANKED] edits (fix/ranked_install.lua)
- **match RoundManager** (9): 1 requires; 2 `award` -> `RankedServer.ApplyResult(player, mode, ratings[other], won, draw, ratings[side])`
  and the payload into the summary (`RatingChange = delta`); 3 the bot / aborted early return keeps those fields; 4 the old K32 write is
  gone; 5 `ratings[side]` = the side's average tier (Studio bot sides: BotElo); **v3:** 6 `rankedPays(match)` + `rankedLeave(match, m, why)`
  (before `backToLobby`); 7 at the match start `match.ratings = ratings` and `RankedServer.MarkPending` for every player (paying matches
  only); 8 after `MatchCore.playMatch`: `match.resulted = true` (no leave penalty from here) and `ClearPending` for players still here who
  are not paid (admin end / live bot); 9 the MatchFlow `Leave` handler calls `rankedLeave` before `backToLobby`.
- **lobby MatchmakingManager** (8): requires; `ratingOf` = `RankedServer.EloOf`; queue entry `k` = tier (also on the refresh re-create and
  in `searching[player].tier`); ranked `pickGroup` returns `RankedCore.PickGroup(pool, need, now, mode)`; **v3:** `pickGroup(..., mode)`
  signature and the `runQueue` call passes `q.Mode`. Casual queues unchanged.
- **lobby Template** (comment only) and **PlayerStore** (`PlayerStore.Ranked`).
- The split installer (`fix/split_lobby_install.lua`) edits other MatchmakingManager lines (startMatch / deliver) and goes last.

## 7. Tests
### v3 (2026-10-17)
- **Unit** (`python tools/ranked_test.py lobby|match`; `scripts/ranked/tests/unit_tests.lua` + `fixture_v2.lua`, regenerated with
  `--fixture`, now also carries the Python `team()` result): **168 passed, 0 failed in both places**. All v2 checks still apply (Edward's
  11, the 882-cell table, rounding, clamps, ladder names, the 1v1 window, pair rule, PickGroup), plus: Season 1 reset of every old shape,
  v2 records and mirrors (Prev kept), a Season bump, the carry-over option, Edward's flag values, shield (not in placements, below
  1600 only, once a day), decay (7 free days, -25, floor 1600, idempotent, not below Elite, never-played), LeaveDelta (solo and 2v2),
  one shared key for every mode, **Edward's 2v2 check (+8 / -50 / +45 / -8)**, even teams = solo for all 441 tier pairs, 3v3 even,
  team draw 0, the 2v2 / 3v3 windows (2.5 / 30 min, 1.25 / 15 min) and pairs, PartyTier and a party in a 2v2 pick.
- **Play, match place** (one client "ocxa", play lock "map"):
  - 2v2 ranked (`{"Mode":"2v2","Ranked":true,"BotElo":1000,"Teams":{"A":["me","bot"],"B":["bot","bot"]}}`, short StudioTimes):
    join -> `Ranked.All {S 1, Elo 100}`, mirrors on 1v1/2v2/3v3, `RankMode All`, `RankPlacements 10`, `RankedTop = RankedTop_All = []`,
    `RankedLadders ["All"]`, no `RankedTop_1v1`. Pending set at the match start `{mode 2v2, opp 9, own 0}`. 3-0 (hook kills) ->
    **100 -> 270 (+170 = 85 x2, placement 1/10)**, Pending cleared; console `[Ranked] ocxa All win: 100 -> 270 (+170) placement 1/10`.
  - Hook: placements 2..10 in 2v2 / 1v1 / 3v3 (all `All`): every delta doubled (e.g. +74 = 37 x2, -42 = 21 x2), `revealed` only on 10,
    `RankPlaced` 2..10; `RankShield` true after placement 10. Shield: first loss 554 -> 554 (shieldUsed), second -13. Leave with the
    shield ready: **541 -> 503 (-38 = 13 + 25)**, not shielded, the shield still ready afterwards.
  - Team (server `ApplyResult` with own / opp team tiers 9 / 9): Commander 1 **+8 / -50**, Bronze 1 **+45 / -8** (199 -> 191; from 100
    the floor keeps it at 100), even Platinum 2v2 +21 (= solo), team draw 0.
  - Decay (LastPlayed set back): 2000 idle 10 days -> 1925 (Decayed 3, RankElo 1925), again the same day 1925, 1630 idle 30 -> 1600,
    Diamond 1550 idle 30 -> 1550, 2000 idle 6 -> 2000.
  - Disconnect: a Pending from another JobId settled at join: Gold 1 vs Gold 1 **700 -> 660 (-40 = 15 + 25)**, why disconnect, not
    shielded, Pending cleared; a same-JobId Pending (reconnect) is not settled. A v2 record `{Elo 825, Peak 900, W7 L4}` -> 100 with Prev.
    Seeded leaderboard (5 fakes at 2600..) -> `RankedTop` == `RankedTop_All`, cutoff nil.
  - 1v1 ranked, **real Leave from the client** (`MatchFlow:FireServer("Leave")` in Live): 700 -> **667 (-33)** = Loss(blend 3 vs 6) 8 + 25
    (the start-of-match tiers were taken before the seed, own 0 / opp 6), `leave true, why leave, shieldUsed false`, RankShield still true,
    Pending cleared, the bot side won by forfeit (MatchEnd), console `[Ranked] ocxa All LEAVE: 700 -> 667 (-33)`.
- **Play, lobby** (split installed): join -> `Ranked.All` at 100, mirrors, `RankMode All` (also while `MM_Queue = R3v3`), `RankedTop` /
  `RankedTop_All` set, a v2 record resets to 100 with Prev on read, MatchmakingManager requires fine (offline: no MemoryStore). No errors.
- **Install:** match: v2 UNDO (RoundManager "matches its backup") -> v3 install (9 edits) -> second run all "already in". Lobby: split UNDO
  (4e51facc -> 790cc368, all "match their backup") -> v2 ranked UNDO (all "match their backup") -> v3 install (8 + 2 edits) -> split install
  (all 7 edits applied; after-hash ce26d680, the MatchmakingManager part differs from 4e51facc because the ranked text changed) -> a
  ranked re-run: all "already in".
- Not tested (Studio can't): the real MemoryStore queues (2v2 / 3v3 windows and parties by unit test only), a real 2v2 with four real
  players (bots don't carry a tier, so the blend is tested through ApplyResult + unit tests, not a 2v2 test map), a real disconnect and
  rejoin across servers (simulated with a fake JobId), real idle days (LastPlayed set back), the real OrderedDataStore.

### v2 (2026-10-16, history)
100/100 unit; Play ranked match vs a bot (+35 promoted), shield 0 then -13 demoted; admin `;setelo / ;rankreset / ;rankinfo / ;simrank`;
mock leaderboard 250 fakes -> cutoff 2401, Warlord #101 / #51; install / UNDO hash-exact in both places.

## 8. Open / for the lead
1. The UI items in `notes/ranked_ui_requests.md` (v3 section): leaderboard key names, the reveal, hiding the rank during placements.
2. Parties: `PickGroup` accepts party entries, but the lobby queue has no party join yet (each FindMatch is one player).
3. A match server crash / admin end after a disconnect charges that player a leave at their next join (the Pending mark can't tell).
4. Shield during placements: off (rank hidden, every result x2). Say if Edward wants it on there.
