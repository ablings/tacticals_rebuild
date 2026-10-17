# Tacticals ranked: design (started 2026-10-16 with Edward; UI session + lead session)
Reference: `notes/rivals_ranked_reference.md` (RIVALS Season 3 screens + rules).

## Ranks (Edward 2026-10-16: "bronze to diamond should be the standard for every game then 3 ranks after"; picked "Command")
| Rank | ELO floor | Divisions |
|---|---|---|
| Bronze | 0 | I-III (200 each) |
| Silver | 600 | I-III |
| Gold | 1,200 | I-III |
| Platinum | 1,800 | I-III |
| Diamond | 2,400 | I-III |
| Elite | 3,000 | (open: divisions or one band) |
| Commander | 3,600 | (open) |
| Warlord | top 200 by ELO (above Commander's floor) | leaderboard place shown ("Warlord #12") |
Spacing copies RIVALS (600 per rank, 200 per division) so the numbers feel familiar. Thresholds are proposals until the
lead session's ELO maths is agreed.

## Open (next to decide)
- Elite / Commander: divisions or a single band?
- Placement duels (RIVALS: 10), daily ELO shield, decay at the top, map/weapon bans, season length, rewards currency.
- Emblem art per rank (olive / bone / gunmetal palette, stencil-military insignia, more detail higher up).

## Server contract (lead session, 2026-10-16; pending Edward's rules)
- Data: `Ranked[mode] = {Elo, Peak, Placed (0-10), Wins, Losses, Streak, ShieldDay, LastPlayed}` (migrated from the old
  `{Rating,...}`; StartingRating 1000; old K=32). Modes 1v1 / 2v2 / 3v3. Ranked unlocks at account level 50 (LobbyConfig.RankedLevel).
- Elo: expected score, K 40 in placements / 24 after, team = average Elo. Daily shield: first loss of the day costs 0 below
  Elite. Decay at 3,000+ after N idle days.
- Warlord: OrderedDataStore `Ranked_<mode>_v1`, cached every ~2 min into ReplicatedStorage `RankedTop` (JSON top 200:
  userId, name, elo) and `RankedCutoff`.
- Player attributes for the UI: `RankElo`, `RankTier`, `RankDivision` (1-3 / 0), `RankPlaced` (0-10), `RankShield`.
  MatchResults adds `{eloBefore, eloAfter, delta, shieldUsed, promoted, demoted}`.
- Open for Edward: one rank per mode or one across modes; reset or carry the old Rating; where placements land you.
