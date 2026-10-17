# Loophole / glitch audit (overnight 2026-10-17, Edward: "glitches ranked loopholes check for loopholes")

Status legend: FIXED (installed in the working copies, ships with the next publish) · OPEN (needs Edward / later) · OK (checked, fine)

## Critical
1. **Fake matches through TeleportData (ranked Elo farming).** FIXED, `fix/secure_install.lua` [SECURE].
   The match places took mode / ranked / teams from the first player's TeleportData, which travels through the client and
   can be forged. A player could teleport themselves into a *public* server of the Ranked place with
   `Teams = {A = {me}, B = {alt}}` and farm Elo off an alt (or a friend), or edit the teams of a real match.
   Fix: the lobby (pad deploy + PLAY matchmaker) writes the match to MemoryStore `MatchSpec[<PrivateServerId>]`
   (ReserveServer's 2nd return); `RoundManager.joinMatchData` on a live server plays only `MatchSpec.Secure(td)`:
   public / VIP servers never run a match, the spec decides mode / ranked / teams, TeleportData only supplies loadouts
   (validated against ownership already). No spec: the Ranked place refuses, other places play casual.
   A ranked match whose spec can't be written isn't started.
   Rollout note: lobby servers still running the old version send no spec, so their ranked matches are refused by the new
   Ranked place (casual still plays). After publishing, shut down / migrate old servers (Creator Hub > the experience >
   ... > Restart servers) so every lobby runs the new code.
   The old combined place 81861384114744 (v113) still accepts forged TeleportData: it isn't routed to any more, but anyone
   can teleport into it and farm casual rewards (XP / scissors) off an alt. PLAN: at the next publish, overwrite it with the
   secured Matchmaking build (reserved servers + spec only, casual), so it is as safe as the new places.

## High
3. **Free headshots / bigger hitbox through the claimed hit check.** FIXED [SECURE] (`scripts/secure/HitRewind.lua`).
   CombatManager accepted a claimed hit point up to `HitPositionTolerance` (6) + half the part's size from where the server
   saw the part: a cheater could claim `hitPart = Head` on any shot passing within ~7 studs of a head (body shots and near
   misses became headshots). Now HitRewind keeps ~1.2 s of every character's root CFrame (Heartbeat) and checks the claimed
   point against the claimed part *where it was* during the shooter's lag window (ping x 2 + 0.15 s, 0.2-1.0 s), within
   `HitRewind.Tolerance` = 1.25 studs (animation pose). Characters with no history yet fall back to the old rule.
   Tune `HitRewind.Tolerance` if legit hits get refused (Studio prints "hit too far from target (x studs)").

## Medium
8. **Sitting on the leaderboard.** FIXED [SECURE] in `scripts/ranked/RankedServer.lua` (installed via tools/ranked_build.py).
   Decay was only applied when a player joined, so a top player who stopped playing kept #1 / Warlord forever (and kept
   a Warlord seat from someone active). The leaderboard value now carries the last-played day and the idle days already
   charged (ELO x 1e6 + day % 1000 x 1000 + decayed); the refresh shows ELO minus the decay due, drops entries that fall
   under WarlordFrom, re-sorts, and computes the cutoff from the shown values. Old plain-ELO values still read (no decay
   shown until their next ranked match). Tested: active 2500 -> 2500; 10 idle days -> 2425; 3 days already charged at join ->
   no double charge; 100 idle days at 1700 -> 1600 floor; legacy 2300 -> 2300; sort order kept.
2. **Game passes granted on the purchase-finished event alone.** FIXED [SECURE] in LobbyManager:
   `PromptGamePassPurchaseFinished` is now confirmed with `UserOwnsGamePassAsync` before granting (Roblox's own advice; the
   join-time `checkPasses` already used it).

## Low / latent
4. **Speed / teleport hacks are invisible to the server** (Roblox movement is client-driven). ADDED a flag-only detector:
   `ServerScriptService.MoveGuard` flags a 2 s average horizontal speed above 42 studs/s (legit tops: cover sprint 31,
   dive 34 bursts) to the server log, the admin audit (command "moveguard") and player attribute `MoveFlags`. It never
   moves or kicks anyone. Single steps over 40 studs (server teleports) reset the window, so a blink teleport isn't caught.
5. **Ranked pads would allow win-trading** (friends in one server pick each other). LATENT: there are no ranked pads today
   (`LobbyConfig.RankedBays` empty, no pad has `Ranked`). If ranked pads are ever added, keep them out of the Ranked place
   (or require the online queue) - otherwise two friends can farm Elo off each other.
