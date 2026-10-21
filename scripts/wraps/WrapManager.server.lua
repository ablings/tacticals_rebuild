-- ServerScriptService.WrapManager (Script) [WRAPS] 2026-10-21. Puts each player's equipped wrap (profile data.Wraps, see WrapConfig) on
-- their weapons wherever the server makes them, so everyone sees it: Tools in the Backpack / character (WeaponId / MeleeId) and the
-- HolsterManager copies (character.Holsters, models named "Gun:<id>", "GunLeft:<id>", "Melee:<id>"; Dual Pistols' left gun included).
-- Random = a fresh owned wrap per life. The Kit's display models are the UI's (client, WrapConfig.Apply). Remotes (lobby UI):
--   Events.Wraps.Equip(itemId, wrapId | "None" | "Random", inverted)   Events.Wraps.Favorite(wrapId, on)
-- Both places (lobby: PlayerStore writes through the Replica; match places: the shared profile is read only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WrapConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WrapConfig"))
local okDM, DataManager = pcall(function() return require(ServerScriptService:WaitForChild("Data", 30):WaitForChild("DataManager", 30)) end)

local events = ReplicatedStorage:WaitForChild("Events")
local folder = events:FindFirstChild("Wraps") or Instance.new("Folder")
folder.Name = "Wraps"
folder.Parent = events
local function remote(name)
	local r = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end
local EquipRemote, FavoriteRemote = remote("Equip"), remote("Favorite")

local function profile(player: Player)
	if not okDM or not DataManager then return nil, nil end
	local data = DataManager:Get(player)
	local replica = DataManager.DataReplicas and DataManager.DataReplicas[player]
	return data, replica
end

-- write a value at data.Wraps[...path], creating the Wraps table on first use
local function write(player: Player, path: { any }, value: any): boolean
	local data, replica = profile(player)
	if not data then return false end
	if type(data.Wraps) ~= "table" then
		local fresh = { Owned = {}, Equipped = {}, Favorites = {} }
		if replica then replica:SetValue({ "Wraps" }, fresh) else data.Wraps = fresh end
	end
	for _, k in { "Owned", "Equipped", "Favorites" } do
		if type(data.Wraps[k]) ~= "table" then
			if replica then replica:SetValue({ "Wraps", k }, {}) else data.Wraps[k] = {} end
		end
	end
	local full = { "Wraps" }
	for _, k in path do table.insert(full, k) end
	if replica then replica:SetValue(full, value)
	else
		local t = data
		for i = 1, #full - 1 do t = t[full[i]] end
		t[full[#full]] = value
	end
	return true
end

-- the item a tool / holster copy stands for
local function itemOf(inst: Instance): string?
	if inst:IsA("Tool") then return inst:GetAttribute("WeaponId") or inst:GetAttribute("MeleeId") end
	if inst:IsA("Model") and inst.Parent and inst.Parent.Name == "Holsters" then
		local kind, id = inst.Name:match("^(%w+):(.+)$")
		if kind == "Gun" or kind == "GunLeft" or kind == "Melee" then return id end
	end
	return nil
end

local lifeRandom = {} -- [Player] = { [itemId] = wrapId } (Random, rolled once per life)
local function wrapFor(player: Player, itemId: string): (string?, boolean)
	local data = profile(player)
	local wr = type(data) == "table" and data.Wraps
	local e = type(wr) == "table" and type(wr.Equipped) == "table" and wr.Equipped[itemId]
	if type(e) == "table" and e.Id == "Random" then
		lifeRandom[player] = lifeRandom[player] or {}
		local picked = lifeRandom[player][itemId]
		if not picked or not WrapConfig.Owns(data, picked) then
			picked = WrapConfig.EquippedFor(data, itemId)
			lifeRandom[player][itemId] = picked
		end
		return picked, e.Inverted == true
	end
	return WrapConfig.EquippedFor(data, itemId)
end

local function dress(player: Player, inst: Instance)
	local item = itemOf(inst)
	if not item then return end
	local id, inverted = wrapFor(player, item)
	if inst:GetAttribute("WrapId") == id and (inst:GetAttribute("WrapInverted") == true) == inverted then return end
	WrapConfig.Apply(inst, id, inverted)
end

local function refreshAll(player: Player)
	local places = { player:FindFirstChildOfClass("Backpack"), player.Character }
	local holsters = player.Character and player.Character:FindFirstChild("Holsters")
	if holsters then table.insert(places, holsters) end
	for _, c in places do
		for _, inst in (c and c:GetChildren() or {}) do task.spawn(dress, player, inst) end
	end
end

local function watch(player: Player, container: Instance)
	container.ChildAdded:Connect(function(inst)
		task.defer(dress, player, inst) -- after the giver has finished setting its attributes / parts
		if inst.Name == "Holsters" and inst:IsA("Folder") then watch(player, inst) end
	end)
	for _, inst in container:GetChildren() do
		task.defer(dress, player, inst)
		if inst.Name == "Holsters" and inst:IsA("Folder") then watch(player, inst) end
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		lifeRandom[player] = nil
		watch(player, character)
		local bp = player:WaitForChild("Backpack", 10)
		if bp then watch(player, bp) end
	end)
	if player.Character then watch(player, player.Character) end
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then watch(player, bp) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p) lifeRandom[p] = nil end)

local last = {} -- [Player] = os.clock() (remote rate limit)
local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (last[player] or 0) < 0.15 then return false end
	last[player] = now
	return true
end

EquipRemote.OnServerEvent:Connect(function(player: Player, itemId: any, wrapId: any, inverted: any)
	if not allowed(player) or type(itemId) ~= "string" or #itemId > 40 or type(wrapId) ~= "string" then return end
	local data = profile(player)
	if not data then return end
	if wrapId == "None" then
		write(player, { "Equipped", itemId }, nil)
	elseif wrapId == "Random" or WrapConfig.Owns(data, wrapId) then
		write(player, { "Equipped", itemId }, { Id = wrapId, Inverted = inverted == true })
		if lifeRandom[player] then lifeRandom[player][itemId] = nil end
	else
		return -- not owned
	end
	refreshAll(player)
end)

FavoriteRemote.OnServerEvent:Connect(function(player: Player, wrapId: any, on: any)
	if not allowed(player) or type(wrapId) ~= "string" or not WrapConfig.Wraps[wrapId] then return end
	write(player, { "Favorites", wrapId }, on == true or nil)
end)
