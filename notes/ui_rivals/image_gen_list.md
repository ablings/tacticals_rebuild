# RIVALS 1:1 image list: what an image generator can make (2026-10-21, after port1)

Sources compared: ours = `notes/ui_rivals/port1/*.png` (1436x784 captures) + `grade4/hub.png`, `grade4/kit_picker.png`;
RIVALS = `notes/rivals_rec/t0000/t0052/t0136.0s.jpg` (1280x720) and vault `practice/rivals/img/ref_04, 10, 11, 14, 35, 36,
42, 51, 53, 55, 63` (1920x1080, colour-correct from ref_21). Sizes below are **RIVALS px at 1920x1080**. Hex values were
sampled from the refs (anti-aliased, so treat them as ±10).

The image ids come from `ui/rivals/Assets.lua`, which is byte-identical to `rivals_practice/ui/kit/Assets.lua`. Many
"RIVALS" marks in the port are not images at all. They are Frames drawn in code: `Armory.lua` GLYPH.empty / leave / closex /
up / bars / lens / star, and the `vbox` rifle / knife / grenade vectors. Others are the replica's PIL-drawn stand-ins:
`tasks.check`, `tasks.star6`, `tasks.trophy`, `hud.*`, `hotkeys.*`. Those two groups are where the gaps are.

Rules applied: images only (no layout). Tacticals keeps its own item models, scissors currency and level shield. Live 3D or
posed renders of Tacticals items are skipped (see the end).

## Table (ordered by how visible it is)

