-- StarterPlayerScripts.JumpFeel (LocalScript, hub + match places) [JUMPFEEL] 2026-10-18, Edward: "the gravity is way too high on
-- jumping ... like too fast". A softer jump arc for the player's own character ONLY (workspace.Gravity stays 196.2, so
-- grenades / gadgets / props keep their arcs):
--   * from the moment a jump starts (Humanoid state Jumping: Roblox's jump in the lobby, CoverController's hop in matches)
--     until landing, a VectorForce on the root cancels (1 - Scale) of gravity, so the character falls at Scale x gravity;
--   * the launch speed is capped at sqrt(2 g Scale H) (H = JumpHeight at the jump), so the apex stays as high as before (cover hops,
--     vault clearances and level design unchanged) - the arc is just slower and floatier (airtime x 1/sqrt(Scale)).
-- Falling off a ledge without jumping keeps normal gravity. Scale: ReplicatedStorage attribute JumpGravityScale (0.2..1),
-- default 0.75 (25% less gravity in the air, airtime about +15%).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_SCALE = 0.75 -- Edward 2026-10-18: "maybe 25% less" gravity
local player = Players.LocalPlayer
local humanoid, root, force, attach = nil, nil, nil, nil
local jumping = false   -- in the air from a jump
local jumpHeight = 0    -- the Humanoid's JumpHeight when this jump started (the hop sets HopHeight just before)

local function scale(): number
	local s = tonumber(ReplicatedStorage:GetAttribute("JumpGravityScale")) or DEFAULT_SCALE
	return math.clamp(s, 0.2, 1)
end

local function bind(character: Model)
	jumping = false
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not (humanoid and root) then return end
	attach = Instance.new("Attachment")
	attach.Name = "JumpFeelAttachment"
	attach.Parent = root
	force = Instance.new("VectorForce")
	force.Name = "JumpFeel"
	force.Attachment0 = attach
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Enabled = false
	force.Parent = root
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			jumping = true
			jumpHeight = humanoid.UseJumpPower and (humanoid.JumpPower ^ 2) / (2 * workspace.Gravity) or humanoid.JumpHeight
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.Swimming or new == Enum.HumanoidStateType.Dead
			or new == Enum.HumanoidStateType.Seated or new == Enum.HumanoidStateType.Climbing then
			jumping = false
		end
	end)
end

player.CharacterAdded:Connect(bind)
if player.Character then task.spawn(bind, player.Character) end

RunService.Heartbeat:Connect(function()
	if not (force and force.Parent and root and humanoid and humanoid.Parent) then return end
	local s = scale()
	if not jumping or s >= 0.999 or root.Anchored then
		force.Enabled = false
		return
	end
	-- keep the apex height: under s x gravity the launch may be at most sqrt(2 * g * s * H). The Humanoid keeps pushing its own
	-- (full-gravity) jump speed for a few frames while in the Jumping state, so cap it every frame of that state.
	local v = root.AssemblyLinearVelocity
	local vmax = math.sqrt(2 * workspace.Gravity * s * math.max(jumpHeight, 0))
	if humanoid:GetState() == Enum.HumanoidStateType.Jumping and v.Y > vmax then
		root.AssemblyLinearVelocity = Vector3.new(v.X, vmax, v.Z)
	end
	force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - s), 0)
	force.Enabled = true
end)
