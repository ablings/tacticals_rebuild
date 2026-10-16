# Admin commands: cheat sheet

Type these in chat. Start with `;`. `me` = you, `all` = everyone, `others` = everyone but you, or part of a name, or `@userid`.
Leave the player out and it means you. Wipes ask you to type the same thing again with `confirm` (within 10 seconds).
You (ocxa) are Owner everywhere; anyone in Studio is Owner. `;cmds` lists everything, `;help wipe` explains one.

## Data
- `;stats bob` - show bob's level, scissors, items, stats, missions
- `;setlevel me 30` - set your level to 30
- `;addxp me 500` - add 500 XP (minus number takes it away)
- `;setxp me 0` - set XP exactly
- `;setcredits me 5000` - set scissors to 5000
- `;addcredits all 1000` - give everyone 1000 scissors
- `;setstat me wins 25` - set a stat (wins, kills, headshots, matchesplayed, rating1v1, rankedwins1v1 ...)
- `;give me sniper` - give an item (`;give bob 500` still gives 500 scissors)
- `;take me sniper` - take an item away
- `;giveall me` - own every item (`/unlockall` works too)
- `;wipe me all` then `;wipe me all confirm` - full reset (also: stats, level, inventory, credits, missions, cooldowns, settings)
- `;resetcooldowns me` - duel rewards pay again straight away
- `;missions me complete` - all missions ready to claim (`reset` = new missions)

## Players
- `;tp me 1v1a` - teleport to a pad (also: `spawn`, `hangar`, a player's name, or `10,5,20`)
- `;heal me` / `;kill bob` / `;respawn me`
- `;god me on` - can't take damage (`off` to stop)
- `;speed me 40` - walk faster in the lobby (`reset` for normal)
- `;kick bob being rude` - kick with a reason

## Duels
- `;duelsolo on` - stand on a duel pad alone and it starts with bots (no rewards); `off` to stop
- `;listmatches` - running duels
- `;endmatch D1` - stop a duel (or `;endmatch bob`)
- `;arenas` - arena slots and maps

## Other
- `;announce Server restarts in 5 minutes` - message to everyone
- `;whoami` - your admin level
- `;serverinfo` - server details
- `;audit` - last commands used
- `;pads` - the duel pads' state
- Old ones still work: `/scissors 5000`, `/scissors set 0`, `/give bob 500`, `/wipeweapons`, `/unlockall`, `/admin`
