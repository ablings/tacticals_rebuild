--@lib
-- CoverPullUp: jump, both hands catch a ledge (head height or lower), pull, right knee up onto the top, stand.
-- Root motion is NOT in the clip (Roblox never applies it): the code moves the HRP along ROOT below (stored on the
-- source as attribute RootKeys) and the clip's hands/feet are solved to sit on the ledge along that path.
-- Signs (checked on the FK puppet): torso/head +X = tip BACK (lean forward is negative X); UpperArm +X = raise forward;
-- LowerArm +X = elbow bend; UpperLeg +X = knee up; LowerLeg -X = knee bend; Foot +X = toes up.
local LEN = 0.70
local T_GRAB, T_TOP = 0.10, 0.50
local H, D = 4.5, 1.6            -- authored ledge: top 4.5 studs above the feet, face 1.6 studs ahead of the start
local EDGE_Z = -D - 0.22         -- palms land just past the edge
-- HRP height above the start floor (y) and forward offset (z, negative = toward the ledge) at each key
local ROOT = {
	{ 0.00, 2.80, 0.00 },  -- launch crouch
	{ 0.05, 3.22, -0.10 },  -- the hop is quick off the floor
	{ T_GRAB, 3.35, -0.20 }, -- small hop, hands land on the edge
	{ 0.24, 4.35, -0.50 },  -- pull: chest up to the edge
	{ 0.37, 6.05, -1.05 },  -- press: hips over the edge, right foot on the top
	{ 0.43, H + 2.55, -1.90 }, -- push-up: hips rise past the lip so the trailing leg clears it
	{ T_TOP, H + 2.20, -2.30 }, -- both feet land on the top (crouched)
	{ 0.62, H + 2.80, -2.30 },
	{ LEN, H + 2.96, -2.30 }, -- standing on the top
}
-- start 1.6 from the face (was 1.2): the path after take-off moves 0.4 further forward
for _, r in ROOT do r[3] -= (r[1] >= T_GRAB and 0.4 or 0.4 * r[1] / T_GRAB) end
local function rootOf(t) for _, r in ROOT do if math.abs(r[1] - t) < 1e-4 then return Vector3.new(0, r[2], r[3]) end end end

local function arms(ua, la, out)
	return { LeftUpperArm = { ua, 0, -out }, LeftLowerArm = { la, 0, 0 }, RightUpperArm = { ua, 0, out }, RightLowerArm = { la, 0, 0 } }
end
local function merge(...)
	local r = {}
	for _, t in { ... } do for k, v in t do r[k] = (typeof(v) == "CFrame") and v or L.cf(v) end end
	return r
end
-- palm on the ledge: fingers forward and a little down, palm facing down
local GUN_LIFT = 0.55
local PALM_R = CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(90), 0, 0) -- gun hand: level, gun forward
local PALM_L = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.Angles(math.rad(75), 0, 0)
-- pushing down by the hips: fingers forward, palm down, wrist bent back
local PUSH_R = CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(92), 0, 0)
local PUSH_L = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.Angles(math.rad(95), 0, 0)
local FLAT = CFrame.identity -- foot flat in HRP space

local errs = {}
local badSolves = {}
local function hands(poses, t, rotR, rotL)
	local r = rootOf(t)
	for _, side in { { "Right", 0.55, rotR }, { "Left", -0.55, rotL } } do
		-- off hand: palm on the top (wrist 0.12 up); gun hand: a fist on the edge, gun lying level above the top
		local lift = side[1] == "Right" and GUN_LIFT or 0.12
		local target = Vector3.new(side[2], H, EDGE_Z) - r + Vector3.new(0, lift, 0)
		local e = L.solve(poses, side[1] .. "UpperArm", side[1] .. "LowerArm", side[1] .. "Hand", target, 1)
		table.insert(errs, e); if e > 0.05 then table.insert(badSolves, string.format("%sHand@%.3f=%.2f", side[1], t, e)) end
		L.orient(poses, side[1] .. "LowerArm", side[1] .. "Hand", side[3])
	end
