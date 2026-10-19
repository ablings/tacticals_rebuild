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
	if old then old:Destroy() end
	local t = Instance.new("Tool")
	t.Name = name
	t.CanBeDropped = false
	t.RequiresHandle = true
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
local function finish(tool, parent, grip)
	if grip then tool.Grip = grip end
	tool.Parent = parent
end

-- Pump Shotgun: long barrel + magazine tube under it, a pump grip, wooden stock
do
	local t = newTool("PumpShotgun", W, "WeaponId")
	local h = handlePart(t, Vector3.new(0.22, 0.62, 0.32), WOOD, Enum.Material.Wood)
	copyChildren(pistol.Handle, h, { "Fire", "Reload", "Empty" })
	part(t, h, "Receiver", Vector3.new(0.24, 0.32, 0.9), CFrame.new(0, 0.32, -0.3), DARK)
	local barrel = part(t, h, "Barrel", Vector3.new(0.14, 0.14, 1.7), CFrame.new(0, 0.42, -1.55), METAL)
	muzzleOn(barrel, -0.86)
	part(t, h, "Tube", Vector3.new(0.12, 0.12, 1.4), CFrame.new(0, 0.26, -1.4), DARK)
	part(t, h, "Pump", Vector3.new(0.2, 0.2, 0.55), CFrame.new(0, 0.26, -1.15), WOOD, Enum.Material.Wood)
	part(t, h, "Stock", Vector3.new(0.2, 0.3, 0.8), CFrame.new(0, 0.12, 0.62) * CFrame.Angles(math.rad(-12), 0, 0), WOOD, Enum.Material.Wood)
	part(t, h, "TriggerGuard", Vector3.new(0.06, 0.16, 0.24), CFrame.new(0, 0.12, -0.12), DARK)
	finish(t, W)
end

-- Dual Pistols: two pistols (the right one is the Handle; the left is a welded copy offset to the side)
do
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
do
	local t = newTool("Bat", M, "MeleeId")
	local h = handlePart(t, Vector3.new(0.18, 0.18, 0.9), GRIP)
	copyChildren(knife.Handle, h, { "Swing", "Hit" })
	part(t, h, "Knob", Vector3.new(0.26, 0.26, 0.08), CFrame.new(0, 0, 0.47), GRIP, Enum.Material.SmoothPlastic)
	for i, d in { 0.24, 0.3, 0.36 } do
		part(t, h, "Barrel" .. i, Vector3.new(d, d, 0.55), CFrame.new(0, 0, -0.45 - i * 0.52), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
			.CFrame = h.CFrame * CFrame.new(0, 0, -0.45 - i * 0.52) * CFrame.Angles(0, math.rad(90), 0)
	end
	finish(t, M)
end

-- Katana: a long wrapped grip, a round guard, and a long thin slightly curved blade (two segments)
do
	local t = newTool("Katana", M, "MeleeId")
	local h = handlePart(t, Vector3.new(0.16, 0.2, 1.0), GRIP)
	copyChildren(knife.Handle, h, { "Swing", "Hit" })
	part(t, h, "Guard", Vector3.new(0.42, 0.42, 0.06), CFrame.new(0, 0, -0.53), DARK, Enum.Material.Metal)
	part(t, h, "BladeLow", Vector3.new(0.05, 0.2, 1.5), CFrame.new(0, 0, -1.3), Color3.fromRGB(205, 210, 215))
	part(t, h, "BladeHigh", Vector3.new(0.05, 0.18, 1.4), CFrame.new(0, 0.06, -2.7) * CFrame.Angles(math.rad(4), 0, 0), Color3.fromRGB(205, 210, 215))
	finish(t, M)
end

-- Riot Shield: a tall rounded slab with a dark viewing window and a grip on the back
do
	local t = newTool("RiotShield", M, "MeleeId")
	local h = handlePart(t, Vector3.new(0.2, 0.5, 0.2), GRIP)
	copyChildren(knife.Handle, h, { "Swing", "Hit" })
	part(t, h, "Shield", Vector3.new(2.2, 3.6, 0.14), CFrame.new(0, 0.3, -0.35), Color3.fromRGB(30, 34, 38), Enum.Material.SmoothPlastic)
	part(t, h, "Window", Vector3.new(1.3, 0.35, 0.16), CFrame.new(0, 1.35, -0.35), Color3.fromRGB(120, 150, 170), Enum.Material.Glass).Transparency = 0.35
	part(t, h, "Rim", Vector3.new(2.3, 0.12, 0.18), CFrame.new(0, -1.5, -0.35), Color3.fromRGB(200, 190, 60), Enum.Material.SmoothPlastic)
	finish(t, M)
end

return "built PumpShotgun, DualPistols (Weapons), Bat, Katana, RiotShield (Melee)"