| # | name | where it appears | RIVALS' version | ours now | Assets key |
|---|---|---|---|---|---|
| 1 | **Close X glyph** | the red close button on Play, Missions, Shop, Settings and Codes (every screen) | A heavy, chunky multiplication sign (like ✖): short thick arms with slightly rounded ends, ~40x40 px on a 135x67 red button. Fill near-white `#FDFFFF`, with a soft grey `#D2D2D2` shade on the lower half of each arm. No outline. The button runs `#EA4445` (top) to `#AA2220` (bottom). | Two thin capsule bars with a dark red outline (`GLYPH.closex`), so it reads thin and "drawn" | none (drawn). New: `ui.close_x` |
| 2 | **Empty-slot mark** | Kit bottom strip (Skin / Wrap / Finisher) and the picker's "None" tile | A rounded-square **outline** (not filled): ~46x46 px in the strip and ~70x70 in the picker. Stroke ~5-8 px, corner radius ~22% of the side. One diagonal slash runs from the bottom-left corner to the top-right corner and joins the outline (a ⍁ "none" box). Grey `#5A5A5A` in the strip (reads `#4D4D4D`-`#6A6A6A` over the dark disc). In the picker it is darker `#333333` on black. Each strip slot sits on a ~90 px dark translucent disc. | A **filled** translucent grey square with a separate thin slash that doesn't reach the corners (`GLYPH.empty`). Reads as a dim tile, not a "none" box. | none (drawn). New: `kit.slot_empty` |
| 3 | **Leave X** | Kit bottom strip, first slot | A **3D extruded** red X, ~90x75 px, seen slightly from above-left. Front faces `#E11D1D` / `#CC181A`, extrusion sides deep red `#94050F`. Squared, chunky arm ends, a glossy top-left highlight, no outline. Looks like a toy plastic X. | Two flat red bars with a dark red stroke (`GLYPH.leave`) | none (drawn). New: `kit.leave_x` |
| 4 | **Elimination claw glyph** | hub Daily Missions panel ("Get 8 eliminations"), Missions cards + Weekly Contracts rows, Hotkeys "Fire" | Three curved talon blades fanning from one point, sweeping up-right like a bird claw or feathered dart. Solid white `#FEFEFE`. The task card tints it lime `#63FF32` when complete. ~46 px in the task card, ~22 px in the hub panel, ~40 px in Hotkeys. | `rowIcon.crosshair` (a four-way split crosshair). The Tacticals `Kit.ICONS.elims` is three claw *scratches*, which is also not the RIVALS mark. | `rowIcon.crosshair` (wrong). New: `tasks.elims` |
| 5 | **Career category icons (set of 4)** | Kit career card tabs (and the mirrored pair flanking the "Weapons" list header) | Flat solid silhouettes, mid-grey `#858487` (the active tab is white), ~40 px inside 62 px dark `#1E1D22` rounded squares. Chunky Roblox-gun proportions with a slight 3/4 tilt. RIVALS has emote / rifle / pistol / knife / grenade; ours needs **rifle (Weapons), combat knife (Melee), grenade (Gadget), clock (History)** in the same style. | Code-drawn vectors: a thin rifle outline, a single line for the knife, a blob grenade and a ring clock. They look crude next to RIVALS. | none (`vbox` + `GLYPH.clock`). New: `kit.cat_rifle/knife/grenade/clock` |
| 6 | **Level-up arrows** | Kit right panel, "Level up now!" | Three solid up-arrows: a tall one in the centre, two shorter ones either side and lower. Chunky triangular heads, white `#E7E7E7`, ~36 px. | A double chevron (`GLYPH.up`) | none (drawn). New: `kit.levelup` |
| 7 | **Reward seal** | Kit right panel, "Reward at Level N" | A flat white rounded 12-14 point starburst seal (a cog-like badge), `#E3E3E3`, ~32 px | A full-colour orange **explosion** (`items.skin_explosion`) | `items.skin_explosion` (wrong). Cheapest fix: reuse `Kit.ICONS.level` (same shape). Or generate `kit.reward_seal`. |
| 8 | **Statistics bars** | Kit right panel, "Statistics" | Three white rounded-top bars on a baseline: medium on the left, tallest in the middle, short on the right (a podium bar chart). `#E7E7E7`, ~34 px | A **gold trophy** (`pass.trophy_gold`, full colour, never tinted) | `pass.trophy_gold` (wrong). Reuse `rowIcon.leaderboard` or generate `kit.stats` |
| 9 | **Lime check (with outline)** | Kit picker "None" / equipped tile; the Missions card bar when complete; Kit "Equipped" button | A fat check mark, lime `#65FE34` with a darker green underside `#3FBF1F`. On the progress bar it has a ~3 px near-black `#141414` outline. ~80 px in the picker, ~40 px on the bar. | `tasks.check` (PIL white tick) tinted green. Thin, no outline, no bevel. | `tasks.check` (stand-in). New: `tasks.check_lime` |
| 10 | **"To Duels" pinwheel star** | hub "Duel Pads" button (ours has none), the Missions "Play" button | A **twisted** six-point star like a shuriken or pinwheel: each arm skews clockwise, with a hexagonal hole in the centre. White, ~30 px. | `tasks.star6`: a straight, regular six-point star with a round hole (PIL). Thinner and static-looking. Missing from the hub button. | `tasks.star6` (stand-in) |
| 11 | **Bundle banner backdrops** | Shop: Founder's Bundle (big card), Operator Kit (Special Offer card) | Full-bleed painted backdrop. A saturated colour field (lime `#7ED321` to yellow-green for Super Starter; deep blue, crimson or teal for the others) with a lighter radial glow behind where the hero item sits, faint scattered "+" sparkles, soft dark silhouettes of gear at the edges, and calm space on the left for the title. The weapon breaks out of the frame. | A flat grey gradient (Founder's) and a flat blue gradient (Operator Kit), with live item renders on top | `bundles.bg_*` exist but are RIVALS' own guns. New: `shop.bg_founders`, `shop.bg_operator` (backdrop only; our item renders go on top) |
| 12 | **Card-corner weapon tag** | Shop item cards (Arms tab and featured grid) | A dark grey `#3A3A3A` tab in the card's top-right corner (rounded bottom-left corner only), ~55x45 px. On it, a light grey `#CDCDCD` assault-rifle silhouette with a bold "?" (random weapon) or "∞" (all weapons) at its lower right. | No tag | none. New: `shop.tag_random`, `shop.tag_all` |
| 13 | **Inspect magnifier** | Kit right panel "Inspect"; Hotkeys "Inspect" | A chunky white magnifier: a thick ring with a short fat handle down-right, and a small four-point sparkle inside the lens (RIVALS hotkey Inspect). ~34 px | A thin drawn ring + line (`GLYPH.lens`) | none. New: `kit.inspect` |
| 14 | **Settings row icons (set)** | Settings Video / Game / Controls rows (left of each row, ~52 px, white) | The ones where ours differs: **Optimized Textures** = a 3x3 checkerboard (white corners + centre, rounded outer corners). **Optimized Wraps** = an unrolled roll of wrapping material (a curled sheet with a tube at the bottom-left). **Damage Numbers / Camera Shake** = a "kaboom" burst (crown-like jagged spikes with an inner flame notch). **Toggle Crouch** = a down arrow + blocky crouching figure. **Toggle/Auto Sprint** = a chunky sneaker with three speed lines. **Easy Slide** = a blocky figure sliding feet-first + a right arrow. **Easy Gun Bash** (RIVALS Easy Quick Attack) = a spiral swoosh with a dash trail. **Hide HUD** = an eye inside a rounded-square frame. **Weapon Picker / Aim Assist** = an M16-style rifle tilted 45°. | `rowIcon.texture` (2x2 tiles), `rowIcon2.wraps` (cloth drape), `rowIcon.damage` (8-point star outline), `rowIcon.crouch`, `rowIcon.sprint` (running man), `rowIcon2.effects2`, `rowIcon.eye` (bare eye). `rowIcon2.inking` (a rifle) stands in for Aim Assist, Challenge Requests, Party Invites, Equip Gun / Melee, Delivery Mode, Keep Window and Bash Keeps Aim. | `rowIcon.texture`, `rowIcon2.wraps`, `rowIcon.damage`, `rowIcon.crouch`, `rowIcon.sprint`, `rowIcon2.effects2`, `rowIcon.eye`, `rowIcon2.inking` |
| 15 | **Hotkeys action icons** | Settings > Hotkeys rows (~40 px, white) | **Reload** = a circular arc with three bullets standing inside it. **Quick Melee** (our Gun Bash) = a fist or blade with speed lines streaking left. **Quick Utility** (our Throw Gadget) = a round grenade or flask with its top tilted. **Attack** (our Fire) = the claw from #4. **Ability** = a split-ring crosshair (ours is fine). | `rowIcon.reset` (a plain refresh arrow), `rowIcon2.effects2`, `rowIcon.particles` (sparkles), `rowIcon.damage` | `rowIcon.reset`, `rowIcon.particles`, `rowIcon.damage` |
| 16 | **Gamepad button badges** | Hotkeys controller columns | White badges with black letters, ~44 px. R2 / L2 = a trapezoid trigger shape; X / Y / A = filled circles; R3 = a stick cap with a small down-arrow over it; D-pad = a white plus with the pressed arm marked. | Drawn in code (`HotkeysPage.padGlyph`) | none |
| 17 | **Picker "unknown item" tile art** | Kit picker locked rarity tiles | Behind the white padlock: a dark, low-contrast silhouette of the weapon skin, with 2-3 four-point sparkles (✦) around it, all in a darker shade of the rarity colour | The item's pistol silhouette, tinted. No sparkles. | none. New: `kit.locked_sparkles` (overlay, tinted per rarity) |
| 18 | **Play mode card art** (optional) | Play: 1v1 / 2v2 / 3v3 / Duel Pads / Training | Stylised first-person action art: a big chunky gun in the foreground bottom-right, blocky enemies as **solid red silhouettes**, a white or lavender boxy arena, and a pink/purple colour wash, so the white title reads on top | Plain Studio screenshots of our avatar and red dummies on grey floors | `play.arena_a/b/c` are RIVALS-themed. New: `play.card_1v1` etc. |

