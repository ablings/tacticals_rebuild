-- Client/Controllers/TrainingPadsController (client, lobby place): jump pads in Training only (notes/training_extras_done.md).
-- Pads: parts tagged TrainingJumpPad in LobbyMap.Training.Extras.JumpPads, attribute LandAt (world point on the landing
-- surface), Apex (studs above the higher end). The character is client-owned, so the launch is set here: a ballistic arc
-- from the pad to LandAt, its peak kept CeilingY - Headroom below the Training ceiling; the horizontal speed is held each
-- frame (Humanoid air control would bleed it off). While a pad flight lasts, IsPadFlight() is true and WeaponController lets
-- you shoot in the air (the normal no-shooting-mid-hop rule is back as soon as you land). Gated: nothing runs outside Training.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Gate = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
local RunService = Gate.RunService
local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)

local player = Players.LocalPlayer
local controller = {}
local flight = nil          -- { t0, T, vxz, landedAt }
local lastLaunch = {}       -- [pad] = os.clock()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

function controller.IsPadFlight(): boolean
	return flight ~= nil
end

local function flash(pad: BasePart)
	for _, p in pad.Parent:GetChildren() do
		if p.Name == "PadRing" and (p.Position - pad.Position).Magnitude < 3 then
			local c = p.Color
			p.Color = Color3.fromRGB(236, 232, 218)
			TweenService:Create(p, TweenInfo.new(0.45), { Color = c }):Play()
		end
	end
end

local function launch(pad: BasePart, root: BasePart, hum: Humanoid)
	local land = pad:GetAttribute("LandAt")
	if typeof(land) ~= "Vector3" then return end
	local g = workspace.Gravity
	local start = root.Position
	local target = land + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	local apexY = math.max(start.Y, target.Y) + (pad:GetAttribute("Apex") or TX.JumpPads.Apex)
	apexY = math.min(apexY, TX.CeilingY - TX.JumpPads.Headroom)               -- root apex: the head stays under the ceiling
	apexY = math.max(apexY, target.Y + 1.5)
	local up = math.max(apexY - start.Y, 1)
	local vy = math.sqrt(2 * g * up)
	local T = vy / g + math.sqrt(2 * math.max(apexY - target.Y, 0.1) / g)
	local flat = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
	local vxz = flat / T
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = vxz + Vector3.new(0, vy, 0)
	flight = { t0 = os.clock(), T = T, vxz = vxz, vy = vy, g = g, start = start }
	flash(pad)
end

function controller.Start()
	if not (ok and TX.On("JumpPads")) then return end
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) or hum.Health <= 0 then flight = nil; return end
		local now = os.clock()
		if flight then
			local st = hum:GetState()
			local airborne = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
			if now - flight.t0 > 0.25 and not airborne then
				flight = nil                                -- landed: the normal no-shooting-in-the-air rule is back
			elseif now - flight.t0 > flight.T + 1.5 then
				flight = nil
			else
				local t = now - flight.t0
				if t < flight.T then
					-- follow the planned arc (Humanoid air control and the first grounded frame would otherwise eat speed):
					-- the arc's velocity plus a small pull back onto the arc's position
					local f = flight
					local want = f.start + f.vxz * t + Vector3.new(0, f.vy * t - 0.5 * f.g * t * t, 0)
					root.AssemblyLinearVelocity = f.vxz + Vector3.new(0, f.vy - f.g * t, 0) + (want - root.Position) * 8
				end
				return
			end
		end
		local pads = CollectionService:GetTagged("TrainingJumpPad")
		if #pads == 0 then return end
		params.FilterDescendantsInstances = pads
		local r = workspace:Raycast(root.Position, Vector3.new(0, -(hum.HipHeight + root.Size.Y / 2 + 1), 0), params)
		if not r then return end
		local pad = r.Instance
		if lastLaunch[pad] and now - lastLaunch[pad] < TX.JumpPads.Cooldown then return end
		local Get = shared.Get
		local cover = Get and Get("CoverController")
		local move = Get and Get("MovementController")
		if cover and ((cover.IsVaulting and cover.IsVaulting()) or (cover.IsMoving and cover.IsMoving())) then return end
		if move and move.IsSliding and move.IsSliding() then return end
		lastLaunch[pad] = now
		launch(pad, root, hum)
	end)
end

return controller