6. **Reaction range best time is client-reported** (`ServerScriptService.LobbyRange`): anyone can post 1.2 s. Cosmetic
   (one server attribute, not saved). OPEN, low priority.
7. **Ranked dodge during Loading.** FIXED [SECURE] (RoundManager, match places), with a switch: a player who saw the opponent
   on the loading screen and left before the match was marked (MarkPending ran after Loading) cancelled the match with no
   penalty. Now a ranked arrival is marked pending at once (own tier vs own tier, overwritten by the real tiers after
   Loading), so a leave during Loading pays the normal leave (loss + LeavePenalty 25) at the next join. A cancelled match
   (the other team never arrived) clears the mark for everyone still there. Live servers only (Studio skips it).
   Turn off with `RankedCore.Config.DodgePenalty = false` if Edward prefers free dodges.

## Tests (2026-10-17)
- HitRewind with a dummy running 20 studs/s (match place Play): a point on the head now -> ok (0.00); 3 studs behind (a lagging
  shooter's view) -> ok via rewind (0.00); the torso centre claimed as Head -> refused (1.90); 5 studs to the side -> refused (4.40).
- Live remote test (practice bot, 10 studs away, the real FireWeapon remote, Pistol): legit head shot 90 -> 30 (60 damage);
  forged head (point 2.6 studs below the head) refused, log "hit too far from target (2.0 studs)"; legit torso 30 -> 0.
- MoveGuard: 90 studs/s for 3.2 s -> 1 flag; a 12 studs/s walk -> no flag. Console clean.
- Exfil one-way (lobby Play): walking pad -> hangar through the barrier (16 touches) no cutscene; hangar -> pad starts it.
- Leaderboard decay encode/decode (match place, required clone): active 2500 -> 2500; 10 idle days -> 2425; 3 days already
  charged -> 2425 (no double charge); 100 idle days at 1700 -> 1600 floor; legacy plain 2300 -> 2300; sort order kept.
- All edited scripts parse (loadstring) in both copies. Live-only paths (MatchSpec with MemoryStore + reserved servers, the
  dodge guard) can only be tested after publishing: start a ranked and a casual match from the lobby and check the match
  server log for "[MatchSpec]" warnings (there should be none).

## Checked, fine
- CombatManager: rate limit, increasing shot ids, fire interval, ammo / reload on the server, origin within 8 studs of the
  head, muzzle-through-wall check, hit point on the ray (1 stud), range, wall check, server-side damage, same-match /
  friendly-fire guards. SelectWeapon checks ownership.
- MeleeManager: the server picks the target (range, angle, line of sight), cooldown, same-match guard.
- GadgetManager: kit gadget only, charges, cooldown, direction validated, thrown from the server's character.
- Match place only: RangeManager SetKit / Teleport (test servers only, TestMode; never in real matches, no rewards there),
  TutorialManager Start / Progress (no rewards, only TutorialDone), BotManager RequestPractice (one bot, solo player on a
  Waiting server), RoundManager MatchFlow (Vote checked against the map list, Pick through validPick + ownership, Leave =
  forfeit + ranked leave), SyncTween getTween (read-only).
- Lobby: LobbyCodes (two small launch codes), AutoLevel (Edward's account only), TrainingBins swap (InTraining, near a bin,
  trial guns end on leaving Training), LobbyFeatures ad reward (cooldown; paid through ProcessReceipt), AssetCheckReport
  (once per player, log only), LobbyDuelManager flow (map id / ownership checks; one reward per opponent pair per 10 min).
- Admin framework: every entry point resolves the real player on the server; levels from the user list / group rank; rate
  limit; audit log; Studio-only simulated levels.
- LobbyManager handlers: Equip (ownership + slot), Favorite (item id), BuyItem / BuyBundle (server prices, Spend checks),
  ClaimQuest (server-side progress, Claimed flag before paying), RedeemCode (per-profile RedeemedCodes, 40-char cap),
  BuyRobux / BuyPass (prompts only; Studio-only test grants), ProcessReceipt (PurchaseId dedupe), DevAddStat (Studio only).
- SaveSettings: debounced, SettingsConfig.Sanitize, no size cap needed (DataStore 4 MB).
- Ranked: leaves never get the shield; a disconnect after MarkPending pays at the next join; a team that never arrives =
  cancelled, no rewards (so a solo forged match can't win by forfeit even before the fix).
- Old match test server (public servers): no rewards are paid there.
