-- [STEAMFILL] Studio-only test hook: ServerStorage.SteamFillTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar
-- code gets fresh module copies, so it can't reach this manager's state). Valves are named "<Map>/<Valve>" ("Warehouse2/SteamValve_S1").
--   "valves"                 -> JSON list { path, fill, used, at, untilT, radius, jet, hiss }
--   "shoot", path, player?   -> a real shot from the player's head through the valve (OnShot, as CombatManager calls it)
--   "activate", path | "reset" | "radius", path | "masked", Vector3
--   "bots" -> JSON { name, pos, noiseAt, heardAt, clock } | "botAt", Vector3, autonomous? | "ammo", n, player?
--   "sees", player? -> JSON { sees, depth } (round 3) | "hears", player? -> JSON { steps (true/false/"seen"), reload, botInSteam,
--   playerInSteam }: runs the AI's real _perceive / HearNoise once (round 3, after the grader: never re-implement the rule here)
local function steamTestHook()
	local HttpService = game:GetService("HttpService")
	local function pathOf(m: Instance): string
		return (m.Parent and m.Parent.Parent and m.Parent.Parent.Name or "?") .. "/" .. m.Name
	end
	local function valveBy(path: any): Model?
		for _, v in valves do
			if pathOf(v.model) == path or v.model.Name == path then return v.model end
		end
		return nil
	end
	local function playerBy(name: any): Player?
		if type(name) == "string" then return Players:FindFirstChild(name) :: Player? end
		return Players:GetPlayers()[1]
	end
	local function botList()
		local bm = Get and Get("BotManager")
		return (bm and bm.GetBots and bm.GetBots()) or {}
	end
	local hook = game:GetService("ServerStorage"):FindFirstChild("SteamFillTestHook") or Instance.new("BindableFunction")
	hook.Name = "SteamFillTestHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any)
		local now = workspace:GetServerTimeNow()
		if cmd == "valves" then
			local list = {}
			for _, v in valves do
				local m = v.model
				table.insert(list, { path = pathOf(m), fill = SteamMask.FillOf(m) ~= nil, used = v.used, at = m:GetAttribute("SteamAt"),
					untilT = m:GetAttribute("SteamUntil"), radius = SteamMask.Radius(m, now), jet = v.jet.Enabled, hiss = v.hiss.IsPlaying, now = now })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "shoot" then
			local m, p = valveBy(a), playerBy(b)
			local head = p and p.Character and p.Character:FindFirstChild("Head")
			local body = m and (m:FindFirstChild("ValveBody") or m:FindFirstChildWhichIsA("BasePart"))
			if not (head and body) then return "no head / valve" end
			local dir = (body.Position - head.Position).Unit
			manager.OnShot(head.Position, body.Position + dir * 2, p)
			return if m:GetAttribute("SteamUntil") then "steaming" else "not hit"
		elseif cmd == "activate" then
			local m = valveBy(a)
			if not m then return "no valve" end
			manager.ActivateValve(m, nil)
			return "ok"
		elseif cmd == "reset" then
			manager.ResetAll()
			return "ok"
		elseif cmd == "radius" then
			local m = valveBy(a)
			return if m then SteamMask.Radius(m, now) else -1
		elseif cmd == "masked" then
			return SteamMask.IsMasked(a)
		elseif cmd == "bots" then
			local list = {}
			for _, bot in botList() do
				table.insert(list, { name = bot.model.Name, pos = tostring(bot.root.Position), noiseAt = bot.noiseAt, heardAt = bot.heardAt, clock = os.clock() })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "botAt" then
			for _, bot in botList() do
				bot:SetAutonomous(b == true)
				bot.root.CFrame = CFrame.new(a)
				bot.root.AssemblyLinearVelocity = Vector3.zero
				return "ok"
			end
			return "no bot"
		elseif cmd == "sees" then -- round 3: can the first bot see this player (walls, smoke, steam; FOV ignored)?
			local p = playerBy(a)
			for _, bot in botList() do
				local char = p and p.Character
				local eye = bot.head and bot.head.Position
				local at = char and char:FindFirstChild("UpperTorso")
				return HttpService:JSONEncode({ sees = bot:CanSee(char, true),
					depth = (eye and at) and SteamMask.SightDepth(eye, at.Position, now) or -1 })
			end
			return "no bot"
		elseif cmd == "hears" then -- round 3: drives the AI's REAL hearing code once (BotManager), for the first bot and this player
			-- steps: bot:_perceive() with the player moving (only counts when the bot can't see them: then "seen")
			-- reload: CombatManager's own test (IsMasked at the source) + the real BotManager.HearNoise(..., quiet = true)
			local p = playerBy(a)
			local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local bm = Get and Get("BotManager")
			for _, bot in botList() do
				if not (root and bm) then return "no player" end
				local vel = root.AssemblyLinearVelocity
				local heard0, noise0 = bot.heardAt, bot.noiseAt
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
				bot.heardAt = bot.heardAt or heard0
				bot.noiseAt = bot.noiseAt or noise0
				return HttpService:JSONEncode({ steps = steps, reload = reload,
					botInSteam = SteamMask.InFill(bot.root.Position), playerInSteam = SteamMask.InFill(root.Position) })
			end
			return "no bot"
		elseif cmd == "ammo" then
			local cm = Get and Get("CombatManager")
			local p = playerBy(b)
			if cm and p then cm.SetAmmo(p, a) end
			return "ok"
		end
		return "unknown command " .. tostring(cmd)
	end
	hook.Parent = game:GetService("ServerStorage")
end

