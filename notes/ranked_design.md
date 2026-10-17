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

## Edward's rules v1 (2026-10-16) — supersedes the RIVALS-spacing proposal above
### Ladder
- 7 ranks x 3 tiers, **100 ELO per tier**. Bronze 1 = 100 (the floor: you can never drop below 100).
  Bronze 1 100 · Bronze 2 200 · Bronze 3 300 · Silver 1 400 … Gold 1 700 · Platinum 1 1000 · Diamond 1 1300 · Elite 1 1600 ·
  Commander 1 1900 · Commander 3 2100-2199.
- 2200+: if you're in the top 200 by ELO you are **Warlord**; otherwise you stay Commander 3 and keep earning ELO.
  Warlord uses Commander's gain/loss numbers.
### ELO per match (`notes/ranked_elo_table.md`, all of Edward's examples reproduced exactly)
- Same rank: win +W, loss -L by your rank: Bronze 30/10 · Silver 28/12 · Gold 25/15 · Platinum 21/18 · Diamond 17/21 ·
  Elite 13/23 · Commander 10/25 (gains shrink and losses grow as you climb).
- Rank gap d = opponent rank - your rank (use tiers/3 for in-between steps):
  win vs stronger x1.414 per rank · win vs weaker x0.632 per rank · lose to stronger x0.707 per rank · lose to weaker x2 per rank.
- Every result is clamped to 1..100.
### Matchmaking window (per player, widens while you wait)
- t = 0: same rank (±2 tiers), the quickest match first.
- 0-5 min: widens linearly to ±2 ranks (±6 tiers): Bronze can reach Gold; Gold reaches Bronze..Diamond.
- 5-60 min: widens very slowly to ±6 ranks (±18 tiers), so a Bronze 1 can meet a Commander after about an hour.
- A pair matches when each is inside the other's window (so mid ranks fill from both sides).
- Open: one queue/ELO per mode (1v1/2v2/3v3) or shared — Edward is checking RIVALS.
