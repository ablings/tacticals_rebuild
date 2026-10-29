-- fix/noclimb_1029.lua [MOVE1029] NoClimb tags (2026-10-29, systems session; with fix/move_rework_1029.lua)
-- The pull-up climbs any surface up to the standing head top (CoverConfig.PullUpMaxHeight) unless the part, or an ancestor, has
-- NoClimb = true. This tags every surface a map relies on NOT being climbed. Found with tools/pullup_scan.lua (every pull-up the
-- rule allows) and the maps' build notes:
--   Arena      Cover.Decks (the 5-high decks, their curbs and parapets: the ramp stays the only way up), Box (walls, rims)
--   Warehouse / Warehouse 2   the room shell (COLP_Wall_*, COLP_Ceiling*, the CamSkin walls), the doors' OutOfBounds blockers,
--              shutters and bollards (the roof edges and out of bounds)
--   House      window sills / frames (COLP_*_Win_*), every window / rail barrier (BAR_*), the railings and stair ramps, the
--              floor slabs and ceilings (the gallery edge), HouseExterior and HouseBounds (out of bounds)
--   Tutorial   (PlaceKind Tutorial only) every cover piece TutorialConfig scripts a lesson on
--   lobby      the hub (LobbyMap: the cover controllers are off there, belt and braces), Training's shell, every duel map's layers
-- Where it looks: Workspace.<map> (match places), ServerStorage.StagingMaps.<Id>.Workspace (Test place staging), and in the lobby
-- ServerStorage.DuelMaps.<Id>.Visual / .Solid and ServerStorage._DuelSource.<Id> (the pad duels' layers and their source).
-- Idempotent; marks what it tagged (attribute NoClimbBy1029) so UNDO removes only its own tags.
-- python tools/run_luau_at.py <studio id> fix/noclimb_1029.lua [UNDO]
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local function lastName(p) return p.Name end
local function has(s, pat) return s:find(pat) ~= nil end

-- per map: a rule on each BasePart (name, path inside the map) and folders tagged whole
local RULES = {
	Arena = {
		folders = { "Cover/Decks", "Box" },
		part = function(_) return false end,
	},
	Warehouse = {
		folders = { "CamSkin" },
		part = function(p)
			local n = p.Name
			return has(n, "^COLP_Wall") or has(n, "^COLP_Ceiling") or has(n, "^COLP_CamSkin") or n == "OutOfBounds" or n == "Shutter" or n == "Bollard"
		end,
	},
	House = {
		folders = {},
		part = function(p)
			local n = p.Name
			return has(n, "^BAR_") or has(n, "_Win_") or has(n, "^COLP_Rail") or has(n, "^COLP_Stair") or has(n, "^COLP_Slab")
				or has(n, "^COLP_Ceiling") or has(n, "Above$") or has(n, "_Above_") or p:HasTag("WindowBarrier")
		end,
		whole = { "HouseExterior" }, -- extra models of this map tagged whole (out of bounds)
	},
}
RULES.Warehouse2 = RULES.Warehouse

local res = {}
local counts = {}
local function tag(inst: Instance, why: string)
	if UNDO then
		if inst:GetAttribute("NoClimbBy1029") then
			inst:SetAttribute("NoClimb", nil)
			inst:SetAttribute("NoClimbBy1029", nil)
			counts[why] = (counts[why] or 0) + 1
		end
		return
	end
	if inst:GetAttribute("NoClimb") == true then return end
	inst:SetAttribute("NoClimb", true)
	inst:SetAttribute("NoClimbBy1029", true)
	counts[why] = (counts[why] or 0) + 1
end

local function walk(root: Instance, path: string)
	local node = root
	for seg in path:gmatch("[^/]+") do node = node and node:FindFirstChild(seg) end
	return node
end

-- one map model (or a layer of one): its folders and parts
local function applyMap(model: Instance, id: string, label: string)
	local rule = RULES[id]
	if not rule then return end
	for _, f in rule.folders do
		local node = walk(model, f)
		if node then tag(node, label .. ":" .. f) end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and rule.part(d) then tag(d, label .. ":parts") end
	end
end

local IS_HUB = workspace:FindFirstChild("LobbyMap") ~= nil and RS:FindFirstChild("PlaceKind") == nil
local kindValue = RS:FindFirstChild("PlaceKind")
local KIND = kindValue and kindValue.Value or nil

if not IS_HUB then
	-- match places: the maps in Workspace (the registry says which model is which map)
	local maps = RS:FindFirstChild("DuelMaps")
	for _, entry in (maps and maps:GetChildren() or {}) do
		local wsName = entry.Name
		local info = entry:FindFirstChild("MapInfo")
		if info and info:IsA("ModuleScript") then
			local ok, t = pcall(function() return loadstring(info.Source)() end)
			if ok and type(t) == "table" and t.WorkspaceName then wsName = t.WorkspaceName end
		end
		local model = workspace:FindFirstChild(wsName)
		if model then applyMap(model, entry.Name, entry.Name) end
		for _, extra in (RULES[entry.Name] and RULES[entry.Name].whole or {}) do
			local m = workspace:FindFirstChild(extra)
			if m then tag(m, entry.Name .. ":" .. extra) end
		end
	end
	local hb = game:GetService("ServerScriptService"):FindFirstChild("HouseBounds")
	local _ = hb
	-- the Test place's staging maps
	local staging = SS:FindFirstChild("StagingMaps")
	for _, entry in (staging and staging:GetChildren() or {}) do
		local ws = entry:FindFirstChild("Workspace")
		for _, m in (ws and ws:GetChildren() or {}) do
			if RULES[entry.Name] and table.find(RULES[entry.Name].whole or {}, m.Name) then tag(m, entry.Name .. ":staging " .. m.Name)
			else applyMap(m, entry.Name, entry.Name .. " staging") end
		end
	end
	-- the Tutorial place: the lessons' scripted cover pieces
	if KIND == "Tutorial" then
		local cfgModule = RS.Modules.Shared.Config:FindFirstChild("TutorialConfig")
		local ok, cfg = pcall(function() return loadstring(cfgModule.Source)() end)
		local names = {}
		local function collect(t, depth)
			if depth > 4 then return end
			for _, v in t do
				if type(v) == "string" and v:find("^COLP_") then names[v] = true
				elseif type(v) == "table" then collect(v, depth + 1) end
			end
		end
		if ok and type(cfg) == "table" then collect(cfg, 0) end
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and names[d.Name] then tag(d, "Tutorial spots") end
		end
	end
else
	-- lobby: the hub (controllers off there) and Training's shell, then every duel map's layers + their source
	local hub = workspace:FindFirstChild("LobbyMap")
	local training = hub and hub:FindFirstChild("Training", true)
	for _, d in (hub and hub:GetChildren() or {}) do
		if d ~= training and not (training and training:IsDescendantOf(d)) then tag(d, "hub") end
	end
	if training then
		for _, d in training:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide and (has(d.Name:lower(), "wall") or has(d.Name:lower(), "rail") or has(d.Name:lower(), "bound")
				or has(d.Name:lower(), "ceiling") or has(d.Name:lower(), "roof") or has(d.Name:lower(), "glass") or has(d.Name:lower(), "edge")) then
				tag(d, "Training shell")
			end
		end
	end
	local dm = SS:FindFirstChild("DuelMaps")
	for _, entry in (dm and dm:GetChildren() or {}) do
		for _, layer in { "Visual", "Solid" } do
			local l = entry:FindFirstChild(layer)
			if l then applyMap(l, entry.Name, entry.Name .. " " .. layer) end
		end
	end
	local src = SS:FindFirstChild("_DuelSource")
	for _, entry in (src and src:GetChildren() or {}) do
		for _, m in entry:GetChildren() do
			if RULES[entry.Name] and table.find(RULES[entry.Name].whole or {}, m.Name) then tag(m, entry.Name .. ":source " .. m.Name)
			else applyMap(m, entry.Name, entry.Name .. " source") end
		end
	end
end

local keys = {}
for k in counts do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do table.insert(res, k .. " " .. counts[k]) end
return (UNDO and "UNDO " or "") .. "NOCLIMB1029 " .. (IS_HUB and "lobby" or ("match " .. tostring(KIND))) .. ": " .. (#res > 0 and table.concat(res, ", ") or "nothing to do")