end
local function foot(poses, t, side, worldTarget, rot)
	local r = rootOf(t)
	local e = L.solve(poses, side .. "UpperLeg", side .. "LowerLeg", side .. "Foot", worldTarget - r, -1)
	table.insert(errs, e); if e > 0.05 then table.insert(badSolves, string.format("%sFoot@%.3f=%.2f", side, t, e)) end
	L.orient(poses, side .. "LowerLeg", side .. "Foot", rot or FLAT)
end
local ANK = 0.25 -- ankle pivot height above the sole (R15 foot: centre 0.15 up, ankle 0.10 above it)

local P = {}
-- 0.00 launch: moving on frame 1 (knees bent, arms swinging up, eyes on the ledge); feet on the floor
-- gun hand: muzzle up for the jump
P[1] = merge(arms(20, 145, 10), { RightHand = { 0, 0, 0 } }, { LowerTorso = { -14, 0, 0 }, UpperTorso = { -6, 0, 0 }, Head = { 16, 0, 0 } })
foot(P[1], 0, "Left", Vector3.new(-0.5, ANK, 0.05)); foot(P[1], 0, "Right", Vector3.new(0.5, ANK, 0.05))
-- 0.10 EdgeGrab: both palms on the edge, body under it, legs hang
P[2] = merge(arms(120, 15, 8), { LowerTorso = { -6, 0, 0 }, UpperTorso = { 0, 0, 0 }, Head = { 18, 0, 0 },
	LeftUpperLeg = { 10, 0, 0 }, LeftLowerLeg = { -30, 0, 0 }, LeftFoot = { -15, 0, 0 },
	RightUpperLeg = { 22, 0, 0 }, RightLowerLeg = { -48, 0, 0 }, RightFoot = { -15, 0, 0 } })
hands(P[2], T_GRAB, PALM_R, PALM_L)
-- 0.24 pull: elbows bend and flare, chest to the edge, right knee drives up
P[3] = merge(arms(70, 90, 22), { LowerTorso = { -16, 0, 0 }, UpperTorso = { -12, 0, 0 }, Head = { 20, 0, 0 },
	LeftUpperLeg = { 6, 0, 0 }, LeftLowerLeg = { -35, 0, 0 }, LeftFoot = { -10, 0, 0 },
	RightUpperLeg = { 25, 0, 0 }, RightLowerLeg = { -70, 0, 0 }, RightFoot = { -5, 0, 0 } }) -- legs hang until the hips clear the top
hands(P[3], 0.24, PALM_R, PALM_L)
-- 0.37 press: arms straighten down by the hips, chest over the top, right foot set on the top, left leg trails
P[4] = merge(arms(10, 20, 14), { RightHand = { 80, 0, 0 } }, { LowerTorso = { -34, 0, 0 }, UpperTorso = { -12, 0, 0 }, Head = { 36, 0, 0 },
	LeftUpperLeg = { -14, 0, 0 }, LeftLowerLeg = { -45, 0, 0 }, LeftFoot = { -15, 0, 0 },
	RightUpperLeg = { 110, 0, 0 }, RightLowerLeg = { -120, 0, 0 } })
foot(P[4], 0.37, "Right", Vector3.new(0.5, H + ANK, -2.7)) -- set where it stays planted
-- 0.50 TopReached: both feet land on the top in a low crouch
P[5] = merge(arms(30, 35, 12), { RightHand = { 70, 0, 0 } }, { LowerTorso = { -20, 0, 0 }, UpperTorso = { -6, 0, 0 }, Head = { 20, 0, 0 },
	LeftUpperLeg = { 60, 0, 0 }, LeftLowerLeg = { -100, 0, 0 }, RightUpperLeg = { 70, 0, 0 }, RightLowerLeg = { -110, 0, 0 } })
