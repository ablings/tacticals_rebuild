# Lead queue, 2026-10-21 (Edward in the Shadow PC lead chat). Work top to bottom; tick when done + tested.

1. [~] **Crouch / slide animations vanish mid-match.** FIX deployed to both copies (not live): MovementController loads its tracks
   only once the character is Ready (PlayerRegistry rebuilds the body with ApplyDescription and then sets Ready; tracks loaded
   before that sit on the old joints) and reloads on a re-Ready; CoverController drops its tracks on Ready. Not reproducible in
   Studio (avatar loads instantly, even with 0.5 s replication lag); Edward to retest live after the next port.
   (Studio gotcha: group-owned animation ids don't load in a local file under whitteguy -> clear PublishedId on the client to test.) "after you pick all your weapons you can't crouch or slide ... it changes your
   movement ... but the animations dont appear ... i won a round could slide then next round i couldn't". Movement works, the
   MoveCrouchIdle / MoveCrouchWalk / MoveSlide tracks don't show.
   - Ruled out so far (match copy, 1v1 vs bot): a new character each round (MovementController.bindCharacter resets its track
     cache); the Animator is present at once on respawn; with NO weapon picks, crouch played fine in round 7.
   - Suspect: weapon swaps (Pick during Countdown / RoundEnd / Loadout) leave stacked Action-priority looped weapon poses
     (Hold / Lowered) that drown the Action-priority crouch / slide tracks. To test: several picks in a Countdown, then C, then list
     playing tracks + priorities + weights.
2. [ ] **No Ready button.** After you pick all your weapons it should put you in the game (Loadout phase): the third pick = ready.
3. [ ] **Pre-round flow** (replaces [ROUNDFLOW]'s "swap until you move 2 studs / fire"): a 5 s pre-round; weapon switching is free until
   the round starts; when the picker opens you must pick all three before you can move; no aiming and no melee (and no firing)
   until the round starts.
4. [ ] **After a kill (RoundEnd) you can still shoot AND use utility**; everything thrown is removed from the map when the next round
   starts (round refresh).
5. [ ] **Gadget hold**: throwing auto-releases far too fast (THROWNOW MaxHoldTime 0.02); you must be able to hold the gadget at least
   5 s (still full strength on release).
7. [ ] **Controller dash = D-pad up** instead of double-tapping LB. (Check the conflicts: D-pad up = Settings in a match / the
   Training picker.)
8. [ ] **Climb** (new mechanic): on vaultable objects that are very WIDE or very LONG (deep), Space doesn't vault across: a climb
   animation puts you on top. Also on taller objects, as long as your head is above the object's top.
6. [ ] **Map-selection overlay**: like RIVALS (and like we had before), a background overlay during the map-vote / loading so the player
   can't see which map they're on.
