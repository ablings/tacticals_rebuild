-- ReplicatedStorage/Modules/Shared/MapRegistry (ModuleScript): the lobby duels map registry (server + client).
-- One entry per ReplicatedStorage.DuelMaps.<Id> folder that has a MapInfo module (built by fix/duel_split_map.lua).
-- Nothing in the duel code may assume one map's layout: footprint, spawns, modes and the layers all come from here.
--   MapRegistry.List() -> { info }            every map
--   MapRegistry.Get(id) -> info?              info = MapInfo table + .Folder (the ReplicatedStorage entry)
--   MapRegistry.ForMode(mode) -> { info }     maps whose Modes include mode (the vote list; "Random" picks among these)
--   MapRegistry.HasMode(mode) -> bool         false = pads of that mode can't start an in-lobby match (NoMap)
--   MapRegistry.SlotSpacing() -> number       distance between arena slots: the biggest footprint + the longest weapon range
--   MapRegistry.Changed  (RBXScriptSignal-like :Connect) fires when a map folder is added or removed (cache dropped)
-- Optional MapInfo keys read by the duel code (phase 2): RayFolders = { "<Solid child>" } (what smoke / blast rays hit;
-- default: CollisionProxies if the map has it, else the whole Solid layer), LightBudget (see fix/duel_split_map.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapRegistry = {}
local WEAPON_RANGE = 600 -- longest gun range (Sniper); arenas must be further apart than this
local cache
local changed = Instance.new("BindableEvent")
MapRegistry.Changed = changed.Event
local watching = false
local function watch(root)
	if watching or not root then return end
	watching = true
	-- a map added or removed at runtime (e.g. a Studio test map) is picked up on the next call
	local function drop() cache = nil; changed:Fire() end
	root.ChildAdded:Connect(drop)
	root.ChildRemoved:Connect(drop)
end

local function load()
	if cache then return cache end
	local root = ReplicatedStorage:FindFirstChild("DuelMaps")
	watch(root)
	local list = {}
	for _, f in (root and root:GetChildren() or {}) do
		local mod = f:FindFirstChild("MapInfo")
		if mod and mod:IsA("ModuleScript") then
			local ok, info = pcall(require, mod)
			if ok and type(info) == "table" then
				local entry = table.clone(info)
				-- the folder is authoritative: its name is the map id, its Modes attribute ("1v1,2v2") overrides MapInfo.Modes
				-- (so a map's modes can change without regenerating MapInfo, and a copied folder is its own map)
				entry.Id = f.Name
				local modes = f:GetAttribute("Modes")
				if type(modes) == "string" and modes ~= "" then
					entry.Modes = {}
					for m in modes:gmatch("[^,%s]+") do table.insert(entry.Modes, m) end
				end
				entry.Folder = f
				table.insert(list, entry)
			else
				warn("[MapRegistry] bad MapInfo in " .. f:GetFullName() .. ": " .. tostring(info))
			end
		end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	cache = list
	return list
end

function MapRegistry.List() return load() end

function MapRegistry.Get(id: string?)
	for _, m in load() do if m.Id == id then return m end end
	return nil
end

function MapRegistry.ForMode(mode: string)
	local out = {}
	for _, m in load() do
		if table.find(m.Modes or {}, mode) then table.insert(out, m) end
	end
	return out
end

function MapRegistry.HasMode(mode: string): boolean
	return #MapRegistry.ForMode(mode) > 0
end

function MapRegistry.SlotSpacing(): number
	local biggest = 0
	for _, m in load() do
		local s = m.Size or Vector3.new(200, 50, 200)
		biggest = math.max(biggest, s.X, s.Z)
	end
	return math.max(1000, biggest + WEAPON_RANGE + 100)
end

return MapRegistry
