-- fix/draw_animations.lua [DRAWANIM] (2026-10-19, Edward: "i will pull the assault rifle from my back"; yes to making and uploading
-- the draw animations). Builds four KeyframeSequences in ReplicatedStorage.Repository.AnimationSources, in the same pose tree
-- as PistolEquip (HumanoidRootPart > LowerTorso > UpperTorso > arms; Euler degrees per joint):
--   DrawHip / DrawHipLeft    the hand drops to the thigh holster, grabs, brings the gun up into the Hold pose
--   DrawBack / DrawBackLeft  the hand reaches up over the shoulder, grabs the gun off the back, swings it forward into Hold
-- The Left versions mirror the right ones (gun in the left hand after a shoulder swap). WeaponController plays Draw instead of
-- Equip when the gun's WeaponConfig.DrawAnimation names one, sped to fit DrawTime. Live needs the uploaded ids: after
-- "Save to Roblox" (group Gunsy Funsy) each source gets attribute PublishedId = "rbxassetid://<id>" like the existing ones.
-- Rebuilding keeps an existing PublishedId (so a re-run doesn't lose the upload). UNDO = true removes the four sources.
local UNDO = false --@UNDO
local SRC = game:GetService("ReplicatedStorage").Repository.AnimationSources

-- keyframes: { time, { [joint] = {x, y, z} } } for the RIGHT-hand version; the left version mirrors joints and Y/Z
local HOLD = { LeftUpperArm = { 87, -4, 60 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 90, 0, 0 } }
local DEFS = {
	DrawHip = {
		{ 0.00, { LeftUpperArm = { 5, 0, 0 }, RightUpperArm = { -8, 0, 12 }, RightLowerArm = { 18, 0, 0 }, RightHand = { -25, 0, 0 } } },
		{ 0.10, { LeftUpperArm = { 5, 0, 0 }, RightUpperArm = { -12, 0, 14 }, RightLowerArm = { 22, 0, 0 }, RightHand = { -20, 0, 0 } } },
		{ 0.22, { LeftUpperArm = { 45, -2, 30 }, LeftLowerArm = { 8, 0, 0 }, RightUpperArm = { 55, 0, 4 }, RightLowerArm = { 35, 0, 0 } } },
		{ 0.35, HOLD },
	},
	DrawBack = {
		{ 0.00, { LeftUpperArm = { 5, 0, 0 }, RightUpperArm = { 165, 0, -25 }, RightLowerArm = { 95, 0, 0 }, RightHand = { 20, 0, 0 } } },
		{ 0.14, { LeftUpperArm = { 25, 0, 10 }, RightUpperArm = { 170, 0, -30 }, RightLowerArm = { 105, 0, 0 }, RightHand = { 25, 0, 0 } } },
		{ 0.32, { LeftUpperArm = { 70, -3, 45 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 120, 0, -8 }, RightLowerArm = { 45, 0, 0 } } },
		{ 0.48, HOLD },
	},
}

local function mirror(name: string): string
	if name:sub(1, 4) == "Left" then return "Right" .. name:sub(5) end
	if name:sub(1, 5) == "Right" then return "Left" .. name:sub(6) end
	return name
end

local function build(name: string, keys, left: boolean): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = false
	ks.Priority = Enum.AnimationPriority.Action2 -- like PistolEquip (WeaponController raises Equip / Draw to Action4)
	for _, key in keys do
		local kf = Instance.new("Keyframe")
		kf.Time = key[1]
		local root = Instance.new("Pose"); root.Name = "HumanoidRootPart"; root.Parent = kf
		local lower = Instance.new("Pose"); lower.Name = "LowerTorso"; lower.Parent = root
		local upper = Instance.new("Pose"); upper.Name = "UpperTorso"; upper.Parent = lower
		local joints = {}
		for joint, e in key[2] do
			local j = left and mirror(joint) or joint
			joints[j] = left and { e[1], -e[2], -e[3] } or e
		end
		local function pose(nameP, parent)
			local p = Instance.new("Pose")
			p.Name = nameP
			local e = joints[nameP]
			if e then p.CFrame = CFrame.Angles(math.rad(e[1]), math.rad(e[2]), math.rad(e[3])) end
			p.Parent = parent
			return p
		end
		for _, side in { "Left", "Right" } do
			local ua = pose(side .. "UpperArm", upper)
			local la = pose(side .. "LowerArm", ua)
			pose(side .. "Hand", la)
		end
		kf.Parent = ks
	end
	return ks
end

local log = {}
for base, keys in DEFS do
	for _, left in { false, true } do
		local name = base .. (left and "Left" or "")
		local old = SRC:FindFirstChild(name)
		local keepId = old and old:GetAttribute("PublishedId")
		if old then old:Destroy() end
		if not UNDO then
			local ks = build(name, keys, left)
			if keepId then ks:SetAttribute("PublishedId", keepId) end
			ks.Parent = SRC
			table.insert(log, name .. (keepId and (" (kept " .. keepId .. ")") or ""))
		else
			table.insert(log, "removed " .. name)
		end
	end
end
return "DRAWANIM: " .. table.concat(log, ", ")
