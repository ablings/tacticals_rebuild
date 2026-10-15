--[[ fix/hub2.lua : hub polish pass 2 (Future lighting) in Tacticals_rebuild.rbxl (LOCAL copy only; never the live place).
Brief: notes/brief_hub2.md. Report: notes/hub2.md. Runs after fix/place_hub1.lua.
Idempotent: run as often as you like. UNDO = true puts everything back (colours, variant roughness, hidden FX/lights, tags,
sign carriers, new lights and the lip plate).
Runner: python tools/run_luau.py fix/hub2.lua [UNDO]
Own assets only: the one map swap reuses our own concrete_smooth roughness id (Gunsy Funsy upload from hub1).
]]
local UNDO = false --@UNDO

local CS = game:GetService("CollectionService")
local LM = workspace:WaitForChild("LobbyMap")
local hub = LM:WaitForChild("Hub1")
local MS = game:GetService("MaterialService")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local F = Enum.NormalId

---------------------------------------------------------------- data
-- 1. Floor: under Future the sealed floor concrete picks up a strong blue sky specular (rendered 32,53,72 from colour 62,62,60;
-- with EnvironmentSpecularScale 0 it drops to 23,30,36). Two steps: rougher roughness map on TacFloorConcrete (our
-- concrete_smooth rough) and warm-compensated base colours so the rendered floor lands on RIVALS' neutral 36-62.
local FLOOR_ROUGH = "rbxassetid://77416348183156" -- concrete_smooth roughness (own)
local RECOLOUR = {
	H_Floor = {floor_field = rgb(76, 62, 50), floor_border = rgb(46, 38, 30), floor_insert = rgb(94, 80, 66), grate = rgb(30, 26, 22)},
	H_SpawnDisc = {floor_border = rgb(46, 38, 30), disc_plate = rgb(88, 76, 64)},
	-- 2. Drums read lime (107,122,58 on TacMetal): military-green family next to the 65,94,56 crates.
	H_Props = {drum_olive = rgb(70, 82, 52)},
}
-- 4. Hub bounds for old FX / lights that now sit inside or in front of the new shell.
local function inHub(p) return p.X > -92 and p.X < 91 and p.Y > -2 and p.Y < 76 and p.Z > -47 and p.Z < 47 end
local KEEP_LIGHTS = {SpawnTop = true, WalkFill = true} -- Lights.SpawnTop (shadowed key on the disc), Lights.WalkFill (bridge decks)
local UNTAG = {"LobbyBeacon", "LobbyRun"} -- LobbyFX rewrites these parts' Transparency every frame: untag (kept in Hub2_Tags)

