# Ranked: requests for the UI session (from the ranked server session, 2026-10-16)
Interface: `notes/ranked_server.md` section 4 (attributes, ReplicatedStorage leaderboard attributes, MatchResults payload).

1. **Read the Rank* attributes, not `data.Ranked[mode].Rating`.** `LobbyUIController` (line ~384, "SR") and `UIKit.PlayScreen` (~330)
   read `Ranked[mode].Rating`. It still works (Rating is now a mirror of Elo, 100-based), but the label should say ELO and use
   `RankedAll` (per mode) / `RankElo` + `RankName`.
2. **DuelHUD results** (`sum.RatingChange .. " SR"`): show `delta` as ELO, `rankBefore -> rankAfter`, and a promoted / demoted banner
   (`promoted`, `demoted`), and "ELO shield used" when `shieldUsed`.
3. **Warlord**: emblem when `RankWarlord`; `RankName` already says "Warlord #12" when the place is known (`RankPlace`). Leaderboard
   lists from `ReplicatedStorage.RankedTop_<mode>` (JSON) and the threshold from `RankedCutoff_<mode>` (nil = every 2200+ player).
4. **Placements**: off now (`RankPlacements = 0`). If Edward turns them on, hide the emblem while `RankPlaced < RankPlacements`.
5. **Shield banner** ("Daily ELO Shield Active") when `RankShield` is true (false while the flag is off).
6. Progress bar: `RankFloor` .. `RankNextFloor` with `RankElo`; names from `RankedCore.Tiers` (ReplicatedStorage.Modules.Shared.RankedCore).

## v3 (2026-10-17, Edward's answers; notes/ranked_server.md section 0)
7. **One shared ladder.** `RankMode` is always `"All"`; `RankedAll` has the single key `"All"`. The leaderboard is now
   `ReplicatedStorage.RankedTop` / `RankedCutoff`; `RankedTop_All` / `RankedCutoff_All` carry the same values (RankedScreen's
   `"RankedTop_" .. SharedKey` keeps working). **`RankedTop_1v1/2v2/3v3` are gone** (nothing in `ui/` read them). Switch to the plain
   names when convenient.
8. **Old "SR" readers** (LobbyUIController ~383, PlayScreen ~329, `data.Ranked[mode].Rating`): those entries are now mirrors of the shared
   record (`{ Mirror = "All", Rating, Wins, Losses }`), so they show the shared ELO. Still better: `RankElo` / `RankName`, and hide them
   during placements.
9. **Placements are ON (10).** Hide emblem / name / ELO while `RankPlaced < RankPlacements` (RankedScreen does). DuelHUD results: during
   placements show "Placement N/10" instead of the ELO / rank lines (`placement = true`); on `revealed = true` (the 10th) show a rank reveal
   with `rankAfter` / `eloAfter`. The deltas in placements are doubled already.
10. **Shield is ON**: `RankShield` really turns true now (banner). `shieldUsed` in MatchResults -> "ELO shield used".
11. **Leave penalty**: a leaver gets no MatchResults (they're teleported out). If the Leave button has a confirm, it can say
    "Leaving a ranked match costs your normal loss + 25 ELO" (`RankedCore.Config.LeavePenalty`). Same for a disconnect (charged at the next join).
12. `RankedCore.Delta(elo, oppTier, won, draw, ownTeamTier)` has a 5th argument (team blend) if a preview uses it.
