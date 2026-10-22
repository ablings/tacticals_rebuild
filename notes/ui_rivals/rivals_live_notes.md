# RIVALS live session notes (2026-10-21, UI session on the Shadow PC, Roblox Player)

Played live with the user's OK. Only menus were opened. No purchases, no chat. One Robux dialog was opened to look at it and closed with the X.

## Joining
New accounts land in RIVALS' **tutorial**: a bot duel, then a teleport to the lobby.
Roblox UI note: a click only registers after the mouse has *moved onto* the button (hover first).

## Lobby hub
- **PLAY on hover:** grows about 10% and brightens.
- **Nav items** (Weapons / Tasks / Settings), 3D posed icons on dark discs:
  - On hover the icon grows and lifts, and a white speech-bubble tip appears above it ("weapons, career, emotes, & more").
  - The red count badge sits on Tasks.
- **Other players:** hovering one shows a big floating nameplate (level shield + name + device glyph) and "Double tap to view profile".

## Weapons (Kit)
- **Opening:** the screen cuts to black for about 0.3 s, then shows the room with the big 3D gun.
- **Left list:** the selected weapon gets a lighter band, white bold text and its render popping out to the right.
- **Bottom strip:**
  - Leave is a red X.
  - Empty Skin / Wrap / Charm / Finisher slots are grey rounded squares with a diagonal slash: the "none" glyph.
- **Skin picker:** clicking a slot replaces the strip with:
  - a red "↶ Back" button, a wide search bar and a "Favorited" checkbox;
  - a row of square tiles filled with their rarity colour, each a dark silhouette render with a white padlock and the name;
  - a first "None" tile with a big green check.
- **Right panel** (about the same density as ours):
  - name + checkbox, and 2 bullet lines;
  - the level bar;
  - "Level up now!" with a yellow key-price button;
  - "Reward at Level 5" with a posed key ×1;
  - Contracts / Overview / Statistics rows with big blue icon buttons.

## Tasks
- **Opening:** fully open within 0.2 s over a blurred backdrop. Red X outside the panel, top right.
- **Panel:** "Beginner Tasks [1 / 3]" with a blue "To Shooting Range" header button. Each of the 3 tiles has a flat white glyph, a
  progress bar, "x / y" under it and a posed key ×1. Hovering a tile enlarges its title.
- **Completing a task:** it pays out by itself, with no CLAIM click. A dark pill banner drops at top centre with a big green check,
  "Task Completed / You've earned ×1 Key!" and the key render. A compact task tracker list sits on the left of the HUD: the done row
  is ticked green with a full bar.

## Shop
- **Opening** (the + beside the currency): three white loading dots for about 0.2 s, then the shop. The data is preloaded.
- **Tabs:** posed 3D icons above the labels; the selected tab is white. A red callout pill above Daily says "Claim your FREE reward now!".
- **Keys tab:** big cards with a huge cropped key render behind, a big "+10" and a green Robux price button.
  Hovering a card swaps the "+10" for the key icon "×10", showing what you get, and the card brightens.
- **Home tab:** crates and items are posed renders over coloured tiles with price buttons, plus a big Season Pass card with an eye
  button and a Special Offer strip.
- **Buying:** the Robux price button opens Roblox's own "Buy Robux and item" dialog (closed without buying).

## Match HUD (tutorial duel)
- **Top centre:** a team score box with avatars + a big score, a dark timer box, and the enemy score box.
- **Bottom right:** the weapon name big, then the hotbar tiles with 3D items and a key hint strip (Scoreboard Tab, Quick Melee F, Quick Utility G).
- **Health:** a green bar bottom left with the number.

## Second live session (2026-10-21 evening): beginner matches, results, the real Play screen
- **New account: Play doesn't open a menu.** It queues straight into "Beginner 2v2". A dark pill drops at top centre
  ("Searching for players... / Beginner 2v2", a clock and a red X) and PLAY hides. The full Play screen unlocks after the beginner
  matches (3 played here). The Ranked card we compared before (t0287) is the Ranked *podium's* requirement list, not this screen.
