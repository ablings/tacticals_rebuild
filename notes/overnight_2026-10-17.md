# Overnight 2026-10-17: lead session (glitches + ranked / loophole audit)

Edward: "work on stuff until i tell you im awake ... glitches ranked loopholes check for loopholes". The UI session took UI
polish, the missing RIVALS elements (profile card etc.) and the touch tests. Full details: `notes/loophole_audit.md`.

## PUBLISHED 04:10-04:18 (port 10, notes/port_manifest.md)
lobby **v279**, Tutorial / Matchmaking / Ranked **v4**, old combined place **v115** (now the secured casual build). Everything in the
table below went live with it, plus the touch controls (the UI session tested them in Studio's Device Simulator; real multi-touch
still needs a phone).

## After the publish (in the working copies, goes live with the next publish)
- **Kill-cam**: when you die you watch your killer (then a living teammate / anyone alive if they die). UI shows "KILLED BY".
- **Opening run**: round 1 of every match starts with both sides near the middle, a standoff beat, then everyone runs round
  their pillar to their spawn (the tutorial's opening, now default for every match until you make per-map ones).
- **Victory beat**: after the deciding kill, 4 s "Victory" phase (default VICTORY / DEFEAT screen by the UI session) before results.
- **Critical hit marker** (UI session): crits are a big red X with their own sound; body hits stay white.
- **Challenge a player** from the player menu / profile card (server done, UI wired): a 1v1 lobby duel. Needs a 2-player test.
- Tutorial lines say the touch button names on phones ("Tap Take Cover" instead of "Press [Q]").
All tested in Studio against a test bot except Challenge (needs two real players).

## Fixed tonight (published in port 10)
| # | What | Severity | Where |
|---|---|---|---|
| 1 | Fake ranked matches: anyone could teleport into a public Ranked server with made-up teams (themselves + an alt) and farm Elo | critical | MatchSpec: the lobby writes each match server-side; match servers only play reserved servers + that spec |
| 2 | Free headshots: a hit only had to be within ~7 studs of the claimed part, so cheats could turn any body shot into a headshot | high | HitRewind: lag-compensated check, 1.25 studs; tested live (legit hits land, forged headshot refused) |
| 3 | Sitting on #1: idle top players never decayed on the leaderboard (decay only ran when they joined) | medium | leaderboard values carry the last-played day; the board shows decayed ELO |
| 4 | Ranked dodging: leave during the loading screen after seeing the opponent = no penalty | medium | pending mark on arrival (leave pays the normal leave); cancelled matches clear it. Switch: `RankedCore.Config.DodgePenalty = false` |
| 5 | Game passes granted on the purchase-finished event alone | medium | confirmed with UserOwnsGamePassAsync first |
| 6 | Speed hacks invisible to the server | low | MoveGuard: flag-only (log + admin audit + `MoveFlags`), never kicks |
| 7 | Exfil barrier started the cutscene when walking BACK from the pad | glitch | one-way now (tested both ways) |
| 8 | Duel-pad hologram beams floated outside the building | glitch | beams back under each pad hologram |
| 9 | Players could stand on the Outfitters featured turntable | glitch | invisible clip box (shots/clicks pass through) |

## Needs Edward
- **Live check** (published at 04:10): start one ranked + one casual match; there should be no "WRONG SERVER". If there is,
  restart servers in Creator Hub (an old lobby server was still running).
- **Old combined place 81861384114744**: done, it now runs the secured casual build (v115).
- **Dodge penalty**: on by default; say if you'd rather have free dodges.
- **Ranked pads**: none exist; if you ever add them, friends could win-trade there (keep ranked to the online queue).
- Low: the reaction-range best time is client-reported (cosmetic).

## Checked and fine
Gun / melee / gadget servers, admin framework, shop / codes / quests / receipts, duels, tutorial, range, bots, settings save.
