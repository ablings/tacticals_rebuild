-- [GLASS] Studio-only test hook: ServerStorage.GlassTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar code gets
-- fresh module copies, so it can't reach this manager's state). Windows are named "<Map>/<Window>" ("Warehouse2/TestWindow").
--   "windows"                  -> JSON list { path, broken, cause, at }
--   "shoot", path, player?     -> a real OnShot from the player's head through the pane's centre to 40 studs past it
--   "melee", path, player?     -> OnMelee from the player's root facing the pane (reach 6, angle 70: a knife)
--   "blast", path, studs       -> a real Explode("Frag") that far in front of the pane (keep players away)
--   "reset"                    -> ResetAll (as a new round does)
local function glassTestHook()
	local HttpService = game:GetService("HttpService")
	local function pathOf(m: Instance): string
		local map = m:FindFirstAncestorWhichIsA("Model")
		while map and map.Parent ~= workspace do map = map.Parent and map.Parent:FindFirstAncestorWhichIsA("Model") or nil end
		return (map and map.Name or "?") .. "/" .. m.Name
	end
	local function windowBy(path: any): Instance?
		for _, w in windows do
			if pathOf(w) == path or w.Name == path then return w end
		end
		return nil
	end
	local function playerBy(name: any): Player?
		if type(name) == "string" then return Players:FindFirstChild(name) :: Player? end
		return Players:GetPlayers()[1]
	end
	local hook = game:GetService("ServerStorage"):FindFirstChild("GlassTestHook") or Instance.new("BindableFunction")
	hook.Name = "GlassTestHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any)
		if cmd == "windows" then
			local list = {}
			for _, w in windows do
				table.insert(list, { path = pathOf(w), broken = Openings.IsBroken(w), cause = w:GetAttribute("GlassCause"),
					at = tostring(w:GetAttribute("GlassHitAt")) })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "shoot" or cmd == "melee" then
			local w, p = windowBy(a), playerBy(b)
			local char = p and p.Character
			local head = char and char:FindFirstChild("Head")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local pane = w and Openings.GlassParts(w)[1]
			if not (head and root and pane) then return "no player / window" end
			if cmd == "shoot" then
				local dir = (pane.Position - head.Position).Unit
				manager.OnShot(head.Position, pane.Position + dir * 40, p)
			else
				manager.OnMelee(root.Position, (pane.Position - root.Position).Unit, 6, 70, p)
			end
			return if Openings.IsBroken(w) then "broken" else "intact"
		elseif cmd == "blast" then
			local w = windowBy(a)
			local pane = w and Openings.GlassParts(w)[1]
			if not pane then return "no window" end
			local s = pane.Size -- the pane's thinnest axis is its facing
			local normal = pane.CFrame.LookVector
			if s.X <= s.Y and s.X <= s.Z then normal = pane.CFrame.RightVector elseif s.Y <= s.Z then normal = pane.CFrame.UpVector end
			manager.Explode(pane.Position + normal * (tonumber(b) or 4), "Frag", nil)
			return if Openings.IsBroken(w) then "broken" else "intact"
		elseif cmd == "reset" then
			manager.ResetAll()
			return "ok"
		end
		return "unknown command " .. tostring(cmd)
	end
	hook.Parent = game:GetService("ServerStorage")
end
