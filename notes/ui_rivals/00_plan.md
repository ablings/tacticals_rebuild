# RIVALS three-qualities pass: integrator plan (2026-10-21, UI session, Shadow PC)

Edward's direction: base our UI on three qualities of RIVALS' UI: (1) interactability, (2) cleanliness, (3) kid-friendly.
Keep our own look and ignore RIVALS' Halloween colours. Audits: 01-08 in this folder; imagery: imagery_A/B → imagery_balance.md.

## Shared pieces (integrator, done first)
- **ui/lobby/Kit.lua** (UIKit.Kit) motion helpers that every screen uses instead of its own copies:
  `countTo`, `fillTo`, `pop`, `popIn`, `breathe`, `pulse`, `shake` and `busy`. Existing helpers: `bindButton`, `open` / `close`, `loadingDots`.
- **ui/matchplace/Theme.lua** colour tokens: `field`, `fieldDark`, `done`, `cream`, `tan`, `plate`. Screens move onto these instead of
  literals or the `olive` / `gold` / `amber` aliases. Today those aliases are all the comic yellow #FFD400. Edward picked
  #FFD400 as the accent on 2026-10-20, so its fate is question Q1. With tokens, it becomes a one-line change either way.

## Questions for Edward (each reverses a look choice)
- **Q1, comic yellow #FFD400 in the lobby.** Every audit found it on done / ready states, the avatar ring, the invite +, the Shop pills,
  the TVs, the prompts and the loadout's selected tab. Proposal: done = field green, labels and icons = cream, keep yellow only for #1 /
  rank-1 highlights. Or keep the yellow.
- **Q2, the violet Ranked tile and ranked strips:** move them to tan / dark green.
- **Q3, the corner-bracket hover decor (Tac.hoverBrackets)** on Shop / Missions cards: drop it, since RIVALS uses lift + glow?

## Needs the lead (server data)
- Leaderboard categories: streak / kills / level lists published like wins (scripts/pseudolobby/server/LobbyLeaderboard.lua).
- A `Short` label per quest (hub widget), and optionally "reward at weapon level X" in Config (Kit).

## Accepted changes per implementation group (each group edits only its own files)
- **A, hub + Play** (LobbyHudController, PlayRow, PlayScreen, RankedScreen):
  - nav disc lights + press squash;
  - Play tiles pop in;
  - locked Ranked → requirement card with a bar;
  - green PLAY bars on the Ranked mode cards;
  - scissors pill counts up;
  - hub Daily Missions widget: green CLAIM pill when done and tweened bars;
  - player list: keep rows by UserId, slide on reorder, own row marked, hover lift.
- **B, Shop** (ShopScreen):
  - update in place (no full rebuild per click);
  - build the pages at join behind the loading dots;
  - a detail card + busy dots before buying (replaces Confirm-in-place);
  - the wallet counts up;
  - the tab pops and the page slides;
  - the carousel slides;
  - can't afford: shake;
  - owned: cream check.
- **C, Kit** (Armory):
  - Kit.bindButton on every button;
  - price on the Unlock button, no "SURE?" click;
  - side panels slide in / out;
  - Statistics / History / tray pop in;
  - locked cosmetics: padlock + "Coming soon";
  - headings in Montserrat Heavy.
- **D, Missions / Codes / Notify:**
  - a claim moment (squash, check pop, reward pop, sound);
  - ready cards breathe + CLAIM sheen + hover lift;
  - drop the D-01 ids and the IN PROGRESS strip;
  - Codes: success pop / error shake;
  - Inbox open / close animated;
  - top-right buttons react.
- **E, match HUD + results** (DuelHUD, HUD, Hotbar / HealthBar, CombatFeedback):
  - results buttons: Play Again primary, bindButton;
  - the results card pops in, numbers count up, empty stats are hidden;
  - score bump + round-card sweep;
  - chunky spectate arrows;
  - one button behaviour.
- **F, flow + social** (MatchFlowUI, PartyScreen, PlayerCards, NameplatesController, TouchControlsController, LoadingScreen):
  - phases pop in / out;
  - party buttons 130x52 + bindButton;
  - map / loadout tiles squash and vote heads pop;
  - honest loading (dots + words);
  - timers pulse in the last 3 s;
  - player-menu rows stagger with flat icons.
- **G, in-world (deployable files)** (PadBoards, PadUI, PromptsController):
  - a cream prompt card with one big word and a bob;
  - pad boards: one card per plate, big count + headshot, in Scale;
  - delete the dead side panel.
- **H, integrator, later** (Studio-only sources, edited live then snapshotted):
  - the leaderboard board (hero row, tabs once the lead has the data, our fonts / colours);
  - the TVs / tickers / labels (palette + fonts, the Duels TV only updates the clock);
  - the remaining Settings detail.

## Cut (changes our look or follows RIVALS' Halloween styling)
- Anything that adds RIVALS' green / orange seasonal colours.
- Amber in the lobby (tutorial-only, per Edward).
- The reward "fly to pill" from audit 04 (the agent's own idea, not in RIVALS).
- The full Armory Scale migration (P3, too big for this pass; later).

## AI-UI tells pass (user, 2026-10-21): applies to everything above
Edward named the pattern people read as "AI-generated Roblox UI":
1. **Gotham / Montserrat as the font everywhere.** Roblox now draws Gotham as Montserrat.
2. **Rounded UICorner + a thin 1-2 px UIStroke border** on every panel, card and button.
3. **A thin vertical accent bar down the left edge** of an element.

Decision: headings in **Oswald Bold**, body in **Rubik**. The Phase B Montserrat switch was reverted in Theme, SettingsTheme, Tac and
MatchFoundGate; the implementation agents revert it in their own files. No new corner + hairline cards and no left bars anywhere.

Integrator follow-up (after the agents):
- Kit.closeButton / SettingsKit.closeButton: drop the hairline and use a solid plate + thick offset shadow.
- To Pads: drop the hairline.
- Missions TacBar left bars.
- The tutorial (later, per the user):
  - the amber left bar on the strip;
  - the subtitle plate;
  - Builder Sans everywhere becomes Oswald + Rubik;
  - corner + stroke on keycaps and plates.
