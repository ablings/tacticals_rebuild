# RIVALS imagery audit A (frames t0000-t0152)

Kinds: **a** = live 3D (viewport/world), **b** = flat 2D icon, **c** = posed render (baked image).
Timeline correction: t0016-t0058 is the **Weapons** screen and its cosmetic pickers, not unbox reveals. The "reveals"
are previews of skins, wraps, charms and finishers on the live model or dummy. Shop is t0068-t0106, Tasks t0062-t0066,
free rewards t0086-t0092, login rewards t0102, the duel t0112-t0122, player card t0124-t0132, Settings t0136-t0138
and the Season Pass t0142-t0148.

## 1. RIVALS per screen

**Backpack + capsule + odds (t0002-t0014)**
| element | kind | frames | notes |
|---|---|---|---|
| capsule / wings / box items | c | t0002, t0006 | ~45 px, glossy, with a gun badge corner and "xN", no tile background |
| capsule popup item | c | t0004, t0012 | ~60 px on a black popup |
| odds rows (wrap swatches, charms) | c | t0008, t0014 | ~16 px thumbnails |
| close X, red lock | b | all | |

**Weapons / Kit (t0016-t0058)**
| element | kind | frames | notes |
|---|---|---|---|
| hero weapon on the bench | a | t0018-t0032, t0052 | full-screen, in the world, sways and lights live |
| locked weapon + gold chains + padlock | a | t0056 | 3D overlay in the world |
| emote / finisher preview on a dummy | a | t0036-t0050 | dummy on a red target floor, animated |
| picker tiles (lock on rarity colour) | b | t0020, t0034 | ~40 px lock glyph |
| picker title icon | c | t0026, t0038 | ~22 px swatch or emote thumbnail |
| equipped wrap in the slot bar | c | t0024 | ~38 px swatch |
| empty slot / Leave X | b | t0024 | |
| left list weapon pictures | c | t0058 | ~30 px dark gun renders |
| right panel glyphs (contracts, eye, stats) | b | t0018 | ~14 px |

**Tasks / contracts / free rewards (t0062-t0092)**
| element | kind | frames | notes |
|---|---|---|---|
| daily-task icons (play, crosshair, trophy) | b | t0062 | ~22 px white |
| key reward | c | t0062 | ~16 px gold key, "xN" |
| milestone avatars | c | t0062 | Roblox character renders |
| contract weapon glyph | b | t0064 | grey silhouette |
| contract reward thumbs | c | t0064 | ~20 px wrap and key renders |
| free-reward thumbs | c | t0086 | ~30 px with captions |
| social logos | b | t0092 | |

**Shop (t0068-t0106)**
| element | kind | frames | notes |
|---|---|---|---|
| tab icons | c | t0068 | ~30 px glossy |
| crates and chests | c | t0068-t0078 | ~55 px, no tile, price pill under each |
| charm tiles + gun-infinity badge | c+b | t0070 | red tile |
| emote tile (5,000 candy) | a | t0070 (empty) then t0072 | dummy loads late |
| Season Pass banner | c | t0068-t0078 | ~250x110, the same in every frame |
| carousel bundles (Starter, Exogun) | c | t0072, t0076 | ~250x110 |
| bundle popup contents | c | t0074 | ~45 px tiles, box x15, keys x20 |
| Bundles tab banners | c | t0106 | ~130x90, with a "xN VALUE" sticker |
| Keys tab key-heap art | c | t0084 | backgrounds on the tiles |
| Daily: skins / melee | c | t0094-t0104 | the same in every frame |
| Daily: emotes | a | t0096 vs t0097 | grey dummies change pose between frames |
| Finishers row | c | t0096 | dummy plus effect |
| currency (key, candy, robux) | b | all | ~16 px |

**Login rewards (t0102)**: check marks (b); Day 3 crate (c); Day 7 golden ticket (c), shown big at ~120 px.

**Duel HUD (t0112-t0122)**
| element | kind | frames | notes |
|---|---|---|---|
| score-bar avatars | c | t0112 | Roblox headshots |
| level badges, eye, timer glyph | b | t0112 | |
| hotbar items | c* | t0112, t0122 | static ~45 px, wrap visible, no rotation (could be a still viewport) |
| kill-cam avatar card | c | t0116 | Roblox avatar |

**Player card (t0126)**: "most played weapons" (c, ~30 px renders); level and streak (b).

**Settings (t0136-t0138)**
| element | kind | frames | notes |
|---|---|---|---|
| tab icons | c | t0136 | ~28 px glossy renders |
| row glyphs | b | t0136 | speaker, sparkle, mute, reset |

