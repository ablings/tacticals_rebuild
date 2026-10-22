-- fix/duels_tv_spectators.lua [DUELSPEC] 2026-10-21 (lobby only): the Duels TV rows show an eye + spectator count when an entry
-- carries `sp` (UI session, LobbyScreensController). LobbyFeaturesManager now remembers the occupant user ids of each pad duel it
-- starts and, every feed tick, counts the players whose DuelSpectate is that duel's id (the fighters carry DuelMatch = the id).
-- Online / remote / finished duels get sp = nil (eye hidden). Same edits as scripts/features/LobbyFeaturesManager.lua.
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local M = game:GetService("ServerScriptService"):FindFirstChild("LobbyFeaturesManager", true)
assert(M, "no LobbyFeaturesManager")
local edits = {
	{ [==[				local a, bb = {}, {}
				for _, o in b.occupants or {} do table.insert(o.t == "A" and a or bb, nameOf(o.u)) end
				local e = { k = game.JobId .. ":" .. key .. ":" .. os.time(), m = b.mode, r = b.ranked == true, a = a, b = bb, t = os.time(), s = "pad" }
				addLive(e); publish(e)
]==], [==[				local a, bb, us = {}, {}, {}
				for _, o in b.occupants or {} do table.insert(o.t == "A" and a or bb, nameOf(o.u)); table.insert(us, o.u) end
				local e = { k = game.JobId .. ":" .. key .. ":" .. os.time(), m = b.mode, r = b.ranked == true, a = a, b = bb, t = os.time(), s = "pad" }
				addLive(e); publish(e)
				padUids[e.k] = us -- [DUELSPEC]
]==] },
	{ [==[	local prevState = {}
	local lastJson
]==], [==[	local prevState = {}
	local padUids = {} -- [DUELSPEC] [entry key] = occupant user ids of a pad duel started on this server
	local lastJson
]==] },
	-- (2026-10-21) 0 watchers: no eye; the row keeps "ON A PAD"
	{ [==[				x.sp = n
			else
]==], [==[				-- nobody watching: no eye, the row keeps its "ON A PAD" line
				x.sp = n > 0 and n or nil
			else
]==], true },
	{ [==[		for _, x in live do if os.time() - x.t < cfg.MatchMinutes * 60 then table.insert(keep, x) end end
		live = keep
]==], [==[		for _, x in live do if os.time() - x.t < cfg.MatchMinutes * 60 then table.insert(keep, x) end end
		live = keep
		-- [DUELSPEC] spectator count per in-hub duel: players whose DuelSpectate is that duel's id (its fighters carry DuelMatch).
		-- Online / remote duels and finished ones get no count (sp = nil hides the eye on the Duels TV row).
		local stillUids = {}
		for _, x in live do
			local id
			for _, u in padUids[x.k] or {} do
				local pl = Players:GetPlayerByUserId(u)
				id = id or (pl and pl:GetAttribute("DuelMatch"))
			end
			if id then
				local n = 0
				for _, pl in Players:GetPlayers() do if pl:GetAttribute("DuelSpectate") == id then n += 1 end end
				-- nobody watching: no eye, the row keeps its "ON A PAD" line
				x.sp = n > 0 and n or nil
			else
				x.sp = nil
			end
			stillUids[x.k] = padUids[x.k]
		end
		padUids = stillUids
]==], true },
}
local s = M.Source:gsub("\r\n", "\n")
local out = {}
for i, e in edits do
	local old, new = e[1], e[2]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then table.insert(out, i .. "=")
	elseif e[3] and not s:find(old, 1, true) then
		-- optional: edit 3 (the 0-watchers upgrade) has nothing to upgrade on a fresh copy; edit 4 then inserts the final block
		table.insert(out, i .. "-")
	else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "LobbyFeaturesManager would not parse: " .. tostring(err))
if M.Source ~= s then M.Source = s end
return "LobbyFeaturesManager " .. table.concat(out, " ")
