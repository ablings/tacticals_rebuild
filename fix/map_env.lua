-- fix/map_env.lua [PRANGE] 2026-10-20: per-map spawns + lighting in the match place's RoundManager, for a second placed map
-- (Workspace.PracticeRange, fix/map_practice_range.lua). When a map wins the vote, Workspace.MatchSpawns.SpawnA / SpawnB are
-- moved onto that map's own markers (<map>.MatchSpawns) and MapInfo.Lighting is applied (Lighting, Atmosphere, MapGrade,
-- Bloom). Maps without them, and the after-match lobby, get the place's originals back (captured the first time). Everything
-- that reads Workspace.MatchSpawns (round spawns, bots, the range) follows without changes. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local RM = game:GetService("ServerScriptService").ServerScripts["[Server] Init"].GameManager.Managers.RoundManager

local HELPER = [==[
-- [PRANGE] each placed map can bring its own team markers (<map>.MatchSpawns) and Lighting (MapInfo.Lighting); maps without them
-- (the Warehouse) and the after-match lobby get the place's originals back (captured on the first call)
local envDefaults
local function applyMapEnv(info)
	local L = game:GetService("Lighting")
	local spawns = workspace:FindFirstChild(C.SpawnFolderName or "MatchSpawns")
	local atm, grade, bloom = L:FindFirstChildOfClass("Atmosphere"), L:FindFirstChild("MapGrade"), L:FindFirstChildOfClass("BloomEffect")
	if not envDefaults then
		envDefaults = { spawns = {}, light = {} }
		for _, s in (spawns and spawns:GetChildren() or {}) do if s:IsA("BasePart") then envDefaults.spawns[s.Name] = s.CFrame end end
		for _, k in { "ClockTime", "GeographicLatitude", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient",
			"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows" } do envDefaults.light[k] = L[k] end
		if atm then envDefaults.atmo = { Density = atm.Density, Offset = atm.Offset, Haze = atm.Haze, Glare = atm.Glare, Color = atm.Color, Decay = atm.Decay } end
		if grade then envDefaults.grade = { Brightness = grade.Brightness, Contrast = grade.Contrast, Saturation = grade.Saturation, TintColor = grade.TintColor } end
		if bloom then envDefaults.bloom = { Intensity = bloom.Intensity, Size = bloom.Size, Threshold = bloom.Threshold } end
	end
	local model = info and workspace:FindFirstChild(info.WorkspaceName or info.Id)
	local own = model and model:FindFirstChild("MatchSpawns")
	for name, cf in envDefaults.spawns do
		local marker = spawns and spawns:FindFirstChild(name)
		local mine = own and own:FindFirstChild(name)
		if marker then marker.CFrame = mine and mine.CFrame or cf end
	end
	local look = info and info.Lighting
	local function set(obj, defaults, values)
		if not obj or not defaults then return end
		for k, v in defaults do
			local want = v
			if type(values) == "table" and values[k] ~= nil then want = values[k] end
			obj[k] = want
		end
	end
	set(L, envDefaults.light, look)
	set(atm, envDefaults.atmo, look and look.Atmosphere)
	set(grade, envDefaults.grade, look and look.Grade)
	set(bloom, envDefaults.bloom, look and look.Bloom)
end

]==]

local edits = {
	{ "local function eligibleMaps(mode: string)\n", HELPER .. "local function eligibleMaps(mode: string)\n" },
	{ "\t\t\tmatch.map = MapRegistry.Get(id)\n\t\t\tReplicatedStorage:SetAttribute(\"ArenaMap\", id)\n",
		"\t\t\tmatch.map = MapRegistry.Get(id)\n\t\t\tReplicatedStorage:SetAttribute(\"ArenaMap\", id)\n\t\t\tapplyMapEnv(match.map) -- [PRANGE] this map's spawns + lighting\n" },
	{ "\tlocal ok, PL = pcall(function() return require(ServerScriptService.Shared.PseudoLobby) end)\n",
		"\tapplyMapEnv(nil) -- [PRANGE] the after-match lobby: the place's own spawns + lighting\n\tlocal ok, PL = pcall(function() return require(ServerScriptService.Shared.PseudoLobby) end)\n" },
}
local s = RM.Source
local out = {}
for i, e in edits do
	local old, new = e[1], e[2]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then
		table.insert(out, i .. "=")
	else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "RoundManager would not parse: " .. tostring(err))
if RM.Source ~= s then RM.Source = s end
return "RoundManager " .. table.concat(out, " ")
