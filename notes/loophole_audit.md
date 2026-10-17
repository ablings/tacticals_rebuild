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
   can teleport into it. It has no ranked ladder writes of the v3 kind, but it should get the same fix or be made private.

## High
3. **Free headshots / bigger hitbox through the claimed hit check.** FIXED [SECURE] (`scripts/secure/HitRewind.lua`).
   CombatManager accepted a claimed hit point up to `HitPositionTolerance` (6) + half the part's size from where the server
   saw the part: a cheater could claim `hitPart = Head` on any shot passing within ~7 studs of a head (body shots and near
   misses became headshots). Now HitRewind keeps ~1.2 s of every character's root CFrame (Heartbeat) and checks the claimed
   point against the claimed part *where it was* during the shooter's lag window (ping x 2 + 0.15 s, 0.2-1.0 s), within
   `HitRewind.Tolerance` = 1.25 studs (animation pose). Characters with no history yet fall back to the old rule.
   Tune `HitRewind.Tolerance` if legit hits get refused (Studio prints "hit too far from target (x studs)").

## Medium
2. **Game passes granted on the purchase-finished event alone.** FIXED [SECURE] in LobbyManager:
   `PromptGamePassPurchaseFinished` is now confirmed with `UserOwnsGamePassAsync` before granting (Roblox's own advice; the
   join-time `checkPasses` already used it).

## Checked, fine
- LobbyManager handlers: Equip (ownership + slot), Favorite (item id), BuyItem / BuyBundle (server prices, Spend checks),
  ClaimQuest (server-side progress, Claimed flag before paying), RedeemCode (per-profile RedeemedCodes, 40-char cap),
  BuyRobux / BuyPass (prompts only; Studio-only test grants), ProcessReceipt (PurchaseId dedupe), DevAddStat (Studio only).
- SaveSettings: debounced, SettingsConfig.Sanitize, no size cap needed (DataStore 4 MB).
- Ranked: leaves never get the shield; a disconnect after MarkPending pays at the next join; a team that never arrives =
  cancelled, no rewards (so a solo forged match can't win by forfeit even before the fix).
- Old match test server (public servers): no rewards are paid there.
