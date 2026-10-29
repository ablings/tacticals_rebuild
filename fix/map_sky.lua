-- fix/map_sky.lua [MAPSKY] 2026-10-29: per-map Sky, Atmosphere and backdrop models (House illusion pass; House is the only user).
-- Why: the match code applied a map's Lighting / Atmosphere / grade / bloom (fix/map_env.lua [PRANGE]) but never its sky, so a
-- desert map showed the place's blue sky through its high windows; a place without an Atmosphere ignored the map's one; and a
-- map's far field (ground to the horizon, mountain ring) would sit round every other map of the same place all the time.
-- Idempotent; works in whichever place it runs in (both parts if both are there). UNDO puts every edit back byte for byte.
--
-- A. Match / Test places (ServerScriptService...Managers.RoundManager with the [PRANGE] applyMapEnv): applyMapEnv(info) also
--    calls applyMapSky(info):
--    - info.Lighting.Sky = { SkyboxBk = ..., SkyboxDn, SkyboxFt, SkyboxLf, SkyboxRt, SkyboxUp, CelestialBodiesShown,
--      SunAngularSize, MoonAngularSize, StarCount, ... }: the place's own Sky(s) move to ServerStorage._PlaceSkyPark and a Sky
--      "MapSky" with those values goes into Lighting; any other map / the after-match lobby (info nil) puts the place's back.
--    - info.Lighting.Atmosphere when the place has no Atmosphere: a "MapAtmosphere" is made (removed again after). (With one,
--      [PRANGE] already sets its values.)
--    - info.Hide = { "<Workspace child>", ... }: their look (Transparency, decals, textures) steps aside while the map is loaded,
--      collision untouched (House hides the place Baseplate: a grey line at its horizon, grade r1).
--    - info.Backdrop = { "<model name>", ... }: models kept in ServerStorage.MapBackdrops are moved into Workspace while that map
--      is loaded and back afterwards (a far field never sits round the other maps).
-- B. Lobby place (the duel client ArenaLoader): when the duel map's Lighting Configuration holds a Sky, the lobby's Sky steps
--    aside (moved under the script, local only) like its Atmosphere already did, and comes back on unload. And House's
--    Lighting Configuration (ReplicatedStorage.DuelMaps.House.Lighting) gets DuelSky (+ the match place's House atmosphere)
--    when SKY below is set.
local UNDO = false --@UNDO

-- House's sky (art/house/sky/make_sky.py; images uploaded under gunsy funsy 2026-10-29 as house_sky3_<face> (warmer horizon band, r3); these are the IMAGE ids (Creator Hub lists the decal ids, resolved by InsertService:LoadAsset); round 1 house_sky_* superseded). Used by B; A reads MapInfo.Lighting.Sky
-- (written into House's MapInfo by fix/house_illusion.lua from the same ids).
local SKY = {
	SkyboxBk = "rbxassetid://114348272707345", SkyboxDn = "rbxassetid://86790958697926", SkyboxFt = "rbxassetid://95474979956768", --@SKYIDS1
	SkyboxLf = "rbxassetid://119298313393503", SkyboxRt = "rbxassetid://115392060292720", SkyboxUp = "rbxassetid://72034095232801", --@SKYIDS2
	CelestialBodiesShown = true, SunAngularSize = 9, MoonAngularSize = 7, StarCount = 0,
}
local HOUSE_ATMO = { Density = 0.25, Offset = 0.3, Haze = 0.7, Glare = 0.3, Color = Color3.fromRGB(214, 196, 166), Decay = Color3.fromRGB(150, 120, 90) } --@ATMO

local out = {}
local function edit(script, edits, tag)
	local s = script.Source
	local res = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		local done
		if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
		if done then
			table.insert(res, i .. "=")
		else
			local a, b = s:find(old, 1, true)
			assert(a, tag .. " edit " .. i .. " anchor not found")
			assert(not s:find(old, b + 1, true), tag .. " edit " .. i .. " anchor not unique")
			s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
			table.insert(res, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, tag .. " would not parse: " .. tostring(err))
	if script.Source ~= s then script.Source = s end
	table.insert(out, tag .. " " .. table.concat(res, " "))
end

-- ====================================================================================== A. match / Test places: RoundManager
local SSS = game:GetService("ServerScriptService")
local RM = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
RM = RM and RM:FindFirstChild("GameManager") and RM.GameManager:FindFirstChild("Managers") and RM.GameManager.Managers:FindFirstChild("RoundManager")
if RM and RM.Source:find("local function applyMapEnv(info)", 1, true) then
	local HELPER = [==[
-- [MAPSKY] a map's own Sky (MapInfo.Lighting.Sky), an Atmosphere for places without one, and its backdrop models
-- (MapInfo.Backdrop, kept in ServerStorage.MapBackdrops while another map is loaded); info nil = the place's own (fix/map_sky.lua)
local function applyMapSky(info)
	local L = game:GetService("Lighting")
	local SS = game:GetService("ServerStorage")
	local look = info and info.Lighting
	local park = SS:FindFirstChild("_PlaceSkyPark")
	local old = L:FindFirstChild("MapSky")
	if old then old:Destroy() end
	if look and type(look.Sky) == "table" then
		if not park then park = Instance.new("Folder"); park.Name = "_PlaceSkyPark"; park.Parent = SS end
		for _, c in L:GetChildren() do if c:IsA("Sky") then c.Parent = park end end
		local sky = Instance.new("Sky")
		sky.Name = "MapSky"
		for k, v in look.Sky do pcall(function() (sky :: any)[k] = v end) end
		sky.Parent = L
	elseif park then
		for _, c in park:GetChildren() do c.Parent = L end
	end
	local made = L:FindFirstChild("MapAtmosphere")
	if made then made:Destroy() end
	if look and type(look.Atmosphere) == "table" and not L:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Name = "MapAtmosphere"
		for k, v in look.Atmosphere do pcall(function() (a :: any)[k] = v end) end
		a.Parent = L
	end
	local store = SS:FindFirstChild("MapBackdrops")
	if store then
		local want = {}
		for _, n in (info and type(info.Backdrop) == "table" and info.Backdrop or {}) do want[n] = true end
		for _, m in store:GetChildren() do if want[m.Name] then m.Parent = workspace end end
		for _, m in workspace:GetChildren() do
			if m:GetAttribute("MapBackdrop") and not want[m.Name] then m.Parent = store end
		end
	end
	-- MapInfo.Hide: Workspace children whose LOOK steps aside while this map is loaded (the place's Baseplate drew a grey line
	-- along a desert map's horizon); collision untouched; any other map / nil shows them again
	local hide = {}
	for _, n in (info and type(info.Hide) == "table" and info.Hide or {}) do hide[n] = true end
	for _, c in workspace:GetChildren() do
		if hide[c.Name] or c:GetAttribute("MapSky_Hidden") then
			local list = c:GetDescendants(); table.insert(list, c)
			for _, d in list do
				if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
					local saved = d:GetAttribute("MapSky_T")
					if hide[c.Name] then
						if saved == nil then d:SetAttribute("MapSky_T", d.Transparency); d.Transparency = 1 end
					elseif saved ~= nil then
						d.Transparency = saved; d:SetAttribute("MapSky_T", nil)
					end
				end
			end
			c:SetAttribute("MapSky_Hidden", hide[c.Name] or nil)
		end
	end
end

]==]
	edit(RM, {
		{ "local envDefaults\nlocal function applyMapEnv(info)\n", HELPER .. "local envDefaults\nlocal function applyMapEnv(info)\n" },
		{ "\tset(bloom, envDefaults.bloom, look and look.Bloom)\nend\n",
			"\tset(bloom, envDefaults.bloom, look and look.Bloom)\n\tapplyMapSky(info) -- [MAPSKY] sky, atmosphere for places without one, backdrop models\nend\n" },
	}, "RoundManager")
else
	table.insert(out, "RoundManager: none with [PRANGE] applyMapEnv here (not a match place)")
end

-- ====================================================================================== B. lobby: duel ArenaLoader (client)
local loader
for _, d in game:GetService("StarterPlayer"):GetDescendants() do
	if d:IsA("LocalScript") and d.Name:match("^ArenaLoader") then loader = d break end
end
if loader and loader.Source:find("local function swapLighting(cfg: Instance?)", 1, true) then
	edit(loader, {
		{ "\tlocal hasAtmo = cfg:FindFirstChildOfClass(\"Atmosphere\") ~= nil\n\tfor _, c in Lighting:GetChildren() do\n\t\tif c:IsA(\"Atmosphere\") and hasAtmo then\n",
			"\tlocal hasAtmo = cfg:FindFirstChildOfClass(\"Atmosphere\") ~= nil\n\tlocal hasSky = cfg:FindFirstChildOfClass(\"Sky\") ~= nil -- [MAPSKY] the map's own sky (fix/map_sky.lua)\n\tfor _, c in Lighting:GetChildren() do\n\t\tif (c:IsA(\"Atmosphere\") and hasAtmo) or (c:IsA(\"Sky\") and hasSky) then\n" },
	}, "ArenaLoader")
	local entry = game:GetService("ReplicatedStorage"):FindFirstChild("DuelMaps")
	entry = entry and entry:FindFirstChild("House")
	local cfg = entry and entry:FindFirstChild("Lighting")
	if cfg then
		local s = cfg:FindFirstChild("DuelSky")
		if s then s:Destroy() end
		local atm = cfg:FindFirstChild("DuelAtmosphere")
		if UNDO then
			local orig = atm and atm:GetAttribute("MapSky_Orig")
			if orig then
				local o = game:GetService("HttpService"):JSONDecode(orig)
				for k, v in o do atm[k] = (type(v) == "table") and Color3.new(v[1], v[2], v[3]) or v end
				atm:SetAttribute("MapSky_Orig", nil)
			end
			table.insert(out, "House lobby DuelSky removed, atmosphere back")
		elseif not SKY.SkyboxUp:match("://0$") then
			local sky = Instance.new("Sky"); sky.Name = "DuelSky"
			for k, v in SKY do sky[k] = v end
			sky.Parent = cfg
			if atm then
				if not atm:GetAttribute("MapSky_Orig") then
					local o = {}
					for k in HOUSE_ATMO do local v = atm[k]; o[k] = typeof(v) == "Color3" and { v.R, v.G, v.B } or v end
					atm:SetAttribute("MapSky_Orig", game:GetService("HttpService"):JSONEncode(o))
				end
				for k, v in HOUSE_ATMO do atm[k] = v end
			end
			table.insert(out, "House lobby DuelSky + atmosphere set")
		else
			table.insert(out, "House lobby: SKY ids not set yet, no DuelSky")
		end
	end
else
	table.insert(out, "ArenaLoader: none here (not the lobby)")
end
return (UNDO and "UNDO " or "") .. table.concat(out, "; ")
