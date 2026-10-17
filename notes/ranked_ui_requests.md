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
