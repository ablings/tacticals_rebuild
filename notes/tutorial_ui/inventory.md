# Tutorial UI inventory (2026-10-21, Shadow PC UI session, read from match_place_ref.rbxl)

Capture sheets: `sheet_desktop.jpg` (1920x1080 game viewport, every state in order) and `sheet_tablet_4x3.jpg` (1036x775).
Captured in Studio Play with `ReplicatedStorage.StudioTutorialServer = true` (Studio-only, not saved), steps advanced by firing
`Events.Tutorial.Progress(waitFor)` from the client; the Instructor ended from the server. Real-screen grabs (CopyFromScreen),
so BillboardGuis (COVER tags, the Instructor's bubble) are in.

## Where it lives (none of it is in the repo: the place only)
| Piece | Path | Size |
|---|---|---|
| Client UI + input lock | `StarterPlayer.StarterPlayerScripts.Client.Controllers.TutorialController` (ModuleScript) | 1190 lines |
| Server script | `ServerScriptService.ServerScripts.[Server] Init.GameManager.Managers.TutorialManager` | 1553 lines |
| Lines + tuning | `ReplicatedStorage.Modules.Shared.Config.TutorialConfig` | 211 lines |
| Loading screen with the logo slash | `ReplicatedFirst.LoadingScreen` (repo `ui/intro/LoadingScreen.lua`, UI session) | |
| Old versions (ignore) | `ServerStorage.TutorialController_BeforeRestyle`, `_TutorialV1_Reference.*`, `_PreAnimIds40.*` | |
Server start: `RoundManager.runTutorialServer()` (TeleportData.Tutorial or the Studio attribute). Starter tutorial = 1 of 3 scripted
tutorials (2 stealth and 3 "map fights for you" exist in the config/manager, keys Y / U in Studio).

## What's on screen (TutorialController.buildUI)
- **Panel** (one ScreenGui): centred at `UDim2.fromScale(0.5, 0.82)`, `fromOffset(660, 0)` wide + AutomaticSize, fill (10,10,13) at
  0.25 transparency, UIStroke white 1.5 px @ 0.86, rounded. OFFSET sizes, not Scale.
- **Portrait**: 68x68 px ImageLabel (Builderman's headshot, `Instructor = { Name = "Builderman", UserId = 156 }`) over the panel's
  left edge, (28,29,34) backing; **name tag** "BUILDERMAN" pill, BLUE (124,200,255) fill, ExtraBold dark text, 24 px tall.
- **Objective tag**: "OBJECTIVE · <UPPERCASE>" 22 px pill, BLUE text and outline; done = "✓ <TEXT>" in green (120,230,140).
- **Line**: Builder Sans Medium, (226,229,236), types out at 0.015 s / letter with a metal-click tick (pitch 2.6); `[Key]` words
  light up BLUE; CAPS words bold white; a pressed key pushes in, then turns green.
- **Fonts**: Builder Sans Medium / Bold / ExtraBold for the panel; GothamBlack (killcam stamp), GothamMedium (fade title),
  GothamBold (COVER tag) elsewhere: three families on one screen.
- **Highlight**: SelectionBox + surface tint (90,170,255) on the target cover + BillboardGui "COVER" tag 120x28 px GothamBold blue.
- **Gadget zone**: a Neon cylinder (90,170,255) @ 0.55 on the floor.
- **Instructor bubble**: "On the move!" world text (BillboardGui) over him; red outline through walls (Highlight 255,45,45).
- **Cinematic bars**: two black frames 9 % tall slide in/out (Quint 0.45 / 0.6 s) during `cinematic` steps.
- **Alert slam** (unused now: `Alerts = {}`): red headline 90 px, red full-screen flash, panel shake.
- **Killcam**: ColorCorrection to grey + blur, red GothamBlack "ELIMINATED" 520x70 stamp (Back 0.18 / 0.25 pop), 0.9 s fade back.
- **Fade**: black full-screen + GothamMedium title (0.9 s in, 1.2 s out).
- **Tweens**: panel pop Back 0.42 (UIScale), portrait Elastic 0.5, confirm Back 0.35 + green stroke fading 0.9, objective colour swap.

## Server-driven (TutorialManager `Step` payload -> client `onStep`)
`line` (key into Lines / Lines2 / Lines3, or raw text) + `args`, `waitFor` (LeftCover, EnteredCover, ReachedHighlight, Slid,
Vaulted, ... -> sets the objective tag), `allow` (control lock: Q / E / G / Aim / Shoot / Move / Vault / Crouch / Melee / Reload),
`highlight` (BasePart | false), `zone` (Vector3 | false), `focus` / `follow` / `focusTime` / `cinematic` (camera direction + bars),
`teleport`, `cutscene = "Opening"`, `runTo` / `runRoute` / `runSpeed` / `runAfter` (the scripted opening run), `openingGo`,
`fade` + `title`, `killcam`, `autoRush` / `autoVaultBack` / `autoLight` (demos), `stepOut`, `enterCover`, `reloadLocked`, `finished`.
Client -> server: `Progress(eventName)`; `Start(n)`.
Text: all lines are in TutorialConfig (`Lines`, plus `Touch` versions for touch players). Timing: TypeSpeed 0.015, ConfirmBeat 0.7,
ReadPad 1.3, ReadPerChar 0.014, ReadyHold 4.

## Starter tutorial, in order (desktop sheet)
Loading (logo) -> logo slash + shatter -> opening run to the pillar (cinematic) -> Welcome -> LEAVE COVER [Q] -> TAKE COVER [Q]
(pillar outlined, COVER tag) -> REACH THE HIGHLIGHTED COVER [E] (crate) -> SLIDE [Shift]+[C] ("On the move!") -> REACH THE
HIGHLIGHTED COVER [E] (wall) -> VAULT THE WALL [Space] -> "Now get him!" aim + shoot (no objective tag) -> killcam ELIMINATED
+ "Got him! You know the basics now." -> "Taking you to the lobby..." -> panel gone, teleport.

## My one-line take
The most "AI" thing is the panel itself: a wide grey glass card of full sentences with a blue pill label and a floating portrait,
which reads like a chat assistant overlaid on a shooter, in a different blue and different fonts from every other screen of ours,
instead of a short game-style prompt ([Q] TAKE COVER) that lives where the action is.