## Image-generation prompts

House format, as in `rivals_practice/ui/art/*/imagegen_prompts.json`. Generate each icon at **512x512**, transparent
background (real alpha). If the tool can't give alpha, use flat `#00FF00` and key it out. Icons marked *tintable* must be
pure white `#FFFFFF` so `ImageColor3` can recolour them. Style line used throughout ("RIVALS flat"): *flat 2D mobile-game UI
icon in the style of the Roblox game RIVALS: bold, chunky, rounded silhouette, solid fill, no text, no thin lines, no drop
shadow, centred with ~8% padding, readable at 24 px.*

1. **ui.close_x** (`close_x.png`, 512x512, transparent):
   "Flat 2D mobile-game UI icon in the style of the Roblox game RIVALS: a single heavy multiplication-sign X like the ✖ glyph, short very thick arms with slightly rounded square ends, near-white #FDFFFF fill with a soft light-grey #D2D2D2 shading on the lower half of each arm (subtle bevel), no outline, no drop shadow, centred with 12% padding, transparent background, PNG. No text."

2. **kit.slot_empty** (`slot_empty.png`, 512x512, transparent, tintable):
   "Flat 2D UI glyph, pure white #FFFFFF on transparent background: a rounded-square OUTLINE (not filled), stroke width 11% of the icon, corner radius 22%, with one straight diagonal stroke of the same width running from the inside bottom-left corner to the inside top-right corner and joining the outline, like a 'none / empty slot' symbol. Clean vector edges, no shading, no shadow, 8% padding, PNG. No text."

