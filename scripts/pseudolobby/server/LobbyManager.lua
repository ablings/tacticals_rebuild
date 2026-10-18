-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- ServerScripts/[Server] Init/GameManager/Managers/LobbyManager (ModuleScript)
-- Loadout, item shop, bundles, quests and the Robux store. Matchmaking is QueueManager.
-- The client never changes data itself: it asks through LobbyRemotes and this module checks
-- everything (ownership, prices, quest progress) before writing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
local PlayerStore = require(ServerScriptService.Data.PlayerStore)
local Remotes = require(ServerScriptService.Lobby.LobbyRemotes)
local RN = require(ServerScriptService.Shared.RichNotify) -- [NOTIFY]

local LobbyManager = {}

local IS_STUDIO = RunService:IsStudio()
-- [PSEUDOLOBBY] on a match place (no Workspace.LobbyMap at start) the loadout only changes in the after-match lobby, never mid-round
local IS_LOBBY_PLACE = workspace:FindFirstChild("LobbyMap") ~= nil

local function result(ok: boolean, msg: string?)
	return { ok = ok, msg = msg }
end

local function creditMultiplier(player: Player): number
	local data = PlayerStore.Get(player)
	-- (pass 37) 2X SCISSORS doubles mission rewards, VIP adds 25% (they stack: x2.5)
	local m = 1
	if data and data.Passes and data.Passes.DoubleCredits then m *= 2 end
	if data and data.Passes and data.Passes.VIP then m *= 1.25 end
	return m
end

-------------------------------------------------------------------------------
-- Loadout
-------------------------------------------------------------------------------
Remotes.Handlers.Equip = function(player, slot, itemId)
	if not IS_LOBBY_PLACE and not player:GetAttribute("InPseudoLobby") then return result(false, "Change your loadout after the match") end -- [PSEUDOLOBBY]
	local item = type(itemId) == "string" and Config.Items[itemId]
	if not item or item.Slot ~= slot then
		return result(false, "You can't equip that")
	end
	if not PlayerStore.Owns(player, itemId) then
		return result(false, `You don't own {item.Name} yet`)
	end
	PlayerStore.Set(player, { "Loadout", slot }, itemId)
	PlayerStore.ApplyLoadoutAttributes(player)
	return result(true, `{item.Name} equipped`)
end

-- Star / unstar an item in the Armory (no toast: the star itself is the feedback)
Remotes.Handlers.Favorite = function(player, itemId, on)
	if type(itemId) ~= "string" or not Config.Items[itemId] then
		return { ok = false, silent = true }
	end
	PlayerStore.Set(player, { "Favorites", itemId }, on == true or nil)
	return { ok = true, silent = true }
end

-------------------------------------------------------------------------------
-- Item shop + bundles (Credits)
-------------------------------------------------------------------------------
Remotes.Handlers.BuyItem = function(player, itemId)
	local item = type(itemId) == "string" and Config.Items[itemId]
	if not item or item.Default then
		return result(false, "That isn't for sale")
	end
	if PlayerStore.Owns(player, itemId) then
		return result(false, `You already own {item.Name}`)
	end
	if not PlayerStore.Spend(player, item.Price) then
		return result(false, "Not enough scissors")
	end
	PlayerStore.Grant(player, itemId)
	RN.Item(player, itemId) -- [NOTIFY]
	return result(true, `{item.Name} unlocked`)
end

Remotes.Handlers.BuyBundle = function(player, bundleId)
	local bundle
	for _, b in Config.Bundles do
		if b.Id == bundleId then bundle = b end
	end
	if not bundle then
		return result(false, "That bundle doesn't exist")
	end
	local cost, missing = Config.BundleCost(bundle, function(id) return PlayerStore.Owns(player, id) end)
	if missing == 0 then
		return result(false, "You already own everything in this bundle")
	end
	if not PlayerStore.Spend(player, cost) then
		return result(false, "Not enough scissors")
	end
	for _, id in bundle.Items do
		local had = PlayerStore.Owns(player, id)
		PlayerStore.Grant(player, id)
		if not had then RN.Item(player, id) end -- [NOTIFY]
	end
	return result(true, `{bundle.Name} unlocked`)
end

-------------------------------------------------------------------------------
-- Quests
-------------------------------------------------------------------------------
local function periodKey(scope: string): string
	local now = os.time()
	if scope == "Daily" then
		return os.date("!%Y-%m-%d", now)
	end
	-- weeks start Monday 00:00 UTC (1 Jan 1970 was a Thursday, hence +3)
	return "W" .. math.floor((math.floor(now / 86400) + 3) / 7)
end
LobbyManager.PeriodKey = periodKey

