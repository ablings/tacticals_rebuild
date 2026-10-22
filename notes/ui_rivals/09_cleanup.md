# UI AI-tells cleanup (2026-10-21)

## AI-tells cleanup (Shop)
File: `ui/shop/ShopScreen.lua`
- Fonts swapped: 0. The file already uses only Theme.font tokens (F.display = Oswald Bold, F.bold / F.medium = Rubik); no Gotham / Montserrat / Builder Sans / SourceSans.
- Strokes removed (8, all thin <= 2): price tag 1.5 border (and its colour / transparency swap in update()); gear item card 1 px rarity border (the 6 px top RarityStripe stays); bundle card 1 px border; bundle item tiles 1.5 rarity stroke; Featured offer bundle tiles 2 px rarity stroke; Featured gear tiles 2 px rarity edge; scissor pack card 2 px border (top AccentStripe stays); pass card 2 px owned / not-owned stroke.
- Replacements: bundle tiles + offer tiles got a bottom RarityBar (5-6 px); Featured gear tiles' RarityBar grown from 70x5 to 94x8; pass cards got a 6 px bottom StateBar (field green = owned, faint cream = to buy). OWNED label on bundle tiles raised to ZIndex 3 so it draws over the new bar.
- Strokes kept: `outlined()` text strokes (Contextual, around letters); spotlight `holeStroke` (Thickness 4000 when active: it is the spotlight dimmer, not a border).
- Left bars removed: 1 (bundle card AccentBar, 8 px at x=0; it was only decoration, the bundle colour stays in the diagonal stripe).
- Colours: bundle tag pill C.amber -> C.cream; bundle default colour C.amber -> C.cream; OWNED label C.amber -> C.cream; scrollbar C.olive -> C.field (same value, now explicit). No #FFD400 / violet literals in the file.
- Skipped: Kit.closeButton in the detail card and the shop frame (integrator restyles it); Tac.hoverBrackets corner brackets (not a border or left bar).

## AI-tells cleanup (Kit / Armory)
**ui/lobby/Armory.lua**
- Fonts swapped: 3 constant definitions + 2 inline. FONT_HEAVY (labels, buttons, numbers, ~35 uses) Builder Sans ExtraBold -> Oswald Bold; FONT (text() default) Builder Sans Bold -> Rubik Bold; FONT_MED (body/small, ~15 uses) Builder Sans Medium -> Rubik Medium. Transition overlay "A-07"/"TAC" door tags and "ARMORY" title: Enum.Font.GothamBlack -> FontFace = FONT_TITLE (Oswald Bold). FONT_TITLE was already Oswald. No new locals.
- Strokes removed: 2. Favourite box 2.5 px white border (unticked state is now a solid white fill at 0.75 transparency so the box stays visible; ticked stays solid white); Ability/Perk box 1 px green border (tinted fill alone).
- Strokes kept: cosmetic tray circles' 3 px white ring (only on the Default/equipped circle = selection) and bottom-strip slotRings 3 px (open-tray slot = selection); text shade() / row name strokes (around letters); glyph-drawing strokes (padlock shackle, eye, lens/none/finisher rings, LEAVE X edge: they are the icon shapes, not borders); ARMORY title 3 px text stroke; the 4->1 px pulse ring tween (a one-shot effect).
- Left bars removed: 0 (none found; the tape CutEdge 4 px frame is a cut animation edge, not a panel accent).
- Colours: HAZARD_Y blast-door stripe literal 255,212,0 -> cream 236,230,210. No violet literals. Accent colours come from ctx.THEME (central).
- Skipped: nothing else in scope.

