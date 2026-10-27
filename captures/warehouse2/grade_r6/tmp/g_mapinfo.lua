local f = game.ReplicatedStorage.DuelMaps.Warehouse2
local out = {}
for _, c in f:GetChildren() do table.insert(out, c.ClassName .. " " .. c.Name) end
local mi = f:FindFirstChild("MapInfo")
local s = mi and mi.Source or "?"
return table.concat(out, ", ") .. "\n" .. s
