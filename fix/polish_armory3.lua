-- polish_armory3.lua : Armory round 3, three small fixes from notes/review_armory2.md. Tacticals_rebuild.rbxl ONLY.
-- Re-run order: fix/polish_armory.lua, fix/polish_armory2.lua, fix/polish_armory3.lua (armory2 rebuilds the slots).
-- 1. Featured rifle lost on its dais: the crate stack behind it is part of the merged A_Props meshes (one mesh for every
--    crate in the room), so it can't be moved alone. A dark freestanding backdrop on the far side of the dais (seen from
--    the entrance and the dais approach) gives the spinning rifle a clean dark field, as RIVALS does for its featured item.
-- 2. Gun-wall rifles rested on their magazines with the receivers ~0.5-0.7 above the rail. Each GunWall slot's Anchor
--    (the rest line) moves down by the placeholder's magazine drop and Gap goes 0.1 -> 0.04, so the body sits at rail-top
--    height against the rail face with the magazine hanging in front of it. Two pegs per slot carry the body (static
--    hardware, like the niche pegs). ArmoryWeaponSlots.Apply() still works: it reads the Anchor and the attributes.
-- 3. The old baked guns left 8 support pins in A_GunWall__trim_metal (merged with the rails, can't be isolated). Each pin
--    tip gets a small cap in the wall-plate colour and material, so it reads as plate, not as a bolt between the rifles.
--    (The two round dots at (-6.7,8.0) / (-5.7,8.0) are rivets of our TacConcretePanels texture, not old hardware.)
-- Idempotent and UNDO-able: anchor/slot originals in attributes PolishArmory3_OrigY / PolishArmory3_OrigGap; new parts in
-- Workspace.LobbyMap.Polish.Armory.Round3. No new lights. UNDO: python tools/run_luau.py fix/polish_armory3.lua UNDO
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local LM = workspace.LobbyMap
local PA = LM.Polish.Armory
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(s) table.insert(log, s) end

local gws = PA:FindFirstChild("Round2") and PA.Round2:FindFirstChild("GunWallSlots")
assert(gws, "run fix/polish_armory2.lua first")
local mod = SS:FindFirstChild("ArmoryWeaponSlots")
assert(mod, "ArmoryWeaponSlots missing (polish_armory2)")
local cfg = require(mod:Clone())

local function slots()
	local t = {}
	for _, s in ipairs(gws:GetChildren()) do if s:IsA("Model") and s:FindFirstChild("Anchor") then table.insert(t, s) end end
	return t
end
local function refit(s)
	local ok, err = cfg.Fit(s, cfg.Slots[s.Name] or cfg.Default)
	if not ok then say("FIT FAIL " .. s.Name .. " " .. tostring(err)) end
end

if UNDO then
	local n = 0
	for _, s in ipairs(slots()) do
		local a = s.Anchor
		local y0 = a:GetAttribute("PolishArmory3_OrigY")
		if y0 then
			local cf = a.CFrame
			a.CFrame = cf + Vector3.new(0, y0 - cf.Position.Y, 0)
			a:SetAttribute("PolishArmory3_OrigY", nil)
			s:SetAttribute("Gap", s:GetAttribute("PolishArmory3_OrigGap") or 0.1)
			s:SetAttribute("PolishArmory3_OrigGap", nil)
			refit(s); n += 1
		end
	end
	if PA:FindFirstChild("Round3") then PA.Round3:Destroy() end
	return "UNDO polish_armory3: " .. n .. " gun-wall slots restored and refitted, Round3 removed\n" .. table.concat(log, "\n")
end

if PA:FindFirstChild("Round3") then PA.Round3:Destroy() end
local root = Instance.new("Folder"); root.Name = "Round3"
root:SetAttribute("PolishPass", "polish_armory3.lua")

local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = o.collide == true; p.CanQuery = o.collide == true; p.CanTouch = false
	p.CastShadow = o.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.variant then p.MaterialVariant = o.variant end
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end

-- every visible map part queryable while measuring (pins, lamps and trims are CanQuery off); restored at the end
local qsaved = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 1 then qsaved[d] = true; d.CanQuery = true end
end
local function restoreQuery() for d in pairs(qsaved) do if d.Parent then d.CanQuery = false end end end

---------------------------------------------------------------------------------------------------
-- 2. Seat the gun-wall rifles
---------------------------------------------------------------------------------------------------
local HANG = {Mag = true, Magazine = true, MagBase = true, Handle = true, Grip = true, TriggerGuard = true, Trigger = true}
local function bbox(p)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
		local w = p.CFrame * Vector3.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)
		lo = lo:Min(w); hi = hi:Max(w)
	end end end
	return lo, hi