## AI-tells cleanup (tutorial)
File: `ui/tutorial/TutorialController.lua`
- Fonts swapped: the 3 Builder Sans constants (F_HEAVY / F_BOLD / F_BODY) replaced. F_HEAVY + F_BODY = Oswald Bold (17 + 1 uses: callsign, strip words, keycap glyphs + check, count "3/7", plus sign, alert headline, fade title, TRAINING COMPLETE, skill names, ticks, PLAY label, world chevrons). F_BOLD = Rubik SemiBold (radio subtitle line, strip sub line, "YOU LEARNED"); the verb captions under the keys (HOLD / AIM / LOOK) moved from F_HEAVY to Rubik as small captions.
- Strokes removed: the strip's edge stroke (1 px, invisible, kept "for a done flash" that nothing used); the keycap mouse outline (2 px) -> the mouse body is now a solid grey (190,188,180) shape on the cream face; the subtitle plate's alert ring no longer tweens down to a 1.5 px edge (it stays 3 px and fades out).
- Strokes kept: text outlines on the subtitle line, alert headline, PLAY label (the PLAY button itself has no stroke), enemy chevron and world-keycap chevron (Contextual, around letters); the reticle glyph's ring raised 2.5 -> 3 (it is the icon, not a border); the floor zone ring (9 px, thick).
- Left bars removed: 1 (strip.accent, 0.012-wide amber bar at x=0). Its state moved to a solid 5 design-px bar along the strip plate's BOTTOM edge (AMBER = do this, GOOD olive = done; same strip.accent field, so showStrip / stripDone are unchanged). Finish card checked: no left bar, stroke or edge left (only the stale "tan edge" comment, updated).
- Colours: none changed (tutorial keeps AMBER 232,174,69 / GOOD 127,166,80 / ALERT_RED enemy only). KeepColors tag kept. Keycap drop-shadow block kept. Behaviour untouched.

## AI-tells cleanup (Missions / Codes / Notify / Codes-adjacent)
**ui/pseudolobby/hub/MissionsScreen.lua**
- Fonts: none to swap (already Theme.font display / bold / medium = Oswald / Rubik).
- Strokes removed: 1, the panel edge `Kit.stroke(C.olive, 1, 0.8)` in panel(), plus its `Kit.corner(2)`. Kept: `Kit.textStroke` outlines on the reward count and "3 / 5" count (around letters).
- Left bars removed: 2, the 8 px TacBar down each Daily / Weekly panel and the 10 px TacBar beside the MISSIONS title. Neither marked state; the black 0.5 panel fill separates the panel.
- Colours: none changed. The done bar fill, done title, check and ReadyStripe (a top bar) use Tac.C.oliveHi, which is now field green centrally.
- Kept: Tac.brackets corner marks (not a border stroke, not covered by the rules).

**ui/lobby/CodesScreen.lua**
- Fonts: 2 constants swapped. FB Builder Sans ExtraBold -> Oswald Bold (title, code box, status, "Redeemed" heading, redeemed codes); FM Builder Sans Medium -> Rubik Medium (body line, empty-list line).
- Strokes: none removed. The `stroke()` helper only outlines the "Codes" / "Redeemed" TextLabels (Contextual text outlines), so it stays.
- Left bars: none.
- Colours: the redeemed-code rows and the success status line, #FFD400 -> field green #8DBF5A (new local DONE).

**ui/hud/Notify.lua**
- Fonts: 2 constants swapped. FX Builder Sans ExtraBold -> Oswald Bold (banner / inbox titles, counts, badge, glyphs, fold x); FB Builder Sans Bold -> Rubik SemiBold (sub lines, time chips, tooltips).
- Strokes: none removed. Kept the 2 px UIStroke on the reward count TextLabel (outline around letters).
- Left bars: none.
- Colours: the GREEN check / done colour 255,212,0 -> field green 141,191,90; the reward scissors / check icon 255,205,60 -> cream 236,230,210. Level blue and badge red unchanged.

**ui/lobby/LobbyUIController.lua** (visible bits only)
- Fonts: THEME.Title / Bold / Body went from Enum.Font.GothamBlack / GothamBold / GothamMedium to Font objects: Oswald Bold / Rubik SemiBold / Rubik Medium. All 64 `Font = THEME.x` became `FontFace = THEME.x`, a mechanical swap that also covers the hidden old panels. Style.lua's FONT_MAP no longer matches these labels, so they keep the faces set here.
- Toast: the 4 px kind-colour bar at the left edge -> a solid 4 px bar along the bottom edge (KindBar, spans the padding). The good / bad / info state still shows in its colour.
- Tooltips: built by the separate Tooltip module, not in this file, so nothing to change here.
- Skipped (hidden old panel UI, per the brief): the panelFrame TacBar (around line 1489), OLIVE 255,212,0 and VIOLET / Ranked 176,120,255 in the old deploy board, and the many thin `stroke()` borders on the old cards / tabs / queue pill / play row.

## AI-tells cleanup (pads, prompts, settings)

