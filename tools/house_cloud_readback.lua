-- House port read-back from a cloud window (published place): ids, registry, House geometry, doors, glass, test marks
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local out = {}
local function add(...) local t = {} for _, v in ipairs({...}) do t[#t+1] = tostring(v) end out[#out+1] = table.concat(t, " ") end
add("PlaceId", game.PlaceId, "| PlaceVersion", game.PlaceVersion)
local maps = {} for _, m in ipairs(RS.DuelMaps:GetChildren()) do maps[#maps+1] = m.Name end
add("DuelMaps", table.concat(maps, ","))
local pk = RS:FindFirstChild("PlaceKind", true) add("PlaceKind", pk and pk.Value or RS:GetAttribute("PlaceKind"))
local h = workspace:FindFirstChild("House")
if h then
	local parts, mesh = 0, 0
	for _, d in ipairs(h:GetDescendants()) do if d:IsA("BasePart") then parts += 1 if d:IsA("MeshPart") then mesh += 1 end end end
	add("House parts", parts, "mesh", mesh, "proxies", #h.CollisionProxies:GetChildren(), "windows", #h.Shootables:GetChildren(), "doors", #h.Doors:GetChildren(), "lights", #h.Lights:GetDescendants())
	local ds = {} for _, d in ipairs(h.Doors:GetChildren()) do ds[#ds+1] = d.Name .. "=" .. tostring(d:GetAttribute("DoorState")) end
	add("doors", table.concat(ds, " "))
	local e = RS.DuelMaps:FindFirstChild("House") add("House Image", e and (e:GetAttribute("Image") or (e:FindFirstChild("MapInfo") and "MapInfo")))
else add("House MISSING in workspace") end
local ex = workspace:FindFirstChild("HouseExterior") add("HouseExterior", ex and #ex:GetDescendants() or "nil")
add("HouseKit", game.ServerStorage:FindFirstChild("HouseKit") and #game.ServerStorage.HouseKit:GetDescendants() or "nil")
add("StudioTeleportData", RS:GetAttribute("StudioTeleportData"))
local marks, scripts = {}, 0
for _, s in ipairs(game:GetDescendants()) do
	if s:IsA("LuaSourceContainer") then
		scripts += 1
		local ok, src = pcall(function() return s.Source end)
		if ok and (src:find("HOUSE2P", 1, true) or src:find("--TESTONLY", 1, true)) then marks[#marks+1] = s:GetFullName() end
	end
end
add("scripts", scripts, "test marks", #marks, table.concat(marks, ","))
add("GlassController", game.StarterPlayer:FindFirstChild("WindowGlassController", true) ~= nil or RS:FindFirstChild("WindowGlassController", true) ~= nil)
return table.concat(out, "\n")
