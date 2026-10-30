-- [PERFSET] state of the three targets (length + a rolling hash of each source) and the UNDO park
local t = {}
for _, p in {"ReplicatedStorage/UIKit/SettingsData", "StarterPlayer/StarterPlayerScripts/Client/Controllers/SettingsEffectsController", "StarterPlayer/StarterPlayerScripts/Client/Controllers/ExplosionController"} do
  local i = game; for s in p:gmatch("[^/]+") do i = i and i:FindFirstChild(s) end
  if i then local src = i.Source; local h = 0; for k = 1, #src do h = (h * 31 + src:byte(k)) % 2147483647 end
    table.insert(t, i.Name .. " " .. #src .. " " .. h .. (src:find("[PERFSET]", 1, true) and " PERFSET" or ""))
  else table.insert(t, p:match("[^/]+$") .. " missing") end
end
table.insert(t, "park " .. tostring(game.ServerStorage:FindFirstChild("_PerfSetOrig") ~= nil) .. " | PlaceId " .. game.PlaceId)
return table.concat(t, " | ")
