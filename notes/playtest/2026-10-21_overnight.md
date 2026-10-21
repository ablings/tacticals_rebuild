# Overnight playtest 2026-10-21 (main PC lead, match working copy 7a8bab8a, Studio Play)

Setup: ReplicatedStorage.StudioTeleportData 1v1 me vs "bot" (short StudioTimes, RoundsToWin 2), a client recorder on every
RemoteEvent (out/pt_rec.lua, log out/pt_rec_run1.txt), ServerStorage.MatchTestHook kill/config, PlayerScripts.GadgetTestHook.
StudioTeleportData cleared afterwards. Studio-only noise: the Tutorial auto-starts in Studio, so its Instructor bot shoots
into the arena (1 dmg hits) and its panel shows; that's why two rounds went to B on timeout. Not a live issue.

| Check | Result |
|---|---|
| [THROWNOW] G press, held 0.45 s | thrown by itself within 50 ms, p=1.00, mode Throw, one throw |
| Frag fuse | leaves hand -> gone 2.01 s later, Explosion event "Frag" |
| [ROUNDFLOW] Live pick before moving | Gadget Frag + Weapon PumpShotgun swapped at once (tool in hand) |
| Move > 2 studs | KitLocked = true |
| Live pick after moving | queued (NextKitWeapon = Revolver), applied when the round left Live (KitWeapon = Revolver at RoundEnd) |
| KitLocked at Countdown | cleared every round |
| RoundEnd shots | pass the combat gate and spend ammo (were "combat disabled"); the hit itself was rejected by the wall check in this setup, so the "no damage" branch is still unproven |
| [KILLFEED] Kill payload | {killer, victim, weapon = PumpShotgun / Revolver, headshot, kind} |
| [STATS] MatchResults | Kills 3, Headshots 2, DamageDealt 450, DamageTaken 2, Assists 0, Won |
| Map vote | PracticeRange chosen when voted inside MapVote; both bodies spawn inside it, its lighting applied (clock 15.2, bright 1.6) |
| Rematch pressed late (pseudo lobby) | rematch, score reset, MapVote |
| **Rematch pressed during the results** | **BUG: dropped** (only counted after postMatch started). Fixed: fix/rematch_early.lua [REMATCHEARLY]; retest: vote 1/1 in MatchEnd, MapVote 12.7 s later |

## Dual Pistols grip + Riot Shield holster (02:20)
- [DUALGRIP] new ServerScriptService.DualGrip (scripts/abilities/DualGrip.server.lua, fix/dual_grip_install.lua): while held,
  the left gun's parts are welded to the LeftHand as the mirror of the right gun in the RightHand (Weld with C0, not a
  WeldConstraint: those take their offset from each machine's own view, so the client kept the old spot); back on the Handle
  in the Backpack. Measured: LeftGrip 0.1 studs from the left hand (was 1.9, hanging off the right gun).
  Before / after: 2026-10-21_dualpistols_before.png / _after.png (arms down only because the test camera stops the aim pose).
- Riot Shield holstered on the back while a gun is out: 2026-10-21_riotshield_holster.png, flat on the back, no clipping.
- Installed + saved in the match copy (221cdf09). The lobby copy still needs fix/dual_grip_install.lua (its Studio was down).
- 02:15 GPU reset ("Device removed 0x887a0007") killed the match Studio mid-test; the 02:11 save had everything, reopened.
