-- ServerScriptService/Shared/MatchCore (ModuleScript): the round rules of a team match, shared by the lobby's pad duels
-- (one MatchCore run per match, LobbyDuelManager) and the match place's RoundManager (one per server; [MATCH] 2026-10-16,
-- notes/match_place_flow.md: it also uses runPreMatch / castVote / ownedItems / ownedKit below).
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
--   ctx.aborted          bool      set by an admin end: the closing announce says "MATCH ENDED"
-- Published on ctx.state (names from notes/lobby_duels_design.md section 6; PhaseEndsAt == StateEndsAt always):
--   MatchState, MatchPhase, StateEndsAt, PhaseEndsAt, CombatEnabled, RoundNumber, RoundsToWin, ScoreA, ScoreB
-- Player (member) attributes: InMatch, Team, RoundWins, MatchKills, MatchDeaths, Alive
-- 2026-10-17 (Edward: kill-cam, opening run, final-round victory; the UI session draws them):
--   member SpectateTarget = UserId to watch while dead (the killer first; bots have negative ids: their model carries
--     attribute SpectateId = the same id), SpectateReason = "Killer" | "Teammate" | "Enemy"; both nil when the next round starts.
--   state MatchState "RunIn" (MatchPhase "RunIn"): round 1 opening, both sides start close in the middle, freeze for a
--     standoff beat, then run back to their own spawn / pillar (C.RunIn = false turns it off; C.RunInEveryRound for every round).
--   state MatchState "Victory" (MatchPhase "Victory") between the deciding round and MatchEnd (C.VictoryTime, default 4 s):
--     WinnerTeam = "A" | "B", Winner = UserId of the player who got the final kill (nil if none / draw); cleared at match start.
--     The default screen until Edward makes per-player finishers / victory cutscenes.
local MatchCore = {}

local PHASE_OF = { Loading = "Loading", MapVote = "MapVote", Loadout = "Loadout", Countdown = "Playing", Live = "Playing",
	RoundEnd = "Playing", MatchEnd = "Ended", Cancelled = "Ended", RunIn = "RunIn", Victory = "Victory" }

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

-- // Kill-cam: who a dead member watches -----------------------------------------------------------------------------
local function aliveMembers(ctx, side)
	local out = {}
	for s, list in ctx.teams do
		if side == nil or s == side then
			for _, x in list do if ctx.isPresent(x) and MatchCore.isAlive(x) then table.insert(out, x) end end
		end
	end
	return out
end
local function spectateOn(m, target, reason)
	if target and target.bot then target.bot:SetAttribute("SpectateId", target.userId) end
	MatchCore.setAttr(m, "SpectateTarget", target and target.userId or nil)
	MatchCore.setAttr(m, "SpectateReason", target and reason or nil)
end
-- pick for a dead member: the killer if alive, else a living teammate, else any living enemy
local function pickSpectate(ctx, m, killer)
	if killer and killer ~= m and ctx.isPresent(killer) and MatchCore.isAlive(killer) then return killer, "Killer" end
	local mates = aliveMembers(ctx, MatchCore.getAttr(m, "Team"))
	if #mates > 0 then return mates[1], "Teammate" end
	local any = aliveMembers(ctx, nil)
	if #any > 0 then return any[1], "Enemy" end
	return nil, nil
end
function MatchCore.clearSpectate(ctx)
	for _, list in ctx.teams do for _, x in list do spectateOn(x, nil) end end
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
		-- the final kill decides the Victory screen's Winner; the dead watch their killer (kill-cam)
		local realKiller = (killer and killer ~= m) and killer or nil
		ctx.lastKill = { killer = realKiller and realKiller.userId or nil, victim = m.userId }
		local target, reason = pickSpectate(ctx, m, realKiller)
		spectateOn(m, target, reason)
		-- anyone who was watching the one who just died moves on to someone alive
		for _, list in ctx.teams do
			for _, x in list do
				if x ~= m and MatchCore.getAttr(x, "SpectateTarget") == m.userId then
					local t2, r2 = pickSpectate(ctx, x, nil)
					spectateOn(x, t2, r2)
				end
			end
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

