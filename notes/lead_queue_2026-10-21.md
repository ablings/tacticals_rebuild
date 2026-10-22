# Lead queue, 2026-10-21 (Edward in the Shadow PC lead chat). Work top to bottom; tick when done + tested.
# Items 1-8 LIVE in port 31 (~14:10).

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
2. [x] **No Ready button.** (MatchFlowUI: the third pick sends Ready; the button never shows) After you pick all your weapons it should put you in the game (Loadout phase): the third pick = ready.
3. [x] **Pre-round flow** (fix/preround.lua [PREROUND]: Countdown 5 s, kit locks at Live, no aim / melee before Live (client); Edward: frozen until the round starts) (replaces [ROUNDFLOW]'s "swap until you move 2 studs / fire"): a 5 s pre-round; weapon switching is free until
   the round starts; when the picker opens you must pick all three before you can move; no aiming and no melee (and no firing)
   until the round starts.
4. [x] **After a kill (RoundEnd)** (guns already fired in RoundEnd - tested, server accepts; gadgets now too; GadgetManager clears everything at each Countdown, smoke loops stop) ** you can still shoot AND use utility**; everything thrown is removed from the map when the next round
   starts (round refresh).
5. [x] **Gadget hold** (MaxHoldTime 5; tested: held 3 s no throw, release throws, auto-throw past 5 s): throwing auto-releases far too fast (THROWNOW MaxHoldTime 0.02); you must be able to hold the gadget at least
   5 s (still full strength on release).
7. [x] **Controller dash = D-pad up** instead of double-tapping LB (deployed both copies; CoverDash bound E + DPadUp, LB = cover only).
   Moved off D-pad up: match Settings = HOLD View/Select 0.5 s (tap = scoreboard as before); Training picker = T / D-pad down;
   hub Codes loses its D-pad glyph; Settings > Hotkeys shows Dash = D-pad up, Equip Melee pad blank (RB cycles).
8. [x] (fix/climb.lua [CLIMB] + CoverController startClimb/climbSpot; tested on a test platform: 8-deep crate climbs (+3 up, 1.6 on),
   3-deep crate still vaults, 5-stud wall (top under the head) climbs, 6-stud wall just hops; poses checked on R15 dummies.
   LIVE NEEDS the CoverClimb upload: Save to Roblox under Gunsy Funsy on Edward's account, then set PublishedId - until then
   the climb moves you without its animation) **Climb** (new mechanic): on vaultable objects that are very WIDE or very LONG (deep), Space doesn't vault across: a climb
   animation puts you on top. Also on taller objects, as long as your head is above the object's top.
6. [x] (MatchFlowUI: the map vote is back on the solid gradient backdrop like the loading screen; the gun pick stays see-through; screenshot-checked) **Map-selection overlay**: like RIVALS (and like we had before), a background overlay during the map-vote / loading so the player
   can't see which map they're on.
9. [x] (Edward: "do both". Quick: phones wait <=5 s for join assets, training picker tiles built on first InTraining (0d91124).
   Streaming (fix/streaming.lua [STREAM], lobby copy only, saved; NOT live until the next port): StreamingEnabled on, pads / Heli /
   Showroom pinned Persistent (Showroom Folder -> Model), LobbyFX + SettingsEffects catch streamed-in parts. Tested at target radius
   96 (3,860 of ~8,300 parts at join): hub, Kit armory camera, To Pads + boards, Training entry all fine, console clean; radius back
   to 1024, integrity PauseOutsideLoadedArea (Properties panel only - scripts can't read these). Edward to feel it on a phone.)
   **Mobile loading is very slow** (Edward). Found: lobby StreamingEnabled=false with 7,645 parts / 1,109 unique meshes, so game.Loaded
   waits for the whole map; LoadingScreen then waits up to 12 s on assets; join also preloads menu images and builds ~23 training-picker
   ViewportFrames (UI: can defer to first InTraining). Options asked of Edward: quick (5 s cap on touch) vs streaming test.
10. [ ] **Logos are pixelated** (Edward). UI: sources are 1024 wide (no downscale on upload), clean 1:1 at 1080p, so it is upscaling on
   bigger / high-DPI screens or mobile low texture quality. Needs Edward's original logo art (tacticals_ui repo not on this PC) + his group
   upload, and which screen / device looks pixelated.

## Afternoon (Edward via the main PC lead / Roblox training)
11. [x] HitConfirm payload for RIVALS hit numbers / flash (fix/hitinfo.lua [HITINFO], tested; e16a1ec).
12. [x] Frag cooking, 2 s fuse from the press, explodes in hand (fix/cook.lua [COOK] + GadgetController; both copies, saved 15:32).
    Tested: hold 0.6 s -> thrown, blew 1.28 s later (2 - 0.6 - 0.12); held 2.6 s -> blast in hand (150 -> 0), late release threw nothing;
    CookStart / CookFuse set while held, nil after (UI shows the draining bar).
13. [x] RIVALS throw for every throwable (fix/rivals_throw.lua [RTHROW] + GadgetController): tap = roll (TapTime 0.15), hold = throw
    at 100 studs/s straight at the crosshair, gravity x0.1875 until first touch (RIVALS ItemLibrary: ThrowForce 100, ThrowGravity 0.375,
    the same for all throwables; lob 50 / 0.75 not ported), dashed arc while held (ArcPreview Always). Applied both copies, saved 15:32. Tested: tap -> roll (flat, no VectorForce, blew 1.75 s later); hold -> 100 studs/s
    with the reduced-gravity VectorForce.
14. [~] (white trail done + tested: fix/throw_trail.lua, on in flight, off at first landing; windup / follow-through / rise-in to do)
    Throw feel on our camera: overhand windup, white streak trail, follow-through, next item rising in from below.
15. [~] (ui/set/WeaponFeel.lua [FEEL], both copies, saved. Tested in a 1v1: equip bounce - shoulder from 7/34 deg to the 79/0 hold
    with a 82/-3 overshoot, settled ~0.4 s; pistol kick +10 deg peak, settles ~0.4 s. Sway / bob / reload roll in, not measured. Open: the
    FOV step on switching off a scoped Sniper (CameraController; ScopeController already eases the zoom).) Weapon feel (notes/feel_brief_2026-10-21.md): equip bounce spring, sway / bob, recoil kick, reload motion, quick-switch off the
    Sniper. Edward: keep OUR over-the-shoulder camera, bring the RIVALS feel to how items are used.
16. [~] (v1 IN both copies, saved: scripts/wraps/WrapConfig + WrapManager via tools/wraps_install.py; 120 template parts tagged
    A / B / skip; 8 wraps - Beige / Blue / Salmon / Yellow / Glossy owned by default, Hazard / Woodland / Carbon locked (source TBD by
    Edward); textures art/wraps (Python-made, uploaded). Tested lobby Training: Equip(Pistol, Yellow) -> held gun + holster copy body
    yellow, details kept; Hazard previewed client-side: notes/feel_ref/wrap_hazard_pistol.png. UI builds the Wrap tab.) Wraps (cosmetic, every weapon): WrapConfig (primary + accent channels, inverted swaps them, rarity, source text), PlayerStore
    OwnedWraps / EquippedWrap[weapon] (incl. Random) / FavoriteWraps, equip remote, server-side apply on tools / holsters / Kit models /
    DualGrip left gun (Textures on 6 faces + tint; WrapChannel Primary / Accent tags on every template part, WrapSkip on lenses /
    muzzles). Start ~8 (4 plain colours, Glossy, 3 codex-made seamless patterns); everyone owns the plain ones. How the rest are earned
    = Edward's call (store / cases / weapon levels or contracts). UI has the screens + client-only preview of locked wraps.
17. [x] (fix/trash_cans.lua [TRASHCAN], lobby copy saved: the 9 Training swap bins are red Part-built cans, crate kept invisible
    so its prompt still shows - a prompt moved onto the new Body part stopped showing; F at a can fires "Trash Can / Change Weapons"
    and toggles the picker; notes/feel_ref/trash_can_training.png. A Blender mesh can may replace the Parts later.) Training trash cans: 2-3 red cans with a "Q  Trash Can / Change Weapons" prompt that opens the free weapon picker.
    Wrap look per channel (from RIVALS frames): Color, Material (incl. Neon / Glass / ForceField), Texture + StudsPerTile (fixed per
    wrap so patterns keep their size on every part), Transparency (ghost wraps ~0.3-0.5; cap it on the local player's held gun if aiming
    suffers), optional client-side animation: texture Scroll and/or a colour cycle { colours, period } on the glow channel (cap animated
    parts). Inverted = swap Primary / Accent. Sources seen in RIVALS: wrap case, weapon contract (per weapon), season pass, bundles.
    SKINS (Edward builds them himself; keep compatible): a skin = a different model of the same weapon with its own animations /
    sounds / FX and identical gameplay. Stats only from WeaponConfig[weaponId] (keep WeaponId on the tool); one lookup (weapon id + skin
    id -> template) for tools / holsters / Kit models / DualGrip; animations / sounds / muzzle FX per (weapon, skin) with fallback; wraps
    apply to skin models via the same WrapChannel / WrapSkip tags. Wraps v1 = static only (Edward); Inverted = swap the two looks.
