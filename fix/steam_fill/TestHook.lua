-- [STEAMFILL] Studio-only test hook: ServerStorage.SteamFillTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar
-- code gets fresh module copies, so it can't reach this manager's state). Valves are named "<Map>/<Valve>" ("Warehouse2/SteamValve_S1").
--   "valves"                 -> JSON list { path, fill, used, at, untilT, radius, jet, hiss }
--   "shoot", path, player?   -> a real shot from the player's head through the valve (OnShot, as CombatManager calls it)
--   "activate", path | "reset" | "radius", path | "masked", Vector3
--   "bots" -> JSON { name, pos, noiseAt, heardAt, clock } | "botAt", Vector3, autonomous? | "ammo", n, player?
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

