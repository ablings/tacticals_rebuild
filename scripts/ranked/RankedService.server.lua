-- ServerScriptService/RankedService (Script) [RANKED] 2026-10-16, notes/ranked_server.md
-- Boots ServerScriptService.Shared.RankedServer in this place (lobby or match place): join migration + Rank* attributes,
-- decay (flag), and the leaderboard refresh (RankedTop_<ladder> / RankedCutoff_<ladder> every ~2 min).
-- Studio only: ServerStorage.RankedTestHook (BindableFunction) drives the tests from the MCP (the MCP's own VM has its own
-- module cache, so it can't call this VM's RankedServer directly).
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RankedServer = require(ServerScriptService:WaitForChild("Shared"):WaitForChild("RankedServer"))
local RankedCore = RankedServer.Core

RankedServer.Start()

if RunService:IsStudio() then
	local hook = ServerStorage:FindFirstChild("RankedTestHook") or Instance.new("BindableFunction")
	hook.Name = "RankedTestHook"
	hook.Parent = ServerStorage
	local function who(id) return Players:GetPlayerByUserId(tonumber(id) or 0) or Players:GetPlayers()[1] end
	hook.OnInvoke = function(cmd, a, b, c)
		if cmd == "attrs" then
			local p, out = who(a), {}
			for k, v in p:GetAttributes() do if k:sub(1, 4) == "Rank" then out[k] = v end end
			return out
		elseif cmd == "raw" then
			local d = RankedServer.GetData(who(a))
			return d and d.Ranked and d.Ranked[b]
		elseif cmd == "setraw" then
			return RankedServer.WriteRecord(who(a), b, c)
		elseif cmd == "record" then
			return (RankedServer.Record(who(a), b))
		elseif cmd == "last" then
			return RankedServer._last[who(a).UserId]
		elseif cmd == "config" then
			local old = RankedCore.Config[a]
			RankedCore.Config[a] = b
			return old
		elseif cmd == "seed" then
			-- a = ladder key, b = count, c = top elo: b fake entries from c down in steps of 1
			local store = RankedServer.Leaderboard.Store(a)
			for i = 1, b do RankedServer.Leaderboard.Write(a, 900000000 + i, c - (i - 1), "Fake" .. i) end
			return store.data ~= nil
		elseif cmd == "clearboard" then
			RankedServer.Leaderboard.stores[a] = nil
			RankedServer.Leaderboard.known[a] = nil
			return true
		elseif cmd == "refresh" then
			RankedServer.RefreshLeaderboards()
			local key = a or RankedCore.Config.DefaultMode
			local top = RankedServer.Leaderboard.top[key]
			return { count = top and #top or 0, cutoff = RankedServer.Leaderboard.cutoff[key], first = top and top[1], mock = RankedServer.Leaderboard.mock }
		elseif cmd == "apply" then
			-- a = userId, b = mode, c = { oppElo | oppTier, won, draw, ownTier? }
			local opp = tonumber(c.oppTier) or RankedCore.TierOf(c.oppElo)
			return RankedServer.ApplyResult(who(a), b, opp, c.won == true, c.draw == true, tonumber(c.ownTier))
		elseif cmd == "leave" then
			-- a = userId, b = mode, c = { oppElo | oppTier, ownTier? }
			local opp = tonumber(c.oppTier) or RankedCore.TierOf(c.oppElo)
			return RankedServer.ApplyLeave(who(a), b, opp, tonumber(c.ownTier), "test")
		elseif cmd == "pending" then
			-- a = userId, b = mode, c = { oppTier, ownTier?, job? }: mark; job = "other" fakes a match on another server
			local p = who(a)
			RankedServer.MarkPending(p, b, tonumber(c.oppTier) or 0, tonumber(c.ownTier))
			if c.job then
				local rec, key = RankedServer.Record(p, b)
				rec.Pending.job = c.job
				RankedServer.WriteRecord(p, key, rec)
			end
			return (RankedServer.Record(p, b)).Pending
		elseif cmd == "settle" then
			RankedServer.SettlePending(who(a))
			return RankedServer._last[who(a).UserId]
		elseif cmd == "decay" then
			RankedServer.ApplyDecay(who(a))
			RankedServer.ApplyAttributes(who(a))
			return (RankedServer.Record(who(a), b))
		end
		return "unknown " .. tostring(cmd)
	end
end
