local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/AimPoseController (ModuleScript)
-- Bends the body up/down with the aim while a weapon is out, for you and for everyone else.
-- The waist only bends so far (a real back has limits); past that the head and both arms carry on,
-- so the gun still points where you aim without the spine folding backwards.
--   * Your pitch is sent to the server a few times per second (unreliable remote, cosmetic only)
--   * The server stores it as the character attribute AimPitch (clamped)
--   * Every client applies everyone's pitch locally
-- Hit validation doesn't depend on this; the server allows for small pose differences.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoverConfig"))
local AimPitchRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat"):WaitForChild("AimPitch")

local localPlayer = Players.LocalPlayer

local controller = {}
local currentPitch = setmetatable({}, { __mode = "k" }) -- [Model] = smoothed degrees (losing one is harmless)
local raisedAmt = setmetatable({}, { __mode = "k" })    -- [Model] = 0..1, how far the aim pose is blended in [POSE]
local lastSentPitch, lastSentTime = 0, 0
local myHeadPitch = 0 -- radians, read by HeadLookController (it owns your own neck)

-- How the aim is shared out (degrees). Positive = looking up.
local WAIST_UP, WAIST_DOWN = 25, 20       -- the most the back bends
local WAIST_SHARE = 0.55                  -- of the aim taken by the waist before it maxes out
local ARMS_UP, ARMS_DOWN = 55, 45         -- the arms raise/lower the gun the rest of the way
local HEAD_UP, HEAD_DOWN = 35, 40 -- [POSE] the neck bends forward further (it levels the head out of a slide lean)

local function hasWeaponOut(character: Model): boolean
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("WeaponId") ~= nil
end

-- A joint's rest pose lives in either a Motor6D's C0 or (newer rigs) its AnimationConstraint's
-- torso-side attachment. The rest pose is stored ON the joint as an attribute, so it can never be lost
-- and re-captured while bent (that was the "stuck leaning back" bug: a weak table forgot it).
local function jointTarget(joint: Instance?): (Instance?, string?)
	if not joint then return nil, nil end
	if joint:IsA("Motor6D") then return joint, "C0" end
	if joint:IsA("AnimationConstraint") then
		local a0 = (joint :: AnimationConstraint).Attachment0
		if a0 then return a0, "CFrame" end
	end
	return nil, nil
end

local function restOf(obj: Instance, prop: string): CFrame
	local rest = obj:GetAttribute("AimPoseRest")
	if typeof(rest) ~= "CFrame" then
		rest = (obj :: any)[prop]
		obj:SetAttribute("AimPoseRest", rest)
	end
	return rest
end

local function bend(joint: Instance?, degrees: number)
	local obj, prop = jointTarget(joint)
	if not obj or not prop then return end
	(obj :: any)[prop] = restOf(obj, prop) * CFrame.Angles(math.rad(degrees), 0, 0)
end

