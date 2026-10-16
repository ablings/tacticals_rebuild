-- AdminFramework/Commands/Data: profile commands. Every write goes through DataAdapter (PlayerStore / the player's Replica),
-- so it saves with ProfileService and the HUD (LobbyHudController / LobbyUIController listen to the replica) updates at once.
local Players = game:GetService("Players")

local P = { name = "player", type = "players", defaultToken = "me" }
local WIPE_PARTS = { "all", "stats", "level", "inventory", "credits", "missions", "cooldowns", "settings" }

-- run fn(player) for every target whose data has loaded; returns the names done and the names skipped
local function each(ctx, list, fn)
	local done, skipped = {}, {}
	for _, p in list do
		if ctx.Data.Ready(p) then
			local note = fn(p)
			table.insert(done, note and (p.Name .. " " .. note) or p.Name)
			ctx.Data.Refresh(p)
		else
			table.insert(skipped, p.Name)
		end
	end
	if #skipped > 0 then ctx.reply("data not loaded yet for " .. table.concat(skipped, ", ") .. " (try again in a second)") end
	return done
end

local function tellTarget(ctx, p, text)
	if p ~= ctx.caller and ctx.Core.Notify then ctx.Core.Notify(p, "An admin " .. text, "info") end
end

local function levelLine(D, xp)
	local level, into, need = D.LevelOf(xp)
	return ("LV %d (%d XP, %d/%d to next)"):format(level, xp, into, need)
end

-- what each wipe part resets (profile keys back to their template defaults)
local function wipePart(D, p, part)
	local function reset(key) D.Set(p, { key }, D.Default(key)) end
	if part == "stats" or part == "all" then reset("Stats"); reset("Ranked") end
	if part == "level" or part == "all" then reset("XP"); reset("ItemXP") end
	if part == "inventory" or part == "all" then
		reset("Owned"); reset("Favorites"); reset("ItemXP"); D.Set(p, { "Loadout" }, D.DefaultLoadout())
	end
	if part == "credits" or part == "all" then reset("Credits") end
	if part == "missions" or part == "all" then reset("Quests") end
	if part == "cooldowns" or part == "all" then D.Set(p, { "DuelPairs" }, {}) end
	if part == "settings" or part == "all" then reset("Settings") end
	if part == "all" then reset("RedeemedCodes") end
	if part == "missions" or part == "all" then
		local LM = workspace:FindFirstChild("LobbyMap") and D.Lobby("LobbyManager") or nil
		if LM and LM.EnsureQuests then pcall(LM.EnsureQuests, p) end -- new missions at once (the lobby also re-rolls every 30 s)
	end
end

local function questSummary(data)
	local bits = {}
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests and data.Quests[scope]
		local n, claimed = 0, 0
		for _, e in (q and q.List or {}) do n += 1; if e.Claimed then claimed += 1 end end
		table.insert(bits, ("%s %d (%d claimed)"):format(string.lower(scope), n, claimed))
	end
	return table.concat(bits, ", ")
end

return {
	{
		name = "stats", aliases = { "profile" }, level = "Tester",
		description = "Print a player's profile summary (level, XP, scissors, items, stats, ranked, missions, cooldowns).",
		args = { { name = "player", type = "player", defaultToken = "me" } },
		anyTarget = true, -- reading is harmless
		run = function(ctx, a)
			local D, p = ctx.Data, a.player
			local data = D.Get(p)
			if not data then return false, p.Name .. "'s data hasn't loaded yet" end
			local owned, total = 0, 0
			for id, item in D.Items() do total += 1; if D.Owns(p, id) then owned += 1 end end
			local s = data.Stats or {}
			ctx.reply(("%s (@%d): %s, %d scissors"):format(p.Name, p.UserId, levelLine(D, tonumber(data.XP) or 0), data.Credits or 0))
			ctx.reply(("items %d/%d owned, loadout %s / %s / %s"):format(owned, total, tostring(data.Loadout and data.Loadout.Weapon),
				tostring(data.Loadout and data.Loadout.Gadget), tostring(data.Loadout and data.Loadout.Melee)))
			local sb = {}
			for _, k in { "MatchesPlayed", "Wins", "Kills", "Headshots", "MeleeKills", "CoverKills", "GadgetsThrown" } do
				table.insert(sb, k .. " " .. tostring(s[k] or 0))
			end
			ctx.reply("stats: " .. table.concat(sb, ", "))
			local rb = {}
			for mode, r in (data.Ranked or {}) do
				if type(r) == "table" then table.insert(rb, ("%s SR %s W%s L%s"):format(mode, tostring(r.Rating), tostring(r.Wins or 0), tostring(r.Losses or 0))) end
			end
			local cd = 0
			for _ in (type(data.DuelPairs) == "table" and data.DuelPairs or {}) do cd += 1 end
			ctx.reply(("ranked: %s; missions: %s; duel reward cooldowns: %d"):format(#rb > 0 and table.concat(rb, ", ") or "none",
				questSummary(data), cd))
			return true
		end,
	},
	{
		name = "wipe", level = "Admin", destructive = true,
		description = "Reset profile data to the defaults: all, stats (Stats + Ranked), level (XP + gun XP), inventory (owned, loadout, favourites, gun XP), credits, missions, cooldowns, settings. Purchases (Passes, Receipts) and TutorialDone are never wiped.",
		args = { P, { name = "what", type = "choice", choices = WIPE_PARTS, optional = true, default = "all" } },
		confirmText = function(ctx, a)
			local names = {}
			for _, p in a.player do table.insert(names, p.Name) end
			return ("wipe %s of %s"):format(a.what, table.concat(names, ", "))
		end,
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				wipePart(ctx.Data, p, a.what)
				tellTarget(ctx, p, "wiped your " .. a.what .. " data.")
			end)
			return #done > 0, ("Wiped %s for %s."):format(a.what, table.concat(done, ", "))
		end,
	},
	{
		name = "setlevel", aliases = { "level" }, level = "Tester",
		description = "Set the account level: XP becomes exactly that level's threshold.",
		args = { P, { name = "level", type = "integer", min = 1 } },
		run = function(ctx, a)
			local D = ctx.Data
			local lv = math.min(a.level, D.MaxLevel())
			local xp = D.XPForLevel(lv)
			local done = each(ctx, a.player, function(p) D.Set(p, { "XP" }, xp); tellTarget(ctx, p, "set your level to " .. lv .. ".") end)
			return #done > 0, ("Level %d (%d XP) for %s."):format(lv, xp, table.concat(done, ", "))
		end,
	},
	{
		name = "addxp", level = "Tester", description = "Add (or with a negative number remove) account XP.",
		args = { P, { name = "xp", type = "integer" } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p)
				local cur = tonumber(D.Read(p, { "XP" })) or 0
				local new = math.max(0, cur + a.xp)
				D.Set(p, { "XP" }, new)
				return "-> " .. levelLine(D, new)
			end)
			return #done > 0, ("%+d XP: %s."):format(a.xp, table.concat(done, "; "))
		end,
	},
	{
		name = "setxp", level = "Tester", description = "Set account XP to an exact number.",
		args = { P, { name = "xp", type = "integer", min = 0 } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p) D.Set(p, { "XP" }, a.xp) end)
			return #done > 0, ("XP = %d (%s) for %s."):format(a.xp, levelLine(D, a.xp), table.concat(done, ", "))
		end,
	},
	{
		name = "setcredits", aliases = { "setscissors" }, level = "Tester", description = "Set scissors (Credits) to an exact amount.",
		args = { P, { name = "amount", type = "integer", min = 0 } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p) ctx.Data.Set(p, { "Credits" }, a.amount); tellTarget(ctx, p, "set your scissors to " .. a.amount .. ".") end)
			return #done > 0, ("Scissors = %d for %s."):format(a.amount, table.concat(done, ", "))
		end,
	},
	{
		name = "addcredits", aliases = { "addscissors" }, level = "Tester", description = "Add (negative: take) scissors; never below 0.",
		args = { P, { name = "amount", type = "integer" } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p)
				local cur = tonumber(D.Read(p, { "Credits" })) or 0
				local new = math.max(0, cur + a.amount)
				D.Set(p, { "Credits" }, new)
				tellTarget(ctx, p, (a.amount >= 0 and "gave you %d scissors." or "took %d scissors."):format(math.abs(new - cur)))
				return "-> " .. new
			end)
			return #done > 0, ("%+d scissors: %s."):format(a.amount, table.concat(done, "; "))
		end,
	},
	{
		name = "setstat", level = "Tester",
		description = "Set a stat: MatchesPlayed, Wins, Kills, Headshots, CoverKills, MeleeKills, GadgetsThrown, Rating1v1/2v2/3v3, RankedWins<mode>, RankedLosses<mode>, XP, Credits.",
		args = { P, { name = "stat", type = "stat" }, { name = "value", type = "integer" } },
		run = function(ctx, a)
			local D, st = ctx.Data, a.stat
			local done = each(ctx, a.player, function(p)
				if st.ranked then D.SetRanked(p, st.ranked, st.field, a.value) else D.Set(p, st.path, a.value) end
			end)
			return #done > 0, ("%s = %d for %s."):format(st.name, a.value, table.concat(done, ", "))
		end,
	},
	{
		name = "give", aliases = { "grant" }, level = "Tester",
		description = "Give an item (id or name). Old form: ;give <player> <number> gives scissors.",
		args = { P, { name = "item", type = "string" } },
		run = function(ctx, a)
			local D = ctx.Data
			local amount = tonumber(a.item)
			if amount then -- the old AdminCommands /give name 500
				amount = math.floor(amount)
				local done = each(ctx, a.player, function(p)
					local cur = tonumber(D.Read(p, { "Credits" })) or 0
					D.Set(p, { "Credits" }, math.max(0, cur + amount))
					tellTarget(ctx, p, (amount >= 0 and "gave you %d scissors." or "took %d scissors."):format(math.abs(amount)))
				end)
				return #done > 0, ("Gave %d scissors to %s."):format(amount, table.concat(done, ", "))
			end
			local id, item = D.FindItem(a.item)
			if not id then return false, item end
			if item.Default then return false, id .. " is a default item: everyone always owns it" end
			local done = each(ctx, a.player, function(p)
				if D.Owns(p, id) then return "(already owned)" end
				D.Set(p, { "Owned", id }, true)
				tellTarget(ctx, p, "gave you " .. (item.Name or id) .. ".")
			end)
			return #done > 0, ("Gave %s to %s."):format(id, table.concat(done, ", "))
		end,
	},
	{
		name = "take", aliases = { "revoke" }, level = "Tester",
		description = "Take an item away (if it's equipped, that slot goes back to the default item).",
		args = { P, { name = "item", type = "item" } },
		run = function(ctx, a)
			local D, id = ctx.Data, a.item
			local item = D.Items()[id]
			if item.Default then return false, id .. " is a default item and can't be taken" end
			local def = D.DefaultLoadout()
			local done = each(ctx, a.player, function(p)
				if not D.Owns(p, id) then return "(didn't own it)" end
				D.Set(p, { "Owned", id }, nil)
				if D.Read(p, { "Loadout", item.Slot }) == id then D.Set(p, { "Loadout", item.Slot }, def[item.Slot]) end
				if D.Read(p, { "Favorites", id }) then D.Set(p, { "Favorites", id }, nil) end
			end)
			return #done > 0, ("Took %s from %s."):format(id, table.concat(done, ", "))
		end,
	},
	{
		name = "giveall", aliases = { "unlockall" }, level = "Tester", description = "Own every item in the catalogue.",
		args = { P },
		run = function(ctx, a)
			local D = ctx.Data
			if not D.HasCatalogue then return false, "this place has no item catalogue" end
			local done = each(ctx, a.player, function(p)
				local n = 0
				for id, item in D.Items() do
					if not item.Default and not D.Owns(p, id) then D.Set(p, { "Owned", id }, true); n += 1 end
				end
				return "+" .. n
			end)
			return #done > 0, ("Unlocked every item: %s."):format(table.concat(done, ", "))
		end,
	},
	{
		name = "resetcooldowns", aliases = { "resetcd" }, level = "Tester",
		description = "Clear the duel reward cooldowns (DuelPairs: one paid match per opponent pair per 10 min).",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local n = 0
				for _ in (type(ctx.Data.Read(p, { "DuelPairs" })) == "table" and ctx.Data.Read(p, { "DuelPairs" }) or {}) do n += 1 end
				ctx.Data.Set(p, { "DuelPairs" }, {})
				return "(" .. n .. " cleared)"
			end)
			return #done > 0, "Duel reward cooldowns reset: " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "missions", aliases = { "quests" }, level = "Tester",
		description = "reset = new daily + weekly missions now; complete = every unclaimed mission finished (ready to claim).",
		args = { P, { name = "action", type = "choice", choices = { "reset", "complete" } } },
		run = function(ctx, a)
			local D = ctx.Data
			local LC = D.LobbyConfig
			local done = each(ctx, a.player, function(p)
				if a.action == "reset" then
					wipePart(D, p, "missions")
					return
				end
				if not LC or not LC.Quests then error("this place has no mission list") end
				local n = 0
				for _, scope in { "Daily", "Weekly" } do
					local q = D.Read(p, { "Quests", scope })
					for i, e in (type(q) == "table" and q.List or {}) do
						local def
						for _, d in LC.Quests[scope].Pool do if d.Id == e.Id then def = d end end
						if def and not e.Claimed then
							local stat = tonumber(D.Read(p, { "Stats", def.Stat })) or 0
							-- progress = Stats[stat] - Base; Base low enough that progress = Goal
							D.Set(p, { "Quests", scope, "List", i, "Base" }, stat - def.Goal)
							n += 1
						end
					end
				end
				return "(" .. n .. " ready to claim)"
			end)
			return #done > 0, ("Missions %s: %s."):format(a.action, table.concat(done, ", "))
		end,
	},
}
