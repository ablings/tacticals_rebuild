-- scripts/features/_geometry.lua : the feature-pass geometry (temporary Part screens, pits, wayfinding, effects).
-- Included into fix/install_features.lua by tools/build_features.py. Everything new lives in LobbyMap.Features (attribute
-- LF_New) except the leaderboard screen, which the existing LeaderboardScreen script looks up as LobbyMap.Signs.Screen_Leaderboard.
-- The only changed existing instances: Rooms3.D_Floor.D_Floor__floor_border / __floor_field CanCollide -> false (original in
-- attribute LF_OrigCollide; their collision is replaced by LobbyMap.Features.DropPits.FloorProxy with the two pit holes).
local CS = game:GetService("CollectionService")
local LM = workspace.LobbyMap

local INK, PANEL, BEZEL = Color3.fromRGB(8, 9, 8), Color3.fromRGB(22, 25, 21), Color3.fromRGB(34, 38, 33)
local CREAM, OLIVE, DOLIVE, WARMW = Color3.fromRGB(236, 232, 218), Color3.fromRGB(138, 156, 74), Color3.fromRGB(107, 122, 58), Color3.fromRGB(255, 241, 208)
local TITLE = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local function part(parent, name, size, cf, props)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	p.Parent = parent
	return p
end
local function folder(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end

-- a wall face: ray from a point inside the room toward the wall (collision + query geometry); fallback = given point
local wallRP = RaycastParams.new(); wallRP.FilterType = Enum.RaycastFilterType.Exclude; wallRP.RespectCanCollide = true
local function face(from, dir, fallback, fallbackN)
	local r = workspace:Raycast(from, dir, wallRP)
	if r and math.abs(r.Normal:Dot(-dir.Unit)) > 0.95 then return r.Position, r.Normal end
	return fallback, fallbackN
end

-- temporary TV: bezel (child, removable) + a dark screen plate whose Front face points along n
local function screen(parent, name, pos, n, w, h, kind)
	n = Vector3.new(n.X, 0, n.Z).Unit
	local sp = pos + n * 0.28
	local scr = part(parent, name, Vector3.new(w, h, 0.08), CFrame.lookAt(sp, sp + n), { Color = INK, Material = Enum.Material.Glass, Reflectance = 0.02 })
	local bp = pos + n * 0.13
	part(scr, "TempBezel", Vector3.new(w + 0.5, h + 0.5, 0.2), CFrame.lookAt(bp, bp + n), { Color = BEZEL, Material = Enum.Material.Metal })
	local lip = pos + n * 0.24 - Vector3.new(0, h / 2 + 0.17, 0)
	part(scr, "TempLip", Vector3.new(w + 0.5, 0.08, 0.12), CFrame.lookAt(lip, lip + n), { Color = DOLIVE, Material = Enum.Material.Neon, Transparency = 0.2 })
	if kind then scr:SetAttribute("Screen", kind); CS:AddTag(scr, "LobbyScreen") end
	return scr
end

-- floor stencil: text painted on the floor, readable for someone walking along dir. The part lies flat with its Front face
-- up (LookVector = +Y) and its UpVector = dir, so the GUI's top points away from the reader and its right is the reader's right
-- (Front-face SurfaceGui orientation is unambiguous; Top-face orientation is not).
local function stencil(parent, txt, pos, dir, w, h, color)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local c = pos + Vector3.new(0, 0.035, 0)
	local back = -Vector3.yAxis
	local p = part(parent, "Stencil_" .. txt:gsub("%W", ""), Vector3.new(w, h, 0.02), CFrame.fromMatrix(c, dir:Cross(back), dir, back), { Transparency = 1 })
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40
	g.LightInfluence = 1; g.MaxDistance = 200; g.Parent = p
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.Text = txt; l.TextScaled = true
	l.FontFace = TITLE; l.TextColor3 = color or CREAM; l.TextTransparency = 0.12; l.Parent = g
	return p
end

-- floor chevrons: n chevrons pointing along dir (cream, flush with the floor)
local function chevrons(parent, tip, dir, n, floorY)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = dir:Cross(Vector3.yAxis)
	local m = Instance.new("Model"); m.Name = "Chevrons"; m.Parent = parent
	for i = 0, n - 1 do
		local t = Vector3.new(tip.X, floorY + 0.055, tip.Z) - dir * (i * 2.1)
		for _, s in { 1, -1 } do
			local u = (-dir + side * s).Unit
			local c = t + u * 1.1
			part(m, "Bar", Vector3.new(0.5, 0.05, 2.2), CFrame.lookAt(c, c + u), { Color = CREAM, Transparency = 0.08 })
		end
	end
	return m
end

-- wall label plate: cream text on a near-black plate with an olive edge
local function plate(parent, txt, pos, n, w, h)
	n = Vector3.new(n.X, 0, n.Z).Unit
	local c = pos + n * 0.1
	local p = part(parent, "Label_" .. txt:gsub("%W", ""), Vector3.new(w, h, 0.12), CFrame.lookAt(c, c + n), { Color = PANEL })
	local e = pos + n * 0.17 - Vector3.new(0, h / 2 - 0.06, 0)
	part(p, "Edge", Vector3.new(w, 0.12, 0.04), CFrame.lookAt(e, e + n), { Color = OLIVE, Material = Enum.Material.Neon, Transparency = 0.15 })
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60
	g.LightInfluence = 0.4; g.Brightness = 1.2; g.MaxDistance = 160; g.Parent = p
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Position = UDim2.fromScale(0.04, 0.12); l.Size = UDim2.fromScale(0.92, 0.7)
	l.Text = txt; l.TextScaled = true; l.FontFace = TITLE; l.TextColor3 = CREAM; l.Parent = g
	return p
end

-- spotlight fixture: housing aimed at target, warm-white lens, SpotLight; rod up to the first surface above (if any)
local function spot(parent, name, pos, target, cfg)
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent
	local cf = CFrame.lookAt(pos, target)
	local h = part(m, "Housing", Vector3.new(1.1, 1.1, 1.7), cf, { Color = BEZEL, Material = Enum.Material.Metal })
	part(m, "Lens", Vector3.new(0.85, 0.85, 0.06), cf * CFrame.new(0, 0, -0.86), { Color = WARMW, Material = Enum.Material.Neon })
	part(m, "Yoke", Vector3.new(1.5, 0.2, 0.3), CFrame.new(pos + Vector3.new(0, 0.75, 0)), { Color = BEZEL, Material = Enum.Material.Metal })
	-- rod up to the structure above (lengths measured in Edit with the non-queryable kit meshes made queryable for the ray)
	local len = cfg.rod or 0
	if len > 0.05 then part(m, "Rod", Vector3.new(0.22, len, 0.22), CFrame.new(pos.X, pos.Y + 0.85 + len / 2, pos.Z), { Color = BEZEL, Material = Enum.Material.Metal }) end
	local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Front; l.Color = WARMW; l.Brightness = cfg.brightness or 2
	l.Range = cfg.range or 40; l.Angle = cfg.angle or 40; l.Shadows = cfg.shadows == true; l.Parent = h
	return m
end

-- aviation beacon: small dark base + Neon dome + PointLight (blinked by LobbyFeaturesFXController via tag LF_Beacon)
local function beacon(parent, name, pos, color, phase)
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent
	part(m, "Base", Vector3.new(0.7, 0.35, 0.7), CFrame.new(pos + Vector3.new(0, 0.175, 0)), { Color = BEZEL, Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder })
	m.Base.CFrame = CFrame.new(pos + Vector3.new(0, 0.175, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local d = part(m, "Lamp", Vector3.new(0.6, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, 0.6, 0)), { Color = color, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	d:SetAttribute("Phase", phase); CS:AddTag(d, "LF_Beacon")
	local l = Instance.new("PointLight"); l.Color = color; l.Brightness = 1.6; l.Range = 9; l.Shadows = false; l.Parent = d
	return m
end

-- hologram cone: a camera-facing Beam between two attachments (wide end -> narrow end), cream fading to olive
local function cone(parent, name, a, b, w0, w1, transp)
	local host = part(parent, name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(a), { Transparency = 1 })
	local A0 = Instance.new("Attachment"); A0.Name = "A0"; A0.Parent = host
	local A1 = Instance.new("Attachment"); A1.Name = "A1"; A1.WorldPosition = b; A1.Parent = host; A1.WorldPosition = b
	local beam = Instance.new("Beam"); beam.Attachment0 = A0; beam.Attachment1 = A1; beam.FaceCamera = true; beam.Segments = 12
	beam.Width0 = w0; beam.Width1 = w1; beam.LightEmission = 0.7; beam.LightInfluence = 0.2
	beam.Color = ColorSequence.new(CREAM, OLIVE)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transp or 0.72), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = host
	return host
end

-- subtle sparkles inside a box around an interactable (purpose-bound: only around things you can use)
local function sparkles(parent, name, cf, size)
	local host = part(parent, name, size, cf, { Transparency = 1 })
	local e = Instance.new("ParticleEmitter"); e.Name = "Sparkles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(CREAM, OLIVE); e.LightEmission = 1; e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.3, 0.22), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.2, 2); e.Rate = 2.5; e.Speed = NumberRange.new(0.2, 0.6); e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 0.4, 0); e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = host
	return host
end

-- vent puff: invisible host on the grille, emitter facing out of the wall (Rate 0; the client emits small puffs)
local function ventPuff(parent, name, pos, n)
	local host = part(parent, name, Vector3.new(6, 3, 0.1), CFrame.lookAt(pos, pos + n), { Transparency = 1 })
	local e = Instance.new("ParticleEmitter"); e.Name = "Puff"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.EmissionDirection = Enum.NormalId.Front
	e.Color = ColorSequence.new(Color3.fromRGB(214, 210, 200)); e.LightEmission = 0; e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 3.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(0.35, 0.84), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.6, 2.6); e.Rate = 0; e.Speed = NumberRange.new(2.5, 4); e.Drag = 1.6
	e.Acceleration = Vector3.new(0, 0.8, 0); e.SpreadAngle = Vector2.new(16, 16); e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-20, 20)
	e.Parent = host; CS:AddTag(e, "LF_VentPuff")
	return host
end

local function buildGeometry(say)
	local F = folder(LM, "Features"); F:SetAttribute("LF_New", true)

	------------------------------------------------------------------ 3 drop pits (Duels hall, centre columns between pad rows)
	local DP = folder(F, "DropPits")
	local floorY = 16.03
	local PITS = { { x0 = -117, x1 = -111, z0 = 12, z1 = 22 }, { x0 = -117, x1 = -111, z0 = -22, z1 = -12 } }
	local D = LM.Rooms3.D_Floor
	local mat = D.D_Floor__floor_field.Material
	for _, nm in { "D_Floor__floor_border", "D_Floor__floor_field" } do
		local m = D:FindFirstChild(nm)
		if m then
			if m:GetAttribute("LF_OrigCollide") == nil then m:SetAttribute("LF_OrigCollide", m.CanCollide) end
			m.CanCollide = false
		end
	end
	local proxy = folder(DP, "FloorProxy")
	local function slab(x0, x1, z0, z1)
		part(proxy, "Floor", Vector3.new(x1 - x0, 1, z1 - z0), CFrame.new((x0 + x1) / 2, floorY - 0.5, (z0 + z1) / 2),
			{ Transparency = 1, CanCollide = true, CanQuery = true, Material = mat })
	end
	slab(-140, -117, -45, 45); slab(-111, -95, -45, 45)
	slab(-117, -111, -12, 12); slab(-117, -111, 22, 45); slab(-117, -111, -45, -22)
	for i, P in PITS do
		local m = Instance.new("Model"); m.Name = "Pit_" .. i; m.Parent = DP
		local cx, cz, w, l = (P.x0 + P.x1) / 2, (P.z0 + P.z1) / 2, P.x1 - P.x0, P.z1 - P.z0
		part(m, "Void", Vector3.new(w, 0.04, l), CFrame.new(cx, floorY + 0.04, cz), { Color = Color3.fromRGB(3, 4, 3) })
		-- rim: cream outer strip + olive inner lip, flush (decor only; Blender rim kit replaces these)
		for _, s in { { 0, (l + 0.5) / 2, w + 1, 0.5 }, { 0, -(l + 0.5) / 2, w + 1, 0.5 }, { (w + 0.5) / 2, 0, 0.5, l }, { -(w + 0.5) / 2, 0, 0.5, l } } do
			part(m, "Rim", Vector3.new(s[3], 0.06, s[4]), CFrame.new(cx + s[1], floorY + 0.05, cz + s[2]), { Color = CREAM })
		end
		for _, s in { { 0, l / 2 - 0.1, w, 0.2 }, { 0, -l / 2 + 0.1, w, 0.2 }, { w / 2 - 0.1, 0, 0.2, l }, { -w / 2 + 0.1, 0, 0.2, l } } do
			part(m, "Lip", Vector3.new(s[3], 0.07, s[4]), CFrame.new(cx + s[1], floorY + 0.06, cz + s[2]), { Color = DOLIVE, Material = Enum.Material.Neon, Transparency = 0.35 })
		end
		-- shaft under the floor (dark walls) and the catch volume the server tests
		for _, s in { { 0, l / 2 + 0.25, w + 1, 0.5 }, { 0, -l / 2 - 0.25, w + 1, 0.5 }, { w / 2 + 0.25, 0, 0.5, l }, { -w / 2 - 0.25, 0, 0.5, l } } do
			part(m, "Shaft", Vector3.new(s[3], 13, s[4]), CFrame.new(cx + s[1], floorY - 1.1 - 6.5, cz + s[2]), { Color = PANEL })
		end
		part(m, "Catch", Vector3.new(w, 16, l), CFrame.new(cx, floorY - 2.2 - 8, cz), { Transparency = 1 })
		local sgn = cz > 0 and 1 or -1
		stencil(m, "KEEP CLEAR", Vector3.new(cx, floorY, P.z0 * (sgn > 0 and 1 or 0) + P.z1 * (sgn > 0 and 0 or 1) - sgn * 1.3), Vector3.new(0, 0, sgn), 5.6, 1.4)
	end
	local rp = part(DP, "ReturnPoint", Vector3.new(4, 0.2, 4), CFrame.lookAt(Vector3.new(-99, floorY + 0.1, 0), Vector3.new(-110, floorY + 0.1, 0)), { Transparency = 1 })
	rp:SetAttribute("Note", "Duels start: where drop-pit fallers land (LobbyFeaturesManager)")
	say("DropPits: 2 pits, 5 floor proxies, ReturnPoint", tostring(rp.Position))

	------------------------------------------------------------------ screens (temporary dark plates; the Blender TV kit replaces bezels)
	local wl, wn
	wl, wn = face(Vector3.new(-55.5, 15.6, 30), Vector3.new(0, 0, 20), Vector3.new(-55.5, 15.6, 43.75), Vector3.new(0, 0, -1))
	local lb = screen(LM.Signs, "Screen_Leaderboard", wl, wn, 10, 6.17, nil)   -- 940:580 canvas of LeaderboardScreen
	lb:SetAttribute("LF_New", true)
	say("Leaderboard screen at", tostring(lb.Position))
	wl, wn = face(Vector3.new(-55.5, 15.6, -30), Vector3.new(0, 0, -20), Vector3.new(-55.5, 15.6, -43.75), Vector3.new(0, 0, 1))
	screen(folder(F, "DuelsTV"), "Screen_DuelsTV", wl, wn, 10, 6.2, "DuelsTV")
	wl, wn = face(Vector3.new(55, 15.6, 30), Vector3.new(0, 0, 20), Vector3.new(55, 15.6, 43.75), Vector3.new(0, 0, -1))
	screen(folder(F, "LikesBoard"), "Screen_Likes", wl, wn, 10, 6.2, "Likes")
	wl, wn = face(Vector3.new(55, 15.6, -30), Vector3.new(0, 0, -20), Vector3.new(55, 15.6, -43.75), Vector3.new(0, 0, 1))
	local AB = folder(F, "AdBoard")
	screen(AB, "Screen_Ad", wl, wn, 10, 6.2, "Ad")
	local pp = part(AB, "PromptSpot", Vector3.new(1, 1, 1), CFrame.new(55, 4, wl.Z + wn.Z * 3), { Transparency = 1 })
	local pr = Instance.new("ProximityPrompt"); pr.ActionText = "Watch ad"; pr.ObjectText = "Supply drop"; pr.HoldDuration = 0.4
	pr.MaxActivationDistance = 10; pr.RequiresLineOfSight = false; pr.Enabled = false; pr:SetAttribute("LF_WatchAd", true); pr.Parent = pp
	wl, wn = face(Vector3.new(70, 15.6, -22.3), Vector3.new(30, 0, 0), Vector3.new(87.75, 15.6, -22.3), Vector3.new(-1, 0, 0))
	screen(folder(F, "TrainingScreen"), "Screen_Training", wl, wn, 10, 6.2, "Training")
	wl, wn = face(Vector3.new(-79, 5.6, 0), Vector3.new(-10, 0, 0), Vector3.new(-84, 5.6, 0), Vector3.new(1, 0, 0))
	screen(folder(F, "DuelsSign"), "Screen_DuelsSign", wl, wn, 9, 2.4, "DuelsSign")
	say("screens: Leaderboard, DuelsTV, Likes, Ad (+prompt), Training, DuelsSign")

	------------------------------------------------------------------ 23 wayfinding (hub floor top 0.03)
	local W = folder(F, "Wayfinding")
	local X, Z = Vector3.xAxis, Vector3.zAxis
	chevrons(W, Vector3.new(-30, 0, 0), -X, 3, 0.03); chevrons(W, Vector3.new(-56, 0, 0), -X, 3, 0.03)
	stencil(W, "DUELS", Vector3.new(-43, 0.03, 0), -X, 7, 2.2)
	chevrons(W, Vector3.new(30, 0, 0), X, 3, 0.03); chevrons(W, Vector3.new(62, 0, 0), X, 3, 0.03)
	stencil(W, "EXFIL · TRAINING", Vector3.new(45, 0.03, 0), X, 12, 2.2)
	chevrons(W, Vector3.new(0, 0, 27), Z, 3, 0.03); stencil(W, "SHOP", Vector3.new(0, 0.03, 34), Z, 5, 2)
	chevrons(W, Vector3.new(0, 0, -27), -Z, 3, 0.03); stencil(W, "ARMORY", Vector3.new(0, 0.03, -34), -Z, 6, 2)
	chevrons(W, Vector3.new(117, 0, 0), X, 3, 0.02); stencil(W, "TRAINING", Vector3.new(121.5, 0.02, 0), X, 6, 1.8)
	chevrons(W, Vector3.new(-103, 0, 0), -X, 2, floorY)   -- into the Duels hall, toward the pads
	wl, wn = face(Vector3.new(116, 13, -10), Vector3.new(0, 0, -30), Vector3.new(116, 13, -27), Vector3.new(0, 0, 1))
	plate(W, "TRAINING  ·  BOARD THE HELI", wl, wn, 7.2, 1.3)
	say("wayfinding: 6 chevron sets + Duels hall, 6 stencils, 1 plate at", tostring(wl))

	------------------------------------------------------------------ 29 spotlights (warm white, 2 with shadows)
	local SP = folder(F, "Spotlights")
	local spawnT = Vector3.new(0, 2, 0)
	spot(SP, "Spot_HubNE", Vector3.new(48.75, 23.4, 7), spawnT, { rod = 1.1, brightness = 2, range = 60, angle = 28, shadows = true })
	spot(SP, "Spot_HubSE", Vector3.new(48.75, 23.4, -7), spawnT, { rod = 1.1, brightness = 1.6, range = 60, angle = 28 })
	spot(SP, "Spot_HubNW", Vector3.new(-48.75, 23.4, 7), spawnT, { rod = 1.1, brightness = 1.6, range = 60, angle = 28 })
	spot(SP, "Spot_HubSW", Vector3.new(-48.75, 23.4, -7), spawnT, { rod = 1.1, brightness = 1.6, range = 60, angle = 28 })
	spot(SP, "Spot_ShopCounter", Vector3.new(3, 11.5, 96.5), Vector3.new(3, 3.4, 101.8), { rod = 0.37, brightness = 1.4, range = 20, angle = 45 })
	spot(SP, "Spot_GunWall", Vector3.new(0, 15, -101), Vector3.new(0, 6, -110.5), { rod = 4.58, brightness = 1.4, range = 22, angle = 50 })
	spot(SP, "Spot_ArmoryDais", Vector3.new(-10, 16.5, -89), Vector3.new(-10, 2, -96), { rod = 2.45, brightness = 1.8, range = 26, angle = 38, shadows = true })

	------------------------------------------------------------------ 30 beacons (amber on the hangar mouth, red on pad masts)
	local BC = folder(F, "Beacons")
	local AMBER, RED = Color3.fromRGB(255, 168, 60), Color3.fromRGB(230, 40, 32)
	beacon(BC, "Beacon_MouthN", Vector3.new(126, 21.6, 26.4), AMBER, 0)
	beacon(BC, "Beacon_MouthS", Vector3.new(126, 21.6, -26.4), AMBER, 0.5)
	-- red obstruction beacons on top of the two existing hangar gear posts (E_Gear beam tops, y 15.0)
	beacon(BC, "Beacon_PostN", Vector3.new(149.6, 15.0, 25), RED, 0.25)
	beacon(BC, "Beacon_PostS", Vector3.new(149.6, 15.0, -25), RED, 0.75)

	------------------------------------------------------------------ 31 interactable cones + sparkles
	local IX = folder(F, "InteractFX")
	cone(IX, "Cone_ShopCounter", Vector3.new(3, 3.45, 101.8), Vector3.new(3, 8.2, 101.8), 0.5, 3.4, 0.74)
	sparkles(IX, "Sparkle_ShopCounter", CFrame.new(3, 5.6, 101.8), Vector3.new(3.5, 3.5, 3.5))
	part(IX, "Ring_GunWall", Vector3.new(0.06, 4.2, 4.2), CFrame.new(0, 0.11, -106.6) * CFrame.Angles(0, 0, math.rad(90)), { Shape = Enum.PartType.Cylinder, Color = OLIVE, Material = Enum.Material.Neon, Transparency = 0.55 })
	cone(IX, "Cone_GunWall", Vector3.new(0, 0.15, -106.6), Vector3.new(0, 6.5, -106.6), 3.8, 0.4, 0.8)
	sparkles(IX, "Sparkle_GunWall", CFrame.new(0, 6, -109.4), Vector3.new(6, 5, 1.2))
	cone(IX, "Cone_ArmoryDais", Vector3.new(-10, 1.3, -96), Vector3.new(-10, 8.5, -96), 4.6, 1.2, 0.78)
	sparkles(IX, "Sparkle_ArmoryDais", CFrame.new(-10, 4.5, -96), Vector3.new(4.5, 5, 4.5))

	------------------------------------------------------------------ 32 vent puffs (4 real hub floor vents, H_Bays grilles)
	local VP = folder(F, "VentPuffs")
	ventPuff(VP, "Vent_N_-55", Vector3.new(-55, 3.5, 42.55), -Z)
	ventPuff(VP, "Vent_N_55", Vector3.new(55, 3.5, 42.55), -Z)
	ventPuff(VP, "Vent_S_-27", Vector3.new(-27.5, 3.5, -42.55), Z)
	ventPuff(VP, "Vent_S_27", Vector3.new(27.5, 3.5, -42.55), Z)
	say("effects: 7 spotlights (2 shadows), 4 beacons, 3 cones + 3 sparkles + ring, 4 vent puffs")
	return F
end
