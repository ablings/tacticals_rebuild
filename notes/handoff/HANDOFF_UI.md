# Tacticals UI handoff (latest: 2026-10-22, main PC UI session took over from the Shadow PC)

## 2026-10-22 day (Edward: "do 1 and 2; 3 and 4 if RIVALS does it; scissors economy")
- UI shipped (deployed + saved, nothing published): d215ad9 in-match Daily Missions (MatchTasksUI), 58d2975 Shop daily free reward,
  0bd6400 Missions 7-day login row, 36cb2d2 Rubik instead of Oswald, 7f3b85b 4:3 tablets (HUD on the edges), Switch Weapons slim.
- **Waiting on the lead (server), spec sent:** MatchQuests (+ QuestTick) in the match place; DailyFreeAt + ClaimDailyFree; LoginDay /
  LoginClaimed + ReplicatedStorage LoginRewards. Each UI piece hides until its attribute exists.
- Economy proposal for Edward: `notes/economy/scissors_economy.md` (no config changed).

## 2026-10-22 night 1 (Edward asleep: juggle live RIVALS / Kuroko's copy + sub-agent grading, until he says wrap up)
- Sources: a live RIVALS 1v1 recorded end to end (`notes/ui_rivals/night1/rv_match/`, results_full.jpg), Kuroko 16:9 refs
  (`night1/kuroko169/`), ours (`night1/ours`, `ours169` = cropped to the 16:9 canvas, `ours_match`). Sub-agent grades are
  summarised in the vault (Lobby UI Kit.md, night 1).
- Shipped (deployed + saved in both copies, nothing published):
  - ff05fbb: **Play X stuck-screen fix**. The legacy InterfaceController hid the parent frame of any button named "Close"; kit
    buttons are now tagged Nonapplicable.
  - 57eb42e: results are a RIVALS SCENE (winner posed, title plate, name plate, stat tiles), and To Hub | Play | Rematch sit in one
    row at the play row; the results close when you arrive back in the lobby.
  - 447f963: loadout blurred, no tabs / team boxes, row centred; ROUND card lower and smaller; kill feed under the gear.
  - 33e1030: team boxes as wide as the team. 213a1fa: Shop X in the tab row.
- **For the lead (server):** in a 1v1 your death ends the round and no `SpectateTarget` / `SpectateReason = "Killer"` is set, so
  the killer card (DuelHUD `RV.kcard`, which works) never shows. RIVALS keeps the killer card up through ROUND LOST while it spectates
  the killer, and at match end replays the final kill with a Skip button (bottom right) before the results.
- Later in the night: 398f9b6 map vote like RIVALS (one big row, green striped strips, the winner glides to the middle); a434ef8
  Shop tabs with More / Back rows and no title, dark-gold Ranked tile, Kit Career card up, Settings pane (Parent fix in 15b15fc);
  4004496 profile shows Level + Streak; f69bf6c a shared party column bottom left on Play / Missions / Codes / profile.
  Killer card: it works. The lead confirmed SpectateTarget is set; my screenshots were just ~3 s late (no change).
  Before / after sheet: `notes/overnight_ui_2026-10-22.jpg`.
- **Open, need Edward / the server** (from the last grader pass; e75c2b6 did its results item):
  1. RIVALS keeps the Daily Tasks panel on screen during matches (left, y 37-61 %), ticking on kills. Ours shows it only in the
     lobby. Needs mission progress in the match place (server).
  2. The Shop "Claim your FREE reward now!" hook and FREE tiles need a daily free grant (server). The UI is ready
     (`DAILY_TIP_PREVIEW` / freeDailyUp).
  3. HUD clutter vs RIVALS: the permanent top-left "Leave" (RIVALS keeps leave in the menu), the big Switch Weapons bar, and the 44 px
     hint strip. All were built to Edward's earlier asks, so they're his call.
  4. RIVALS' bright green menu glow is the Halloween season theme: ignored, per Edward.
