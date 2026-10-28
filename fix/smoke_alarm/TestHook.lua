-- [SMOKEALARM] Studio-only test hook: ServerStorage.SmokeAlarmTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar
-- code gets fresh module copies, so it can't reach this manager's state). Alarms are named by their model name ("SmokeAlarm_G").
--   "alarms"               -> JSON list { name, pos, broken, blareAt, blareUntil, chirpAt, now }
--   "shoot", name, player? -> a real OnShot from the player's head through the alarm (as CombatManager calls it)
--   "chirp", name          -> chirp now (skips the 25-40 s wait)
--   "reset"                -> ResetAll (as a new round does)
--   "masked", Vector3      -> SteamMask.IsMasked (what footsteps / reloads ask)
--   "spawnai", Vector3     -> a BotManager AI (not autonomous: it stands still and only perceives) at that spot; "botAt", Vector3 moves it
--   "hears", player?       -> JSON { steps, reload, botInBlare, playerInBlare }: the AI's REAL _perceive / HearNoise once (first bot),
--                             the reload exactly as CombatManager gates it (IsMasked at the source, then HearNoise(..., quiet = true))
local function alarmTestHook()
	local HttpService = game:GetService("HttpService")
	local SmokeAlarmMod = require(Shared.SmokeAlarm)
	local function alarmBy(name: any)
		for _, a in (alarms and alarms.alarms or {}) do
			if a.model.Name == name then return a end
		end
		return nil
	end
	local function playerBy(name: any): Player?
		if type(name) == "string" then return Players:FindFirstChild(name) :: Player? end
		return Players:GetPlayers()[1]
	end
	local hook = game:GetService("ServerStorage"):FindFirstChild("SmokeAlarmTestHook") or Instance.new("BindableFunction")
	hook.Name = "SmokeAlarmTestHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any)
		local now = workspace:GetServerTimeNow()
		if cmd == "alarms" then
			local list = {}
			for _, e in (alarms and alarms.alarms or {}) do
				local m = e.model
				table.insert(list, { name = m.Name, pos = tostring(e.pos), broken = e.broken, blareAt = m:GetAttribute("BlareAt"),
					blareUntil = m:GetAttribute("BlareUntil"), chirpAt = m:GetAttribute("ChirpAt"), nextChirpIn = e.nextChirp - os.clock(), now = now })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "shoot" then
			local e, p = alarmBy(a), playerBy(b)
			local head = p and p.Character and p.Character:FindFirstChild("Head")
			local base = e and e.model:FindFirstChild("Base")
			if not (head and base) then return "no head / alarm" end
			local dir = (base.Position - head.Position).Unit
			manager.OnShot(head.Position, base.Position + dir * 2, p)
			return if e.broken then "blaring" else "not hit"
		elseif cmd == "chirp" then
			local e = alarmBy(a)
			if not e then return "no alarm" end
			e.nextChirp = 0
			alarms:Step()
			return "ok"
		elseif cmd == "reset" then
			manager.ResetAll()
			return "ok"
		elseif cmd == "masked" then
			return SteamMask.IsMasked(a)
		elseif cmd == "spawnai" then
			local bm = Get and Get("BotManager")
			if not (bm and bm.Spawn) then return "no BotManager" end
			bm.Spawn(CFrame.new(a), { autonomous = false, name = "AlarmTestAI" })
			return "ok"
		elseif cmd == "botAt" then
			local bm = Get and Get("BotManager")
			for _, bot in ((bm and bm.GetBots and bm.GetBots()) or {}) do
				bot.root.CFrame = CFrame.new(a)
				bot.root.AssemblyLinearVelocity = Vector3.zero
				return "ok"
			end
			return "no bot"
		elseif cmd == "hears" then
			local p = playerBy(a)
			local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local bm = Get and Get("BotManager")
			local list = (bm and bm.GetBots and bm.GetBots()) or {}
			for _, bot in list do
				if not (root and bm) then return "no player" end
				local vel = root.AssemblyLinearVelocity
				local heard0, noise0, known0, noisePos0 = bot.heardAt, bot.noiseAt, bot.lastKnown, bot.noisePos
				root.AssemblyLinearVelocity = Vector3.new(12, 0, 0)
				bot.heardAt = nil
				bot:_perceive()
				local steps: any = bot.heardAt ~= nil
				if bot.visible then steps = "seen" end
				root.AssemblyLinearVelocity = vel
				bot.noiseAt = nil
				if not SteamMask.IsMasked(root.Position) then
					bm.HearNoise(root.Position, (Config.ReloadHearRange or 22), true)
				end
				local reload = bot.noiseAt ~= nil
				bot.heardAt, bot.noiseAt, bot.lastKnown, bot.noisePos = heard0, noise0, known0, noisePos0 -- a probe mustn't start a hunt
				return HttpService:JSONEncode({ steps = steps, reload = reload,
					botInBlare = SmokeAlarmMod.Blaring(bot.root.Position, now), playerInBlare = SmokeAlarmMod.Blaring(root.Position, now) })
			end
			return "no bot"
		end
		return "unknown command " .. tostring(cmd)
	end
	hook.Parent = game:GetService("ServerStorage")
end
