-- ReplicatedStorage.Modules.Shared.AimAssist (ModuleScript, client) [AIM] 2026-10-17, Edward:
-- "aim assist only exists for mobile and controller players, its base is at 50% but it has a maximum of 25% in ranked ...
--  the aim assist strength goes to a little bit below the roblox head and right around the neck area so it doesn't just get
--  headshots ... admin settings to enable aim assist for myself on pc ... and to test against an npc".
--
-- Who gets it: the last input was Touch or a Gamepad (UserInputService:GetLastInputType), or the admin override
--   (player attribute AimAssistForce = true, set by ;aimassist). Mouse + keyboard never get it.
-- Strength (0..1): player attribute AimAssistStrength (admin test override, 0-100) else the player's Settings row
--   Setting_AimAssist ("50%" default / "25%" / "Off") else Base 50%. Ranked matches cap it at RankedCap 25%.
-- Aim point: the NECK (R15 UpperTorso.NeckRigAttachment, else just under the Head), never the head. The vertical pull only
--   lifts the crosshair up TO the neck; it never drags a crosshair that is on the head down, and never pulls above the neck,
--   so headshots stay the player's own skill.
-- Two effects, both scaled by strength:
--   friction: the camera turns slower while the crosshair is near a target (sensitivity multiplier)
--   pull:     while the player is actively aiming (moving, turning the camera, aiming down sights or firing), the camera
--             eases toward the neck point of the target nearest the crosshair inside the assist cone
-- Targets: alive (never dead players / NPCs), in line of sight, within Range; in a match only the other team; in the
--   practice range (InTraining) the Training dummies + enemy; anywhere the ;aimnpc test dummy (tag "AimAssistTarget").
--
-- Camera hook (CameraController, UI session), once per frame after reading the look input:
--   local aa = AimAssist.Step(dt, camera.CFrame, { aiming = isAiming, firing = recentlyFired, looking = lookDeltaMagnitude > 0 })
--   sensitivity *= aa.sensitivity                    -- friction (1 when no target)
--   state.yaw += aa.yaw; state.pitch += aa.pitch    -- radians; yaw + = turn left, pitch + = look up
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AimAssist = {}
AimAssist.Config = {
	Base = 0.50,            -- default strength
	RankedCap = 0.25,       -- ranked matches never above this
	Range = 160,            -- studs
	ConeDeg = 3,            -- assist cone half-angle at 0 strength ...
	ConeDegPerStrength = 7, -- ... plus this x strength (50% -> 6.5 deg)
	Friction = 0.55,        -- sensitivity at the target centre drops by Friction x strength (50% -> 27%)
	PullRate = 7,           -- per second at full strength, fraction of the angle error removed (50% -> 3.5/s)
	MaxPullDegPerSec = 40,  -- hard cap on how fast the pull may turn the camera
	NeckDrop = 0.15,        -- studs below the neck joint (a little below the head)
}
local C = AimAssist.Config
local player = Players.LocalPlayer
local GAMEPADS = {}
for _, t in Enum.UserInputType:GetEnumItems() do if t.Name:match("^Gamepad%d") then GAMEPADS[t] = true end end

local NONE = { yaw = 0, pitch = 0, sensitivity = 1, target = nil }

function AimAssist.InputEligible(): boolean
	if player:GetAttribute("AimAssistForce") == true then return true end
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or GAMEPADS[last] == true
end

-- the player's setting (Settings > Aim Assist: "50%" default / "25%" / "Off"; a number 0-100 also works) -> 0..1 or nil
local function settingStrength(): number?
	local v = player:GetAttribute("Setting_AimAssist")
	if v == nil then return nil end
	if v == false or v == "Off" or v == "OFF" then return 0 end
	if v == true then return C.Base end
	local n = tonumber(v) or tonumber(string.match(tostring(v), "(%d+)"))
	return n and math.clamp(n / 100, 0, C.Base) or nil
end

function AimAssist.Strength(): number
	-- admin test override first (any 0-100), else the player's setting (never above Base), else Base
	local admin = tonumber(player:GetAttribute("AimAssistStrength"))
	local s = admin and math.clamp(admin / 100, 0, 1) or settingStrength() or C.Base
	if ReplicatedStorage:GetAttribute("MatchRanked") == true or player:GetAttribute("MatchRanked") == true then
		s = math.min(s, C.RankedCap)
	end
	return s
end

-- dead players / NPCs never count (Edward): health 0, or a match member flagged dead (Alive = false)
local function alive(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead) then return false end
	local owner = Players:GetPlayerFromCharacter(model)
	if owner and owner:GetAttribute("Alive") == false then return false end
	if model:GetAttribute("Alive") == false then return false end
	return true
end

-- the practice range (Edward: "it should work in the practice range"): while InTraining, the Training room's dummies and the
-- training enemy (humanoid models with an OnHit event under LobbyMap.Training) are targets. Rescanned every 2 s.
local rangeCache, rangeAt = {}, -math.huge
local function rangeTargets()
	if os.clock() - rangeAt < 2 then return rangeCache end
	rangeAt = os.clock()
	rangeCache = {}
	local map = workspace:FindFirstChild("LobbyMap")
	local training = map and map:FindFirstChild("Training")
	for _, d in (training and training:GetDescendants() or {}) do
		if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") and d.Parent:FindFirstChild("OnHit") then
			table.insert(rangeCache, d.Parent)
		end
	end
	return rangeCache