end
local pegs = grp("GunWallPegs", root)
local nSeat = 0
local drops = {}
for _, s in ipairs(slots()) do
	local a = s.Anchor
	local y0 = a:GetAttribute("PolishArmory3_OrigY")
	if not y0 then
		y0 = a.Position.Y
		a:SetAttribute("PolishArmory3_OrigY", y0)
		s:SetAttribute("PolishArmory3_OrigGap", s:GetAttribute("Gap") or 0.1)
	end
	-- fit at the original rest line first, measure the drop (lowest body point above the lowest point overall)
	a.CFrame = a.CFrame + Vector3.new(0, y0 - a.Position.Y, 0)
	s:SetAttribute("Gap", 0.04)
	refit(s)
	local w = s:FindFirstChild("Weapon")
	local minAll, minBody = 1e9, 1e9
	for _, p in ipairs(w:GetDescendants()) do
		if p:IsA("BasePart") then
			local lo = bbox(p)
			minAll = math.min(minAll, lo.Y)
			if not HANG[p.Name] then minBody = math.min(minBody, lo.Y) end
		end
	end
	local drop = math.max(0, minBody - minAll)
	table.insert(drops, ("%s %.2f"):format(s.Name:gsub("WeaponSlot_", ""), drop))
	a.CFrame = a.CFrame - Vector3.new(0, drop, 0)
	refit(s)
	w = s:FindFirstChild("Weapon")
	-- pegs: under the handguard and under the stock/receiver rear, top = the body's underside at that x
	local front = -1e9
	local bodies = {}
	for _, p in ipairs(w:GetDescendants()) do
		if p:IsA("BasePart") then
			local lo, hi = bbox(p)
			front = math.max(front, hi.Z)
			if not HANG[p.Name] then table.insert(bodies, {p.Name, lo, hi}) end
		end
	end
	local function under(x)
		local y = 1e9
		for _, b in ipairs(bodies) do if x >= b[2].X and x <= b[3].X then y = math.min(y, b[2].Y) end end
		return y
	end
	local hg, st = w:FindFirstChild("Handguard", true), w:FindFirstChild("Stock", true)
	local wcf, wsz = w:GetBoundingBox()
	local xs = {
		hg and hg.Position.X or (wcf.Position.X - wsz.X * 0.25),
		st and st.Position.X or (wcf.Position.X + wsz.X * 0.3),
	}
	local rp = RaycastParams.new(); rp.FilterDescendantsInstances = {root, gws}
	for i, x in ipairs(xs) do
		local top = under(x)
		if top < 1e8 then
			local yc = top - 0.06
			-- start the peg at the first surface behind it (plate, beam or rail face)
			local hit = workspace:Raycast(Vector3.new(x, yc, front), Vector3.new(0, 0, -1.5), rp)
			local back = hit and hit.Position.Z or (front - 0.7)
			local len = front + 0.05 - back
			part(pegs, ("%s_Peg%d"):format(s.Name:gsub("WeaponSlot_", ""), i), Vector3.new(0.12, 0.12, len),
				CFrame.new(x, yc, back + len / 2), C(120, 116, 108), M.Metal)
		end
	end
	nSeat += 1
end
say(("gun wall: %d slots seated, drops %s"):format(nSeat, table.concat(drops, ", ")))