**Season Pass (t0142-t0148)**
| element | kind | frames | notes |
|---|---|---|---|
| free / premium track shields | b | t0142 | ~60 px |
| rewards (wings, keys, tickets, Grappler, emotes) | c | t0142-t0146 | ~50 px |
| wrap rewards + gun badge | c+b | t0144 | |
| Spear | a? | t0144 | 3D model breaks out of the tile; only one frame shows it |
| Prime / Contraband banners | c | t0144 | ~240x100 |

## 2. RIVALS balance
- Backpack: everything is posed renders, with flat glyphs for close and lock.
- Weapons/Kit: hero, locked overlay and previews are live; tiles are flat locks; thumbnails are posed.
- Tasks/rewards: task icons are flat; rewards are posed.
- Shop: almost all posed renders; live dummies only for emotes; flat currency.
- Duel HUD: avatars and hotbar are posed; status glyphs are flat.
- Settings: tabs are posed renders; rows are flat glyphs.
- Season Pass: track shields are flat; rewards and banners are posed.

## 3. Ours today vs RIVALS
| our screen / element | ours | RIVALS | gap |
|---|---|---|---|
| Kit hero item (`Armory.lua` Showcase) | a | a | none |
| Kit slot buttons (`GLYPH.skin/wrap/...`) | b drawn | b | none |
| Kit cosmetic tray (`openCosmeticTray`) | b "none" + "Soon" | c swatches + b locks | needs swatches once wraps exist |
| Kit list pictures | a mesh silhouettes | c | fine |
| Shop gear tiles (`ShopScreen.itemArt`) | a | c | allowed (RIVALS goes live for emotes); every tile being live costs performance |
| Shop Founder's / VIP hero cards | a (gun cluster, medal) | c banner | **gap**: needs one painted banner each |
| Shop scissor packs | a (fanned scissors, `still`) | c (key heaps) | small gap; reads OK |
| Shop tabs | a | c | fine |
| Currency (`SCISSORS_IMG`) | c | b | small: a flat glyph would read better at 16 px |
| Missions task icons (`MissionsScreen` l.38-42) | a (grenade, coins, knife viewports) | **b** | **gap**: should be flat white glyphs |
| Missions reward scissors | a still | c | fine |
| Settings tabs + rows (`FlatIcons`) | b | c tabs, b rows | Edward chose flat; keep |
| Duel HUD hotbar | a/c 3D items | c | none |
| Duel HUD avatars | Roblox headshot | c | none |
| Kill feed (`art/killfeed/w_*`) | b | b | none |
| Ranked lock (Play) | c padlock | b | small |
| Login rewards / Season Pass / Backpack | none | - | no screen; nothing to make now |

`LobbyUIController` already checks `Config.Images[itemId]` before it falls back to a viewport, so posed renders can be dropped in without new code.

## 4. Must make
All are PNGs with transparent backgrounds, saved to `ui/art/<folder>/_upload/`.
| file | shows | kind | px | goes to |
|---|---|---|---|---|
| `shop/banner_founders.png` | pistol, knife and grenade fanned, with a "LIMITED" ribbon area left clear | c | 1200x560 | `ShopScreen.lua` Featured hero card (replaces the live cluster) |
| `shop/banner_vip.png` | gold VIP medal on a tag, with a scissors sparkle | c | 1200x560 | `ShopScreen.lua` VIP card (replaces the `ViewIcons.Icon "Medal"`) |
| `shop/pack_scissors_s/m/l.png` | small, medium and large heaps of scissors | c | 512x512 | `ShopScreen.lua` scissor-pack tiles (l.333/506), optional |
| `icons/icon_scissors_flat.png` | single scissors in white line art | b | 128x128 | `SCISSORS_IMG` (`ShopScreen.lua` l.19, `LobbyUIController` l.50) price tags |
| `icons/icon_gadget.png` | thrown grenade with motion lines | b | 128x128 | `MissionsScreen.lua` task icon ("Throw N gadgets") |
| `icons/icon_melee.png` | knife slash | b | 128x128 | MissionsScreen ("melee elimination") |
| `icons/icon_cover.png` | crouched figure behind a wall | b | 128x128 | MissionsScreen ("from cover") |
| `icons/icon_matches.png` | crossed rifles / match flag | b | 128x128 | MissionsScreen ("Play / Win N matches") |
| `icons/icon_lock.png` | chunky padlock | b | 128x128 | Play Ranked card, Kit picker locks, Shop locked gear |
| `icons/icon_eye.png` | eye | b | 64x64 | duel HUD spectator count |
| `wraps/wrap_<name>.png` (one per wrap) | flat pattern swatch on a rounded square | c | 256x256 | `Armory.lua` `openCosmeticTray` tiles (replaces "Soon") |

Mission icons reuse the existing `_upload_v3` `icon_elims`, `icon_trophy` and `icon_play` where they fit.
No images are needed for Kit hero, unbox/purchase reveal, emote previews or the hotbar: reuse the live viewports.
