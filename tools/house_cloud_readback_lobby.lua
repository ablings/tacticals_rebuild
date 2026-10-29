-- House port: lobby read-back from the cloud window
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function add(...) local t = {} for _, v in ipairs({...}) do t[#t+1] = tostring(v) end out[#out+1] = table.concat(t, " ") end
add("PlaceId", game.PlaceId)
local m = {} for _, x in ipairs(RS.DuelMaps:GetChildren()) do m[#m+1] = x.Name .. "(" .. tostring(x:GetAttribute("Modes") or "") .. ")" end
add("DuelMaps", table.concat(m, ","))
local e = RS.DuelMaps:FindFirstChild("House") add("House image", e and e:GetAttribute("Image"))
local src = game.ServerStorage._DuelSource.House
local vis = game.ServerStorage:FindFirstChild("DuelLayers", true)
local nm, np = 0, 0 for _, d in ipairs(src:GetDescendants()) do if d:IsA("BasePart") then np += 1 if d:IsA("MeshPart") then nm += 1 end end end
add("House source parts", np, "mesh", nm)
local tp = game:FindFirstChild("TestPlace", true) add("TestPlace cmd", tp and tp:GetFullName())
local cfg = RS:FindFirstChild("LobbyConfig", true) local okC, C = pcall(require, cfg) add("TestPlaceId", okC and C.TestPlaceId)
add("LobbySteamFillRound", game:GetService("ServerScriptService"):GetAttribute("LobbySteamFillRound") or RS:GetAttribute("LobbySteamFillRound"))
add("StudioTeleportData", RS:GetAttribute("StudioTeleportData"), "DuelTestSolo", RS:GetAttribute("DuelTestSolo"))
local n, marks = 0, 0
for _, s in ipairs(game:GetDescendants()) do if s:IsA("LuaSourceContainer") then n += 1 local ok, x = pcall(function() return s.Source end) if ok and x:find("HOUSE2P", 1, true) then marks += 1 end end end
add("scripts", n, "test marks", marks)
return table.concat(out, "\n")
