-- AdminFramework/Commands/Debug: help, whoami, serverinfo, audit, simlevel (Studio).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local started = os.clock()

return {
	{
		name = "cmds", aliases = { "help", "commands", "?" }, level = "Tester",
		description = "List the commands you can use, or ;help <command> for one.",
		args = { { name = "command", type = "string", optional = true } },
		run = function(ctx, a)
			local Core = ctx.Core
			if a.command then
				local def = Core.ByName[string.lower((string.gsub(a.command, "^[;/]", "")))]
				if not def then return false, "no command \"" .. a.command .. "\"" end
				ctx.reply(Core.Usage(def) .. "   (" .. def.level .. "+" .. (def.destructive and ", needs confirm" or "") ..
					(def.aliases and #def.aliases > 0 and (", aliases " .. table.concat(def.aliases, " ")) or "") .. ")")
				ctx.reply(def.description or "")
				return true
			end
			local groups, order = {}, {}
			for _, def in Core.Visible(ctx.level) do
				if not groups[def.group] then groups[def.group] = {}; table.insert(order, def.group) end
				table.insert(groups[def.group], def.name)
			end
			for _, g in order do ctx.reply(g .. ": " .. table.concat(groups[g], ", ")) end
			return true, ("You are %s. ;help <command> for details. Players: me, all, others, @userid, name."):format(ctx.levelName)
		end,
	},
	{
		name = "whoami", level = "Tester", description = "Your admin level and why.",
		run = function(ctx)
			local p = ctx.caller
			local Perm = ctx.Core.Permissions
			local real, realWhy = 0, "-"
			if p then real, realWhy = Perm.RealLevel(p) end
			return true, ("%s (@%s): %s via %s; live level %s via %s; group %d"):format(p and p.Name or "console", p and p.UserId or 0,
				ctx.levelName, tostring(ctx.why), Perm.Name(real), realWhy, Perm.GroupId())
		end,
	},
	{
		name = "serverinfo", aliases = { "server" }, level = "Tester", description = "Place, server, players, uptime, data store.",
		run = function(ctx)
			local D = ctx.Data
			local duels = 0
			local m = D.Lobby("LobbyDuelManager")
			for _ in (m and m._matches or {}) do duels += 1 end
			ctx.reply(("place %d v%d  job %s  %s"):format(game.PlaceId, game.PlaceVersion, game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "studio",
				RunService:IsStudio() and "STUDIO" or (game.PrivateServerId ~= "" and "private server" or "public server")))
			return true, ("%d player(s), up %d min, profile store \"%s\", lobby duels %d, audit store %s"):format(#Players:GetPlayers(),
				math.floor((os.clock() - started) / 60), D.StoreKey, duels, ctx.Core.Audit.StoreState())
		end,
	},
	{
		name = "audit", aliases = { "log" }, level = "Admin", description = "The last admin commands run on this server.",
		args = { { name = "count", type = "integer", min = 1, max = 30, optional = true, default = 8 } },
		run = function(ctx, a)
			for _, e in ctx.Core.Audit.Recent(a.count) do
				ctx.reply(("%s %s(%s) %s %s%s -> %s"):format(os.date("!%H:%M:%S", e.time), tostring(e.admin), tostring(e.level), e.command,
					e.args or "", e.targets and (" @" .. e.targets) or "", e.ok and "ok" or ("refused: " .. tostring(e.result))))
			end
			return true
		end,
	},
	{
		name = "dump", aliases = { "rawdata" }, level = "Admin", anyTarget = true,
		description = "Raw profile JSON (one key, or the key list). Read-only.",
		args = { { name = "player", type = "player", defaultToken = "me" }, { name = "key", type = "string", optional = true } },
		run = function(ctx, a)
			local data = ctx.Data.Get(a.player)
			if not data then return false, "data not loaded" end
			if not a.key then
				local keys = {}
				for k in data do table.insert(keys, tostring(k)) end
				table.sort(keys)
				return true, "keys: " .. table.concat(keys, ", ")
			end
			local key
			for k in data do if string.lower(tostring(k)) == string.lower(a.key) then key = k end end
			if key == nil then return false, "no key " .. a.key end
			local ok, json = pcall(HttpService.JSONEncode, HttpService, data[key])
			json = ok and json or tostring(data[key])
			for i = 1, math.min(#json, 1200), 300 do ctx.reply(string.sub(json, i, i + 299)) end
			return true, ("%s.%s (%d chars)"):format(a.player.Name, tostring(key), #json)
		end,
	},
	{
		name = "simlevel", level = "None", studioOnly = true, anyTarget = true, -- None: a simulated non-admin can still undo it
		description = "Studio only: pretend to have another admin level (None to test denial). Undo with ;simlevel owner",
		args = { { name = "level", type = "level" }, { name = "player", type = "player", defaultToken = "me" } },
		run = function(ctx, a)
			local ok, err = ctx.Core.Permissions.SetSimulated(a.player.UserId, a.level ~= ctx.Core.Config.StudioLevel and a.level or nil)
			if not ok then return false, err end
			return true, ("%s now counts as %s in this Studio test."):format(a.player.Name, a.level)
		end,
	},
}