local function questDef(scope: string, id: string)
	for _, q in Config.Quests[scope].Pool do
		if q.Id == id then return q end
	end
end

local function rollQuests(player: Player, scope: string)
	local data = PlayerStore.Get(player)
	if not data then return end
	local pool = table.clone(Config.Quests[scope].Pool)
	local rng = Random.new()
	local list = {}
	for _ = 1, math.min(Config.Quests[scope].Count, #pool) do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { Id = q.Id, Base = data.Stats[q.Stat] or 0, Claimed = false })
	end
	PlayerStore.Set(player, { "Quests", scope }, { Key = periodKey(scope), List = list })
end

local function ensureQuests(player: Player)
	local data = PlayerStore.Get(player)
	if not data then return end
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests[scope]
		if not q or q.Key ~= periodKey(scope) then
			rollQuests(player, scope)
		end
	end
end
LobbyManager.EnsureQuests = ensureQuests

Remotes.Handlers.ClaimQuest = function(player, scope, index)
	if (scope ~= "Daily" and scope ~= "Weekly") or type(index) ~= "number" then
		return result(false, "Bad quest")
	end
	ensureQuests(player)
	local data = PlayerStore.Get(player)
	local entry = data and data.Quests[scope].List[index]
	local def = entry and questDef(scope, entry.Id)
	if not def then
		return result(false, "That quest has expired")
	end
	if entry.Claimed then
		return result(false, "Already claimed")
	end
	local progress = (data.Stats[def.Stat] or 0) - entry.Base
	if progress < def.Goal then
		return result(false, "Not finished yet")
	end
	local reward = math.floor(def.Reward * creditMultiplier(player) + 0.5)
	PlayerStore.Set(player, { "Quests", scope, "List", index, "Claimed" }, true)
	PlayerStore.Increment(player, { "Credits" }, reward)
	RN.Send(player, "Task Completed", ("You've earned x%d Scissors!"):format(reward), { kind = "Scissors", count = reward }) -- [NOTIFY]
	return result(true, `+{reward} scissors`)
end

-------------------------------------------------------------------------------
-- Robux store
-------------------------------------------------------------------------------
local productsById = {}
for _, list in { Config.RobuxProducts, Config.ScissorsProducts or {} } do
	for _, p in list do
		if p.ProductId ~= 0 then productsById[p.ProductId] = p end
	end
end

local function grantProduct(player: Player, product)
	if product.Credits and product.Credits > 0 then
		PlayerStore.Increment(player, { "Credits" }, product.Credits)
	end

	for _, id in product.Items or {} do
		local had = PlayerStore.Owns(player, id)
		PlayerStore.Grant(player, id)
		if not had then RN.Item(player, id) end -- [NOTIFY]
	end
	Remotes.Notify(player, `{product.Name} purchased! Thanks for the support`, "good")
end

local function allProducts()
	local out = table.clone(Config.RobuxProducts)
	for _, p in Config.ScissorsProducts or {} do table.insert(out, p) end
	return out
end
Remotes.Handlers.BuyRobux = function(player, key)
	for _, p in allProducts() do
		if p.Key == key then
			if p.ProductId == 0 then
				if IS_STUDIO then
					grantProduct(player, p)
					return result(true, "TEST purchase (Studio, product id not set)")
				end
				return result(false, "Coming soon")
			end
			MarketplaceService:PromptProductPurchase(player, p.ProductId)
			return result(true)
		end
	end
	return result(false, "Unknown product")
end

Remotes.Handlers.BuyPass = function(player, key)
	for _, p in Config.GamePasses do
		if p.Key == key then
			local data = PlayerStore.Get(player)
			if data and data.Passes[key] then
				return result(false, "You already own this")
			end
			if p.PassId == 0 then
				if IS_STUDIO then
					PlayerStore.Set(player, { "Passes", key }, true)
					if key == "VIP" then player:SetAttribute("VIP", true) end
					return result(true, "TEST purchase (Studio, pass id not set)")
				end
				return result(false, "Coming soon")
			end
			MarketplaceService:PromptGamePassPurchase(player, p.PassId)
			return result(true)
		end
	end
	return result(false, "Unknown pass")
end

-- Developer product receipts. Each PurchaseId is granted exactly once (remembered in the profile).
local MAX_RECEIPTS = 60
MarketplaceService.ProcessReceipt = function(info)
	local product = productsById[info.ProductId]
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not product or not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerStore.Wait(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	grantProduct(player, product)
	-- keep the receipt log small: drop the oldest when full
	local count, oldestKey, oldestTime = 0, nil, math.huge
	for k, t in data.Receipts do
		count += 1
		if t < oldestTime then oldestKey, oldestTime = k, t end
	end
	if count >= MAX_RECEIPTS and oldestKey then
		PlayerStore.Set(player, { "Receipts", oldestKey }, nil)
	end
	PlayerStore.Set(player, { "Receipts", info.PurchaseId }, os.time())
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	-- [SECURE] the event alone is not proof of purchase: ask Roblox before granting
	local okOwn, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	if not (okOwn and owns) then warn("[LobbyManager] pass " .. tostring(passId) .. " not confirmed for " .. player.Name) return end
	for _, p in Config.GamePasses do
		if p.PassId == passId then
			PlayerStore.Set(player, { "Passes", p.Key }, true)
			if p.Key == "VIP" then player:SetAttribute("VIP", true) end
			Remotes.Notify(player, `{p.Name} unlocked!`, "good")
		end
	end
end)

local function checkPasses(player: Player)
	for _, p in Config.GamePasses do
		if p.PassId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.PassId)
			if ok and owns then
				PlayerStore.Set(player, { "Passes", p.Key }, true)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Join / periodic
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Settings (saved so the match place can use them too)
-------------------------------------------------------------------------------
-- every row and its valid values live in UIKit.SettingsData; SettingsConfig checks the whole table
local SettingsConfig = require(game:GetService("ReplicatedStorage").Modules.Shared.Config.SettingsConfig)
local lastSettingsSave = {}
Remotes.Handlers.SaveSettings = function(player, settings)
	if type(settings) ~= "table" then return result(false) end
	if os.clock() - (lastSettingsSave[player] or 0) < 0.25 then return { ok = false } end -- the client debounces; this stops spam
	lastSettingsSave[player] = os.clock()
	PlayerStore.Set(player, { "Settings" }, SettingsConfig.Sanitize(settings))
	if shared.SettingsApply then task.spawn(shared.SettingsApply, player) end -- [PSEUDOLOBBY] match place: SettingsBridge re-applies the attributes
	return { ok = true } -- silent (no toast)
