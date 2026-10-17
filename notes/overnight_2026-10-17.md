# Overnight 2026-10-17: lead session (glitches + ranked / loophole audit)

Edward: "work on stuff until i tell you im awake ... glitches ranked loopholes check for loopholes". The UI session took UI
polish, the missing RIVALS elements (profile card etc.) and the touch tests. Full details: `notes/loophole_audit.md`.

## Fixed tonight (in both working copies; NOT live until the next publish)
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
- **Publish**: everything above is in the working copies only. After publishing, **restart the old servers** (old lobby servers
  send ranked matches without the server-side spec, which the new Ranked place refuses). Then start one ranked + one casual
  match and check there are no "[MatchSpec]" warnings.
- **Old combined place 81861384114744**: still accepts forged matches (casual rewards). Plan: overwrite it with the secured
  Matchmaking build at the publish (or make it unreachable).
- **Dodge penalty**: on by default; say if you'd rather have free dodges.
- **Ranked pads**: none exist; if you ever add them, friends could win-trade there (keep ranked to the online queue).
- Low: the reaction-range best time is client-reported (cosmetic).

## Checked and fine
Gun / melee / gadget servers, admin framework, shop / codes / quests / receipts, duels, tutorial, range, bots, settings save.
