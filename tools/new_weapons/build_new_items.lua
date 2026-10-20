-- tools/new_weapons/build_new_items.lua (UI session 2026-10-19, Edward's weapon design: notes/weapon_abilities.md)
-- Builds the five new part-built tools in the same style as the existing ones (Handle + welded parts, Barrel.Muzzle with the
-- Pistol's flash emitters, the Pistol's / Knife's sounds) into ReplicatedStorage.Repository.Weapons / .Melee.
-- Idempotent: an existing tool of the same name is replaced. Run in Edit mode (execute_luau). Grip / animations: Tacticals session.
local R = game:GetService("ReplicatedStorage"):WaitForChild("Repository")
local W, M = R:WaitForChild("Weapons"), R:WaitForChild("Melee")
local pistol, knife = W:WaitForChild("Pistol"), M:WaitForChild("Knife")

local METAL, DARK, WOOD, GRIP = Color3.fromRGB(58, 60, 62), Color3.fromRGB(32, 33, 35), Color3.fromRGB(120, 78, 44), Color3.fromRGB(24, 24, 26)

local function newTool(name, parent, idAttr)
	local old = parent:FindFirstChild(name)
	local t = Instance.new("Tool")
	t.Name = name
	t.CanBeDropped = false
	t.RequiresHandle = true
	-- a rebuild keeps what other sessions set on the old tool: its Grip, attributes, and non-part children (animations, configs)
	if old then
		t.Grip = old.Grip
		for k, v in old:GetAttributes() do t:SetAttribute(k, v) end
		for _, c in old:GetChildren() do if not c:IsA("BasePart") then c.Parent = t end end
		old:Destroy()
	end
	t:SetAttribute(idAttr, name)
	return t
end
-- a part placed relative to the handle (offset in the handle's space, studs), welded to it
local function part(tool, handle, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color or METAL
	p.Material = material or Enum.Material.Metal
	if shape then p.Shape = shape end
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	p.CFrame = handle.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = p, handle
	w.Parent = p
	p.Parent = tool
	return p
end
local function handlePart(tool, size, color, material)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.Color = color or GRIP
	h.Material = material or Enum.Material.SmoothPlastic
	h.CanCollide, h.CanTouch, h.CanQuery = false, false, false
	h.CFrame = CFrame.new(0, 50, 0)
	h.Parent = tool
	return h
end
local function copyChildren(from, to, names)
	for _, n in names do
		local c = from:FindFirstChild(n)
		if c then c:Clone().Parent = to end
	end
end
local function muzzleOn(barrel, z)
	local src = pistol:FindFirstChild("Barrel") and pistol.Barrel:FindFirstChild("Muzzle")
	local m = src and src:Clone() or Instance.new("Attachment")
	m.Name = "Muzzle"
	m.Position = Vector3.new(0, 0, z)
	m.Parent = barrel
end
-- set ONLY = { PumpShotgun = true } (first line of the run) to rebuild just those tools
local ONLY = ONLY
local function want(name) return ONLY == nil or ONLY[name] == true end
local function finish(tool, parent, grip)
	if grip then tool.Grip = grip end
	tool.Parent = parent
end

-- Pump Shotgun: long barrel + magazine tube under it, a pump grip, wooden stock
-- (2026-10-19, Edward: "the shotgun is detached") every part now overlaps the next: the receiver runs back over the grip,
-- the stock is a wrist + butt flush with the receiver's rear (no rotation), the tube touches the barrel.
if want("PumpShotgun") then
	local t = newTool("PumpShotgun", W, "WeaponId")
	local h = handlePart(t, Vector3.new(0.22, 0.62, 0.32), WOOD, Enum.Material.Wood)
	copyChildren(pistol.Handle, h, { "Fire", "Reload", "Empty" })
	part(t, h, "Receiver", Vector3.new(0.24, 0.34, 1.05), CFrame.new(0, 0.36, -0.3), DARK) -- z -0.83..0.23, y 0.19..0.53
	local barrel = part(t, h, "Barrel", Vector3.new(0.14, 0.14, 1.75), CFrame.new(0, 0.45, -1.68), METAL) -- z -2.55..-0.8
	muzzleOn(barrel, -0.88)
	part(t, h, "Tube", Vector3.new(0.13, 0.13, 1.45), CFrame.new(0, 0.3, -1.5), DARK) -- touches the barrel's underside
	part(t, h, "Pump", Vector3.new(0.2, 0.2, 0.55), CFrame.new(0, 0.3, -1.2), WOOD, Enum.Material.Wood)
	part(t, h, "StockWrist", Vector3.new(0.2, 0.28, 0.5), CFrame.new(0, 0.36, 0.4), WOOD, Enum.Material.Wood) -- z 0.15..0.65
	part(t, h, "StockButt", Vector3.new(0.22, 0.46, 0.5), CFrame.new(0, 0.28, 0.85), WOOD, Enum.Material.Wood) -- z 0.6..1.1
	part(t, h, "ButtPad", Vector3.new(0.23, 0.48, 0.06), CFrame.new(0, 0.28, 1.12), GRIP, Enum.Material.SmoothPlastic)
	part(t, h, "TriggerGuard", Vector3.new(0.06, 0.16, 0.24), CFrame.new(0, 0.14, -0.22), DARK)
	finish(t, W)
end

-- Dual Pistols: two pistols (the right one is the Handle; the left is a welded copy offset to the side)
if want("DualPistols") then
	local t = newTool("DualPistols", W, "WeaponId")
	local h = handlePart(t, Vector3.new(0.2, 0.62, 0.3))
	copyChildren(pistol.Handle, h, { "Fire", "Reload", "Empty" })
	for side, x in { Right = 0, Left = -1.1 } do
		part(t, h, side .. "Slide", Vector3.new(0.2, 0.24, 0.95), CFrame.new(x, 0.38, -0.2), METAL)
		part(t, h, side .. "Frame", Vector3.new(0.18, 0.12, 0.7), CFrame.new(x, 0.2, -0.15), DARK)
		if side == "Left" then part(t, h, "LeftGrip", Vector3.new(0.2, 0.62, 0.3), CFrame.new(x, 0, 0), GRIP, Enum.Material.SmoothPlastic) end
		local b = part(t, h, side .. "Barrel", Vector3.new(0.11, 0.11, 0.16), CFrame.new(x, 0.38, -0.72), METAL)
		b.Name = side == "Right" and "Barrel" or "LeftBarrel"
		muzzleOn(b, -0.1)
	end
	finish(t, W)
end

-- Baseball Bat: a wrapped grip, then the barrel thickening toward the end (three tapered sections)
if want("Bat") then
	local t = newTool("Bat", M, "MeleeId")
	local h = handlePart(t, Vector3.new(0.18, 0.18, 0.9), GRIP)
	copyChildren(knife.Handle, h, { "Swing", "Hit" })
	-- (2026-10-19, Edward: "the bat is detached") the barrel starts where the grip ends and each section overlaps the next
	local alongZ = CFrame.Angles(0, math.rad(90), 0) -- a Cylinder runs along X: turn it onto the bat's axis
	part(t, h, "Knob", Vector3.new(0.08, 0.28, 0.28), CFrame.new(0, 0, 0.47) * alongZ, GRIP, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(t, h, "Taper", Vector3.new(0.3, 0.2, 0.2), CFrame.new(0, 0, -0.5) * alongZ, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	for i, d in { 0.24, 0.3, 0.36 } do
		part(t, h, "Barrel" .. i, Vector3.new(0.58, d, d), CFrame.new(0, 0, -0.62 - (i - 1) * 0.52 - 0.29) * alongZ, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	finish(t, M)
end

-- Katana: a long wrapped grip, a round guard, and a long thin slightly curved blade (two segments)
if want("Katana") then
	local t = newTool("Katana", M, "MeleeId")
	local h = handlePart(t, Vector3.new(0.16, 0.2, 1.0), GRIP)
	copyChildren(knife.Handle, h, { "Swing", "Hit" })
	part(t, h, "Guard", Vector3.new(0.42, 0.42, 0.06), CFrame.new(0, 0, -0.53), DARK, Enum.Material.Metal)
	part(t, h, "BladeLow", Vector3.new(0.05, 0.2, 1.5), CFrame.new(0, 0, -1.3), Color3.fromRGB(205, 210, 215))
	part(t, h, "BladeHigh", Vector3.new(0.05, 0.18, 1.4), CFrame.new(0, 0.06, -2.7) * CFrame.Angles(math.rad(4), 0, 0), Color3.fromRGB(205, 210, 215))
	finish(t, M)
end

-- Riot Shield: a tall rounded slab with a dark viewing window and a grip on the back
if want("RiotShield") then
	local t = newTool("RiotShield", M, "MeleeId")
	local h = handlePart(t, Vector3.new(0.2, 0.5, 0.2), GRIP)
	copyChildren(knife.Handle, h, { "Swing", "Hit" })
	part(t, h, "Shield", Vector3.new(2.2, 3.6, 0.14), CFrame.new(0, 0.3, -0.17), Color3.fromRGB(30, 34, 38), Enum.Material.SmoothPlastic)
	part(t, h, "Window", Vector3.new(1.3, 0.35, 0.16), CFrame.new(0, 1.35, -0.17), Color3.fromRGB(120, 150, 170), Enum.Material.Glass).Transparency = 0.35
	part(t, h, "Rim", Vector3.new(2.3, 0.12, 0.18), CFrame.new(0, -1.5, -0.17), Color3.fromRGB(200, 190, 60), Enum.Material.SmoothPlastic)
	finish(t, M)
end

return "built PumpShotgun, DualPistols (Weapons), Bat, Katana, RiotShield (Melee)"