---------------------------------------------------------------- hide helpers (own attribute set, independent of Hub1)
local function hideOne(inst)
	if inst:GetAttribute("Hub2Hidden") or inst:GetAttribute("Hub1Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst:SetAttribute("Hub2_T", inst.Transparency); inst:SetAttribute("Hub2_C", inst.CanCollide)
		inst:SetAttribute("Hub2_Q", inst.CanQuery); inst:SetAttribute("Hub2_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
	elseif inst:IsA("Decal") then
		inst:SetAttribute("Hub2_T", inst.Transparency); inst.Transparency = 1
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		inst:SetAttribute("Hub2_E", inst.Enabled); inst.Enabled = false
	else
		return 0
	end
	local tags = {}
	for _, t in UNTAG do if CS:HasTag(inst, t) then table.insert(tags, t); CS:RemoveTag(inst, t) end end
	if #tags > 0 then inst:SetAttribute("Hub2_Tags", table.concat(tags, ",")) end
	inst:SetAttribute("Hub2Hidden", true)
	return 1
end
local function unhideOne(inst)
	if not inst:GetAttribute("Hub2Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst.Transparency = inst:GetAttribute("Hub2_T"); inst.CanCollide = inst:GetAttribute("Hub2_C")
		inst.CanQuery = inst:GetAttribute("Hub2_Q"); inst.CanTouch = inst:GetAttribute("Hub2_Tc")
	elseif inst:IsA("Decal") then
		inst.Transparency = inst:GetAttribute("Hub2_T")
	else
		inst.Enabled = inst:GetAttribute("Hub2_E")
	end
	local tags = inst:GetAttribute("Hub2_Tags")
	if tags then for t in tags:gmatch("[^,]+") do CS:AddTag(inst, t) end end
	for _, a in {"Hub2Hidden", "Hub2_T", "Hub2_C", "Hub2_Q", "Hub2_Tc", "Hub2_E", "Hub2_Tags"} do inst:SetAttribute(a, nil) end
	return 1
end
local function hideTree(root)
	local n = hideOne(root)
	for _, d in root:GetDescendants() do n += hideOne(d) end
	return n
end
local function posOf(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then return inst:GetPivot().Position end
	local p = inst:FindFirstAncestorWhichIsA("BasePart"); return p and p.Position
end

---------------------------------------------------------------- UNDO
local add = hub:FindFirstChild("Hub2Add")
if UNDO then
	local n = 0
	for _, d in LM:GetDescendants() do if d:GetAttribute("Hub2Hidden") then n += unhideOne(d) end end
	say("unhidden", n)
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Hub2_OrigColor") then d.Color = d:GetAttribute("Hub2_OrigColor"); d:SetAttribute("Hub2_OrigColor", nil) end
	end
	local v = MS:FindFirstChild("TacFloorConcrete", true)
	if v and v:GetAttribute("Hub2_OrigR") then v.RoughnessMap = v:GetAttribute("Hub2_OrigR"); v:SetAttribute("Hub2_OrigR", nil) end
	for _, s in hub.Overlays:GetChildren() do
		if s:GetAttribute("Hub2_OrigCF") then
			s.CFrame = s:GetAttribute("Hub2_OrigCF"); s.Size = s:GetAttribute("Hub2_OrigSize")
			s.Transparency = 1; s.Color = rgb(163, 162, 165); s.Material = Enum.Material.SmoothPlastic
			for _, a in {"Hub2_OrigCF", "Hub2_OrigSize"} do s:SetAttribute(a, nil) end
		end
	end
	if add then add.Parent = nil; add:Destroy() end
	say("UNDO done")
	return table.concat(log, "\n")
end

---------------------------------------------------------------- 1 + 2. recolour (originals kept per part) and floor roughness
local nCol = 0
for model, map in RECOLOUR do
	local m = hub:FindFirstChild(model)
	if m then for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local c = map[d.Name:match("__(.+)$") or ""]
			if c then
				if d:GetAttribute("Hub2_OrigColor") == nil then d:SetAttribute("Hub2_OrigColor", d.Color) end
				d.Color = c; nCol += 1
			end
		end
	end end
end
local fv = MS:FindFirstChild("TacFloorConcrete", true)
if fv then
	if fv:GetAttribute("Hub2_OrigR") == nil then fv:SetAttribute("Hub2_OrigR", fv.RoughnessMap) end
	fv.RoughnessMap = FLOOR_ROUGH
end
say("recoloured", nCol, "floor roughness", fv and fv.RoughnessMap)

---------------------------------------------------------------- 3. sign text on solid backing plates in front of the boards
-- The text carriers were Transparency-1 plates within 0.1 of the board face (EXFIL's sat 0.08 BEHIND it): text dropped out
-- by depth fighting in some captures. Now: the carrier itself is the backing (board colour, solid), its back face 0.08 proud
-- of the board face measured by ray, SurfaceGui on its Front face, LightInfluence 0.
local signParts = {}
for _, d in hub.H_Signs:GetDescendants() do if d:IsA("BasePart") then table.insert(signParts, d) end end
local q0 = {}
for i, d in signParts do q0[i] = d.CanQuery; d.CanQuery = true end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = signParts
for _, s in hub.Overlays:GetChildren() do
	if s.Name:match("^SignText_") and s:IsA("BasePart") then
		if s:GetAttribute("Hub2_OrigCF") == nil then s:SetAttribute("Hub2_OrigCF", s.CFrame); s:SetAttribute("Hub2_OrigSize", s.Size) end
		local cf0, sz0 = s:GetAttribute("Hub2_OrigCF"), s:GetAttribute("Hub2_OrigSize")
		local look = cf0.LookVector -- Front face points into the hub
		-- sample the board face at 5 points over the label; take the most proud one
		local best
		for _, o in {Vector3.zero, cf0.RightVector * sz0.X * 0.4, -cf0.RightVector * sz0.X * 0.4, cf0.UpVector * sz0.Y * 0.35, -cf0.UpVector * sz0.Y * 0.35} do
			local r = workspace:Raycast(cf0.Position + o + look * 6, -look * 8, rp)
			if r and r.Instance.Name:find("sign_board") then
				local d = (r.Position - cf0.Position):Dot(look)
				if not best or d > best then best = d end
			end
		end
		best = best or 0
		local th = 0.1
		s.Size = Vector3.new(sz0.X, sz0.Y, th)
		s.CFrame = cf0 + look * (best + 0.08 + th / 2)
		s.Transparency = 0; s.Material = Enum.Material.SmoothPlastic; s.Color = rgb(39, 40, 37); s.CastShadow = false
		local g = s:FindFirstChild("Text")
		if g then g.Face = F.Front; g.LightInfluence = 0; g.Brightness = 1.2; g.AlwaysOnTop = false; g.MaxDistance = 0 end
		say(s.Name, "board face offset", ("%.3f"):format(best), "-> plate front at", ("%.3f"):format(best + 0.08 + th))
	end
end
for i, d in signParts do d.CanQuery = q0[i] end

---------------------------------------------------------------- 4. hide stray old FX and old lights inside / in front of the new shell
local nHid, why = 0, {}
local function hideIf(inst, label)
	local p = posOf(inst)
	if p and inHub(p) then local n = hideTree(inst); nHid += n; why[label] = (why[label] or 0) + n end
end
local FX = LM:FindFirstChild("FX")
if FX then
	if FX:FindFirstChild("Decals") then for _, c in FX.Decals:GetChildren() do hideIf(c, "FX.Decals (old pod/wall stickers)") end end
	for _, c in FX:GetChildren() do if c.Name == "Steam" then hideIf(c, "FX.Steam (in wall)") end end
	local fx3 = FX:FindFirstChild("FX3")
	if fx3 then for _, c in fx3:GetChildren() do
		if c.Name == "SkyWindow" or c.Name == "FlightHUD" then hideIf(c, "FX3." .. c.Name)
		elseif c.Name == "Beacon" and math.abs(c.Position.X) <= 88 then hideIf(c, "FX3.Beacon (in cornice)") end
	end end
	local fx4 = FX:FindFirstChild("FX4")
	if fx4 then for _, c in fx4:GetChildren() do if c.Name == "RunLight" then hideIf(c, "FX4.RunLight (old cradles)") end end end
	local fx2 = FX:FindFirstChild("FX2")
	if fx2 then for _, c in fx2:GetChildren() do if c.Name == "Thruster" or c.Name == "StairsLight" then hideIf(c, "FX2." .. c.Name) end end end
end
local L = LM:FindFirstChild("Lights")
if L then for _, c in L:GetChildren() do if not KEEP_LIGHTS[c.Name] then hideIf(c, "Lights." .. c.Name) end end end
for k, v in why do say("hidden", k, v) end
say("hidden this run", nHid)

---------------------------------------------------------------- 5 + 6. new lights in the lamp fixtures, lip cover plate
if add then add:ClearAllChildren() else add = Instance.new("Model"); add.Name = "Hub2Add"; add.Parent = hub end
local function carrier(name, cf, size, parent)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = size; p.CFrame = cf; p.Material = Enum.Material.SmoothPlastic
	p:SetAttribute("NotCover", true); p.Parent = parent
	return p
end
-- Not tagged RoomLight: RoomFX only knows Shop/Armory/Exfil/Training/Showroom and would switch a hub light off.
local lights = Instance.new("Model"); lights.Name = "Lights"; lights.Parent = add
local WARM_CEIL, WARM_WALL = rgb(255, 241, 208), rgb(255, 228, 190)
local nL, nSh = 0, 0
-- ceiling strips (H_CeilLights, y 63.7, purlin rows z +-24): SurfaceLight down from every other bay
for _, z in {24, -24} do
	for _, x in {-68.75, -41.25, -13.75, 13.75, 41.25, 68.75} do
		local c = carrier(("Ceil_%d_%d"):format(x, z), CFrame.new(x, 63.55, z), Vector3.new(6, 0.1, 1.2), lights)
		local sl = Instance.new("SurfaceLight")
		sl.Face = F.Bottom; sl.Angle = 120; sl.Range = 60; sl.Brightness = 1.0; sl.Color = WARM_CEIL
		sl.Shadows = math.abs(x) < 20 -- 4 shadowed strips over the spawn disc / centre lanes
		sl.Parent = c; nL += 1; if sl.Shadows then nSh += 1 end
	end
end
-- wall capsules (H_WallLights, centre y ~14.2 on the piers, lens face at z +-41.45): SurfaceLight out of every other capsule
for _, sg in {1, -1} do
	for _, x in {-75.625, -48.125, -20.625, 20.625, 48.125, 75.625} do
		local zf = sg * (math.abs(x) > 75 and 41.01 or 41.45)
		local c = carrier(("Wall_%d_%s"):format(x, sg > 0 and "N" or "S"), CFrame.lookAt(Vector3.new(x, 14.2, zf - sg * 0.1), Vector3.new(x, 14.2, 0)), Vector3.new(1.2, 6, 0.1), lights)
		local sl = Instance.new("SurfaceLight")
		sl.Face = F.Front; sl.Angle = 120; sl.Range = 24; sl.Brightness = 0.8; sl.Color = WARM_WALL; sl.Shadows = false
		sl.Parent = c; nL += 1
	end
end
say("new lights", nL, "shadowed", nSh)

-- top landing lip: old U_East__dark_metal (shares its mesh with the Duels hall) pokes 0.5 above the y16 deck along the rail at
-- x -85.1..-84.5, z -8.2..8.2 (top 16.53). Cover with a 0.62 metal kerb plate x -85.9..-84.3 (to the rail), z -8.7..8.7, top
-- 16.62, plus a 0.8-deep wedge ramp on the walkway side and at both ends so nothing catches the feet.
local PLATE_COL = rgb(108, 107, 104)
local function solid(p)
	p.Anchored = true; p.CanCollide = true; p.CanQuery = true; p.CanTouch = false; p.Transparency = 0
	p.Material = Enum.Material.Metal; p.MaterialVariant = "TacFloorPlate"; p.Color = PLATE_COL
	p:SetAttribute("NotCover", true); p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = add
	return p
end
local y0, top = 16.0, 16.62
local h = top - y0
local x0, x1, zh = -85.9, -84.3, 8.7
local plate = Instance.new("Part"); plate.Name = "LipPlate"
plate.Size = Vector3.new(x1 - x0, h, zh * 2); plate.CFrame = CFrame.new((x0 + x1) / 2, y0 + h / 2, 0); solid(plate)
-- WedgePart: slope rises toward local -Z (the full-height face is Back = +Z ... verified by ray in check below)
local function wedge(name, centre, lookDir, width, depth)
	local w = Instance.new("WedgePart"); w.Name = name
	w.Size = Vector3.new(width, h, depth)
	w.CFrame = CFrame.lookAt(centre, centre + lookDir)
	return solid(w)
end
local wd = 0.8
wedge("LipRampW", Vector3.new(x0 - wd / 2, y0 + h / 2, 0), Vector3.new(-1, 0, 0), zh * 2, wd)
wedge("LipRampN", Vector3.new((x0 + x1) / 2, y0 + h / 2, zh + wd / 2), Vector3.new(0, 0, 1), x1 - x0, wd)
wedge("LipRampS", Vector3.new((x0 + x1) / 2, y0 + h / 2, -zh - wd / 2), Vector3.new(0, 0, -1), x1 - x0, wd)
-- verify ramp orientation: height should fall away from the plate
local rq = RaycastParams.new(); rq.FilterType = Enum.RaycastFilterType.Include; rq.FilterDescendantsInstances = {add}
local function hAt(x, z) local r = workspace:Raycast(Vector3.new(x, 20, z), Vector3.new(0, -6, 0), rq); return r and r.Position.Y or y0 end
say(("lip ramp W: %.2f at plate edge side, %.2f at outer edge; N: %.2f / %.2f"):format(hAt(x0 - 0.1, 0), hAt(x0 - wd + 0.1, 0), hAt(-85.1, zh + 0.1), hAt(-85.1, zh + wd - 0.1)))

return table.concat(log, "\n")
