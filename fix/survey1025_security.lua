-- fix/survey1025_security.lua [SURVEY1025] 2026-10-25 (systems): the SECURITY findings of the 2026-10-25 cross-place survey
-- (roblox_hq task 20261025065116hki). Run in EVERY place (lobby, Tutorial, Matchmaking, Ranked), in Edit, after
-- fix/play_again_queue.lua and fix/switch_now.lua: python tools/run_luau_at.py <studio_id> fix/survey1025_security.lua [UNDO]
--   (1) lobby  MatchmakingManager FindMatch refused while the CALLER is InMatch / DuelMatch / InDuel (it only checked the party,
--              so a solo pad duelist could join an online search mid-duel and get teleported out of it).
--              The match places' copy is not touched: PLAYQUEUE round 2 took FindMatch off the Request remote there and only
--              RoundManager's Play Again calls it, during the results (when InMatch is still set on purpose).
--   (6) all    CombatManager SelectWeapon checks PlayerStore.Owns (the lobby had it since pass 37; the match places let any client
--              equip any gun on a server where LiveMatch is off, e.g. a reject server).
--   (8) all    ProcessReceipt returns PurchaseGranted only once the save holding the receipt has landed (ProfileService
--              MetaTagsLatest). Before, it returned at once: a crash right after a purchase lost what the player paid for.
--   (7) lobby  the pass-44 AssetCheck diagnostic (ServerScriptService.AssetCheckServer + StarterPlayerScripts.AssetCheck) is
--              moved to ServerStorage._Survey1025Disabled (restorable; UNDO puts it back): it preloaded the whole LobbyMap on
--              every client at every join and let any client write a 4,000-character warn into the server log.
-- Idempotent: every edit is checked before anything is written; an edit already in (or the lobby's own equivalent) counts as
-- applied. Edits this installer wrote are listed in the script's attribute Survey1025Edits; UNDO reverts only those.
-- Backups of the first-touched sources: ServerStorage._RebuildRemoved.SURVEY1025_<name>_Orig.
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local SP = game:GetService("StarterPlayer")
local IS_MATCH = RS:FindFirstChild("PlaceKind") ~= nil
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil and not IS_MATCH
assert(IS_MATCH or IS_LOBBY, "survey1025: not the lobby (Workspace.LobbyMap) and not a split match place (ReplicatedStorage.PlaceKind)")
local WHERE = IS_LOBBY and "lobby" or "match"
local out = { (UNDO and "UNDO " or "") .. "SURVEY1025 security (" .. WHERE .. (IS_MATCH and (" " .. tostring(RS.PlaceKind.Value)) or "") .. "):" }

local function managers()
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	return init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
end
local function manager(name) local m = managers(); return m and m:FindFirstChild(name) end

-------------------------------------------------------------------------------------------------------------------------------
-- edits: { where = "lobby" | "match" | "all", id, old, new, already = text that means "the place has its own equivalent" }
-------------------------------------------------------------------------------------------------------------------------------
local PATCHES = {
	{ key = "MatchmakingManager", find = function() return manager("MatchmakingManager") end, edits = {
		{ id = "s1", where = "lobby",
			old = [====[Remotes.Handlers.FindMatch = function(player, queueId)
	local q = Config.QueueById(queueId)
	if not q then return { ok = false, msg = "Unknown queue" } end
]====],
			new = [====[Remotes.Handlers.FindMatch = function(player, queueId)
	local q = Config.QueueById(queueId)
	if not q then return { ok = false, msg = "Unknown queue" } end
	-- [SURVEY1025] (1) not while YOU are in a match or a pad duel (the party check below only looks at your party): a solo pad
	-- duelist could start an online search mid-duel and be teleported out of it
	if player:GetAttribute("InMatch") or player:GetAttribute("DuelMatch") or player:GetAttribute("InDuel") then
		return { ok = false, msg = "You're in a match right now!" }
	end
]====] },
	} },
	{ key = "CombatManager", find = function() return manager("CombatManager") end, edits = {
		{ id = "s6", where = "all", already = [====[not PlayerStore.Owns(player, weaponId) then return end]====],
			old = [====[	if type(weaponId) ~= "string" or not table.find(WeaponConfig.Loadout, weaponId) then return end
	if ReplicatedStorage:GetAttribute("CombatEnabled") == true and not RunService:IsStudio() then return end
	if ReplicatedStorage:GetAttribute("LiveMatch") then return end]====],
			new = [====[	if type(weaponId) ~= "string" or not table.find(WeaponConfig.Loadout, weaponId) then return end
	-- [SURVEY1025] (6) only guns this player owns (the lobby's pass-37 check; a client could ask for any gun where LiveMatch is off)
	local okPS, PlayerStore = pcall(require, game:GetService("ServerScriptService"):WaitForChild("Data"):WaitForChild("PlayerStore"))
	if not (okPS and PlayerStore and PlayerStore.Owns) or not PlayerStore.Owns(player, weaponId) then return end -- fails closed
	if ReplicatedStorage:GetAttribute("CombatEnabled") == true and not RunService:IsStudio() then return end
	if ReplicatedStorage:GetAttribute("LiveMatch") then return end]====] },
	} },
	{ key = "LobbyManager", find = function() return manager("LobbyManager") end, edits = {
		{ id = "s8a", where = "all",
			old = [====[-- Developer product receipts. Each PurchaseId is granted exactly once (remembered in the profile).
]====],
			new = [====[-- [SURVEY1025] (8) a purchase counts as granted only once the profile save holding its receipt has landed (ProfileService's
-- MetaTagsLatest, as its docs advise for purchases). Before, PurchaseGranted went back before any save, so a server crash
-- right after a purchase lost what the player paid for. No confirmed save within ~20 s, or the profile is released for a
-- teleport: NotProcessedYet, and Roblox asks again later (the Receipts entry makes that retry a save check, never a 2nd grant).
local function receiptProfile(player: Player)
	local okDM, DM = pcall(function() return require(game:GetService("ServerScriptService").Data.DataManager) end)
	local profile = okDM and type(DM) == "table" and DM.Profiles and DM.Profiles[player]
	if profile and profile:IsActive() then return profile end
	return nil
end
local function receiptSaved(player: Player): boolean
	local profile = receiptProfile(player)
	if not profile then return false end
	local seq = (tonumber(profile:GetMetaTag("ReceiptSeq")) or 0) + 1
	profile:SetMetaTag("ReceiptSeq", seq)
	local function landed(): boolean
		local latest = profile.MetaData and profile.MetaData.MetaTagsLatest
		return type(latest) == "table" and (tonumber(latest.ReceiptSeq) or 0) >= seq
	end
	local deadline, nextSave = os.clock() + 20, 0
	while not landed() and os.clock() < deadline do
		if os.clock() >= nextSave and profile:IsActive() then
			profile:Save()
			nextSave = os.clock() + 6
		end
		task.wait(0.1)
	end
	return landed() and profile:IsActive() -- a session lost mid-wait reads another server's tags: let the next server confirm
end

-- Developer product receipts. Each PurchaseId is granted exactly once (remembered in the profile).
]====] },
		{ id = "s8b", where = "all",
			old = [====[	if data.Receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	grantProduct(player, product)
]====],
			new = [====[	-- [SURVEY1025] (8) a profile released for a teleport can't save a grant here: the next server takes the purchase
	if not receiptProfile(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if data.Receipts[info.PurchaseId] then
		if receiptSaved(player) then return Enum.ProductPurchaseDecision.PurchaseGranted end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(player, product)
]====] },
		{ id = "s8c", where = "all",
			old = [====[	PlayerStore.Set(player, { "Receipts", info.PurchaseId }, os.time())
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
]====],
			new = [====[	PlayerStore.Set(player, { "Receipts", info.PurchaseId }, os.time())
	if receiptSaved(player) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	warn("[LobbyManager] receipt " .. tostring(info.PurchaseId) .. " for " .. player.Name .. " not saved yet: Roblox will retry")
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
MarketplaceService.ProcessReceipt = processReceipt
if IS_STUDIO then
	-- [SURVEY1025] Studio only: a fake receipt through the real handler (product ids are still 0, so the product is mapped to a
	-- temporary negative id for the call). ServerStorage.ReceiptTestHook:Invoke(userId, purchaseId, productKey) -> decision name
	local hook = game:GetService("ServerStorage"):FindFirstChild("ReceiptTestHook") or Instance.new("BindableFunction")
	hook.Name = "ReceiptTestHook"
	hook.OnInvoke = function(userId, purchaseId, key)
		local product
		for _, p in allProducts() do if p.Key == key then product = p end end
		if not product then return "no product " .. tostring(key) end
		local fakeId = -424242
		local old = productsById[fakeId]
		productsById[fakeId] = product
		local ok, res = pcall(processReceipt, { PlayerId = userId, PurchaseId = purchaseId, ProductId = fakeId })
		productsById[fakeId] = old
		if not ok then return "error: " .. tostring(res) end
		return res.Name
	end
	hook.Parent = game:GetService("ServerStorage")
end
]====] },
		{ id = "s8d", where = "all",
			old = [====[MarketplaceService.ProcessReceipt = function(info)
]====],
			new = [====[local function processReceipt(info) -- [SURVEY1025] named (assigned below) so the Studio receipt test hook can call it
]====] },
	} },
}

-------------------------------------------------------------------------------------------------------------------------------
-- the source edits: work out every new source first (assert), then write
-------------------------------------------------------------------------------------------------------------------------------
local writes = {}
for _, P in PATCHES do
	local applicable = {}
	for _, e in P.edits do if e.where == "all" or e.where == WHERE then table.insert(applicable, e) end end
	if #applicable == 0 then
		table.insert(out, P.key .. " n/a")
		continue
	end
	local inst = P.find()
	assert(inst and inst:IsA("LuaSourceContainer"), "survey1025: " .. P.key .. " not found")
	local src = inst.Source:gsub("\r\n", "\n")
	local mine = {}
	for id in string.gmatch(inst:GetAttribute("Survey1025Edits") or "", "[^,]+") do mine[id] = true end
	local s = src
	for _, e in applicable do
		if UNDO then
			if not mine[e.id] then
				table.insert(out, P.key .. " " .. e.id .. " not mine")
			elseif not s:find(e.new, 1, true) then
				-- the recorded edit's text isn't there: a later version of this installer changed it. Stop rather than forget
				-- the id (forgetting it would leave the old text in with nothing able to undo it): UNDO with the installer
				-- version that wrote it (git), then re-run.
				error("survey1025: " .. P.key .. " " .. e.id .. " is recorded as installed but its text differs: UNDO with the version that installed it")
			else
				local a, b = s:find(e.new, 1, true)
				assert(not s:find(e.new, b + 1, true), "survey1025: " .. P.key .. " " .. e.id .. " new text not unique (UNDO)")
				s = s:sub(1, a - 1) .. e.old .. s:sub(b + 1)
				mine[e.id] = nil
				table.insert(out, P.key .. " " .. e.id .. " -")
			end
		elseif s:find(e.new, 1, true) then
			table.insert(out, P.key .. " " .. e.id .. " =")
		elseif e.already and s:find(e.already, 1, true) then
			table.insert(out, P.key .. " " .. e.id .. " = (own)")
		else
			local a, b = s:find(e.old, 1, true)
			assert(a, "survey1025: " .. P.key .. " " .. e.id .. " anchor not found")
			assert(not s:find(e.old, b + 1, true), "survey1025: " .. P.key .. " " .. e.id .. " anchor not unique")
			s = s:sub(1, a - 1) .. e.new .. s:sub(b + 1)
			mine[e.id] = true
			table.insert(out, P.key .. " " .. e.id .. " +")
		end
	end
	if s ~= src then
		local f, err = loadstring(s)
		assert(f, "survey1025: " .. P.key .. " would not parse: " .. tostring(err))
	end
	local ids = {}
	for id in mine do table.insert(ids, id) end
	table.sort(ids)
	table.insert(writes, { inst = inst, src = src, s = s, ids = table.concat(ids, ",") })
end

local function backup(inst)
	local folder = SS:FindFirstChild("_RebuildRemoved")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_RebuildRemoved"
		folder.Parent = SS
	end
	local name = "SURVEY1025_" .. inst.Name .. "_Orig"
	if folder:FindFirstChild(name) then return end
	local b = inst:Clone()
	b.Name = name
	if b:IsA("BaseScript") then b.Disabled = true end
	b.Parent = folder
end
for _, w in writes do
	if w.s ~= w.src then
		if not UNDO then backup(w.inst) end
		w.inst.Source = w.s
	end
	w.inst:SetAttribute("Survey1025Edits", w.ids ~= "" and w.ids or nil)
end

-------------------------------------------------------------------------------------------------------------------------------
-- (7) the pass-44 AssetCheck diagnostic (lobby): parked in ServerStorage._Survey1025Disabled, restorable
-------------------------------------------------------------------------------------------------------------------------------
if IS_LOBBY then
	local SPS = SP:FindFirstChild("StarterPlayerScripts")
	local items = {
		{ name = "AssetCheckServer", home = SSS },
		{ name = "AssetCheck", home = SPS },
	}
	local park = SS:FindFirstChild("_Survey1025Disabled")
	for _, it in items do
		local live = it.home and it.home:FindFirstChild(it.name)
		local parked = park and park:FindFirstChild(it.name)
		if UNDO then
			if parked and it.home and not live then
				parked.Parent = it.home
				table.insert(out, it.name .. " restored")
			else
				table.insert(out, it.name .. " " .. (live and "already live" or "nothing parked"))
			end
		elseif live then
			if not park then
				park = Instance.new("Folder")
				park.Name = "_Survey1025Disabled"
				park:SetAttribute("Note", "[SURVEY1025] (7) pass-44 AssetCheck diagnostic, parked 2026-10-25; fix/survey1025_security.lua UNDO restores it")
				park.Parent = SS
			end
			assert(not parked, "survey1025: both a live and a parked " .. it.name)
			live:SetAttribute("Survey1025Home", live.Parent:GetFullName())
			live.Parent = park
			table.insert(out, it.name .. " parked")
		else
			table.insert(out, it.name .. " " .. (parked and "= parked" or "absent"))
		end
	end
	if UNDO and park and #park:GetChildren() == 0 then park:Destroy() end
else
	table.insert(out, "AssetCheck n/a")
end

return table.concat(out, " | ")
