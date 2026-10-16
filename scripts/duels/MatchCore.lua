-- ServerScriptService/Shared/MatchCore (ModuleScript): the round rules of a team match, shared by the lobby's pad duels
-- (one MatchCore run per match, LobbyDuelManager) and, in phase 4, the match place's RoundManager (one per server).
-- Ported from the match place RoundManager (pass 38): playRound / playMatch / win rules / forfeit / kill tally / award maths.
-- Everything place-specific comes in through a context object, so the rules don't know where they run:
--   ctx.state            Instance  the state object (lobby: ReplicatedStorage.LobbyDuels.<id>; match place: ReplicatedStorage)
--   ctx.teams            { A = {member}, B = {member} }   member = { player = Player?, bot = Model?, userId, name }
--   ctx.mode, ctx.ranked
--   ctx.config           MatchConfig
--   ctx.announce(title, subtitle)               Events.Match.MatchAnnounce to the match's players (+ spectators)
--   ctx.spawnMember(member, team, slot) -> character?   respawn + place + MaxHealth
--   ctx.setFrozen(member, frozen)
--   ctx.isPresent(member) -> bool               false once a player left / disconnected
--   ctx.onRoundStart(roundNumber)               reset the arena (shootables, doors, smoke) of THIS match
--   ctx.onKill(info)                            kill feed {killer, victim, weapon, headshot, kind}
-- Published on ctx.state (names from notes/lobby_duels_design.md section 6; PhaseEndsAt == StateEndsAt always):
--   MatchState, MatchPhase, StateEndsAt, PhaseEndsAt, CombatEnabled, RoundNumber, RoundsToWin, ScoreA, ScoreB
-- Player (member) attributes: InMatch, Team, RoundWins, MatchKills, MatchDeaths, Alive
local MatchCore = {}

local PHASE_OF = { Loading = "Loading", MapVote = "MapVote", Loadout = "Loadout", Countdown = "Playing", Live = "Playing",
	RoundEnd = "Playing", MatchEnd = "Ended", Cancelled = "Ended" }

-- // Members (a Player, or a server test bot = an R15 Model) ---------------------------------------------------------
function MatchCore.attrHolder(m) return m.player or m.bot end
function MatchCore.setAttr(m, k, v) local h = MatchCore.attrHolder(m); if h then h:SetAttribute(k, v) end end
function MatchCore.getAttr(m, k) local h = MatchCore.attrHolder(m); return h and h:GetAttribute(k) end
function MatchCore.character(m) if m.player then return m.player.Character end return m.bot end
function MatchCore.humanoid(m) local c = MatchCore.character(m); return c and c:FindFirstChildOfClass("Humanoid") end
function MatchCore.isAlive(m)
	local h = MatchCore.humanoid(m)
	return h ~= nil and h.Health > 0 and MatchCore.getAttr(m, "Alive") ~= false
end

-- // State -----------------------------------------------------------------------------------------------------------
function MatchCore.setState(ctx, state: string, duration: number?)
	local ends = duration and (workspace:GetServerTimeNow() + duration) or 0
	local s = ctx.state
	s:SetAttribute("MatchState", state)
	s:SetAttribute("StateEndsAt", ends)
	s:SetAttribute("PhaseEndsAt", ends)
	s:SetAttribute("MatchPhase", PHASE_OF[state] or state)
	s:SetAttribute("CombatEnabled", state == "Live")
end

local function score(ctx, side) return ctx.state:GetAttribute("Score" .. side) or 0 end
local function scoreLine(ctx) return `{score(ctx, "A")} - {score(ctx, "B")}` end

-- // Kill tally (victim Humanoid attributes LastAttacker / LastHitZone / LastAttackKind set by Combat / Melee) -----------
function MatchCore.newTally() return {} end
local function t(ctx, uid)
	ctx.tally[uid] = ctx.tally[uid] or { kills = 0, headshots = 0, melee = 0, deaths = 0 }
	return ctx.tally[uid]
end
local function memberById(ctx, uid)
	for _, list in ctx.teams do for _, m in list do if m.userId == uid then return m end end end
	return nil
end