-- [POSE] 2026-10-18 (Edward: "your head also cocks back when sliding and aiming in it should look more like the body cocks
-- back to slide but your head still moves with your gun and arms to aim but make it logically sound"):
-- the split works in the body's ACTUAL lean. Animations (the slide leaning back, the run leaning forward, a dive) rotate the
-- hips (LowerTorso tilt) and the waist / neck / shoulders (their Motor6D.Transform). The aim is shared out on top of that:
--   * waist: bends with the aim as before, but not while the body is already leaning hard (a slide / dive): then the body
--     keeps the animation's lean ("the body cocks back to slide");
--   * arms: whatever is left between the chest and the aim (their own animation is the gun-holding pose);
--   * head: exactly what's left to look where the gun points, minus the neck's own animated tilt ("the head still moves with
--     your gun and arms"), all within a real neck / shoulder / back's limits.
local LEAN_HARD = 12 -- degrees of animated lean (hips + waist) above which the back stops adding its own bend

-- pitch (degrees, + = up / leaning back) of a joint's animated Transform, or 0
local function animPitch(joint: Instance?): number
	-- classic Motor6D and the newer AnimationConstraint joints (these rigs) both carry the animated pose in .Transform
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		local ok, t = pcall(function() return (joint :: any).Transform end)
		if ok and typeof(t) == "CFrame" then
			local x = t:ToEulerAnglesXYZ()
			return math.deg(x)
		end
	end
	return 0
end

-- Split a WORLD aim pitch into waist / arms / head bends for this character's current (animated) lean
local function share(character: Model, aim: number): (number, number, number)
	local lower = character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
	local upper = character:FindFirstChild("UpperTorso")
	local headPart = character:FindFirstChild("Head")
	local rightArm = character:FindFirstChild("RightUpperArm")
	local hips = lower and math.deg(math.asin(math.clamp(lower.CFrame.LookVector.Y, -1, 1))) or 0
	local lean = hips + animPitch(upper and upper:FindFirstChild("Waist"))
	local rel = aim - lean
	local waist = 0
	if math.abs(lean) < LEAN_HARD then
		waist = math.clamp(rel * WAIST_SHARE, -WAIST_DOWN, WAIST_UP)
	end
	local torso = lean + waist -- where the chest points now
	-- the arms' own animation is the gun-holding pose (it already points the gun forward from the chest), so the arms only
	-- add what's left between the chest and the aim
	local arms = math.clamp(aim - torso, -ARMS_DOWN, ARMS_UP)
	local head = math.clamp(aim - torso - animPitch(headPart and headPart:FindFirstChild("Neck")), -HEAD_DOWN, HEAD_UP)
	return waist, arms, head
end

-- For HeadLookController: how far your own head should tilt for the aim right now (radians)
function controller.GetHeadPitch(): number
	return myHeadPitch
end

local function update(dt: number)
	-- Your own pitch from the camera
	local myCharacter = localPlayer.Character
	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	local myPitch = 0
	-- Only while the gun is raised (aiming / just fired); with the gun lowered you stand normally
	local cameraController = shared.Get and shared.Get("CameraController")
	local raised = cameraController ~= nil and cameraController.IsFacingCamera()
	-- [POSE] Studio test switch: act as if the gun is raised (simulated input can't hold aim); never in a live server
	if game:GetService("RunService"):IsStudio() and localPlayer:GetAttribute("DebugForceRaised") == true then raised = true end
	local myRaised = raised and localPlayer:GetAttribute("Setting_AimingAnimation") ~= false -- [POSE]
	if myCharacter and myHumanoid and myHumanoid.Health > 0 and hasWeaponOut(myCharacter) and raised then
		myPitch = math.deg(math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y, -1, 1)))
		-- Aim RELATIVE to how your body is tilted right now. Sliding (leaning back) or diving (thrown forward)
		-- tilts the hips; bending the back/arms by the world aim on top of that sent the gun way too high.
		local lower = myCharacter:FindFirstChild("LowerTorso") or myCharacter:FindFirstChild("HumanoidRootPart")
		if lower then
			local tilt = math.deg(math.asin(math.clamp(lower.CFrame.LookVector.Y, -1, 1)))
			myPitch -= tilt
		end
	end

	local now = os.clock()
	if now - lastSentTime >= 1 / Config.AimPitchSendRate and math.abs(myPitch - lastSentPitch) > 1 then
		lastSentTime, lastSentPitch = now, myPitch
		AimPitchRemote:FireServer(myPitch)
	end

	local blend = 1 - math.exp(-15 * dt)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local upperTorso = character and character:FindFirstChild("UpperTorso")
		if upperTorso then
			local target = 0
			if hasWeaponOut(character) then
				target = (player == localPlayer) and myPitch or (character:GetAttribute("AimPitch") or 0)
				-- [SET] Game > Aiming Animation off: your own body stays upright (others still see your aim pose)
				if player == localPlayer and localPlayer:GetAttribute("Setting_AimingAnimation") == false then target = 0 end
			end
			local pitch = (currentPitch[character] or 0) + (target - (currentPitch[character] or 0)) * blend
			if math.abs(pitch) < 0.05 then pitch = 0 end
			currentPitch[character] = pitch

			-- [POSE] the aim pose only while the gun is up; otherwise everything eases back to rest
			local raisedNow = hasWeaponOut(character) and (player ~= localPlayer or myRaised)
			local up = (raisedAmt[character] or 0) + ((raisedNow and 1 or 0) - (raisedAmt[character] or 0)) * blend
			raisedAmt[character] = up
			-- pitch is relative to the hips (that's what's sent); the world aim adds the hips back
			local lower = character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
			local hips = lower and math.deg(math.asin(math.clamp(lower.CFrame.LookVector.Y, -1, 1))) or 0
			local waist, arms, head = share(character, pitch + hips)
			waist, arms, head = waist * up, arms * up, head * up
			bend(upperTorso:FindFirstChild("Waist"), waist)
			local rightArm = character:FindFirstChild("RightUpperArm")
			local leftArm = character:FindFirstChild("LeftUpperArm")
			bend(rightArm and rightArm:FindFirstChild("RightShoulder"), arms)
			bend(leftArm and leftArm:FindFirstChild("LeftShoulder"), arms)
			if player == localPlayer then
				myHeadPitch = math.rad(head) -- HeadLookController owns your neck and blends this in
			else
				local headPart = character:FindFirstChild("Head")
				bend(headPart and headPart:FindFirstChild("Neck"), head)
			end
		end
	end
end

function controller.Start()
	RunService.RenderStepped:Connect(update)
end

return controller