3. **kit.leave_x** (`leave_x.png`, 512x512, transparent):
   "Glossy chunky low-poly 3D cartoon icon, Roblox RIVALS style: a big red X made of two thick extruded plastic bars crossing at the centre, seen slightly from above-left so the top and right extrusion sides show. Front faces bright red #E11D1D, upper faces #CC181A, extrusion sides deep red #94050F, small soft white highlight top-left, squared bar ends, toy-plastic look, soft studio light, no outline, no text, transparent background, centred, 6% padding, PNG."

4. **tasks.elims** (`elims_claw.png`, 512x512, transparent, tintable):
   "Flat 2D mobile-game UI icon, pure white #FFFFFF on transparent background, Roblox RIVALS style: an 'elimination' mark made of three curved talon blades fanning out from one point at the lower-left and sweeping up and to the right like a bird's claw or a feathered dart, the blades thick and pointed with sharp tips, solid fill, no outline, no shading, centred, 8% padding, readable at 22 px, PNG. No text."

5. **kit.cat_rifle / kit.cat_knife / kit.cat_grenade / kit.cat_clock** (4 files, 512x512 each, transparent, tintable). Run as one batch so they match:
   "A matching set of four flat 2D game UI icons, pure white #FFFFFF solid silhouettes on transparent background, Roblox RIVALS loadout-tab style: chunky blocky toy proportions, slight dynamic tilt, no outlines, no interior detail lines, centred, 10% padding. (1) cat_rifle: a blocky assault rifle in side view pointing up-right at 30°, stock, magazine and scope bump visible. (2) cat_knife: a chunky combat knife pointing up-right at 45°, wide blade with a clipped tip, short cross-guard, thick grip. (3) cat_grenade: a round frag grenade with a lever and pull ring on top, tilted 15°. (4) cat_clock: a round stopwatch-style clock face, thick ring with two hands at ten past two and a small button on top. One PNG per icon, same visual weight. No text."

6. **kit.levelup** (`levelup.png`, 512x512, transparent, tintable):
   "Flat 2D UI icon, pure white #FFFFFF on transparent background, Roblox RIVALS style: three solid upward arrows side by side, the centre one tall, the left and right ones about 60% as tall and set lower; chunky triangular heads with thick rectangular shafts, slightly rounded corners, no outline, no shading, centred, 8% padding, PNG. No text."

