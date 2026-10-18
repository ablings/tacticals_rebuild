-- ReplicatedStorage.Modules.Shared.AimAssist (ModuleScript, client) [AIM] 2026-10-17, Edward:
-- "aim assist only exists for mobile and controller players, its base is at 50% but it has a maximum of 25% in ranked ...
--  the aim assist strength goes to a little bit below the roblox head and right around the neck area so it doesn't just get
--  headshots ... admin settings to enable aim assist for myself on pc ... and to test against an npc".
--
-- Who gets it: the last input was Touch or a Gamepad (UserInputService:GetLastInputType), or the admin override
--   (player attribute AimAssistForce = true, set by ;aimassist). Mouse + keyboard never get it.
-- Strength (0..1): admin test override AimAssistStrength (0-100, ;aimassist on <n>) else the player's Settings row
--   Setting_AimAssist ("50%" default / "25%" / "Off") else Base 50%. Ranked matches cap it at RankedCap 25%.
-- Aim point: the NECK (R15 UpperTorso.NeckRigAttachment, else just under the Head), never the head. The vertical centering
--   only lifts the crosshair up TO the neck; it never drags a crosshair that is on the head down, so headshots stay the
--   player's own skill.
-- v2 2026-10-18 (Edward: "if i am moving my crosshair away from the dummy it drags it towards ... at 100 strength it should be
--   better ... look up how aim assist is made in real fps games"): the three layers shipped shooters use (Halo magnetism /
--   friction, Call of Duty + Apex rotational assist, Bloodhunt slowdown + rotation), all scaled by strength:
--   slowdown:   turning is slower while the crosshair is near a target (more at the centre), so it doesn't overshoot. Turning
--               AWAY from the target only gets a little of it (EscapeFriction), so leaving a target never feels sticky.
--   rotational: while the player turns or moves, the camera follows the target's movement RELATIVE to the player (the
--               target's angle change since last frame x Track x strength): strafing past a dummy or tracking a strafing
--               enemy keeps the crosshair on them. A target that isn't moving relative to you adds nothing.
--   centering:  a small pull to the neck, ONLY while the player's own turn already points toward the target (never against
--               the input: turning away is never dragged back).
--   The player's turn direction is measured from the camera's own rotation between frames (minus what aim assist added).
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
	Range = 400,            -- studs (was 160: the Training range's far dummies, 160-350 studs out, never got assist)
	ConeDeg = 3,            -- assist cone half-angle at 0 strength ...
	ConeDegPerStrength = 7, -- ... plus this x strength (50% -> 6.5 deg)
	MaxOffset = 6,          -- ... but never wider than this many studs either side of the target (far targets: a narrow
	                        --     cone, ~1 deg at 300 studs, so long range doesn't turn into a magnet; close range unchanged)
	Friction = 0.65,        -- slowdown: sensitivity at the target centre drops by Friction x strength (100% -> 35%, 50% -> 67%)
	EscapeFriction = 0.25,  -- ... and only this share of it while turning away from the target
	Track = 0.9,            -- rotational: share of the target's relative movement the camera follows, x sqrt(strength) (100% -> 90%, 50% -> 64%)
	CenterRate = 8,         -- centering: per second at full strength, fraction of the angle error removed while turning toward it
	MaxPullDegPerSec = 60,  -- hard cap on how fast aim assist may turn the camera
	Sticky = 0.5,           -- target choice: the current target's score is halved (another must be ~2x closer to take over),
	                        --   but only while the player isn't turning away from it
	Intent = 0.35,          -- target choice: the target the player turns toward scores up to Intent x (0.5 + strength) better
	                        --   (one turned away from, that much worse)
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
	-- an admin test strength (;aimassist on <0-100>) first, else the player's Settings > Aim Assist choice (never above Base),
	-- else Base. ;aimassist on with no number uses the Settings choice (Edward 2026-10-18).
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

-- the target to assist inside the cone: model, point, yawErr, pitchErr, angle, cone.
-- Score = angle / that target's cone (each target's cone narrows with distance); lower wins. Edward: "smart enough to detect
-- which target ... instead of juggling between two you put your crosshair in the middle of":
--   * stickiness: the target already being assisted (current) scores x Sticky, so a second target has to be clearly closer to
--     take over (no flicking between two equal targets);
--   * intent: a target the player's turn (inYaw, inPitch) is heading toward scores lower, one it's turning away from higher.
function AimAssist.Pick(cam: CFrame, strength: number, current: Model?, inYaw: number?, inPitch: number?)
	local cone = math.rad(C.ConeDeg + C.ConeDegPerStrength * strength)
	local inMag = math.sqrt((inYaw or 0) ^ 2 + (inPitch or 0) ^ 2)
	local best, bestScore, bestAng, bestCone, bp, by, bpi = nil, math.huge, cone, cone, nil, 0, 0
	for _, model in candidates() do
		if alive(model) then
			local point = neckPoint(model)
			local dist = point and (point - cam.Position).Magnitude
			if point and dist <= C.Range then
				local c = math.min(cone, math.atan((C.MaxOffset or 6) / math.max(dist, 1)))
				local y, p, a = errors(cam, point)
				if a < c then
					local score = a / c
					local toward = 0 -- 1 = the player's turn heads straight at it, -1 = straight away from it
					if inMag > 1e-5 and a > 1e-5 then
						toward = math.clamp(((inYaw or 0) * y + (inPitch or 0) * p) / (inMag * a), -1, 1)
					end
					-- stickiness only while the player isn't turning away from it (Edward: "if i am moving my mouse away from the
					-- target the aim assist should go to another one ... or the one im moving my mouse towards")
					if model == current and toward > -0.3 then score *= C.Sticky end
					-- intent, stronger with strength (Edward: "depending on the strength"): 25% -> 0.26, 50% -> 0.35, 100% -> 0.52
					score *= 1 - C.Intent * (0.5 + strength) * toward
					if score < bestScore and visible(cam.Position, point, model) then
						best, bestScore, bestAng, bestCone, bp, by, bpi = model, score, a, c, point, y, p
					end
				end
			end
		end
	end
	return best, bp, by, bpi, bestAng, bestCone
end

-- world yaw / pitch of a direction (yaw + = left, pitch + = up), and an angle wrapped to -pi..pi
local function worldAngles(v: Vector3): (number, number)
	local u = v.Unit
	return math.atan2(-u.X, -u.Z), math.asin(math.clamp(u.Y, -1, 1))
end
local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local prevCam = nil                   -- { yaw, pitch } of the camera at the last Step
local lastOut = { yaw = 0, pitch = 0 } -- what aim assist turned the camera by last Step
local track = { model = nil, yaw = 0, pitch = 0 } -- the target's world angles last Step (rotational assist)

local function reset()
	track.model = nil
	lastOut = { yaw = 0, pitch = 0 }
	return NONE
end

function AimAssist.Step(dt: number, cam: CFrame, input)
	input = input or {}
	-- the player's own turn since the last frame = the camera's rotation minus what aim assist added (one frame behind)
	local cy, cp = worldAngles(cam.LookVector)
	local inYaw, inPitch = 0, 0
	if prevCam then
		inYaw = wrap(cy - prevCam[1]) - lastOut.yaw
		inPitch = (cp - prevCam[2]) - lastOut.pitch
	end
	prevCam = { cy, cp }
	if not AimAssist.InputEligible() then return reset() end
	local s = AimAssist.Strength()
	if s <= 0 then return reset() end
	local model, point, yawErr, pitchErr, ang, cone = AimAssist.Pick(cam, s, track.model, inYaw, inPitch)
	if not model then return reset() end

	-- how the player's turn lines up with the target: 1 = straight toward it, -1 = straight away, 0 = across / not turning
	local inMag = math.sqrt(inYaw * inYaw + inPitch * inPitch)
	local errMag = math.sqrt(yawErr * yawErr + pitchErr * pitchErr)
	local toward = 0
	if inMag > 1e-5 and errMag > 1e-5 then toward = (inYaw * yawErr + inPitch * pitchErr) / (inMag * errMag) end
	local leaving = toward < -0.3

	-- slowdown (stronger at the centre; only a little while turning away, so leaving a target is never sticky)
	local close = 1 - math.clamp(ang / cone, 0, 1) -- 1 on the neck, 0 at the cone edge
	local friction = C.Friction * s * close * (leaving and C.EscapeFriction or 1)
	local out = { yaw = 0, pitch = 0, sensitivity = 1 - friction, target = model, point = point }

	-- rotational: follow the target's movement relative to the player, while the player turns or moves
	local ty, tp = worldAngles(point - cam.Position)
	local dTy, dTp = 0, 0
	if track.model == model then dTy, dTp = wrap(ty - track.yaw), tp - track.pitch end
	track.model, track.yaw, track.pitch = model, ty, tp
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1
	local active = input.looking or moving
	if active and not leaving then
		local k = C.Track * math.sqrt(s) -- 25% -> 45%, 50% -> 64%, 100% -> 90% of the relative movement followed
		out.yaw += dTy * k
		out.pitch += dTp * k * 0.5 -- vertical relative motion (jumps, slopes) only half: never a drag off the head
	end

	-- centering: only while the player's own turn already points toward the target, never against it
	if input.looking and toward > 0.2 then
		local k = math.clamp(C.CenterRate * s * dt, 0, 1) * toward
		out.yaw += yawErr * k
		-- vertical: only lift a crosshair that is BELOW the neck up to it; never drag it down off the head
		if pitchErr > 0 then out.pitch += pitchErr * k end
	end

	local cap = math.rad(C.MaxPullDegPerSec) * dt
	out.yaw = math.clamp(out.yaw, -cap, cap)
	out.pitch = math.clamp(out.pitch, -cap, cap)
	lastOut = { yaw = out.yaw, pitch = out.pitch }
	return out
end

return AimAssist
