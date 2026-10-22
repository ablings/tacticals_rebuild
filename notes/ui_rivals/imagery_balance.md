# Imagery balance: RIVALS vs Tacticals (2026-10-21)

The full classification, with frame refs, is in `imagery_A.md` (t0000-t0152) and `imagery_B.md` (t0150-end).

Kinds:
- **(a) live view model:** 3D in a ViewportFrame or in the world.
- **(b) flat 2D icon.**
- **(c) posed render:** a 3D model baked into an image.

## RIVALS' balance
| RIVALS screen | (a) live view model | (b) flat 2D icon | (c) posed render |
|---|---|---|---|
| Menus in general | rare (see the rows below) | small glyphs only: currency, lock, check, task, level star, streak flame, rank, device, eye, prompt cards | almost everything else: crates, item cards, bundle / pass banners, reward tiles, Settings tabs, hotbar items, map rows |
| Weapons / Kit | the hero gun, the locked-gun chains, emote / finisher dummies | tile locks | thumbnails |
| Shop | only for emote dummies | currency | everything else; no other viewports |
| Lobby world | every point of interest (gift, pumpkin, gloves, trophy, gun on glowing pads) | the Ad / Likes boards | the leaderboards and Duels TV, laid over flat glyphs |

## Ours today
| Area | (a) live view model | (b) flat 2D icon | (c) posed render |
|---|---|---|---|
| Kit | hero and list (matches RIVALS) | — | — |
| Badges, nameplates, corner list, prompts, kill feed | — | yes (matches RIVALS) | — |
| Dock + Settings tabs | — | drawn FlatIcons (Edward chose flat on 10-21; RIVALS uses c here) | — |
| Shop, Missions rewards, Play scenes | yes | — | RIVALS uses c here |
| Mission task icons | 3D viewports (grenade, coins, knife) | **needed**: RIVALS uses flat glyphs | — |

The live Shop, Missions and Play pictures read fine but cost performance. Each loses to RIVALS in one place:
- Shop: the bundle hero cards have no full banner art.
- Play: the Training / Lobby Duels cards have no art.

The in-world TV and boards are the biggest gap: no map shots, no eye / LIVE / like glyphs, and no poster art.

## What to make, by route
1. **Flat icons (b), generated with codex on the main PC → upload → wire in.** First batch below.
2. **Posed renders (c):** bundle banners, mode cards, reward crate / scissors pile. Per imagery_B, render our own Blender meshes with a
   rim light instead of image generation, so they match the live models. The UI session can do this on the Shadow PC.
3. **Map shots:** Studio captures of each duel map (640x360), made on the Shadow PC.
4. **Hub points of interest (pads with a gift / crate / trophy):** live Blender models, not images.

## Batch 1 request (flat icons, all transparent PNG, ui/art/icons/_upload/)
Every icon is white / cream line art, chunky strokes, no outline glow and no text. Each must read at 32 px.

| file | shows | px | goes to |
|---|---|---|---|
| icon_gadget.png | a thrown grenade with two motion lines | 128 | MissionsScreen task icon "Throw N gadgets" |
| icon_melee.png | a knife slash arc | 128 | MissionsScreen "melee elimination" |
| icon_cover.png | a crouched figure behind a low wall | 128 | MissionsScreen "from cover" |
| icon_matches.png | two crossed rifles | 128 | MissionsScreen "Play / Win N matches" |
| icon_scissors_flat.png | a single pair of scissors | 128 | price tags / wallet (ShopScreen SCISSORS_IMG, LobbyUIController) |
| icon_lock.png | a chunky padlock | 128 | Ranked locked card, Kit picker locks, Shop locked gear |
| icon_eye.png | an eye | 128 | duel HUD spectator count, Duels TV rows |
| icon_live.png | a red "LIVE" tag with a dot (red fill, white letters; the only coloured one) | 256x96 | leaderboard board, Duels TV header |
| icon_thumbsup.png | a thumbs-up | 128 | Likes board title |
| icon_lb_streak.png, icon_lb_elims.png, icon_lb_wins.png, icon_lb_level.png | a flame, crosshair, trophy and star-in-shield | 128 | leaderboard tabs (reuse Kit.ICONS where one already exists) |

## Batch 1 uploaded (2026-10-21, Gunsy Funsy group, approved by the Shadow PC user in chat)
Decal ids → image ids (read with InsertService in Studio), all now in `Kit.ICONS` (ui/lobby/Kit.lua):

| Kit.ICONS key | image id |
|---|---|
| gadget | 122224655406431 |
| melee | 81713790092609 |
| cover | 94141250592215 |
| matches | 125681613105062 |
| scissorsFlat | 117873069678184 |
| lock | 124085037377046 |
| eye | 139964028443214 |
| live | 85639052729616 |
| thumbsup | 133746546608841 |
| lbStreak | 139831914155940 |
| lbElims | 83789042758416 |
| lbWins | 120316362189428 |
| lbLevel | 81711657935672 |

**Rule (user):** before any view model becomes an icon, check what RIVALS does there.
- Missions task icons → flat. **Wired.** RIVALS Daily Tasks t0062 use flat white glyphs.
- Shop price-tag scissors → flat. **Wired.** RIVALS price tags t0070 use flat currency glyphs.
- Not swapped:
  - Reward pictures and Shop tiles: RIVALS uses posed renders there, so ours stay live.
  - The Ranked padlock: RIVALS' locked Ranked card t0287 has no icon, only a requirement list.
  - The dock: flat since Phase B (Edward OK), but RIVALS uses posed renders there, flagged to the user.
- eye / live / thumbsup / lb_*: for the Studio-only TV and leaderboard screens (next).