---------------------------------------------------------------------------------------------------
-- 3. Caps on the old gun-support pins (found by a ray scan of A_GunWall__trim_metal: small, 0.8 proud, tip z -110.98)
---------------------------------------------------------------------------------------------------
local plate = LM.Rooms2.A_GunWall.A_GunWall__wall_plate
local PINS = {{-13.6, 4.2}, {-13.6, 7.7}, {-9.2, 4.2}, {-9.2, 11.2}, {-4.7, 7.7}, {-4.7, 11.2}, {-0.3, 4.2}, {-0.3, 7.7}}
local caps = grp("PinCaps", root)
local tm = LM.Rooms2.A_GunWall.A_GunWall__trim_metal
local ip = RaycastParams.new(); ip.FilterType = Enum.RaycastFilterType.Include; ip.FilterDescendantsInstances = {tm}
local nCap = 0
for i, pn in ipairs(PINS) do
	-- confirm the pin is still there and read its tip
	local hit = workspace:Raycast(Vector3.new(pn[1], pn[2], -109), Vector3.new(0, 0, -2.5), ip)
	if hit and hit.Position.Z > -111.1 then
		local tip = hit.Position.Z
		local cap = part(caps, "PinCap" .. i, Vector3.new(0.22, 0.34, 0.08), CFrame.new(pn[1], pn[2], tip - 0.02),
			plate.Color:Lerp(Color3.new(0, 0, 0), 0.2), plate.Material, {variant = plate.MaterialVariant})
		nCap += 1
	else
		say(("pin %d at (%.1f,%.1f) not found"):format(i, pn[1], pn[2]))
	end
end
say(("pin caps: %d"):format(nCap))

---------------------------------------------------------------------------------------------------
-- 1. Featured backdrop: on the dais' far side from the entrance/approach (angle 235 deg about the dais axis, r 9.4;
-- the rope posts stand at r 6.4 on 45/135/225/315 deg, the floor ring lines end at r 8.6, the crates at r 17-18)
---------------------------------------------------------------------------------------------------
local FS = LM.Rooms.Armory:FindFirstChild("FeaturedScissors")
local axis = FS and FS:GetPivot().Position or Vector3.new(-10, 3.4, -96)
local ang = math.rad(235)
local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
local base = Vector3.new(axis.X, 0, axis.Z) + dir * 9.4
local bd = grp("FeaturedBackdrop", root)
local face = CFrame.lookAt(base, base - dir)
local function at(x, y, z) return face * CFrame.new(x, y, -z) end
local W, H = 6.0, 5.8
part(bd, "Plinth", Vector3.new(W + 0.4, 0.35, 1.1), at(0, 0.175, 0), C(40, 37, 34), M.Metal, {collide = true})
local panel = part(bd, "Panel", Vector3.new(W, H, 0.3), at(0, 0.35 + H / 2, 0), C(30, 27, 24), M.Plastic, {collide = true, shadow = true})
-- thin dark-olive Neon edge on the front (measured Neon olive, see 7.7j) and a cream stencil on the plinth
local OL = C(90, 106, 42)
part(bd, "EdgeT", Vector3.new(W, 0.08, 0.04), at(0, 0.35 + H - 0.04, 0.17), OL, M.Neon)
part(bd, "EdgeL", Vector3.new(0.08, H - 0.08, 0.04), at(-W / 2 + 0.04, 0.35 + H / 2 - 0.04, 0.17), OL, M.Neon)
part(bd, "EdgeR", Vector3.new(0.08, H - 0.08, 0.04), at(W / 2 - 0.04, 0.35 + H / 2 - 0.04, 0.17), OL, M.Neon)
local st = part(bd, "Stencil", Vector3.new(2.6, 0.22, 0.03), at(0, 0.175, 0.565), C(236, 232, 218), M.SmoothPlastic)
local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.PixelsPerStud = 100; g.Parent = st
local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.94, 0.84)
t.Position = UDim2.fromScale(0.03, 0.08); t.Text = "FEATURED  ·  WPN 01"; t.TextScaled = true
t.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold); t.TextColor3 = C(10, 12, 10)
t.Parent = g
say(("featured backdrop at (%.2f, %.2f), facing the dais"):format(base.X, base.Z))

root.Parent = PA
restoreQuery()
local n = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
say(("Round3: %d parts, 0 lights"):format(n))
return table.concat(log, "\n")
