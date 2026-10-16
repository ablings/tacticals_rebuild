-- AdminFramework/Commands/Duel: lobby pad duels (LobbyDuelManager). In a place without lobby duels these say so.
-- duelsolo sets the player attribute AdminDuelSolo (server-set; clients can't fake it). The [ADMIN] edits in QueueManager
-- (bayIsFull) and LobbyDuelManager (StartMatch) let a pad with such a player start alone and fill the empty places with
-- test bots, live as well as in Studio. A match with a test bot never pays rewards (match.hasBot, LobbyDuelManager.award).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local function ldm(ctx)
	local m = ctx.Data.Lobby("LobbyDuelManager")
	if not m or not m._matches then error("this place has no lobby duels (LobbyDuelManager)") end
	return m
end

local function matchConfig(ctx)
	return ctx.Data.MatchConfig or {}
end

local function describe(m)
	local mem = {}
	for side, list in m.teams do
		for _, x in list do table.insert(mem, side .. ":" .. tostring(x.name) .. (x.isBot and "(bot)" or "") .. (x.left and "(left)" or "")) end
	end
	local s = m.state
	return ("%s  %s slot %d  %s  %s-%s  [%s]"):format(m.id, m.mode, m.slot, tostring(s and s:GetAttribute("MatchState") or "?"),
		tostring(s and s:GetAttribute("ScoreA") or 0), tostring(s and s:GetAttribute("ScoreB") or 0), table.concat(mem, " "))
end

return {
	{
		name = "duelsolo", level = "Admin",
		description = "on: a duel pad you stand on starts with just you; empty places get test bots; bot matches never pay. Only for matches that include you.",
		args = { { name = "on", type = "boolean" }, { name = "player", type = "players", defaultToken = "me" } },
		run = function(ctx, a)
			local names = {}
			for _, p in a.player do
				local lv = ctx.Core.Permissions.LevelOf(p)
				if lv < ctx.Core.Permissions.Values.Admin then
					ctx.reply(p.Name .. " isn't an admin: duelsolo is admins only")
				else
					p:SetAttribute("AdminDuelSolo", a.on or nil)
					table.insert(names, p.Name)
				end
			end
			if RunService:IsStudio() then
				-- Studio: also the old global switch (LobbyDuelManager._TestSolo / the DuelTestHook use it)
				ReplicatedStorage:SetAttribute("DuelTestSolo", a.on or nil)
			end
			if #names == 0 then return false, "nobody changed" end
			return true, ("Duel solo %s for %s. %s"):format(a.on and "ON" or "off", table.concat(names, ", "),
				a.on and "Stand on a pad: it counts down alone, bots fill the rest, no rewards." or "")
		end,
	},
	{
		name = "listmatches", aliases = { "matches", "duels" }, level = "Tester", description = "Running lobby duel matches.",
		run = function(ctx)
			local m = ldm(ctx)
			local n = 0
			for _, match in m._matches do n += 1; ctx.reply(describe(match)) end
			if n == 0 then return true, "No lobby duels running." end
			return true, n .. " match(es)."
		end,
	},
	{
		name = "endmatch", aliases = { "stopmatch" }, level = "Admin",
		description = "End a lobby duel now (match id like D3, or a player in it). Everyone goes back to the pads; nobody is paid.",
		args = { { name = "match", type = "string" } },
		run = function(ctx, a)
			local m = ldm(ctx)
			local id = string.upper(a.match)
			if not m._matches[id] then
				local list = ctx.Core.Args.Players(a.match, ctx)
				local p = list and list[1]
				id = p and p:GetAttribute("DuelMatch")
				if not id then return false, ("no match \"%s\" (and no player in a duel by that name)"):format(a.match) end
			end
			if not m._matches[id] then return false, "match " .. tostring(id) .. " is already over" end
			-- both sides leave: the match ends as a forfeit with nobody present, so award() pays nobody
			m._TestForfeit(id, "A")
			m._TestForfeit(id, "B")
			return true, ("Ending %s: players are being returned to the pads."):format(id)
		end,
	},
	{
		name = "arenas", level = "Tester", description = "Arena slots and the duel maps (modes per map).",
		run = function(ctx)
			local m = ldm(ctx)
			local C = matchConfig(ctx)
			local sl = {}
			for n = 1, C.MaxArenas or 6 do sl[n] = n .. ":" .. tostring(m._slots[n] or "free") end
			ctx.reply("slots " .. table.concat(sl, "  "))
			local ok, MapRegistry = pcall(require, ReplicatedStorage.Modules.Shared.MapRegistry)
			if ok then
				for _, info in MapRegistry.List() do
					ctx.reply(("map %s (%s): modes %s"):format(info.Id, tostring(info.DisplayName), table.concat(info.Modes or {}, ",")))
				end
			end
			return true, ("in-lobby duels %s, solo test %s"):format(C.PadDuelsInLobby and "on" or "OFF",
				tostring(ReplicatedStorage:GetAttribute("DuelTestSolo") == true))
		end,
	},
}
