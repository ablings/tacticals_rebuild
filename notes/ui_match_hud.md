# Match-flow UI: what it reads and sends (UI session, 2026-10-16)

Script: `ui/match/MatchFlowUI.client.lua`, a LocalScript for StarterPlayerScripts. The **same script runs in both places**.
Screens: Loading -> MapVote -> Loadout. It hides itself for any other phase, so the in-match HUD takes over.
Lobby teleport screen (PLAY / global queue only): `ui/pads/PadUI.client.lua` shows it on MM_Status Found/Teleporting, and
hands it to `TeleportService:SetTeleportGui`.

## State object
- Match place: `ReplicatedStorage` itself.
- Lobby duels: `ReplicatedStorage.LobbyDuels[<player.DuelMatch>]`. Any Instance works (Folder / Configuration).
  The player attribute `DuelMatch` selects it; unset = match-place mode.

| Attribute on the state object | Type | Used for |
|---|---|---|
| `MatchPhase` | "Loading" / "MapVote" / "Loadout" / anything else (hidden) | which screen shows |
| `PhaseEndsAt` | number, `workspace:GetServerTimeNow()` deadline | timer (one decimal) |
| `MapList` | JSON `[{id, name, image}]` | map tiles. The UI adds a "Random" tile itself (id "Random") |
| `MapVotes` | JSON `{mapId: [userId, ...]}` | voter headshots + count per tile |
| `MapChosen` | map id | the winning tile flashes. Shown as "Map: X" on the loadout screen |

| Player attribute | Type | Used for |
|---|---|---|
| `Team` | "A" / "B" | team boxes: your team left, theirs right (up to 3 each) |
| `Level` | number | level badge on the team boxes |
| `OwnedItems` | JSON list of item ids | loadout picker options (filtered by `LobbyConfig.Items[id].Slot` when that module exists) |
| `KitWeapon` / `KitMelee` / `KitGadget` | item id | current pick per slot (the 3D cards) |
| `DuelMatch` | matchId | lobby only: which state object to read |

## Client -> server: `ReplicatedStorage.MatchFlow` (RemoteEvent)
- Match place: `FireServer("Vote", mapId)`, `FireServer("Pick", slot, itemId)` with slot = "Weapon" / "Melee" / "Gadget", `FireServer("Ready")`.
- Lobby: the same calls with **matchId first**: `FireServer(matchId, "Vote", mapId)` etc.
- The server validates ownership and sets the Kit attributes. The UI shows the pick right away and corrects itself
  when the attribute changes.

## Studio test hook
`PlayerScripts.MatchFlowTest:Invoke(phase, mapImage?)` fakes the state on the current state object (MapList / Owned / Kit defaults).

## Map art
Warehouse interior shot: `ui/art/map_warehouse.png`. Not uploaded yet (needs Edward's OK); MapList.image takes the asset id.