-- // Opening run (default cutscene): each side starts 35% of the way toward the middle, a standoff beat, then everyone
-- runs back to the spawn they were placed on (behind their pillar). Ends frozen exactly on the spawn, ready for the countdown.
local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
function MatchCore.runIn(ctx)
	local C = ctx.config
	local standoff, runTime = C.RunInStandoff or 0.8, C.RunInTime or 2.2
	local homes, sum, n = {}, { A = Vector3.zero, B = Vector3.zero }, { A = 0, B = 0 }
	for side, list in ctx.teams do
		for _, m in list do
			local ch = ctx.isPresent(m) and MatchCore.character(m)
			if ch and ch.PrimaryPart then
				homes[m] = { cf = ch:GetPivot() }
				sum[side] += homes[m].cf.Position
				n[side] += 1
			end
		end
	end
	if n.A == 0 or n.B == 0 then return end
	local centre = (sum.A / n.A + sum.B / n.B) / 2
	MatchCore.setState(ctx, "RunIn", standoff + runTime + 0.3)
	-- start close in the middle, facing the other side
	for m, h in homes do
		local p = h.cf.Position
		local flat = Vector3.new(centre.X - p.X, 0, centre.Z - p.Z)
		local from = flat.Magnitude > 1 and (p + flat * 0.35) or p
		local ch = MatchCore.character(m)
		if ch then
			ctx.setFrozen(m, true)
			ch:PivotTo(CFrame.lookAt(from, Vector3.new(centre.X, from.Y, centre.Z)))
			h.from = from
		end
	end
	task.wait(standoff)
	-- break for cover: everyone runs back home at a pace that arrives together
	for m, h in homes do
		local hum = MatchCore.humanoid(m)
		if hum and h.from then
			ctx.setFrozen(m, false)
			h.speed = hum.WalkSpeed
			hum.WalkSpeed = math.clamp(flatDist(h.from, h.cf.Position) / math.max(runTime - 0.2, 0.5), 10, 30)
			hum:MoveTo(h.cf.Position)
		end
	end
	local t0 = os.clock()
	while os.clock() - t0 < runTime do
		local all = true
		for m, h in homes do
			local ch = MatchCore.character(m)
			if ch and h.from and flatDist(ch:GetPivot().Position, h.cf.Position) > 2 then all = false end
		end
		if all then break end
		task.wait(0.05)
	end
	-- snap exactly onto the spawn, facing as spawned, frozen for the countdown
	for m, h in homes do
		local ch, hum = MatchCore.character(m), MatchCore.humanoid(m)
		if hum and h.speed then hum.WalkSpeed = h.speed end
		if ch and ch.Parent then ch:PivotTo(h.cf) end
		ctx.setFrozen(m, true)
	end
	task.wait(0.3)
end

function MatchCore.playRound(ctx, roundNumber: number)
	local C = ctx.config
	ctx.state:SetAttribute("RoundNumber", roundNumber)
	MatchCore.clearSpectate(ctx)
	ctx.lastKill = nil
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

	-- opening run (round 1 unless C.RunInEveryRound): the default "run to your pillar" until per-map cutscenes exist
	if C.RunIn ~= false and (roundNumber == 1 or C.RunInEveryRound) then
		MatchCore.runIn(ctx)
		f = MatchCore.forfeitSide(ctx); if f then return f, true end
	end

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
	s:SetAttribute("WinnerTeam", nil); s:SetAttribute("Winner", nil)
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
		if left then
			winner, forfeit = w, true
			-- ctx.aborted (an admin ended the match): no "opponents left" line
			if not ctx.aborted then ctx.announce("OPPONENTS LEFT", "TEAM " .. w .. " WINS") end
			break
		end
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
		if forfeit then
			if not ctx.aborted then ctx.announce("OPPONENTS LEFT", "TEAM " .. winner .. " WINS") end
			break
		end
		if roundNumber >= (C.MaxRounds or 9) then -- safety: endless draws
			local a, b = score(ctx, "A"), score(ctx, "B")
			winner = a > b and "A" or b > a and "B" or nil
			break
		end
	end
	ctx.over = true
	-- final-round Victory beat (default screen; finisher / victory cutscenes come later). Not after a forfeit or an admin end.
	if winner and not forfeit and not ctx.aborted and (C.VictoryTime or 4) > 0 then
		s:SetAttribute("WinnerTeam", winner)
		local lk = ctx.lastKill
		local winnerId = lk and lk.killer
		if winnerId then
			local wm = memberById(ctx, winnerId)
			if not (wm and MatchCore.getAttr(wm, "Team") == winner) then winnerId = nil end
		end
		if not winnerId then
			for _, wm in ctx.teams[winner] do
				if ctx.isPresent(wm) then winnerId = wm.userId break end
			end
		end
		s:SetAttribute("Winner", winnerId)
		MatchCore.setState(ctx, "Victory", C.VictoryTime or 4)
		task.wait(C.VictoryTime or 4)
	elseif winner then
		s:SetAttribute("WinnerTeam", winner)
	end
	MatchCore.clearSpectate(ctx)
	MatchCore.setState(ctx, "MatchEnd", C.ResultsTime or 12)
	if ctx.aborted then
		ctx.announce("MATCH ENDED", "Ended by an admin - no rewards")
	else
		ctx.announce(winner and ("TEAM " .. winner .. " WINS THE MATCH") or "MATCH DRAWN", forfeit and "Forfeit" or "")
	end
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

-- what a player may pick: every catalogue item that is a Default or owned (data.Owned[id] == true), sorted ids
function MatchCore.ownedItems(items, data): { string }
	local owned = {}
	for id, it in items do
		if it.Default == true or (data and type(data.Owned) == "table" and data.Owned[id] == true) then table.insert(owned, id) end
	end
	table.sort(owned)
	return owned
