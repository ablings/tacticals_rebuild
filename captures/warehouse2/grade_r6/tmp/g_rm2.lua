local rm = game.ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers.RoundManager
local dm = game.ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers.DoorManager
local lines = {}
local i = 0
for line in (rm.Source.."\n"):gmatch("(.-)\n") do
  i += 1
  if i >= 375 and i <= 460 then table.insert(lines, i..": "..line) end
end
return table.concat(lines, "\n") .. "\n=====DoorManager\n" .. dm.Source