end
game:GetService("Players").PlayerRemoving:Connect(function(p) lastSettingsSave[p] = nil end)

-------------------------------------------------------------------------------
-- Codes
-------------------------------------------------------------------------------
local Codes = require(ServerScriptService.Lobby.LobbyCodes)
Remotes.Handlers.RedeemCode = function(player, code)
	if type(code) ~= "string" or #code > 40 then return result(false, "Invalid code") end
	code = string.upper((code:gsub("%s", "")))
	local def = Codes[code]
	if not def or (def.Expires and os.time() > def.Expires) then
		return result(false, "That code isn't valid")
	end
	local data = PlayerStore.Get(player)
	if not data then return result(false, "Still loading, try again") end
	if data.RedeemedCodes[code] then return result(false, "You already redeemed that code") end
	PlayerStore.Set(player, { "RedeemedCodes", code }, os.time())
	local parts = {}
	if def.Credits and def.Credits > 0 then
		PlayerStore.Increment(player, { "Credits" }, def.Credits)
		table.insert(parts, `+{def.Credits} scissors`)
	end
	for _, id in def.Items or {} do
		if Config.Items[id] and not PlayerStore.Owns(player, id) then
			PlayerStore.Grant(player, id)
			table.insert(parts, Config.Items[id].Name)
		end
	end
	RN.Send(player, "Code Redeemed", table.concat(parts, " + "), (def.Credits and def.Credits > 0) and { kind = "Scissors", count = def.Credits } or nil) -- [NOTIFY]
	for _, id in def.Items or {} do if Config.Items[id] then RN.Item(player, id) end end -- [NOTIFY]
	return result(true, `Code redeemed! {table.concat(parts, " + ")}`)
end

-- Studio only: fake match stats so quests can be tested without the match place.
--   Request:InvokeServer("DevAddStat", "Kills", 5)
if IS_STUDIO then
	Remotes.Handlers.DevAddStat = function(player, stat, amount)
		if type(stat) ~= "string" or type(amount) ~= "number" then return result(false, "Bad stat") end
		PlayerStore.AddStat(player, stat, amount)
		return result(true, `DEV: {stat} +{amount}`)
	end
end

local function onPlayer(player: Player)
	local data = PlayerStore.Wait(player)
	if not data then return end
	PlayerStore.ApplyLoadoutAttributes(player)
	ensureQuests(player)
	checkPasses(player)
	if data.Passes.VIP then player:SetAttribute("VIP", true) end
end

function LobbyManager.Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	-- hand out new quests when the day / week rolls over while people are online
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in Players:GetPlayers() do
				task.spawn(ensureQuests, p)
			end
		end
	end)
end

return LobbyManager