end
-- the kit a player starts the Loadout phase with: wanted[slot] where it is a valid pick (owned + right slot), else the
-- slot's default (defaults = { Weapon = "Pistol", Melee = "Fists", Gadget = "Smoke" })
function MatchCore.ownedKit(items, ownsFn, wanted, defaults)
	local kit = {}
	for _, slot in { "Weapon", "Melee", "Gadget" } do
		local id = type(wanted) == "table" and wanted[slot] or nil
		kit[slot] = MatchCore.validPick(items, ownsFn, slot, id) and id or defaults[slot]
	end
	return kit
end

-- // Pre-match phases (Loading -> MapVote -> Loadout), used by the match place's RoundManager --------------------------------
-- (LobbyDuelManager runs its own copy of these steps, with the arena loading and the Loaded gate in between.)
-- MapList JSON entries for the UI ({id, name, image}); the UI adds "Random" itself
function MatchCore.mapList(maps)
	local list = {}
	for _, m in maps do table.insert(list, { id = m.Id, name = m.DisplayName or m.Id, image = m.Image or "" }) end
	return list
end
-- a vote: mapId must be one of maps or "Random"; one vote per user id, changeable. Publishes MapVotes {mapId: [userId]}.
function MatchCore.castVote(ctx, userId: number, mapId: any, maps): boolean
	if ctx.state:GetAttribute("MatchState") ~= "MapVote" then return false end
	local ok = mapId == "Random"
	for _, m in maps do if m.Id == mapId then ok = true end end
	if not ok then return false end
	ctx.votes = ctx.votes or {}
	ctx.votes[userId] = mapId
	ctx.lastVote = os.clock()
	local out = {}
	for uid, id in ctx.votes do out[id] = out[id] or {}; table.insert(out[id], uid) end
	ctx.state:SetAttribute("MapVotes", game:GetService("HttpService"):JSONEncode(out))
	return true
end
-- wait up to seconds; true as soon as done() is true, false on timeout or when a whole team is gone
function MatchCore.waitPhase(ctx, seconds: number, done)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if done and done() then return true end
		if MatchCore.forfeitSide(ctx) then return false end
		task.wait(0.1)
	end
	return false
end
-- Loading (C.LoadingTime; opts.skipLoading) -> Intro (opts.introTime, optional) -> MapVote (C.MapVoteTime; skipped when C.DuelMapVote == false or no map is eligible)
-- -> MapChosen -> Loadout (C.LoadoutTime, ends early when every present player member is Ready).
-- opts.maps = the eligible maps (registry entries); opts.voters() -> number of members who can vote;
-- opts.onMapChosen(id) is called before the Loadout phase starts. Returns the chosen map id (nil = no eligible map).
function MatchCore.runPreMatch(ctx, opts)
	local C, s = ctx.config, ctx.state
	local HttpService = game:GetService("HttpService")
	-- opts.skipLoading: the caller ran its own Loading (the match place: arrival + every client's "Loaded")
	if not opts.skipLoading then
		MatchCore.setState(ctx, "Loading", C.LoadingTime or 3)
		MatchCore.waitPhase(ctx, C.LoadingTime or 3)
	end
	-- opts.introTime: a short "Intro" phase (the match place's logo crumble) before the vote; the UI ignores the name
	if opts.introTime and opts.introTime > 0 and not MatchCore.forfeitSide(ctx) then
		MatchCore.setState(ctx, "Intro", opts.introTime)
		MatchCore.waitPhase(ctx, opts.introTime)
	end
	local maps = opts.maps or {}
	s:SetAttribute("MapList", HttpService:JSONEncode(MatchCore.mapList(maps)))
	s:SetAttribute("MapVotes", "{}")
	ctx.votes, ctx.lastVote = ctx.votes or {}, 0
	if C.DuelMapVote ~= false and #maps > 0 and not MatchCore.forfeitSide(ctx) then
		MatchCore.setState(ctx, "MapVote", C.MapVoteTime or 10)
		local voters = opts.voters and opts.voters() or 0
		MatchCore.waitPhase(ctx, C.MapVoteTime or 10, function()
			local n = 0
			for _ in ctx.votes do n += 1 end
			return voters > 0 and n >= voters and os.clock() - ctx.lastVote > 1.5
		end)
	end
	local chosen = MatchCore.resolveVote(ctx.votes, maps)
	s:SetAttribute("MapChosen", chosen)
	if MatchCore.forfeitSide(ctx) then return chosen end
	-- the winning tile flashes
	task.wait(1.5)
	if opts.onMapChosen then opts.onMapChosen(chosen) end
	MatchCore.setState(ctx, "Loadout", C.LoadoutTime or 15)
	MatchCore.waitPhase(ctx, C.LoadoutTime or 15, function()
		for _, list in ctx.teams do
			for _, m in list do
				if m.player and ctx.isPresent(m) and not m.ready then return false end
			end
		end
		return true
	end)
	return chosen
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
