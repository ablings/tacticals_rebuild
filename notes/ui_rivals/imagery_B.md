# RIVALS imagery audit B (t0150-t0329)
a = live 3D (viewport / world), b = flat 2D icon, c = posed render. Halloween colours ignored.
How we checked: the finisher cards stay the same once you allow for the scroll (diff 6.7 at dy 218, t0154.7 vs t0155.0), so they are c. The pad pumpkin, crate and gift turn between frames (t0206-0220), so they are a.

## 1. RIVALS per screen
**Hub HUD**
| element | kind | frames | notes |
|---|---|---|---|
| Dock icons (Backpack...Event) | c | 0150 | ~60 px glossy 3D, no backing |
| Key currency, task key rewards | c | 0150 | gold key, 30-40 px |
| Task glyphs (play, claw, trophy) | b | 0150 | white, 20 px |
| Level star, device, verified | b | 0150, 0228 | |
| Party avatar | c | 0150 | headshot |
| "x3 Keys" toast | c | 0174 | key render on a white card |
| Prompt "Q / View" | b | 0190 | key square, white card |

**Gift player list (0152)**: c headshots, 48 px; b arrow buttons; c gift item card.

**Shop (0154-0162, 0186, 0300)**
| element | kind | frames | notes |
|---|---|---|---|
| Crates, capsules, boxes | c | 0154 | 90 px, no card |
| Skin / charm cards | c | 0154, 0156 | 80 px rarity card; the model spills past the edge |
| Daily weapons | c | 0154.7 | 165x125, breaks out of the card |
| Finishers, wraps | c | 0155 | action pose, motion lines |
| Card-corner gun tag | b | 0154 | |
| Bundle banners | c | 0158 | 260-400 px wide, weapon cropped by the frame, full backdrop |
| Key bundles | c | 0186 | giant cropped key as backdrop |
| Season Pass tile | c | 0154 | |
| Login rewards Day 1-6 | c | 0156 | crate, wheel, pack, keys |
| Day 7 ticket, ticks | b | 0156 | |

**Lobby world (0170-0284, 0320)**
| element | kind | frames | notes |
|---|---|---|---|
| Gift, event pumpkin + crate, gloves, Daggers, Ranked trophy, floating gun, Season crest | a | 0172, 0206, 0228, 0258, 0284, 0272, 0322 | spinning models on glowing pads |
| "Watch now to claim" TV | b | 0150, 0264 | flat yellow poster |
| "Like the game!" | b + c | 0174 | thumbs b, key c |
| Leaderboards (5 boards) | c + b | 0190-0222, 0272 | headshots c; flame / trophy / rank glyphs b |
| Duels LIVE board | c + b | 0228 | **row backdrop = map screenshot**, headshots, eye glyph |
| Pad screens | c + b | 0296 | headshot + level / streak |

**Other**: Daggers locked (0260) shows chains, padlock and weapon as a, the career list as c and the glyphs as b. Gamemode cards (0250) use c full-bleed art with a b glyph. Ranked menu (0286) is b ticks plus a c avatar. Duel HUD (0230-0246) uses c for the hotbar and avatars and b for glyphs.

## 2. Balance
- Hub HUD: mostly c, b glyphs, no a.
- Gift list: c + b.
- Shop: nearly all c, **no viewports**.
- Lobby world: a for every point of interest; boards c over b.
- Locked weapon: one large a; lists c.
- Gamemodes: c + b. Ranked / duel HUD: b + c.

## 3. Ours vs RIVALS
| ours | today | RIVALS | gap |
|---|---|---|---|
| Dock (LobbyHudController:425, FlatIcons) | b | c | the opposite. Edward OK'd flat on 10-21, so we only flag it |
| Kit.ICONS, LEVEL_TIERS, RankArt, Badges.DEVICE, nameplates, corner list | b | b | ok |
| Scissors pill (LobbyHudController:498) | a | c | fine |
| Prompts (PromptsController) | b | b | ok |
| Shop cards / Founder's (ShopScreen) | a | c | no full-bleed bundle banners; live guns on plain cards look empty |
| Missions rewards | a | c | ok |
| Play (PlayScreen squadScene, gun, trophy) | a | c | ok live; Training / Lobby Duels have no art |
| LeaderboardScreen | c headshots + text | c + b | no stat glyphs, no LIVE tag |
| DuelsTV / Sign (LobbyScreensController) | text + pills | c map rows + b eye | **no map shots, no eye glyph** |
| Ad board | text | b poster | **no art** |
| Likes board | text + bar | b + c | **no art** |
| Hub points of interest (sheet_before 1) | one pedestal | a pads | needs Blender models, not images |
| Login rewards | none | c + b | not built |

## 4. Must make (only where RIVALS uses b / c)
| file | shows | kind | px | transp. | goes to |
|---|---|---|---|---|---|
| ui/art/screens/tv_watch_ad.png | olive / amber poster: play disc, film glyph, scissors | b | 1024x512 | no | LobbyScreensController buildAd backdrop |
| ui/art/icons/icon_thumbsup.png | thumbs-up | b | 256 | yes | buildLikes title |
| ui/art/icons/icon_spectate.png | eye | b | 128 | yes | buildDuelsTV rows, DuelsSign |
| ui/art/icons/icon_live.png | red "LIVE" tag | b | 256x96 | yes | LeaderboardScreen, DuelsTV header |
| ui/art/icons/icon_lb_{streak,elims,wins,level,rank}.png | board tab glyphs (reuse Kit.ICONS where they fit) | b | 128 | yes | LeaderboardScreen footer |
| ui/art/maps/map_{name}.png | wide shot per duel map (warehouse exists) | c | 640x360 | no | DuelsTV row backdrop, 50% dim |
| ui/art/shop/bundle_founders.png | Pistol + Knife + Frag close-up, cropped, olive backdrop | c | 1024x512 | no | ShopScreen Founder's card (live guns stay in the pop-up) |
| ui/art/shop/bundle_{vip,starter}.png | same style | c | 1024x512 | no | ShopScreen bundle cards |
| ui/art/play/mode_training.png, mode_lobbyduels.png | dummy + cover; two players on a pad | c | 768x432 | no | PlayScreen Training / Lobby Duels cards |
| ui/art/rewards/reward_ticket.png | golden ticket | b | 512 | yes | login Day 7 (if built) |
| ui/art/rewards/reward_{crate,scissors_pile}.png | crate; scissors pile | c | 512 | yes | login Day 1-6, reward toast |

Make the c images by rendering our own Blender meshes with a rim light, not with image generation, so they match the live models. RIVALS shows the pad items (gift, crate, trophy) as live models (a), so model them in Blender rather than making images.