- Not done (Edward's earlier calls kept): hotbar frames and the hint strip, the bone health bar, "First to 5" / ROUND N under the
  timer, the Codes dock button.

## 2026-10-22: main PC capture pass (sheet notes/ui_rivals/mainpc1/sheet_a.jpg, single captures beside it)
- Captured and compared with RIVALS: hub, Shop, Missions, Settings, Play, Kit, player menu, profile card.
- **Fixed:** profile card Most Played renders now fill the tile and break out of its top like profile_card.png
  (PlayerCards `fill`). Deployed to the lobby (53 files), lobby saved.
- **Match RIVALS, no change needed:** Shop tab row (100 px tabs, 5.2% of the width, same as RIVALS; the icons are not small),
  Play grid proportions, Kit gun size, nameplate (seal, name, Premium, device), player menu.
- **2026-10-22 later (Edward: "replace everything you can besides scissors", "use rivals level icons"):** RIVALS live check: one
  blue starburst seal at every level (36 and 176 look the same), which we already use. The thin cream line icons get RIVALS-style solid
  chunky white glyphs: `ui/art/rivals/_upload_glyphs/` (flame, trophy, level, eye, news, inbox, play, rank, headshot). They're
  wired through `Kit.GLYPH` / `Kit.glyph(name, fallback)`: hub board tabs, the corner list's mode icon, News / Inbox buttons, Missions
  Wins / Matches / Headshots (Headshots no longer reuses the claw). **Edward: upload the 9 PNGs under Gunsy Funsy, then fill
  the ids into `Kit.GLYPH`** (empty = the old icon). The board's Elims tab already uses the uploaded claw.
  The scissors currency art is kept, as asked. Not replaced, because they already match RIVALS: device icons, streak flame,
  level seal, kill-feed weapon silhouettes.
  Studio note: Studio's renderer went all white after the RIVALS player ran next to it; saving and reopening Studio fixed it.
- **Open:**
  1. Missions: Headshots shows the same claw glyph as Eliminations (hub panel + Missions screen). It needs a codex
     `tasks_headshot` glyph; upload under Gunsy Funsy (Edward).
  2. Kit: a cream rectangle under the slot strip is the world's `LobbyMap.Showroom.Rooms4.SR_Lines.SR_Lines__neon_cream`
     floor line seen through the camera, not UI (also in port3/kit.png). It's world art, so it's the lead's or Edward's call.
  3. Play: the Training / Duel Pads tiles look washed lavender next to the 1v1-3v3 art (RIVALS' bottom row keeps full colour).
  4. Not captured yet: the hub board's auto-scroll to #10, the killer card / match boxes with the seal (match place), Shop
     placeholder tabs' "Coming soon".

## Start here (2026-10-21 night): Shadow PC stops UI edits here
- `git pull` in tacticals_rebuild (last UI commit: see `git log`, message "RIVALS 1:1 levels/banners/profile, leaderboards, Shop
  organisation"). Both working copies (Tacticals_rebuild.rbxl, match_place_ref.rbxl) were saved with everything deployed
  (lobby 53 files, match 65 files); play lock released.
- **Publish:** port 32 is the last publish. NOT published yet (lead, on Edward's go): f641ec6 (44 RIVALS images wired), f08b149
  (port3), c8e0405 (live captures/notes only), and tonight's commit.
- **Assets.gen wiring** (the 44 RIVALS images, gunsy funsy): DONE in Kit, Missions, Settings + Hotkeys, Shop, Play, close X
  (f641ec6 + f08b149). Nothing half-done there.
- **Done since port 32:**
  1. Images wired (above); Play = RIVALS normal layout (tall Ranked right, shield, "Unranked"); Kit click-to-equip (no Equipped row,
     no check), dimmed room, gunmetal showcase; one close X size (`Kit.CLOSE_W/H`); dark purple menu backdrop + vignette (UITheme).
  2. Join-queue bubble only for accounts below level 5 (LobbyHudController `wantJoin`), like RIVALS.
  3. **Levels** (ui/lobby/Kit.lua): one RIVALS blue starburst seal for every level (`Kit.levelSeal`, `Kit.setLevel`; `Kit.levelTier`
     returns the seal, so DuelHUD killer card + MatchFlow boxes show it too). Old shields kept as `Kit.LEVEL_TIERS_SHIELD`.
  4. **Nameplates** (NameplatesController): seal, name (Rubik Bold, black outline), device icon; 10 x 1.6 studs; streak flame still
     replaces the seal.
  5. **Player menu + profile** (PlayerCards): RIVALS rows (green Invite/Add Friend, orange Challenge, blue Profile/Avatar, red
     Block, hovered row white). Profile = rivals_normal/profile_card.png: wins / win rate left, name + device, seal + "Level",
     "Most Played Weapons" 4 tiles. ELO / Rank / Career tiles removed from the card (RIVALS shows none; data untouched).
  6. **Leaderboards**: hub board (LeaderboardScreen) rebuilt as RIVALS (red title, LIVE pill, #1 hero row, rows #2-#10 that
     auto-scroll, 4 icon tabs, cycle Streaks > Elims > Wins > Level). Corner player list: rows updated in place, own badge
     (Premium else level seal), no stripes.
  7. **Shop** (ShopScreen): RIVALS tab order Home, Bundles, Arms, Skins, Daily, Emotes, Charms, Finishers, Scissors (=Keys).
     Skins / Daily / Emotes / Charms / Finishers are **placeholders** (`PLACEHOLDER_ITEMS`, each `PLACEHOLDER = true`): a click
     shows "Coming soon", never a purchase. Real purchases unchanged. Plug-in steps in `notes/ui_rivals/10_round3.md`.
- **Verified in Studio (Play, lobby):** no script errors; nameplate, board (51 labels), Shop tabs, and the profile card all built
  (`PlayerCards.Profile(lp)` showed wins / Level / Most Played Weapons). **Not verified by eye:** none of tonight's screens
  were screenshotted. First job: capture + compare vs RIVALS (Shop tab row fit beside the X and wallet with 9 tabs, the tab image icons,
  rarity tint on the weapon renders, the seal number at nameplate distance, the board's auto-scroll reaching #10, the level seal size in
  the player list, the weapon renders in the 72 px profile tiles, the backdrop clearing on profile close, the killer card + match boxes with the seal).
- **Images that may read off in place:** Shop tab icons look small (from port3); `Assets.hud.levelbadge` is the replica's seal
  (falls back to gen.kit_reward_seal + gradient).
- **Open questions for Edward:**
  - Should other players' profiles show real weapons? That needs the server to publish a `MostPlayed` attribute (PublicStats.server.lua; not done).
  - Should the level seal also replace the shields in the match (killer card / boxes)? It does now.
  - Daily reset time: midnight UTC is a guess.
  - Should the "Claim your FREE reward" Daily callout stay hidden until a real free item exists (`DAILY_TIP_PREVIEW`)?
- **Still open from before:** a duplicate "Item Unlocked" banner per bundle item (server, lead); the Missions Day 1-7 streak row (no
  data); hub TVs / tickers (Studio-only sources).
- **Lessons (to vault into Lobby UI Kit.md, which isn't in the Shadow PC's vault copy):**
  - Grade by putting each screen next to RIVALS' own and listing the differences. Icons / colour scheme are preference.
  - Copy RIVALS' layout when unsure: no thin underlines, lips or accent bars.
  - Codex-generated 1:1 images (empty-slot X, seals, close X) beat hand-built glyphs.
  - Placeholders get a PLACEHOLDER flag and a "Coming soon" click that can never prompt a purchase.
  - Kill TextInputHost before tools/save_studio.ps1 (it steals the foreground and the save refuses).


## Start here (2026-10-21 evening)
- `git pull` in tacticals_rebuild (last UI commit 5f720a7). Both working copies (Tacticals_rebuild.rbxl lobby, match_place_ref.rbxl)
  were saved with everything below deployed; the play lock is released.
- **Live as port 32** (published by the lead, 2026-10-21 evening, all four places checked). The UI session stays on the Shadow PC.
- **What changed since port 30** (details + RIVALS frame refs in `notes/ui_rivals/00_plan.md`, `09_cleanup.md`, `10_round3.md`,
  live-play notes in `rivals_live_notes.md`, imagery rules in `imagery_balance.md`; sheets `notes/ui_rivals/sheet_*.jpg`):
  1. RIVALS three-qualities pass (interactability / cleanliness / kid-friendly), rounds 1-3 over every screen: shared motion helpers
     in `ui/lobby/Kit.lua` (countTo, fillTo, pop, popIn, breathe, pulse, shake, busy), hover/press on everything.
  2. AI-UI tells removed everywhere: fonts are now **Oswald Bold headings + Rubik body** (no Gotham/Montserrat/Builder Sans), no
     UICorner + thin UIStroke hairline cards, no left accent bars. Close buttons are RIVALS' red X (Kit/SettingsKit.closeButton).
  3. Edward's Q1-Q3: yellow #FFD400 only for #1; Ranked dark gold; no corner brackets. Field green #8DBF5A -> #4C7A2E for done/primary.
  4. Imagery = "whatever RIVALS does": flat icons only where RIVALS uses flat glyphs (Missions task icons, price scissors; 13 icons in
     Kit.ICONS, uploaded to Gunsy Funsy); everywhere RIVALS uses a posed render we show a live 3D placeholder (Shop bundles, Play
     mode cards, rewards, Kit crate). The dock + Settings tabs are back to 3D icons.
  5. Kit: none-glyph empty cosmetic slots, cosmetic picker (None + rarity tiles + BACK), denser right panel, readable locked rows.
  6. **Missions auto-pay** (lead's [AUTOPAY] server change): no CLAIM button; done = full green bar + check + PAID, pops live; the
     "Task Completed" banner comes from RichNotify. The nav "Claim your reward!" callout is hidden.
  7. **Hub leaderboard board** (`ui/pseudolobby/hub/LeaderboardScreen.lua`, now in deploy_ui.py): Wins / Elims / Streak / Level tabs
     from the lead's LobbyTop* StringValues, auto-cycles 8 s, #1 hero row, own row green.
- **Not verified by hand** (Studio clicks weren't granted): the Kit cosmetic picker and hover states. Tutorial got only the PLAY
  restyle; no fresh tutorial run this evening.
- **Next for UI:** the TVs / tickers / labels in the hub (Studio-only sources: LobbyScreensController, Tickers, Labels) with
  Kit.ICONS eye / live / thumbsup; the own nameplate still shows over the Kit character view; LobbyUITestHook "Close" only closes
  the legacy panel (newer screens need their own close for captures); Missions nav badge can show ~3 s before auto-pay lands.
- Roblox Player is installed on the Shadow PC (used to study RIVALS live; never pay Robux prompts).

---

# Earlier state (port 30, 2026-10-21 midday, from the main PC UI session)

## Get the project
```
git clone https://github.com/ablings/<private repo>.git "%USERPROFILE%\Documents\tacticals_rebuild"
```
(If the folder already exists there: `git pull` instead.) `rivals_practice` is on GitHub too (`git pull`); it holds `mcpcli.py`
(Studio MCP bridge client). Read `CLAUDE.md` in tacticals_rebuild, the lead's `notes/handoff/HANDOFF_LEAD.md`, and the vault pages
`wiki/tacticals/Lobby UI Kit.md` (everything below is written up there, with lessons) + `wiki/log.md`.

## State: everything is LIVE (port 30, published by the lead on Edward's go)
Nothing of the UI session is pending deploy or publish. What shipped across ports 28-30:
- **Look**: "the RIVALS mix" = RIVALS layout and shapes, filled with muted team colours (tan = us, dark green = them), Montserrat Heavy
  + Builder Sans, hairline edges, no comic ink. (Superseded 10-21 evening: Oswald + Rubik, no hairlines.) Field-green primary buttons (#8DBF5A -> #4C7A2E) in the lobby. Intro / pads olive.
  The in-match HUD was tested over pure white / black / green backdrops for readability (hint strip on a dark pill, darker tiles).
- **Match HUD**: content-sized kill-feed pills, ROUND WON/LOST card + MATCH POINT, round fade, kill-type line, RIVALS health bar
  (bottom left, bone -> amber -> red), killer card, Switch Weapons from the countdown until KitLocked (lead), Settings gear (D-pad up),
  RIVALS dashed gadget throw tracer (rarely visible now: THROWNOW throws on tap).
- **Results**: 3D clone of your character, Eliminations / Deaths / Assists / Damage Dealt / Damage Taken / Headshots (lead's fields).
- **Names**: Roblox verified / Premium glyphs (UIKit.Badges; Settings > Game > Display Badges), device icons (lead's Device
  attribute; console = controller icon), ONE icon left of the name: streak flame > rank emblem (Rank mode) > tiered level shield.
- **Kit**: the real item model in the world (not a ViewportFrame), DOF blur; locked items flat black Neon and can't be turned /
  zoomed / inspected; panels fit width on narrow screens.
- **Lobby alive**: PLAY shine sweep, Missions claim callout, nav badge pop, button hover sheen, Shop gear art breaks out of its card
  and tilts on hover.
- **Loading screens**: the TACTICALS logo (UIKit.Logo) on match-found / deploy / match loading / teleport; logo frame teal-fixed.
- Uploaded art (Gunsy Funsy group) and their image ids are in `ui/lobby/Kit.lua` (LEVEL_TIERS, ICONS.streakColor),
  `ui/hud/Badges.lua` (DEVICE), `ui/match/KillIcons.lua`, `ui/lobby/Logo.lua`. Sources under `ui/art/*/_upload`.

## Open items (need Edward's call)
1. **4:3 tablets**: every screen is built on Kit.canvas = a centred 16:9 aspect lock, so on 4:3 the whole HUD sits small in a middle
   band (lobby and match). Fix = anchor HUD groups to the screen edges instead. Design decision; not started.
   Same on tablets: the lead's tutorial "OBJECTIVE · LEAVE COVER" box overlaps the hotbar + Switch Weapons during the real tutorial.
2. Lobby "alive" leftovers from the RIVALS study: a scrolling reward strip on pass / bundle cards on hover (not done).
3. The ;duelsolo results card Edward once saw skipped could not be reproduced in Studio (it showed ~10 s). Watch it live.

## Working with Studio here
- Studio ids change on every reopen: `list_roblox_studios`, then point your test json files at the new ids.
- Deploy: check live == repo first, then `python ui/deploy_ui.py <lobby id>` / `python ui/deploy_ui.py <match id> --match`
  (`--skip=Parent.Name` leaves someone else's live script alone).
- Play lock: run `python tools/play_lock.py take ui` as ITS OWN command and continue only if it prints "taken by ui"; release after.
  Save the lobby / match with `tools/save_studio.ps1` only while holding the lock (shared with the lead).
- Bot match test: ReplicatedStorage `StudioTeleportData` = `{"Mode":"1v1","Teams":{"A":["me"],"B":["bot"]},"StudioTimes":{...}}` in
  Edit, then Play; `ServerStorage.MatchTestHook:Invoke("kill", victim, killer, headshot)` in the Server DM (task.spawn it to capture
  round-end UI). Clear the attribute after. Lobby duel: `ServerStorage.DuelTestHook:Invoke("solo", userId, "1v1")`.
- The main PC's GPU reset several times with 3+ Studios open: keep only the two working copies open.

## Rules (Edward)
Never publish yourself (the lead publishes on Edward's go in its own chat), never enter credentials, uploads only under the
Gunsy Funsy group (Edward uploads), UI in Scale only, commit only your own paths with the Co-Authored-By trailer, push after
commits, vault lessons after each finished piece of work, don't recolour screens nobody asked about.