end

local function neckPoint(model): Vector3?
	local ut = model:FindFirstChild("UpperTorso")
	local att = ut and ut:FindFirstChild("NeckRigAttachment")
	if att then return att.WorldPosition - Vector3.new(0, C.NeckDrop, 0) end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head.Position - Vector3.new(0, head.Size.Y * 0.5 + C.NeckDrop, 0) end
	return nil
end

local function candidates(): { Model }
	local list = {}
	local myChar = player.Character
	local myTeam = player:GetAttribute("Team")
	local inMatch = player:GetAttribute("InMatch") == true and myTeam ~= nil
	if inMatch then
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Character and p:GetAttribute("Team") ~= nil and p:GetAttribute("Team") ~= myTeam then
				table.insert(list, p.Character)
			end
		end
		-- server test bots in a match (their model carries Team / SpectateId; MatchCore bots)
		for _, m in CollectionService:GetTagged("Bot") do
			if m ~= myChar and m:GetAttribute("Team") ~= myTeam then table.insert(list, m) end
		end
	end
	if player:GetAttribute("InTraining") == true then
		for _, m in rangeTargets() do table.insert(list, m) end
	end
	for _, m in CollectionService:GetTagged("AimAssistTarget") do
		if m ~= myChar then table.insert(list, m) end
	end
	return list
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- smoke (Edward: "shouldnt work behind smokes and walls"): GadgetManager's smoke cells are parts tagged "SmokeCloud" with a live
-- Radius attribute (CanQuery off, so raycasts pass through them). The line of sight is blocked when it passes within a cell's
-- radius (bullet holes shrink a cell's Radius, so a tunnel shot through the smoke opens it again).
local function smokeBlocks(from: Vector3, to: Vector3): boolean
	local ab = to - from
	local lenSq = ab:Dot(ab)
	if lenSq < 1e-4 then return false end
	for _, cell in CollectionService:GetTagged("SmokeCloud") do
		local r = tonumber(cell:GetAttribute("Radius")) or 0
		if r > 0.5 and cell:IsA("BasePart") then
			local c = cell.Position
			local t = math.clamp((c - from):Dot(ab) / lenSq, 0, 1)
			if (from + ab * t - c).Magnitude < r then return true end
		end
	end
	return false
end

-- walls (any solid / queryable part, characters excluded) and smoke both block
local function visible(from: Vector3, to: Vector3, model): boolean
	rayParams.FilterDescendantsInstances = { player.Character, model, workspace.CurrentCamera }
	local hit = workspace:Raycast(from, to - from, rayParams)
	if hit then return false end
	return not smokeBlocks(from, to)
end

-- angle errors from the camera's look to a world point: yaw (+ = point is to the left), pitch (+ = point is above)
local function errors(cam: CFrame, point: Vector3): (number, number, number)
	local d = cam:VectorToObjectSpace(point - cam.Position)
	local yaw = math.atan2(-d.X, -d.Z)
	local pitch = math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
	-- total angle off the crosshair
	local look = Vector3.new(0, 0, -1)
	local ang = math.acos(math.clamp(look:Dot(d.Unit), -1, 1))
	return yaw, pitch, ang
end

-- the target nearest the crosshair inside the cone: model, point, yawErr, pitchErr, angle
function AimAssist.Pick(cam: CFrame, strength: number)
	local cone = math.rad(C.ConeDeg + C.ConeDegPerStrength * strength)
	local best, bestAng, bp, by, bpi = nil, cone, nil, 0, 0
	for _, model in candidates() do
		if alive(model) then
			local point = neckPoint(model)
			if point and (point - cam.Position).Magnitude <= C.Range then
				local y, p, a = errors(cam, point)
				if a < bestAng and visible(cam.Position, point, model) then
					best, bestAng, bp, by, bpi = model, a, point, y, p
				end
			end
		end
	end
	return best, bp, by, bpi, bestAng, cone
end

function AimAssist.Step(dt: number, cam: CFrame, input)
	if not AimAssist.InputEligible() then return NONE end
	local s = AimAssist.Strength()
	if s <= 0 then return NONE end
	local model, point, yawErr, pitchErr, ang, cone = AimAssist.Pick(cam, s)
	if not model then return NONE end
	local close = 1 - math.clamp(ang / cone, 0, 1) -- 1 on the neck, 0 at the cone edge
	local out = { yaw = 0, pitch = 0, sensitivity = 1 - C.Friction * s * close, target = model, point = point }
	input = input or {}
	local active = input.aiming or input.firing or input.looking
	if not active then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		active = hum ~= nil and hum.MoveDirection.Magnitude > 0.1
	end
	if active then
		local k = math.clamp(C.PullRate * s * dt, 0, 1)
		local cap = math.rad(C.MaxPullDegPerSec) * dt
		out.yaw = math.clamp(yawErr * k, -cap, cap)
		-- vertical: only lift a crosshair that is BELOW the neck up to it; never drag it down off the head, never above the neck
		if pitchErr > 0 then out.pitch = math.clamp(pitchErr * k, 0, cap) end
	end
	return out
end

return AimAssist