- **Hover bubbles:** plain white pills, dark text, no border ("Join the queue to start playing!", "View your weapons, career, emotes, &
  more"). The PLAY bubble is shown at rest for new players; nav bubbles appear immediately.
- **Done task (Tasks panel):** green title, full green bar with the green check sitting ON the bar, the icon unchanged, no extra label.
- **Match HUD:**
  - team score boxes with avatars, a dark timer box (counts tenths in the last seconds);
  - a compact green "ROUND WON" pill under the score;
  - dead players' portraits turn to skulls; a kill-feed pill top right;
  - a killer card bottom right ("X eliminated you with Assault Rifle") while it spectates the killer;
  - an eye + count bottom left when someone spectates you.
- **Match end:**
  - a close-up of the winner with a "Skip" button;
  - then the results: a team banner ("VICTORY / team"), the winner(s) posed with a name bar and 5 stats;
  - white chunky buttons Rematch (greyed) / Play Again / Leave at the right.
- **Teleport:** three big white dots in the middle, a mascot with a tip bubble bottom left, "Teleporting 0" bottom right.
- **Full lobby (after beginners):**
  - a red "To Hub" button left of Play;
  - the Shop nav with a red "Claim your FREE reward now!" callout;
  - a "Complete your tasks for keys!" bubble on the currency;
  - a tasks widget with a blue "To Shooting Range" button.
- **The real Play screen** (opens in <0.25 s, blurred lobby behind, red X just outside the top-right corner):
  - **Mode grid:** a tall hero tile "Beginner 2v2" on the left, then 1v1 / 2v2 / 3v3 on top and 4v4 / 5v5 below.
  - **Tiles:** every tile is a full-bleed picture (gameplay shot: a gun + red enemies) with one huge white bold title centred. No
    PLAY strips, no "searching" counts, no extra words. The tile is the button. Hover: the tile brightens and gets a white outline.
  - **Below, one scrolling column of sections:**
    - each section header is a dark pill with an icon + title ("Here for a limited time only!" with a row of item icons, "New
      gamemodes in 23h 51m 57s", "Try out these fun, classic gamemodes" with an i);
    - event and arcade tiles are wide pictures with a huge title + one subtitle line ("Gargoyle Tower / There's.. more?", "Team
      Deathmatch / The team with the most points wins!"), a small shield glyph bottom left, an "Arcade Server" white tag top right,
      and a "SOLO" tile beside some.

## Normal-theme reference (2026-10-21, user-suggested RIVALS copies with the default UI, not Halloween)
Captures in `notes/ui_rivals/rivals_normal/`. The first set is from "MOD RIVALS FREE KEYS AND SECRET PANEL" (place 89748640089814); the user
says it's basically 1:1 with RIVALS' default UI. The picker set is from "Kuroko's Rivals MODDED" (94211550075897, free unlocks).
Prices there read "Free": use them for layout only. No buy prompts were opened.
- **Play** (`play.png`): 1v1 / 2v2 / 3v3 on the top row, 4v4 / 5v5 below, and a TALL Ranked tile on the RIGHT ("Ranked / Season 3",
  a big gun render, "Unranked 0 / 10" with the shield glyph). Red X outside the top right. The normal theme has no Beginner hero tile;
  that was the new-account version.
- **Weapons** (`weapons.png`): career card top left with five category icons; list with the selected weapon big, left-aligned, its
  render popping out. Right panel: name + checkbox, 2 bullets, blue level bar with the big level number, "Level up now!" + yellow
  key price, "Reward at Level 5" + render, then Contracts / Overview / Statistics with blue square buttons (NO Equipped row).
  Bottom: Leave (red X) + Skin / Wrap / Charm / Finisher "none" slots.
- **Slot hover:** bubble "Change how this weapon looks".
- **Picker** (`kuroko_picker.png`):
  - top row: red "↶ Back", a wide "Search by name or tooltip" bar, "Favorited" + checkbox on the right;
  - tiles: None (black with a big green check) then rarity tiles (purple / red / teal / green / orange) with a white padlock and
    the skin name at the bottom.
- **Clicking a locked skin** (`kuroko_preview.png`): it previews ON the hero gun at once. A top-centre pill shows the skin icon + name
  ("AKEY-47"), and a white pill under it says how to get it ("Used to be included in the Legendary Key Bundle"). The None tile keeps
  its check (still equipped).
- **Tasks** (`tasks.png`):
  - Daily Tasks with the blue "To Duels" button;
  - 3 tiles with white glyphs, grey bars, "0 / 5" and key rewards;
  - a Day 1-7 streak row (Day 1 circled, gift renders between);
  - then Contracts "sorted by Near Completion" with weapon-icon rows.
- **Shop** (`shop.png`):
  - tabs with 3D icons (Home white selected, Exclusive, Bundles, Skins, Emotes, Charms, Finishers, Events, Keys, Admin, More);
  - crate renders with price buttons;
  - the Season Pass card with the blue eye button;
  - rarity tiles with a dark corner weapon tag and price buttons.
- **Settings** (`settings.png`): Audio tab: rows with ▲▼ + value box + slider, sub-rows indented, toggles = white pill with a black
  knob (off), right pane = icon + big title + description, preset rail 1/2/3/↓.

## Profile, player menu, level badge, news (2026-10-21, live RIVALS, Halloween period)
- **Player menu** (click a name in the top-right list): a dark card with headshot, display name, @user, then two rows "View Profile" /
  "View Avatar". The hovered row is white with a black arrow; the other is dark with a white arrow on a blue end.
- **Profile card** (`rivals_normal/profile_card.png`):
  - left column: avatar headshot, gold trophy, "0 wins", "0% win rate";
  - right: name + device icon, @user, a centred **blue starburst level badge** with a white number and grey "Level" under it;
  - "Most Played Weapons": 4 dark tiles with weapon renders + names;
  - red X under the card; blurred backdrop.
- **Level badge** (nameplates, list, profile): a blue starburst seal (light-blue to blue gradient) with a white bold number.
  Nameplates show it left of the name, then the device icon. A win-streak flame replaces it on players with a streak.
- **News panel** (`rivals_normal/news_panel.png`): opens on join after an update. A big banner image, "UPDATE 24" tag, then rich-text
  patch notes in one scrolling column; a red X and a blue arrow button stacked top-right outside the panel.
- **Proximity prompt:** a white card with a black "Q" key tile, a small title ("Spooky Event") over a big bold verb ("View"), and a
  pointer under it.
- **"Complete your tasks for keys!"** bubble sits under the currency pill for new players. "Join the queue to start playing!" over Play
  only shows for low-level accounts (until ~level 5, user).