7. **kit.reward_seal** (`reward_seal.png`, 512x512, transparent, tintable). You can skip this and reuse `Kit.ICONS.level`:
   "Flat 2D UI icon, pure white #FFFFFF on transparent background: a solid rounded starburst seal badge with 14 short blunt points (like a cog or a sale sticker), perfectly symmetrical, no inner detail, no outline, centred, 8% padding, PNG. No text."

8. **kit.stats** (`stats_bars.png`, 512x512, transparent, tintable). You can skip this and reuse `rowIcon.leaderboard`:
   "Flat 2D UI icon, pure white #FFFFFF on transparent background, Roblox RIVALS style: a simple bar chart of three thick vertical bars with rounded tops standing on a shared baseline, left bar medium height, middle bar tallest, right bar shortest, small even gaps, no axes, no outline, centred, 8% padding, PNG. No text."

9. **tasks.check_lime** (`check_lime.png`, 512x512, transparent):
   "Flat 2D mobile-game UI icon, Roblox RIVALS style: a fat chunky check mark with rounded ends, lime green #65FE34 fill with a darker green #3FBF1F band along its lower edge for a slight bevel, a 3% near-black #141414 outline around the whole shape, tilted naturally, no drop shadow, centred, 8% padding, transparent background, PNG. No text."

10. **tasks.star6** (`star6_pinwheel.png`, 512x512, transparent, tintable):
   "Flat 2D UI icon, pure white #FFFFFF on transparent background: a six-pointed star twisted like a shuriken or pinwheel, each of the six arms skewed clockwise with one straight edge and one curved edge, a hexagonal hole in the exact centre, solid fill, no outline, perfectly rotationally symmetric, centred, 8% padding, PNG. No text."

11. **shop.bg_founders / shop.bg_operator** (2 files, 1536x1024, fully opaque):
   "Use case: stylized-concept. One game shop bundle-card background, landscape 1536x1024, fully opaque, in the style of the Roblox game RIVALS' bundle banners. Glossy chunky low-poly 3D cartoon look, bright saturated colours, soft studio lighting. [founders: warm military olive-to-gold colour field / operator: deep electric-blue colour field] with a strong lighter radial glow right of centre where a hero item will be placed later, faint scattered plus-shaped sparkles, a few soft dark out-of-focus silhouettes of crates and gear at the right and bottom edges, a soft vignette. The left third stays calm, open space for a title. No weapons in the centre, no characters, no text, letters, logos or watermark."

12. **shop.tag_random / shop.tag_all** (2 files, 256x208, transparent):
   "Flat 2D game UI corner tag, Roblox RIVALS shop style: a dark charcoal #3A3A3A tab with a rounded bottom-left corner and square other corners, filling the whole image. On it, a light grey #CDCDCD solid silhouette of a blocky assault rifle pointing up-right, and at its lower right a bold rounded [question mark '?' / infinity sign '∞'] in the same grey. No outline, no shadow, PNG with transparent outside the tab."

13. **kit.inspect** (`inspect.png`, 512x512, transparent, tintable):
   "Flat 2D UI icon, pure white #FFFFFF on transparent background, Roblox RIVALS style: a chunky magnifying glass, a thick ring with a short fat rounded handle pointing down-right, and a small four-point sparkle inside the lens near the top-left, solid fill, no outline, centred, 8% padding, PNG. No text."

