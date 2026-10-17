-- AdminFramework/Commands/Ranked: ranked ELO commands [RANKED] 2026-10-16 (notes/ranked_server.md).
-- They go through ServerScriptService.Shared.RankedServer (installed by fix/ranked_install.lua): the unified Ranked record,
-- the leaderboard write and the Rank* attributes, in both places.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function server()
	local s = ServerScriptService:FindFirstChild("Shared") and ServerScriptService.Shared:FindFirstChild("RankedServer")
	if not s then return nil end
	local ok, m = pcall(require, s)
	return ok and m or nil
end
local function core()
	local s = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules.Shared:FindFirstChild("RankedCore")
	if not s then return nil end
	local ok, m = pcall(require, s)
	return ok and m or nil
end
local NOT_INSTALLED = "The ranked system isn't installed in this place (fix/ranked_install.lua)."
local MODES = { "1v1", "2v2", "3v3" }

return {
	{
		name = "setelo", level = "Tester", description = "Set a player's ranked ELO (never below 100). Mode defaults to 1v1.",
		args = { { name = "player", type = "player" }, { name = "elo", type = "integer", min = 0, max = 100000 },
			{ name = "mode", type = "choice", choices = MODES, optional = true, default = "1v1" } },
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			local rec, key = RS.SetElo(a.player, a.elo, a.mode)
			if not rec then return false, "couldn't write " .. a.player.Name .. "'s ranked record" end
			local info = RS.InfoFor(key, rec, a.player.UserId)
			if a.player ~= ctx.caller and ctx.Core.Notify then ctx.Core.Notify(a.player, ("An admin set your %s ELO to %d."):format(key, rec.Elo), "info") end
			return true, ("%s %s: %d ELO = %s."):format(a.player.Name, key, rec.Elo, info.name)
		end,
	},
	{
		name = "rankreset", level = "Admin", destructive = true,
		description = "Reset a player's ranked record (one mode, or every ladder) to a new player's: 100 ELO, no wins / losses.",
		args = { { name = "player", type = "player" }, { name = "mode", type = "choice", choices = MODES, optional = true } },
		confirmText = function(_, v) return ("reset %s's ranked record (%s)"):format(v.player.Name, v.mode or "every ladder") end,
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			local done = RS.Reset(a.player, a.mode)
			return true, ("Ranked reset for %s: %s."):format(a.player.Name, table.concat(done, ", "))
		end,
	},
	{
		name = "rankinfo", aliases = { "elo" }, level = "Tester", anyTarget = true,
		description = "Show a player's ranked records (ELO, rank, peak, wins / losses, placements, shield) and the Warlord cutoff.",
		args = { { name = "player", type = "player", defaultToken = "me" } },
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			ctx.reply(a.player.Name .. " ranked:")
			for _, line in RS.Lines(a.player) do ctx.reply(line) end
			local bits = {}
			for _, key in RS.Core.LadderKeys() do
				local cut = RS.Leaderboard.cutoff[key]
				local top = RS.Leaderboard.top[key]
				table.insert(bits, ("%s %d at 2200+, cutoff %s"):format(key, top and #top or 0, cut and tostring(cut) or "none"))
			end
			return true, "Warlord: " .. table.concat(bits, "; ") .. (RS.Leaderboard.mock and " (mock store)" or "")
		end,
	},
	{
		name = "simrank", level = "Tester", anyTarget = true,
		description = "Print the ELO change for A (eloA) beating or losing to B (eloB), and B's side of it. Changes nothing.",
		args = { { name = "eloA", type = "integer", min = 0, max = 100000 }, { name = "eloB", type = "integer", min = 0, max = 100000 },
			{ name = "result", type = "choice", choices = { "win", "loss" } } },
		run = function(_, a)
			local RC = core()
			if not RC then return false, NOT_INSTALLED end
			local won = a.result == "win"
			local ea, eb = RC.ClampElo(a.eloA), RC.ClampElo(a.eloB)
			local da = RC.Delta(ea, RC.TierOf(eb), won)
			local db = RC.Delta(eb, RC.TierOf(ea), not won)
			local ia, ib = RC.Info(ea), RC.Info(eb)
			return true, ("A %s (%d) %s vs B %s (%d): A %+d -> %d, B %+d -> %d"):format(ia.name, ea, won and "wins" or "loses", ib.name, eb,
				da, math.max(RC.Config.Floor, ea + da), db, math.max(RC.Config.Floor, eb + db))
		end,
	},
}