foot(P[5], T_TOP, "Left", Vector3.new(-0.5, H + ANK, -2.65)); foot(P[5], T_TOP, "Right", Vector3.new(0.5, H + ANK, -2.7))
-- 0.62 rise (feet stay planted, no overshoot)
P[6] = merge(arms(8, 14, 6), { RightHand = { 60, 0, 0 } }, { LowerTorso = { -6, 0, 0 }, UpperTorso = { -2, 0, 0 }, Head = { 5, 0, 0 },
	LeftUpperLeg = { 14, 0, 0 }, LeftLowerLeg = { -24, 0, 0 }, RightUpperLeg = { 16, 0, 0 }, RightLowerLeg = { -26, 0, 0 } })
foot(P[6], 0.62, "Left", Vector3.new(-0.5, H + ANK, -2.65)); foot(P[6], 0.62, "Right", Vector3.new(0.5, H + ANK, -2.7))
-- 0.70 standing
P[7] = merge({ RightHand = { 45, 0, 0 } }) -- low ready; the weapon hold takes over as the clip fades out

-- grip window (0.10 -> 0.37): extra keys every ~1/30 s with the body blended between the authored keys and the hands
-- re-solved on the ledge for the root at that time (baked IK), linear between them so the palms stay planted
local function lerpPoses(a, b, u)
	local r = {}
	for j in L.TREE do r[j] = (a[j] or CFrame.identity):Lerp(b[j] or CFrame.identity, u) end
	return r
end
local function rootLin(t)
	for i = 1, #ROOT - 1 do
		local a, b = ROOT[i], ROOT[i + 1]
		if t >= a[1] - 1e-6 and t <= b[1] + 1e-6 then
			local u = (t - a[1]) / (b[1] - a[1])
			return Vector3.new(0, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u)
		end
	end
end
local KEYS = { { 0.00, poses = P[1], ease = "Cubic", dir = "Out" } }
-- 0.025 tuck: elbows bent, hands rise close to the face, muzzle up
do
	local t = 0.025
	local poses = lerpPoses(P[1], P[2], 0.35)
	for k, v in merge(arms(130, 90, 10), { RightHand = { 0, 0, 0 }, LeftHand = { 0, 0, 0 } }) do poses[k] = v end
	local rl = rootLin(t)
	table.insert(ROOT, { t, rl.Y, rl.Z })
	table.insert(KEYS, { t, poses = poses, ease = "Linear" })