14. **Settings row icons** (one PNG each, 512x512, transparent, tintable white). The shared prefix: "Flat 2D settings-menu icon, pure white #FFFFFF solid silhouette on transparent background, Roblox RIVALS style, chunky blocky shapes, no outline, no text, centred, 8% padding, PNG:"
   - `texture.png`: "...a 3x3 checkerboard, white squares at the four corners and the centre, transparent squares between, the outer corners rounded."
   - `wraps.png`: "...an unrolled sheet of wrapping material: a wide curled sheet with a wavy top edge, rolled into a tube at the bottom-left."
   - `damage.png`: "...a cartoon explosion burst, a wide jagged crown of 5-7 uneven spikes with a notch at the bottom centre like an inner flame."
   - `crouch.png`: "...a blocky Roblox-style figure crouching on one knee, with a thick downward arrow on its left."
   - `sprint.png`: "...a chunky sneaker in side view facing right, with three horizontal speed lines trailing behind it."
   - `slide.png`: "...a blocky Roblox-style figure sliding feet-first, leaning back, with a thick right-pointing arrow above its legs."
   - `quickattack.png`: "...a spiral swoosh curling up at the right end, trailing a dashed motion line to the left."
   - `hidehud.png`: "...an eye (almond outline with a round pupil) inside a thick rounded-square frame."
   - `weaponpicker.png`: "...a blocky M16-style assault rifle tilted 45°, muzzle up-left, with two short motion ticks at the stock."

15. **Hotkeys action icons** (same prefix as 14):
   - `reload.png`: "...a thick circular arc open at the top right with an arrowhead, three upright bullets standing inside the arc."
   - `quickmelee.png`: "...a chunky fist punching right, with three speed lines streaking behind it to the left."
   - `quickutility.png`: "...a round grenade with its top lever tilted, a small spark at the top."

16. **Gamepad badges** (`pad_R2.png`, `pad_L2`, `pad_R3`, `pad_A`, `pad_X`, `pad_Y`, `pad_dpad_up/down/left/right`, 256x256, transparent):
   "Flat 2D controller button glyph, Roblox RIVALS hotkey style: a solid white #FFFFFF [trapezoid trigger shape, wider at the top, rounded corners / filled circle / stick cap with a small triangle above / plus-shaped d-pad with the {up} arm darker grey] with the bold black #111111 label '[R2/L2/R3/A/X/Y]' in a rounded heavy sans-serif (Fredoka-like), centred, no outline, no shadow, transparent background, PNG."

17. **kit.locked_sparkles** (`locked_sparkles.png`, 512x512, transparent, tintable):
   "Flat 2D overlay, pure white #FFFFFF on transparent background: three four-point sparkle stars (✦) of different sizes, scattered around the edges (big at the top-left, medium at the right, small at the bottom), leaving the centre empty for a padlock, solid fill, no outline, PNG."

18. **play.card_*** (optional; 1024x640, opaque, one per mode):
   "Use case: stylized-concept. A game-mode card illustration, 1024x640, fully opaque, in the style of RIVALS' gamemode cards. A first-person view: a big chunky blocky toy pistol in the foreground at the bottom right, held by a blocky arm. Inside a clean white-lavender boxy arena of large tiles, [1 / 2 / 3] blocky Roblox-style enemies drawn as flat solid red #E0212B silhouettes holding rifles. A strong pink-purple colour wash over everything, soft light, room for a big white title in the centre-left. No text, logos or watermark."

## Skipped on purpose
- **Hub dock icons** (Kit pistol, Missions clipboard, Shop crate, Codes dog-tags, Settings gear). These are live 3D
  `ViewIcons` of Tacticals meshes. Edward OK'd flat on 10-21. RIVALS' gear is lavender-grey `#B8BCD8` and ours is tan/bronze:
  flagging it only.
- **Settings tab icons** (Video / Audio / Game / Hotkeys / Touch). Also live 3D `ViewIcons`. RIVALS' are a landscape-picture
  monitor, a black speaker cabinet, a black gamepad with coloured buttons, a red crosshair and green/yellow keycaps. Ours are a
  monitor, headphones, a gamepad, a keyboard and a phone. Make them images only if that decision changes.
- The Kit hero weapon, list weapon pictures, info-panel gun icon, reward crate thumbnail, shop item renders, scissors currency
  and price pills, the nameplate level shield, and the Missions/Contracts header art. All are Tacticals' own.
- Already close enough: the blue-button eye / arrow, padlock, play triangle, white trophy, Robux hexagon, the lime "+" button,
  the stopwatch (`play.stopwatch` exists; the missing "Offer ends" pill is layout).
