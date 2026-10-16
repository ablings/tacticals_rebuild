# RIVALS vs Tacticals rebuild: what RIVALS' lobby has that ours lacks

Read-only survey, 2026-10-15. RIVALS place (studio 2e616d06…, `place 17625359962 RIVALS(1).rbxl`) and `Tacticals_rebuild.rbxl`
(studio 8ef4e21a…). Nothing was written, saved or played in either. The only changes were temporary camera moves for the captures.
Captures: `out/diff/rivals_<nn>_<name>.png` (raw frames in `out/diff/raw/`). Numbered sheet: `out/diff/diff_sheet.jpg`.
Captures are edit-time renders: TV/board screens show black, and scripted holograms and boards sit in their idle state.

**How to answer:** reply with the numbers you want, for example "5, 14, 18, 29". Nothing on this list is built until you pick.
Effort: **S** = under 1 h, **M** = a session, **L** = several sessions. **Script** = new code needed.
Colours would follow `rivals_style.md` (olive/cream for RIVALS' gold/purple). RIVALS' branding is not on the list.

## The list

| # | Item | Tacticals now | Effort | Script |
|---|---|---|---|---|
| **Areas / rooms** |||||
| 1 | Market hall: a dressed walk-through hall from the centre to the shop displays | Shop is a counter room only | L | no |
| 2 | Pad hallway: queue pads in a long hall with windows, TVs on arms and a red-lit skylight | Duels is one open hall | M | no |
| 3 | Drop pits between the pad rows, with a teleporter that puts fallers back at the Duels start | none (only the global fall catch at y -25) | S | small |
| 4 | In-hub walk-in range entrance with a big "SHOOTING RANGE" screen | heli cutscene + PLAY menu; no screen | S-M | small |
| **Interactive features** |||||
| 5 | Limited-time-mode queue hologram (spinning, prompt "View / Limited Time") | only the officer NPC opens PLAY | S | no (OpenPanel=Play) |
| 6 | Ranked hologram ("Play Now / Ranked") | no ranked panel | M | yes |
| 7 | Arcade machine ("View / Arcade Servers") | none | M-L | yes |
| 8 | Free-rewards gift hologram ("Claim / Free Rewards") | Missions/Quests panels exist, but nothing in the world | S | no (OpenPanel=Missions) |
| 9 | Starter-bundle hologram ("View / Limited Time") | Shop counter only | S | no (OpenPanel=Shop) |
| 10 | Loose weapon displays: 8 weapons on stands, "View <weapon>" | gun wall + dais (one Kit prompt), spinning scissors | M | yes (preselect item) |
| 11 | Jump shards: 3 hidden glowing crystals, a scavenger hunt | none | M | yes |
| 12 | Pad terminals (edit the pad's mode) and bigger 4v4 pads with name boards | 6 pads (1v1-3v3) with holo boards | M-L | yes |
| 13 | Event garage door / portal (opens for events) | none | M | yes |
| **Displays and showcases** |||||
| 14 | Top-player reward stand: exclusive skin rotating on a plinth under a Neon cone | none | S | no (LobbySpin tag) |
| 15 | Season stage: lit alcove, emblem screen, SEASON title, KEEP CLEAR apron, prompt opens the pass | none | M | small |
| 16 | UGC shop stage: curtained alcove with mannequins and a "UGC SHOP" plate | none | M | small |
| 17 | Bundle pad in Duels: rotating bundle on a pad, prompt opens the shop | none | S | no |
| **Signage, screens, leaderboards** |||||
| 18 | Leaderboard TVs (global + ranked) on TV arms in the centre | **code ready, screen part missing** | S | no |
| 19 | Live duels TV: lists the duels in progress | none | M | yes |
| 20 | Likes-goal board + rewarded video-ad board | none | M-L | yes |
| 21 | DUELS sign with a live screen built in | static DUELS sign | S-M | small |
| 22 | Update countdown: floor logo at spawn counting down to the next update | none | M | yes |
| 23 | Wayfinding text: stencil labels (WEST GATE, CARGO ELEVATOR, HOLOBAY 01-04, VAULT, KEEP CLEAR) + floor arrows/chevrons | big signs, floor lines, HullMarks; few arrows | S-M | no |
| **Set dressing and props** |||||
| 24 | Weapons-room dressing: real weapon models on cloth-covered tables, pallets, barrels, target floor | racks, displays, generic crates | M | no |
| 25 | Spinning wall vents/fans with moving fan shadows | vents hidden, nothing spins | S-M | no (constraint/LobbySpin) |
| 26 | TVs on articulated arms throughout (about 20) | FlightHUD screens only | S-M | no |
| 27 | Industrial props: containers, pipe runs, power boxes, intercoms, poster frames | crates, drums, cases only | M | no |
| 28 | Outdoor scenery past the hub (hill, trees, antenna mast with red light, projectors) | city below, Times Square | S (mast only) | no |
| **Lighting and atmosphere** |||||
| 29 | Truss spotlights on a ceiling ring aimed at the centre and showcases (warm, some with shadows) | 6 shadowed lights, none aimed at features | S | no |
| 30 | Red alarm beacons washing the Duels skylight shaft | no red lights | S | no |
| **Effects (purpose-bound only)** |||||
| 31 | Sparkle/glow and hologram cones on every interactable (holograms, weapon stands, shard, reward stand) | only FX.Hologram at spawn | S each | no |
| 32 | Vent puff VFX on the Market vents | none | S | no |
| **Audio** |||||
| 33 | Lobby music: a track that turns muffled while a menu is open and switches to duel music when spectating | Music Volume setting, no player | S-M | yes (own track) |

---

## Details

Coordinates are RIVALS world positions (hub floor ≈ y -681, spawn at 109,-680,1184). RIVALS' lobby scripts are the client modules
`StarterPlayerScripts.Modules.LobbyElements.*`, driven by CollectionService tags (shown in brackets).

### Areas / rooms
**1 Market hall** (`Hub.Extra.Market`, about x 40-170, z 1216-1356). A wide hall north of the centre, with ribbed walls, a hazard band,
ceiling slashes and lane lines. It holds 7 containers, 4 intercoms, pipe runs, a power box, 4 ad-poster frames, 4 spinning vents and an
NPC, and it leads to the Season/UGC stages (15, 16). Players walk through it for the stages; it adds no gameplay. *Tacticals:* the Shop is a
closed room with a counter. The room footprint is fixed, so this could only be done as **dressing the north corridor and Shop** in this
style. **L**, no script.

**2 Pad hallway** (`Hub.Extra.Hallway`, x 186-360). The queue pads line a long corridor. It has window bays, TVs on arms over each
pad, white mode plates (1v1, 2v2, 4v4), a skylight shaft with red beacons (30) and hazard-striped pit edges. *Tacticals:* Duels is one
open hall with 6 pads. Dressing only, inside the existing Duels footprint. **M**.

**3 Drop pits + teleporter** (`Duels.Teleporter`, tag LobbyTeleporter, pits at 273,-697,1140/1228). These are dark pits between the
pad rows. If you fall in, a `From` part sends you to `To` at the Duels start. *Tacticals:* only the global fall catch, which puts you at
spawn or the hangar. **S** with a small touch script; only useful if Duels gets pits.

**4 Range entrance** (`Hub.Important.ShootingRange`: Sign, Entrance, tag ShootingRangeEntrance / LobbyShootingRangeVisuals). This is a
walk-in arch with a big "SHOOTING RANGE" screen at the west end of the hub. Walking in teleports you to the range, and the screen lists
who is inside (ShootingRangeDisplay). *Tacticals:* the heli cutscene at Exfil already does the "walk in" part. The gap is the
**screen at the Exfil/Training entrance showing who is in Training**. **S-M**.

### Interactive features
**5 LTM queue hologram** (`Center.RotatingQueues`, 94,-681,1210). This is a spinning hologram of the current limited-time mode on a
glowing base, with prompt "View / Limited Time" (opens the queue page). *Tacticals:* `LobbyUIController` already opens panels from
any prompt with `OpenPanel`, and "Play" is a valid value, so this is a hologram model + prompt with **no new code**. **S**.

**6 Ranked hologram** (`Center.HologramRanked`, 169,-681,1165). Purple badge hologram, "Play Now / Ranked". *Tacticals:* has no ranked
panel (the panels are Shop, Kit, Play, Missions, Quests, Settings). It needs ranked UI or a Play-panel tab. **M**.

**7 Arcade machine** (`Center.ArcadeServer`). A cabinet that opens custom/arcade servers. *Tacticals:* none. It needs the feature
itself. **M-L**.

**8 Free-rewards gift** (`Center.HologramFreeRewards`, a spinning gift hologram). "Claim / Free Rewards" opens the rewards page.
*Tacticals:* can point at the existing **Missions** (or Quests) panel with `OpenPanel`, so no new code. **S**.

**9 Starter-bundle hologram** (`Extra.Center.SuperStarterBundle`). A spinning bundle model, "View / Limited Time", opens the shop on the
bundle. *Tacticals:* `OpenPanel=Shop`. **S** (opening on a specific item would need a small Shop change).

**10 Loose weapon displays** (`Weapons.LooseWeaponDisplay` x8, tag LobbyLooseWeaponDisplay). These are single weapons floating on
small stands round the weapons room (Energy Rifle, Chainsaw, Minigun…), each with sparkles and a "View <weapon>" prompt. *Tacticals:*
the Armory has one gun-wall prompt and one dais prompt for the whole Kit, plus the spinning featured scissors. Stands are **S**; a
per-weapon prompt that opens Kit on that weapon needs a Kit change. **M**.

**11 Jump shards** (`Hub.Important.Shards`, 3 x JumpShard, tag ScavengerHunt). Small glowing crystals hidden in awkward spots: on a
ledge in the weapons room, by a pad row, high near the centre. Touching one collects it (a scavenger hunt with a reward). *Tacticals:*
none. It needs a data-saved collect script. Ties into Missions if wanted. **M**.

**12 Pad terminals + bigger pads** (10 `Queue Pad #n`, ClientQueuePad / QueuePadTerminal / EditQueuePad). The pads have a terminal for
choosing the mode/settings, and #9/#10 are larger 4v4 pads with Title + Players boards. *Tacticals:* 6 fixed pads (1v1/2v2/3v3 x2)
with holo boards. QueueManager changes would be needed. **M-L**.

**13 Event garage door** (`Center.GarageDoor`, DuelsGarageDoor, ArcadePortal). A large door that opens into a portal during events;
shut the rest of the time. *Tacticals:* none. Only worth it with events. **M**.

### Displays and showcases
**14 Top-player reward stand** (`Center.TopPlayerReward`, 169,-663,1207). A plinth with a Neon cone and an exclusive weapon skin turning
above it, with sparkles; it shows what top ranked players earn. *Tacticals:* none, but a model with the existing `LobbySpin` tag spins
with no new code. **S**.

**15 Season stage** (`Displays.S03Display`, 78,-666,1264). A stage alcove off the market corridor: an emblem screen, a "SEASON 3 / FAME"
plate, a truss with spotlights, a KEEP CLEAR apron with a hazard edge, and a prompt that opens the Battle Pass (`PageName=BattlePass`).
*Tacticals:* no season/pass panel, so it could open Missions instead. **M**.

**16 UGC stage** (`Displays.UGCDisplay`, 139,-666,1264). A matching alcove with red curtains, avatar mannequins and a "UGC SHOP" plate;
the prompt opens the UGC shop. *Tacticals:* none, and it is only useful if Tacticals sells avatar items. **M**.

**17 Duels bundle pad** (`Duels.BundleDisplay`, RotatingBundleDisplay). A bundle model turns on a lit pad in the pad hall and opens the
shop. *Tacticals:* none. **S**.

### Signage, screens, leaderboards
**18 Leaderboard TVs** (`Center.LeaderboardTV` and `Center.Ranked` boards, tag LeaderboardDisplay). Two screens on TV arms beside the
centre. *Tacticals:* **already scripted.** `ServerScriptService.LobbyLeaderboard` publishes the top 10 by wins, and
`LeaderboardScreen` draws it on `LobbyMap.Signs.Screen_Leaderboard` (Front face). Only that part is missing, so adding a screen part with
that name lights it up. **S**, the cheapest item on the list.

**19 Live duels TV** (`Center.DuelsTV`, DuelsDisplay). A screen listing duels in progress (players, mode, score). *Tacticals:* none.
QueueManager knows the matches, but they run in another place, so it needs MessagingService. **M**.

**20 Likes board + video-ad board** (`Center.LikesTV`, `Center.StarterBundleTV`; LikeBoards, BillboardVideoAdBoards). A "like the
game" goal bar that unlocks a code, and an AdService rewarded-video board. *Tacticals:* none. Meta features, so check they suit
Tacticals. **M-L**.

**21 DUELS sign with screen** (`Center.DuelsSign`, LobbyDuelsSign). The big Neon DUELS sign over the corridor has a screen in it
(players in queue / Play). *Tacticals:* static Neon DUELS sign. Could reuse the pad-board data. **S-M**.

**22 Update countdown** (`Center.UpdateCountdown`). A logo set into the floor at spawn, with a countdown to the next update ("ANY SECOND
NOW") and a prompt. *Tacticals:* spawn disc + hologram, no countdown. Needs a set update time (attribute or config). **M**.

**23 Wayfinding labels** (KEEP CLEAR, WEST GATE, CARGO ELEVATOR, HOLOBAY 01-04, MARKET, VAULT, LABORATORY, "WARNING! — PAYLOAD ZONE";
PathArrow meshes, RoadLineBlocks, Arrows). Small white label plates over doors, stencilled floor text and chevrons that lead into
areas. *Tacticals:* has the big signs, floor lines and HullMarks, but few destination labels and almost no floor arrows/chevrons. Own
text in SurfaceGuis (style guide #14). **S-M**.

### Set dressing and props
**24 Weapons-room dressing** (`Hub.Extra.Weapons`). The room has real weapon models (assault rifles, sniper, RPG, flare gun…) on
cloth-covered tables, plus wood crates, barrels, explosive barrels, pallets and a big red/white target floor graphic. *Tacticals:*
the Armory has racks/displays and generic crates, but no actual weapon models lying about. It would use our own weapon models from
`ReplicatedStorage.Repository.Weapons`. **M**.

**25 Spinning vents/fans** (Market `Vent` x4: AngularVelocity-driven fan + SpotLight; weapons-room fans with shadow SpotLights
0.2 brightness). The fan blades turn and throw moving shadows. *Tacticals:* the old GVent kit is hidden and nothing spins. A
`LobbySpin` tag or a HingeConstraint gives the spin; a spotlight behind each fan gives the shadows. **S-M**.

**26 TVs on arms** (about 20 `TVArmPiece` models in the hallway and centre, with screen-glow Beams). Wall/ceiling-mounted TVs on
articulated arms over pads and in the centre. *Tacticals:* only the FlightHUD screens. These are also the hosts for 18/19. **S-M**.

**27 Industrial props** (Market: Container02 x7, Piping, ModularPipe, Power Box with decal, Intercom x4, ADFrame poster frames).
*Tacticals:* the kit has crates, drums and cases only. Pipes/power boxes/intercoms suit a military base. **M**.

**28 Antenna / outdoor scenery** (`Hub.Extra.Range`: hill, palms, pine, Antenna with a red PointLight, projectors). For a floating sky
base only the **antenna mast with a red aviation light** fits (palms/hill do not). **S**.

### Lighting
**29 Truss spotlights** (`Extra.Center` Spotlight_02a x8 on the CenterRingPipes truss; 255,241,208, brightness 1.5-2.5, range 30-60;
shadows on the hero ones). A ceiling ring of spotlights aimed down at the spawn centre, plus three aimed at each showcase stage. *Tacticals:*
87 enabled lights, only 6 with shadows, none aimed at a feature. This is lighting the spawn hologram and the Armory feature the RIVALS way. **S**.

**30 Red alarm beacons** (4 SpotLights 255,32,84, brightness 3, shadows on, in the skylight shaft over the 4v4 pads). They give a red
wash on the shaft walls. *Tacticals:* no red lights at all. Danger red is the one non-palette colour the style guide allows. **S**.

### Effects (purpose-bound only; no ambient particles)
**31 Interactable FX** (RotatingQueues 24 emitters, Hologram 12, LooseWeaponDisplay 40, JumpShard 18, Arch Uzi 12, plus Beam cones
under holograms and on TV screens). Every emitter belongs to something you can use or look at. *Tacticals:* only `FX.Hologram` at
spawn after the particle cleanup. These come with items 5-11 and 14-17; they are listed separately so you can choose items with or
without FX. **S** each.

**32 Vent VFX** (Market vents, 4 emitters). Small puffs from the vents. Purpose-bound (attached to a working vent), but close to
ambient, so it is your call. **S**.

### Audio
**33 Lobby music** (`Controllers.MusicController`). One lobby track (volume 0.5). It switches to a **muffled version while any menu
or the Equipment screen is open**, and to the duel's music when spectating. Event variants exist. There are **no ambient/positional
sound sources** anywhere in RIVALS' lobby (only one AudioVisualizer helper far off-map), so music is the whole soundscape.
*Tacticals:* the Settings "Music Volume" slider exists, but nothing plays. It needs an **own track** (plus a low-passed copy, or an
EqualizerSoundEffect for the muffle) and a small client controller. **S-M**.

---

## Already matched, or left out on purpose
- **Matched already:** queue pads with boards, NPCs with idle animations and talk prompts (RIVALS: Neko, Nosniy, SenseiWarrior),
  shop/kit prompts, spawn hologram, the shooting range (our Training v2), big area signs, Neon wall lights, ceiling strips, the
  RIVALS lighting values.
- **Left out (branding / kid-friendly / seasonal):** purple/gold rings round spawn (`Center.Ring`, gold/purple), the Neko NPC
  reading a book, BirthdayDoor, ToyTrainPaths, FestiveLightsCircuit, the Spooky/Festive/Tropical lighting profiles and music, and
  advent calendar.
- **Technical, not visible:** WaitingRoom box (spectate holding area, off-map), camera-blocker planes, DisabledTexturesBlacklist.
