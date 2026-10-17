# UI gap audit: RIVALS replica (rivals_practice/ui) vs the Tacticals port (overnight 2026-10-17)

Edward: "there are some ui elements the ui didnt add like the clicking on profiles elements and more stuff".
Source of truth for "what RIVALS has": the replica's own UI (rivals_practice/ui/*, built from live RIVALS captures),
plus live RIVALS checks where needed.

## Status legend
DONE = ported and Play-tested in the lobby copy · TODO = UI work, mine · MECH = needs a server path from the Tacticals
session first (UI hides the part until it exists) · N/A = RIVALS-only content with no Tacticals counterpart

| # | RIVALS element (replica file) | Tacticals | Status |
|---|---|---|---|
| 1 | Player menu on a player-list row: header + Party Invite / Add Friend / Challenge / View Profile / View Avatar / Send Gift / Block; Spectate for players in a duel (hud/HudController) | `UIKit.PlayerCards.Menu`, list rows clickable | DONE (Challenge / Spectate: MECH, LobbySocial) |
| 2 | Profile card "View Profile": blurred lobby, card, stats, X under it (hud/HudController) | `PlayerCards.Profile`: rank emblem + ELO, Level / Wins / Win Rate / Matches / Kills / Headshot % from PublicStats | DONE |
| 3 | World: hover a character = "Double tap to view profile", double click = card with Invite to PARTY / Challenge 1v1 (hud/HudController) | `PlayerCards.StartWorld` (raycast: your own character too) | DONE (touch tap: to verify in emulator) |
| 4 | Duel / party request popup: headshot, draining timer, X + check (hud/HudController) | none | MECH (LobbySocial "Request") then TODO |
| 5 | Party screen (+ next to your avatar): your card + 4 slots, search, All / Friends / Lobby tabs (party/PartyController) | the + by the avatar exists; no party system | MECH (parties) |
| 6 | Custom name titles (glitch / legend effects) on list, menu, card | none | TODO (cosmetic; needs a title source: shop item or admin) |
| 7 | Weapons screen: Overview / Statistics / Contracts / Career (Duel History, Map Catalog, Collection) (weapons/WeaponsController) | Armory (Kit) shows loadout only | TODO: Statistics + Duel History need per-weapon stats (MECH) |
| 8 | Season Pass screen (pass/PassController) | none (Missions instead) | N/A unless Edward wants a pass |
| 9 | Backpack (backpack/BackpackController) | Armory | covered |
| 10 | Shooting Range HUD (range/RangeController) | Training (ExfilFX leave, crate picker) | covered |
| 11 | Free Rewards gift + panel, Market, Limited Time stand, lobby TV boards (world/WorldController) | Tacticals has its own boards (BillboardController) | N/A / map side |
| 12 | Proximity prompt billboards in RIVALS style (world/WorldController) | Roblox default prompts on pads/NPCs | TODO: check which prompts the lobby uses |
| 13 | Toast pills (kit/Toast) | Roblox SendNotification used by PlayerCards | TODO: a Kit toast in Tacticals style |

## Log
- 2026-10-17 night: 1-3 built (`ui/hud/PlayerCards.lua`, LobbyHud rows + world hook, PublicStats StatMatches/StatKills/StatHeadshots).
  Play-tested in 829eb64d: own row -> menu (View Profile / View Avatar) -> card; hover hint over your character; double click -> card;
  HUD + PLAY row + dock push away under the card and return on X. LobbySocial contract sent to the Tacticals session.