- **ui/pads/PadUI.client.lua**: fonts 0 swapped (already Oswald Bold / Rubik). Strokes: `brackets()` no longer adds the `_Edge` UIStroke (1.5-3 px) to any panel, slot or JOIN box (corner only; slots separate by their DEEP fill on the GUN box, team colour stays on the 4 px bar under the slots); the unused `NEUTRAL_EDGE` table was removed. Left bars: the SQUAD UP strip's 6 px accent bar removed (ranked still reads from the INVITE fill and the "RANKED" title). Colours: `VIOLET` #B078FF -> dark gold (150,116,52); ranked INVITE gradient #C9A0FF->#7A4CC0 -> (150,116,52)->(74,56,24).
- **ui/pads/PadBoards.client.lua**: fonts 0 (already Oswald). No strokes or left bars (the board's corner brackets are L-shaped corner marks, kept). Colours: `VIOLET` (176,120,255) -> (150,116,52).
- **ui/hud/PromptsController.lua**: fonts 0 (already Oswald / Rubik). No strokes / left bars. Colours: hold-bar fill (255,212,0) -> field green (141,191,90); header comment updated.
- **ui/set/SettingsScreen.lua**: no changes. Fonts come from SettingsTheme (Oswald / Rubik already); the explicit Rubik Font.new calls are fine. Kept: the crosshair-preview UIStrokes (they draw the user's crosshair outline setting, not UI borders). Tab underline left as is.
- **ui/settings/SettingsKit.lua**: fonts 0 swapped. Strokes removed: `Kit.button`'s 1.5 px border; `Kit.closeButton`'s tan 1.5 px hairline, replaced by a dark offset shadow block (Frame "Shadow", 4 design px down-right, same size / corner, behind a "Plate" frame that carries the colour + hover red; cream X kept; the TextButton itself is now a clear hit box). Toggle / stepper / dropdown / swatch / keybind had no borders. Kept: `textStroke` letter outlines (button label, image-tab label, hex box) and the 3 px colour-wheel cursor ring (selection ring, already >= 3). Left bars: the colour picker's 3 px "Accent" bar on the R / G / B boxes removed (the number keeps the channel colour). Skipped: `Enum.Font.SourceSans` in `Kit._measure` is only a GetTextSize measuring font, never drawn; changing it would change auto-size widths, so left.
- **ui/settings/SettingsData.lua**: no fonts, only a white swatch palette: not touched.
- **ui/hud/GamepadNavController.lua**: selection ring UIStroke kept (already Thickness 3). Colours: the corner ticks (255,212,0) -> cream (236,230,210).

## AI-tells cleanup (hub + Play)

**ui/hud/LobbyHudController.lua**
- Fonts swapped: 9 Builder Sans definitions/uses. Player list names went to Rubik Medium, numbers to Oswald (LB_NAME / LB_NUM). The corner hover bubble went to Rubik and the unread count to Oswald. The scissors count (PFONT), the missions title / counts / reward / TO PADS (WFONT) and the nav labels / badge counts (NAV_FONT) went to Oswald. "Claim your reward!" went to Oswald. Mission names and the nav hover tips went to Rubik SemiBold. The name-width measurement used `Enum.Font.BuilderSansBold` and now uses `Enum.Font.Arial`: Enum.Font has no Rubik, and Arial needs no yield.
- Strokes removed (3): the `brackets()` thin `_Edge` border (the Searching panel), the TO PADS 2 px field-green Border hairline, and the 1.5 px white ring on the red nav badge. Kept: the text outlines on labels (count, title, nav labels, mission texts, CLAIM).
- Left bars: none in the file (your own list row already uses a fill).
- Colours: the TO PADS secondary mark is now a solid 5 px field-green bar on the bottom edge. The done mission bar and the done 3D check went from #FFD400 to field green. The OLIVE / OLIVE_HI yellow constants are now cream. The Searching "RANKED" text went from violet #B078FF to dark gold (150,116,52). The NEUTRAL_EDGE table was removed (unused).

**ui/lobby/PlayRow.lua**
- Fonts: none to swap (it already used Theme.font.display).
- Strokes removed (4): the PLAY button's 1.5 px pale border, the avatar's 2.5 px amber/cream ring, the invite +'s 1.5 px olive ring, and the 2 px olive ring on each party head. They now sit on their solid dark discs. Kept: the PLAY text outline (Contextual).
- Colours: the "found" (match ready) gradient went from comic yellow to a brighter field-green ramp. Comments were updated (no amber).

**ui/play/PlayScreen.lua**
- Fonts swapped: HEAVY (Builder ExtraBold) became Oswald Bold and SEMI (Builder Bold) became Rubik SemiBold. That covers every tile title, strip, pill, chip and description.
- Strokes removed: the 2 px `edge()` border. The function now only adds a corner, and `plate` (the only caller) is unused. Kept: the 3 px tile hover ring (it marks hover state and is >= 3) and the text outlines in `big()` and the strip label.
- Colours: the ranked mode-tile gradient went from (78,52,112)->(20,12,34) to (110,84,38)->(38,28,12). The open Ranked tile went from (96,62,140)->(24,14,40) to the same dark gold. The ranked enemy silhouette tint went from violet (58,38,88) to dark gold (60,46,20). The T.violet chip / strip / sub-line were already dark gold through the token, so they are unchanged. The locked Ranked tile's grey (40,36,48)->(10,9,13) was left as a neutral grey.

**ui/ranked/RankedScreen.lua**
- Fonts swapped: FB / FS / FM (Builder Sans) became Oswald Bold, Rubik SemiBold and Rubik Medium.
- Strokes: none removed. Kept: the emblem badge's 3 px rank-coloured edge (a rank edge, >= 3), the 4 px searching-state card ring, and the text outlines.
- Colours: the ELO progress fill gradient went from #FFE14D to field green #8DBF5A. There were no violet literals in this file: the mode cards are olive (#3B4524 -> #14170F). The rank colours (Gold / Warlord) were kept.
- Left bars: none in any of the four files.

## AI-tells cleanup (flow + social)

- **ui/match/MatchFlowUI.client.lua**
  - Fonts: 1 swapped (FB was Builder Sans Bold, now Rubik Bold; it covers the tip bubble, the map chip, the hidden counter and the Random glyph). FX/FR were already Oswald/Rubik.
  - Strokes removed: the `ink()` 1.5 px white hairline (team boxes, timers, map tiles, slot chips, slot tabs, item tiles, Ready); the map tile's grey 1.5 px rest edge; the 2 px black edge on other voters' heads.
  - Strokes kept, all 3 px or thicker: the map-tile vote ring (3 px beige, shown only on your vote, blinks on the winner); your own voter head (3 px white); the open slot chip ring (3 px cream); the current-pick item ring (a new 6 px cream stroke, since ink no longer makes one); text outlines.
  - Colours: the open loadout tab fill and Ready changed from INK_YELLOW to field green #8DBF5A. INK_YELLOW set to exact cream #ECE6D2. The unused OLIVE/OLIVE_HI literal 255,212,0 changed to field green. Legendary rarity gold and Epic purple kept (rarity).
- **ui/hud/PartyScreen.lua**
  - Fonts: 2 swapped (F_NAME/F_SUB from Builder Sans to Rubik Bold/Medium). Button words (Invite / 1v1 / Leave / Leave Party / tabs / + Invite) moved to Oswald F_HEAD.
  - Strokes removed: the person card 1.5 px white hairline; the empty slot's 1.5 px green border. Button text outline kept.
  - Left bar removed: the olive 10x56 bar beside YOUR PARTY.
  - Skipped: Kit.closeButton's own stroke on the main close X belongs to Kit (another group). The kick X already strips it.
- **ui/hud/PlayerCards.lua**
  - Fonts: 3 swapped (F_NAME/F_SUB to Rubik Bold/Medium, F_NUM to Oswald Bold).
  - Strokes removed (6): profile card (2 px), level badge (2 px green), stat tiles (1.5), career tiles (1.5), player-menu panel (1.5), request panel (1.5), hint pill (1.5 bone). Gold-number and button text outlines kept.
  - Skipped: the profile's wins / win-rate gold #E9C46A is not the literal comic yellow and works as a medal-gold stat, so it stays.
- **ui/hud/NameplatesController.lua**
  - Fonts: 2 swapped (BOLD to Oswald Bold, MED to Rubik Medium).
  - Colours: VIP chip fill changed from yellow 255,205,80 to cream (a tag).
  - All strokes are text outlines, kept. Level / streak / rank icons untouched (art).
- **ui/touch/TouchControlsController.lua**
  - Fonts: 5 swapped (4 Builder Sans ExtraBold to Oswald Bold: glyphs/ammo, zone text, Joystick, pill buttons; the size bar name to Rubik Bold, which the +/- buttons inherit).
  - Strokes kept but thickened from 2 to 3 px: the see-through-mode button ring and the joystick's edit-mode outline (each is the only outline showing where the control is). The 3 px blue select ring and the ammo text outline are unchanged.
- **ui/intro/LoadingScreen.lua**: no changes. Fonts were already Oswald/Rubik. The only strokes are the logo badge (4 px) and the shockwave rings (logo / slash animation, left alone as asked). No left bars and no yellow.
- **ui/hud/MatchFoundGate.lua**
  - Colours: the mode subtitle changed from comic yellow 255,212,0 to cream. Font was already Oswald; the 3 px text stroke is kept.

## AI-tells cleanup (match HUD)
- **ui/match/DuelHUD.client.lua** (no new top-level locals; still at the limit)
  - Fonts: 3 swapped in place. FX Montserrat Heavy -> Oswald Bold (STENCIL = FX follows it), FB Builder Sans Bold -> Rubik SemiBold, and the kill-feed width measure `Enum.Font.BuilderSansBold` -> `GetTextBoundsAsync` in FB (it falls back to an estimate if that fails).
  - Strokes removed (hairlines): score boxes, timer box, spectate bar, the result Back / Leave / Play Again / Rematch plates, the post-match panel buttons, killer-card level ring, Switch Weapons key chip, scoreboard board. The SERIOUS calm pass now destroys any non-text stroke thinner than 3 px instead of turning it into a white hairline (it used to clamp to 2), so rows added later stay clean too.
  - Strokes kept because they show state, now 3 px: your own kill-feed pill (1.5 -> 3); the Rematch "voted" ring, now its own 3 px `VotedEdge` that only shows once you've voted (it was a hairline at rest); the 3 px gold winner-card ring (a #1 highlight, unchanged). Every text stroke is kept.
  - Left bars: the scoreboard team header (sbHeader) accent bar is gone. The header text still carries the team colour.
  - Colours: GOOD yellow -> field green (spectate / killer-card health fill, VICTORY title, ELO delta, "Rank up"); OLIVE_HI yellow -> cream (rewards line, "Your rank"); the rank tier-bar fill -> field green (inline). Kept: the amber 235,190,60 mid-health step and the warm emblem glow.
- **ui/set/HUD.lua**
  - Fonts: 2 swapped (TAKEDOWN and the item-bar labels, Builder Sans ExtraBold -> Oswald Bold).
  - Strokes removed: the 1 px edge on the Precision Rhythm pips and the 1 px edge on the Medkit / Shield bar box.
  - Strokes kept: the crosshair outline, the headshot ring (hitmarker), the Revolver / Bat / Parry rings, the reload arc and the reload / stopwatch marks. In all of these the stroke is the graphic itself (crosshair-area glyphs), not a panel border.
  - Colours: 255,205,60 gold -> field green for a filled rhythm pip, Revolver ready and Bat fully charged (GOLD keeps its name); the TAKEDOWN text -> cream.
- **ui/set/HotbarController.lua**
  - Fonts: 5 swapped. UI_FONT Builder Sans -> Rubik (FONT is SemiBold now; used by the hint labels and keycaps, and FONT_HEAVY / FONT_MED follow), STENCIL Montserrat Heavy -> Oswald Bold (keys, ammo numbers), held weapon name Builder Sans Heavy -> Oswald Bold.
  - Strokes: the tile hairline (1.5 px, 0.82) is gone at rest; the held tile shows a solid 3 px white ring (it was 2.5). Text shade strokes are kept.
  - Colours: the disabled PadGold gradient changed from yellow to cream. The kick, sweep and pop are untouched.
- **ui/set/HealthBarController.lua**
  - Fonts: 1 swapped (the number, Montserrat Heavy -> Oswald Bold).
  - Strokes kept: the bar's 3 px dark rim; the 1.5 px outlines on the number and on the cross icon (glyph outlines that fade with the number, not panel borders).
  - Colours: the bone -> amber -> red ramp is kept on purpose.
- **ui/hud/CombatFeedbackController.lua**: no changes. The damage numbers (FredokaOne with a text stroke) are weapon feel, and none of the banned fonts are used.
- **ui/set/ScopeController.lua**: no changes. No text. The lens mask, the shadow rings and the 2 px metal rim make up the scope graphic.
- **ui/set/TrainingBinsController.lua**
  - Fonts: 2 swapped. FONT_H Builder Sans ExtraBold -> Oswald Bold; FONT_B (the tab captions) -> Rubik Bold.
  - Strokes removed: the Weapons pill hairline and the red X edge.
  - Strokes kept, made thicker: the tile hover / held Edge (2.5 / 3 -> 3 / 4). The 5 px selected-tab Edge and the text strokes are unchanged.
  - Colours: OLIVE yellow (the hover edge) -> cream; AMBER 255,196,92 (the TRIAL label) -> cream.
- Not verified in Studio (no Studio this pass). The edits were checked by reading: balanced brackets, no new locals.