-- call once per spawned character of a member (round spawns)
function MatchCore.watchCharacter(ctx, m, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.Died:Once(function()
		if ctx.over or MatchCore.character(m) ~= character then return end
		MatchCore.setAttr(m, "Alive", false)
		local mine = t(ctx, m.userId)
		mine.deaths += 1
		MatchCore.setAttr(m, "MatchDeaths", mine.deaths)
		local killerId = humanoid:GetAttribute("LastAttacker")
		local killer = type(killerId) == "number" and memberById(ctx, killerId)
		local kind = humanoid:GetAttribute("LastAttackKind") or "Gun"
		local headshot = humanoid:GetAttribute("LastHitZone") == "Head"
		if killer and killer ~= m and MatchCore.getAttr(killer, "Team") ~= MatchCore.getAttr(m, "Team") then
			local k = t(ctx, killer.userId)
			k.kills += 1
			if headshot then k.headshots += 1 end
			if kind == "Melee" then k.melee += 1 end
			MatchCore.setAttr(killer, "MatchKills", k.kills)
		end
		if ctx.onKill then
			ctx.onKill({ killer = killer and killer.userId or 0, victim = m.userId, headshot = headshot, kind = kind,
				weapon = killer and MatchCore.getAttr(killer, "Loadout") or nil })
		end
	end)
end

-- // One round. Returns "A", "B" or nil (draw), plus true if a whole team left -------------------------------------------
local function teamAlive(ctx, list) local n = 0 for _, m in list do if ctx.isPresent(m) and MatchCore.isAlive(m) then n += 1 end end return n end
local function teamPresent(ctx, list) local n = 0 for _, m in list do if ctx.isPresent(m) then n += 1 end end return n end
local function teamHealth(ctx, list)
	local h = 0
	for _, m in list do local hu = ctx.isPresent(m) and MatchCore.humanoid(m); if hu and hu.Health > 0 then h += hu.Health end end
	return h
end
function MatchCore.forfeitSide(ctx)
	if teamPresent(ctx, ctx.teams.A) == 0 then return "B" end
	if teamPresent(ctx, ctx.teams.B) == 0 then return "A" end
	return nil
end

function MatchCore.playRound(ctx, roundNumber: number)
	local C = ctx.config
	ctx.state:SetAttribute("RoundNumber", roundNumber)
	if ctx.onRoundStart then ctx.onRoundStart(roundNumber) end

	MatchCore.setState(ctx, "Countdown", C.CountdownTime + 2)
	local total, done = 0, 0
	for side, list in ctx.teams do
		for i, m in list do
			if ctx.isPresent(m) then
				total += 1
				task.spawn(function()
					local ch = ctx.spawnMember(m, side, i)
					if ch then MatchCore.setAttr(m, "Alive", true); MatchCore.watchCharacter(ctx, m, ch) end
					ctx.setFrozen(m, true)
					done += 1
				end)
			end
		end
	end
	local waited = 0
	while done < total and waited < 12 do waited += task.wait(0.1) end
	local f = MatchCore.forfeitSide(ctx); if f then return f, true end

	MatchCore.setState(ctx, "Countdown", C.CountdownTime)
	ctx.announce("ROUND " .. roundNumber, scoreLine(ctx))
	task.wait(C.CountdownTime)
	for _, list in ctx.teams do for _, m in list do ctx.setFrozen(m, false) end end
	MatchCore.setState(ctx, "Live", C.RoundTime)
	ctx.announce("FIGHT", "")

	local endsAt = os.clock() + C.RoundTime
	while os.clock() < endsAt do
		f = MatchCore.forfeitSide(ctx); if f then return f, true end
		local a, b = teamAlive(ctx, ctx.teams.A), teamAlive(ctx, ctx.teams.B)
		if a == 0 or b == 0 then
			task.wait(0.1) -- a trade kill a frame later is still a draw
			a, b = teamAlive(ctx, ctx.teams.A), teamAlive(ctx, ctx.teams.B)
			if a > 0 and b == 0 then return "A" end
			if b > 0 and a == 0 then return "B" end
			return nil
		end
		task.wait(0.05)
	end
	local ha, hb = teamHealth(ctx, ctx.teams.A), teamHealth(ctx, ctx.teams.B) -- timeout: more health left wins
	if ha > hb then return "A" end
	if hb > ha then return "B" end
	return nil
end

-- // A full team match: returns winner ("A"/"B"/nil), forfeit -------------------------------------------------------------
function MatchCore.playMatch(ctx)
	local C = ctx.config
	ctx.tally = ctx.tally or {}
	local s = ctx.state
	s:SetAttribute("ScoreA", 0); s:SetAttribute("ScoreB", 0)
	s:SetAttribute("RoundsToWin", C.RoundsToWin)
	for side, list in ctx.teams do
		for _, m in list do
			MatchCore.setAttr(m, "InMatch", true); MatchCore.setAttr(m, "RoundWins", 0); MatchCore.setAttr(m, "Team", side)
			MatchCore.setAttr(m, "MatchKills", 0); MatchCore.setAttr(m, "MatchDeaths", 0); MatchCore.setAttr(m, "GadgetThrows", 0)
			t(ctx, m.userId)
		end
	end
	local roundNumber, winner, forfeit = 0, nil, false
	while true do
		roundNumber += 1
		local w, left = MatchCore.playRound(ctx, roundNumber)
		if left then winner, forfeit = w, true; ctx.announce("OPPONENTS LEFT", "TEAM " .. w .. " WINS"); break end
		if w then
			local key = "Score" .. w
			s:SetAttribute(key, (s:GetAttribute(key) or 0) + 1)
			for _, m in ctx.teams[w] do MatchCore.setAttr(m, "RoundWins", s:GetAttribute(key)) end
			ctx.announce("TEAM " .. w .. " WINS THE ROUND", scoreLine(ctx))
			if s:GetAttribute(key) >= C.RoundsToWin then winner = w; break end
		else
			ctx.announce("DRAW", scoreLine(ctx))
		end
		MatchCore.setState(ctx, "RoundEnd", C.RoundEndDelay)
		-- a leave during the round-end pause still forfeits
		local untilT = os.clock() + C.RoundEndDelay
		while os.clock() < untilT do
			local f = MatchCore.forfeitSide(ctx)
			if f then winner, forfeit = f, true break end
			task.wait(0.1)
		end
		if forfeit then ctx.announce("OPPONENTS LEFT", "TEAM " .. winner .. " WINS"); break end
		if roundNumber >= (C.MaxRounds or 9) then -- safety: endless draws
			local a, b = score(ctx, "A"), score(ctx, "B")
			winner = a > b and "A" or b > a and "B" or nil
			break
		end
	end
	ctx.over = true
	MatchCore.setState(ctx, "MatchEnd", C.ResultsTime or 12)
	ctx.announce(winner and ("TEAM " .. winner .. " WINS THE MATCH") or "MATCH DRAWN", forfeit and "Forfeit" or "")
	return winner, forfeit
end

-- // Rewards (pure maths; the caller writes them to the profile) ---------------------------------------------------------
function MatchCore.eloDelta(R, myRating: number, theirRating: number, won: boolean?, draw: boolean?): number
	local expected = 1 / (1 + 10 ^ ((theirRating - myRating) / 400))
	local sc = draw and 0.5 or (won and 1 or 0)
	return math.floor((R.RankedK or 32) * (sc - expected) + 0.5)
end

-- returns the MatchResults summary for one member (no profile writes)
function MatchCore.summary(ctx, m, side: string, winner: string?, forfeit: boolean?, passes)
	local R = ctx.config.Rewards or {}
	local st = t(ctx, m.userId)
	local won, draw = winner == side, winner == nil
	local mult = 1
	if passes then
		if passes.DoubleCredits then mult *= 2 end
		if passes.VIP then mult *= 1.25 end
	end
	local xp = (R.XPMatch or 100) + st.kills * (R.XPKill or 50) + (won and (R.XPWin or 150) or 0)
	local scissors = math.floor(((R.ScissorsMatch or 25) + st.kills * (R.ScissorsKill or 10) + (won and (R.ScissorsWin or 50) or 0)) * mult + 0.5)
	local gunXP = (R.GunXPMatch or 50) + st.kills * (R.GunXPKill or 25)
	return {
		Won = won, Draw = draw, Mode = ctx.mode, Ranked = ctx.ranked == true,
		Score = { A = score(ctx, "A"), B = score(ctx, "B") }, Team = side,
		Kills = st.kills, Headshots = st.headshots, MeleeKills = st.melee, Deaths = st.deaths,
		XP = xp, Scissors = scissors, Multiplier = mult, GunXP = gunXP,
		Weapon = MatchCore.getAttr(m, "Loadout") or "Pistol", RatingChange = nil, Saved = false, Forfeit = forfeit == true,
	}
end

-- // Loadout ----------------------------------------------------------------------------------------------------------
-- picks = { Weapon, Melee, Gadget }; ownsFn(id) -> bool; items = LobbyConfig.Items. Sets the Kit* attributes and the
-- gameplay mirror Loadout = KitWeapon (CombatManager gives Loadout).
function MatchCore.validPick(items, ownsFn, slot: string, id: any): boolean
	if type(id) ~= "string" then return false end
	local it = items[id]
	return it ~= nil and it.Slot == slot and (it.Default == true or ownsFn(id))
end
function MatchCore.applyKit(m, kit)
	MatchCore.setAttr(m, "KitWeapon", kit.Weapon)
	MatchCore.setAttr(m, "KitMelee", kit.Melee)
	MatchCore.setAttr(m, "KitGadget", kit.Gadget)
	MatchCore.setAttr(m, "Loadout", kit.Weapon)
end

-- // Map vote: votes = { [userId] = mapId }; maps = registry entries; returns the chosen real map id -------------------------
function MatchCore.resolveVote(votes, maps): string?
	if #maps == 0 then return nil end
	local count = {}
	for _, id in votes do count[id] = (count[id] or 0) + 1 end
	local best, bestN = {}, 0
	for id, n in count do
		if n > bestN then best, bestN = { id }, n elseif n == bestN then table.insert(best, id) end
	end
	local pick = #best > 0 and best[math.random(#best)] or "Random"
	local valid = false
	for _, m in maps do if m.Id == pick then valid = true end end
	if not valid then pick = maps[math.random(#maps)].Id end -- "Random" (or nothing voted) resolves to a real map
	return pick
end

return MatchCore