end
-- 0.05 reach: hands come up the face and over the lip (never under it)
do
	local t = 0.05
	local poses = lerpPoses(P[1], P[2], 0.5)
	for _, j in { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" } do poses[j] = P[2][j] end -- seed: grab arm shape
	local rl = rootLin(t)
	table.insert(ROOT, { t, rl.Y, rl.Z })
	for _, side in { { "Right", 0.55, CFrame.Angles(math.rad(160), 0, 0), 0.75 }, { "Left", -0.55, PALM_L, 0.35 } } do
		local target = Vector3.new(side[2], H + side[4], -D + 0.05) - rl
		local e = L.solve(poses, side[1] .. "UpperArm", side[1] .. "LowerArm", side[1] .. "Hand", target, 1)
		table.insert(errs, e); if e > 0.05 then table.insert(badSolves, string.format("%sHand@%.3f=%.2f", side[1], t, e)) end
		L.orient(poses, side[1] .. "LowerArm", side[1] .. "Hand", side[3])
	end
	table.insert(KEYS, { t, poses = poses, ease = "Linear" })
end
local SEG = { { T_GRAB, 0.24, P[2], P[3], PALM_R, PALM_L, PALM_R, PALM_L }, { 0.24, 0.37, P[3], P[4], PALM_R, PALM_L, PUSH_R, PUSH_L } }
for si, sg in SEG do
	local n = 4
	for i = 0, n - 1 do
		local u = i / n
		local t = sg[1] + (sg[2] - sg[1]) * u
		local poses = lerpPoses(sg[3], sg[4], u)
		table.insert(ROOT, { t, rootLin(t).Y, rootLin(t).Z })
		hands(poses, t, sg[5]:Lerp(sg[7], u), sg[6]:Lerp(sg[8], u))
		-- right leg hangs (P[3]) until the hips clear the top, then the knee comes over the lip
		local rf = nil
		if t >= 0.24 - 1e-6 and t < 0.345 then
			poses.RightUpperLeg, poses.RightLowerLeg, poses.RightFoot = P[3].RightUpperLeg, P[3].RightLowerLeg, P[3].RightFoot
			poses.LeftUpperLeg, poses.LeftLowerLeg, poses.LeftFoot = P[3].LeftUpperLeg, P[3].LeftLowerLeg, P[3].LeftFoot
		elseif t >= 0.345 then rf = Vector3.new(0.5, H + 0.45, -D - 0.7) end
		if rf then foot(poses, t, "Right", rf, CFrame.Angles(math.rad(-20), 0, 0)) end
		table.insert(KEYS, { t, poses = poses, marker = (si == 1 and i == 0) and "EdgeGrab" or nil, ease = "Linear" })
	end
end
table.sort(ROOT, function(a, b) return a[1] < b[1] end)
local dedup = {}
for _, r in ROOT do if not (dedup[#dedup] and math.abs(dedup[#dedup][1] - r[1]) < 1e-4) then table.insert(dedup, r) end end
ROOT = dedup
-- 0.355: the right knee comes over the lip (foot above the top), hands just leaving the push
do
	local t = 0.355
	local poses = lerpPoses(P[3], P[4], 0.85)
	poses.LeftUpperLeg, poses.LeftLowerLeg, poses.LeftFoot = P[4].LeftUpperLeg, P[4].LeftLowerLeg, P[4].LeftFoot
	local rl = rootLin(t)
	table.insert(ROOT, { t, rl.Y, rl.Z })
	foot(poses, t, "Right", Vector3.new(0.5, H + 0.55, -D - 0.45), CFrame.Angles(math.rad(-25), 0, 0))
	table.insert(KEYS, { t, poses = poses, ease = "Cubic", dir = "Out" })
end
-- 0.37 -> 0.50: the trailing left foot comes up the face and over the lip; the right foot stays planted on the top
for _, it in { { 0.40, 0.3, Vector3.new(-0.5, H + 0.15, -D + 1.2) }, { 0.44, 0.62, Vector3.new(-0.5, H + 0.6, -D - 0.6) } } do
	local t, u, lf = it[1], it[2], it[3]
	local poses = lerpPoses(P[4], P[5], u)
	local rl = rootLin(t)
	table.insert(ROOT, { t, rl.Y, rl.Z })
	foot(poses, t, "Right", Vector3.new(0.5, H + ANK, -2.7))
	foot(poses, t, "Left", lf, CFrame.Angles(math.rad(-15), 0, 0))
	-- hands come off the top as the body passes over them
	table.insert(KEYS, { t, poses = poses, ease = "Cubic", dir = "InOut" })
end
table.sort(ROOT, function(a, b) return a[1] < b[1] end)
for _, k in {
	{ 0.37, poses = P[4], ease = "Cubic", dir = "InOut" },
	{ T_TOP, poses = P[5], marker = "TopReached", ease = "Cubic", dir = "InOut" },
	{ 0.62, poses = P[6], ease = "Cubic", dir = "InOut" },
	{ LEN, poses = P[7], ease = "Cubic", dir = "InOut" },
} do table.insert(KEYS, k) end

local SRC = game.ReplicatedStorage.Repository.AnimationSources
local ks = L.build("CoverPullUp", KEYS, { loop = false, priority = Enum.AnimationPriority.Action4, full = true })
local old = SRC:FindFirstChild("CoverPullUp")
if old then
	if old:GetAttribute("PublishedId") then ks:SetAttribute("PublishedId", old:GetAttribute("PublishedId")) end
	old:Destroy()
end
local enc = {}
for _, r in ROOT do table.insert(enc, string.format("%.2f,%.2f,%.2f", r[1], r[2], r[3])) end
ks:SetAttribute("RootKeys", table.concat(enc, ";")) -- t, HRP height above the start floor, forward offset (neg = toward ledge)
ks:SetAttribute("RootKeysLedge", string.format("top %.1f above start feet, face %.1f ahead", H, D))
ks:SetAttribute("Source", "out/anim_pullup_lean/lua/pullup.lua")
ks.Parent = SRC

-- check along the real (eased) playback with the root moved linearly between keys
local rig = workspace._AnimStage.StageRig
local function rootAt(t)
	for i = 1, #ROOT - 1 do
		local a, b = ROOT[i], ROOT[i + 1]
		if t >= a[1] - 1e-6 and t <= b[1] + 1e-6 then
			local u = (t - a[1]) / (b[1] - a[1])
			return Vector3.new(0, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u)
		end
	end
	return Vector3.new(0, ROOT[#ROOT][2], ROOT[#ROOT][3])
end
_G.PULLUP_ROOT_AT = rootAt
local maxDrift, maxPen, maxBody = 0, 0, 0
local grabR
local worst = {}
for f = 0, math.floor(LEN * 60) do
	local t = f / 60
	L.pose(rig, { { ks, t } })
	local w = L.fkRig(rig)
	local r = rootAt(t)
	local wr = (w.RightLowerArm * L.motors.RightHand.C0).Position + r
	if t >= T_GRAB - 1e-6 and t <= 0.34 then
		grabR = grabR or wr
		maxDrift = math.max(maxDrift, (wr - grabR).Magnitude)
	end
	-- nothing below the top inside the block (z < -D) except the hands' own contact
	for _, n in { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg", "LowerTorso", "UpperTorso", "Head" } do
		local part = rig[n]
		local c = w[n] + r
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local p = (c * CFrame.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2)).Position
			if p.Z < -D and p.Y < H then
				local pen = math.min(H - p.Y, -D - p.Z)
				if pen > 0.15 then worst[n .. string.format("@%.2f", t)] = math.max(worst[n .. string.format("@%.2f", t)] or 0, pen) end
				if n:find("Foot") or n:find("Leg") then maxPen = math.max(maxPen, pen) else maxBody = math.max(maxBody, pen) end
			end
		end end end
	end
end
-- gun parts (pistol and rifle on the right hand) must stay out of the ledge and the floor
local gunPen = {}
for _, gunName in { "Pistol", "AutoRifle" } do
	local tool = game.ReplicatedStorage.Repository.Weapons[gunName]
	local worstG, at, what = 0, 0, ""
	for f = 0, math.floor(LEN * 60) do
		local t = f / 60
		L.pose(rig, { { ks, t } })
		local w = L.fkRig(rig)
		local hand = (w.RightHand + rootAt(t)) * rig.RightHand.RightGripAttachment.CFrame * tool.Grip:Inverse() * tool.Handle.CFrame:Inverse()
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") then
				local c = hand * part.CFrame
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					local q = (c * CFrame.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2)).Position
					local pen = 0
					if q.Z < -D and q.Y < H then pen = math.min(H - q.Y, -D - q.Z) end
					if q.Y < 0 then pen = math.max(pen, -q.Y) end
					if pen > worstG then worstG, at, what = pen, t, part.Name end
				end end end
			end
		end
	end
	table.insert(gunPen, string.format("%s %.2f at %.2f (%s)", gunName, worstG, at, what))
end
local wl = {}
for k, v in worst do table.insert(wl, string.format("%s=%.2f", k, v)) end
table.sort(wl)
return table.concat(wl, " ") .. " || gun: " .. table.concat(gunPen, ", ") .. " || bad solves: " .. table.concat(badSolves, " ") .. " || " .. string.format("solve errors max %.3f | right wrist drift while gripping %.2f studs | legs into the block %.2f | body into the block %.2f",
	math.max(table.unpack(errs)), maxDrift, maxPen, maxBody)
