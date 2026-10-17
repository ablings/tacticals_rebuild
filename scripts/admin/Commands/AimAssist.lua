-- AdminFramework/Commands/AimAssist [AIM] 2026-10-17 (Edward: "give me as an admin settings to enable aim assist for myself on pc
-- so i can test and also setting to test against an npc").
--   ;aimassist on [strength 0-100] [player]   force aim assist on (mouse + keyboard too); optional test strength (else the
--                                            player's setting / 50%). Ranked still caps it at 25%.
--   ;aimassist off [player]                   back to normal (touch / controller only)
--   ;aimnpc [on|off] [distance]               a strafing R15 test dummy in front of you (tag AimAssistTarget, 150 HP,
--                                            stands back up 3 s after dying); off removes yours
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local npcs = {} -- [userId] = { model, conn }

local function removeNpc(uid: number)
	local n = npcs[uid]
	if not n then return false end
	npcs[uid] = nil
	if n.conn then n.conn:Disconnect() end
	if n.model then n.model:Destroy() end
	return true
end

local function spawnNpc(owner: Player, distance: number)
	local root = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, "spawn first" end
	removeNpc(owner.UserId)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil, "couldn't build a rig: " .. tostring(model) end
	model.Name = "AimTestNPC"
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = 150
	hum.Health = 150
	hum.WalkSpeed = 14
	hum.DisplayName = "Aim Test NPC"
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local home = root.Position + look * distance
	model:PivotTo(CFrame.lookAt(home, root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, home.Y, 0)))
	model:SetAttribute("AimTestOwner", owner.UserId)
	CollectionService:AddTag(model, "AimAssistTarget")
	model.Parent = workspace
	local npcRoot = model:FindFirstChild("HumanoidRootPart")
	if npcRoot then pcall(function() npcRoot:SetNetworkOwner(nil) end) end
	-- strafe left / right across the owner's view, a short pause at each end
	local side = Vector3.new(-look.Z, 0, look.X)
	local leg, t = 1, 0
	local entry = { model = model }
	entry.conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then return end
		if hum.Health <= 0 then return end
		t += dt
		if t > 1.6 then
			t = 0
			leg = -leg
			hum:MoveTo(home + side * 7 * leg)
		end
	end)
	hum.Died:Connect(function()
		task.delay(3, function()
			if npcs[owner.UserId] == entry and owner.Parent then spawnNpc(owner, distance) end
		end)
	end)
	npcs[owner.UserId] = entry
	return model
end

Players.PlayerRemoving:Connect(function(p) removeNpc(p.UserId) end)

return {
	{
		name = "aimassist", aliases = { "aa" }, level = "Admin",
		description = "on [strength 0-100] [player]: force aim assist on (PC too) for testing; off: back to touch / controller only.",
		args = {
			{ name = "on", type = "boolean" },
			{ name = "strength", type = "number", optional = true, min = 0, max = 100 },
			{ name = "player", type = "players", defaultToken = "me" },
		},
		run = function(ctx, a)
			local names = {}
			for _, p in a.player do
				p:SetAttribute("AimAssistForce", a.on or nil)
				p:SetAttribute("AimAssistStrength", (a.on and a.strength) or nil)
				table.insert(names, p.Name)
			end
			if a.on then
				return true, ("Aim assist forced ON for %s at %s (ranked caps it at 25%%)."):format(table.concat(names, ", "),
					a.strength and (a.strength .. "%") or "their setting / 50%")
			end
			return true, "Aim assist back to normal for " .. table.concat(names, ", ") .. "."
		end,
	},
	{
		name = "aimnpc", level = "Admin",
		description = "[on|off] [distance]: a strafing R15 test dummy in front of you for aim assist / aim tests (150 HP, respawns).",
		args = {
			{ name = "on", type = "boolean", optional = true },
			{ name = "distance", type = "number", optional = true, min = 6, max = 120 },
		},
		run = function(ctx, a)
			local me = ctx.caller
			if not me then return false, "run it as a player" end
			if a.on == false then
				return true, removeNpc(me.UserId) and "Your test NPC is gone." or "You have no test NPC."
			end
			local model, err = spawnNpc(me, a.distance or 25)
			if not model then return false, err end
			return true, ("Test NPC spawned %d studs ahead, strafing. ;aimnpc off removes it."):format(a.distance or 25)
		end,
	},
}
