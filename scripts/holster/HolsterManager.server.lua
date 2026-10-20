-- ServerScriptService.HolsterManager [HOLSTER] (2026-10-19, Edward: "if my kit is a sticky grenade, assault rifle, and a knife,
-- my knife and sticky grenade will be on opposite sides of my front waist, my assault rifle will be on my back when equipped,
-- i will pull the assault rifle from my back, if it is a pistol they will be on the right side of my waist"; "mini uzi should go
-- to the hip"; "katana / bat ... left hip"). Lobby + match places. Installed with tools/install_localscript.py --server.
-- The kit you carry is worn on the body, for everyone to see (welded copies made on the server, so they replicate):
--   right hip     Pistol, Dual Pistols (left gun on the left hip), Suppressed, Revolver, Mini Uzi (barrel down)
--   back          Auto Rifle, Pump Shotgun, Semi-Auto, Sniper (diagonal); the Riot Shield flat over it (too big for the waist)
--   left hip      Katana, Bat (handle up, angled back like a sheathed sword)
--   front waist   Knife front-left; the gadget front-right (a small procedural model per gadget; none for Fists)
-- What you hold is hidden from its holster (the gun / melee Tool in the character). The gadget shows while it has charges.
-- Copies only exist for items you actually carry this life (tools in the Backpack / character), so the hub shows nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Repository = ReplicatedStorage:WaitForChild("Repository")
local WeaponConfig = require(ReplicatedStorage.Modules.Shared.Config.WeaponConfig)
local GadgetConfig = require(ReplicatedStorage.Modules.Shared.Config.GadgetConfig)

local SLOT_OF_GUN = { Pistol = "Hip", DualPistols = "Hip", SilencedPistol = "Hip", Revolver = "Hip", MiniUzi = "Hip",
	AutoRifle = "Back", PumpShotgun = "Back", SemiAuto = "Back", Sniper = "Back" }
local SLOT_OF_MELEE = { Katana = "LeftHip", Bat = "LeftHip", Knife = "FrontLeft", RiotShield = "BackShield" } -- Fists: nothing to wear

-- each slot: the body part, the spot in its space, the long axis (where the barrel / blade points) and the flat-side normal
local SLOTS = {
	-- hip guns sit on the outer upper thigh (a drop-leg holster), clear of the arm that hangs over the hip
	Hip = { part = "LowerTorso", pos = Vector3.new(1.08, -0.75, 0.05), long = Vector3.new(0, -0.94, 0.34), normal = Vector3.new(1, 0, 0) },
	LeftGun = { part = "LowerTorso", pos = Vector3.new(-1.08, -0.75, 0.05), long = Vector3.new(0, -0.94, 0.34), normal = Vector3.new(-1, 0, 0) },
	-- back guns: barrel up over the left shoulder, stock down by the right hip (drawn over the right shoulder)
	Back = { part = "UpperTorso", pos = Vector3.new(0, 0.05, 0.62), long = Vector3.new(-0.64, 0.77, 0), normal = Vector3.new(0, 0, 1) },
	BackShield = { part = "UpperTorso", pos = Vector3.new(0, 0.25, 0.85), long = Vector3.new(0, 0, 0), normal = Vector3.new(0, 0, 1) },
	-- katana / bat: hilt just in front of the hip, the rest sloping down behind the leg
	LeftHip = { part = "LowerTorso", pos = Vector3.new(-1.08, -0.45, 0.7), long = Vector3.new(0, -0.42, 0.91), normal = Vector3.new(-1, 0, 0) },
	FrontLeft = { part = "LowerTorso", pos = Vector3.new(-0.5, -0.15, -0.62), long = Vector3.new(0, -1, 0), normal = Vector3.new(0, 0, -1) },
	FrontRight = { part = "LowerTorso", pos = Vector3.new(0.5, -0.1, -0.6), long = Vector3.new(0, -1, 0), normal = Vector3.new(0, 0, -1) },
}

local GADGET_LOOK = { -- the gadget worn at the waist: { shape, size, colour, cap colour }
	Smoke = { "Cylinder", Vector3.new(0.55, 0.32, 0.32), Color3.fromRGB(150, 160, 140), Color3.fromRGB(60, 62, 60) },
	Flash = { "Cylinder", Vector3.new(0.55, 0.3, 0.3), Color3.fromRGB(205, 205, 200), Color3.fromRGB(60, 62, 60) },
	Frag = { "Ball", Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(96, 110, 60), Color3.fromRGB(60, 62, 60) },
	StickyGrenade = { "Ball", Vector3.new(0.42, 0.42, 0.42), Color3.fromRGB(40, 40, 44), Color3.fromRGB(200, 40, 40) },
	Landmine = { "Cylinder", Vector3.new(0.16, 0.6, 0.6), Color3.fromRGB(70, 74, 64), Color3.fromRGB(200, 40, 40) },
	Medkit = { "Block", Vector3.new(0.5, 0.42, 0.22), Color3.fromRGB(235, 235, 230), Color3.fromRGB(200, 40, 40) },
}

local function quiet(p: BasePart)
	p.Anchored = false
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, false
end

-- a welded copy of a tool's parts (only the parts whose names pass keep(name)), as a Model whose PrimaryPart is the Handle
local function copyTool(template: Instance, keep): Model?
	local clone = template:Clone()
	local model = Instance.new("Model")
	for _, c in clone:GetChildren() do
		if c:IsA("BasePart") and (not keep or keep(c.Name)) then c.Parent = model end
	end
	clone:Destroy()
	local handle = model:FindFirstChild("Handle") or model:FindFirstChildWhichIsA("BasePart")
	if not handle then model:Destroy(); return nil end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then quiet(d)
		elseif d:IsA("Sound") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ParticleEmitter") or d:IsA("Light") then d:Destroy() end
	end
	-- parts left without a weld to the handle (their weld pointed at a part we dropped) get one
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= handle then
			local w = p:FindFirstChildOfClass("WeldConstraint")
			if not (w and w.Part0 and w.Part1 and w.Part0.Parent == model and w.Part1.Parent == model) then
				if w then w:Destroy() end
				local nw = Instance.new("WeldConstraint"); nw.Part0, nw.Part1 = p, handle; nw.Parent = p
			end
		end
	end
	model.PrimaryPart = handle
	return model
end

local function gadgetModel(id: string): Model?
	local look = GADGET_LOOK[id]
	if not look then return nil end
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Handle"
	body.Shape = Enum.PartType[look[1]]
	body.Size = look[2]
	body.Color = look[3]
	body.Material = Enum.Material.Metal
	quiet(body)
	body.Parent = model
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(0.12, 0.14, 0.14)
	cap.Color = look[4]
	cap.Material = Enum.Material.SmoothPlastic
	quiet(cap)
	cap.CFrame = body.CFrame * CFrame.new(look[1] == "Block" and 0 or look[2].X / 2, look[1] == "Block" and look[2].Y / 2 or 0, 0)
	cap.Parent = model
	local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = cap, body; w.Parent = cap
	model.PrimaryPart = body
	return model
end

-- turn the model so its longest local axis runs along slot.long and its thinnest faces slot.normal, centred on slot.pos
local function place(model: Model, character: Model, slotName: string): boolean
	local slot = SLOTS[slotName]
	local body = character:FindFirstChild(slot.part)
	if not (body and body:IsA("BasePart")) then return false end
	local handle = model.PrimaryPart
	local boxCF, size = model:GetBoundingBox()
	local centreInHandle = handle.CFrame:PointToObjectSpace(boxCF.Position)
	local ext = { size.X, size.Y, size.Z }
	local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	local longI, thinI = 1, 1
	for i = 2, 3 do
		if ext[i] > ext[longI] then longI = i end
		if ext[i] < ext[thinI] then thinI = i end
	end
	local normal = slot.normal.Unit
	local long = slot.long.Magnitude > 0.01 and slot.long.Unit or Vector3.yAxis -- the shield: upright
	if longI == thinI then longI = (thinI % 3) + 1 end
	-- tool space -> slot space: thin axis -> normal, long axis -> long, the third from the cross product
	local tLong, tThin = axes[longI], axes[thinI]
	-- the barrel / blade end: most of the item lies that way from the handle (a rifle's barrel, a katana's blade)
	if centreInHandle:Dot(tLong) < 0 then tLong = -tLong end
	local tThird = tLong:Cross(tThin)
	local sThird = long:Cross(normal)
	local toolBasis = CFrame.fromMatrix(Vector3.zero, tLong, tThin, tThird)
	local slotBasis = CFrame.fromMatrix(Vector3.zero, long, normal, sThird)
	local rot = slotBasis * toolBasis:Inverse()
	local handleInSlot = CFrame.new(slot.pos) * rot * CFrame.new(-centreInHandle)
	model:PivotTo(body.CFrame * handleInSlot)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, body
	weld.Parent = handle
	return true
end

-- // Per character ------------------------------------------------------------------------------------------------------
local function setShown(model: Model?, shown: boolean)
	if not model then return end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.Transparency = shown and (d:GetAttribute("HolsterT") or 0) or 1 end
	end
end

local function track(player: Player, character: Model)
	local worn = {} -- [key] = Model; key = "Gun:<id>" / "GunLeft:<id>" / "Melee:<id>" / "Gadget:<id>"
	local folder = Instance.new("Folder")
	folder.Name = "Holsters"
	folder.Parent = character

	local function wear(key: string, make, slotName: string)
		if worn[key] then return worn[key] end
		local m = make()
		if not m then return nil end
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then d:SetAttribute("HolsterT", d.Transparency) end end
		m.Name = key
		m.Parent = folder
		if not place(m, character, slotName) then m:Destroy(); return nil end
		worn[key] = m
		return m
	end
	local function drop(key: string)
		if worn[key] then worn[key]:Destroy(); worn[key] = nil end
	end

	local function refresh()
		if not character.Parent then return end
		local backpack = player:FindFirstChildOfClass("Backpack")
		local carried, held = {}, {}
		for _, c in { backpack, character } do
			for _, t in (c and c:GetChildren() or {}) do
				if t:IsA("Tool") then
					local wid, mid = t:GetAttribute("WeaponId"), t:GetAttribute("MeleeId")
					local key = (wid and SLOT_OF_GUN[wid] and "Gun:" .. wid) or (mid and SLOT_OF_MELEE[mid] and "Melee:" .. mid) or nil
					if key then
						carried[key] = t
						if c == character then held[key] = true end
					end
				end
			end
		end
		local hasGun = false
		for key in carried do if key:sub(1, 4) == "Gun:" then hasGun = true end end
		-- the gadget: worn while you carry a gun (a combat kit) and it has charges
		local gid = player:GetAttribute("KitGadget")
		local cfg = type(gid) == "string" and GadgetConfig[gid]
		local charges = type(cfg) == "table" and cfg.ChargesAttribute and player:GetAttribute(cfg.ChargesAttribute) or 0
		if hasGun and GADGET_LOOK[gid] and (charges or 0) > 0 then carried["Gadget:" .. gid] = true end
		-- Dual Pistols: the left gun goes on the left hip
		for key in carried do
			if key == "Gun:DualPistols" then carried["GunLeft:DualPistols"] = carried[key]; held["GunLeft:DualPistols"] = held[key] end
		end
		for key in worn do if not carried[key] then drop(key) end end
		for key, tool in carried do
			local kind, id = key:match("^(%w+):(.+)$")
			local m
			if kind == "Gun" then
				local conf = WeaponConfig.Get(id)
				local template = conf and Repository.Weapons:FindFirstChild(conf.ToolName or id)
				local keep = id == "DualPistols" and function(n) return n:sub(1, 4) ~= "Left" end or nil
				m = template and wear(key, function() return copyTool(template, keep) end, SLOT_OF_GUN[id])
			elseif kind == "GunLeft" then
				local template = Repository.Weapons:FindFirstChild("DualPistols")
				m = template and wear(key, function()
					local mm = copyTool(template, function(n) return n:sub(1, 4) == "Left" end)
					if mm then -- the copy has no Handle: make LeftGrip its root
						local root = mm:FindFirstChild("LeftGrip") or mm.PrimaryPart
						for _, p in mm:GetChildren() do
							if p:IsA("BasePart") and p ~= root then
								for _, w in p:GetChildren() do if w:IsA("WeldConstraint") then w:Destroy() end end
								local nw = Instance.new("WeldConstraint"); nw.Part0, nw.Part1 = p, root; nw.Parent = p
							end
						end
						mm.PrimaryPart = root
					end
					return mm
				end, "LeftGun")
			elseif kind == "Melee" then
				local template = Repository.Melee:FindFirstChild(id)
				m = template and wear(key, function() return copyTool(template) end, SLOT_OF_MELEE[id])
			elseif kind == "Gadget" then
				m = wear(key, function() return gadgetModel(id) end, "FrontRight")
			end
			setShown(m, not held[key])
		end
	end

	local pending = false
	local function soon()
		if pending then return end
		pending = true
		task.defer(function() pending = false; refresh() end)
	end
	local conns = {}
	local function watch(c) if c then table.insert(conns, c.ChildAdded:Connect(soon)); table.insert(conns, c.ChildRemoved:Connect(soon)) end end
	watch(character)
	watch(player:FindFirstChildOfClass("Backpack"))
	table.insert(conns, player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c); soon() end end))
	table.insert(conns, player.AttributeChanged:Connect(function(name)
		if name == "KitGadget" or tostring(name):find("Charges") then soon() end
	end))
	character.AncestryChanged:Connect(function()
		if not character.Parent then for _, c in conns do c:Disconnect() end end
	end)
	-- the character is rebuilt right after spawning (PlayerRegistry normalization): wait for Ready before welding
	task.spawn(function()
		local waited = 0
		while character.Parent and character:GetAttribute("Ready") ~= true and waited < 10 do waited += task.wait(0.2) end
		task.wait(0.2)
		refresh()
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(c) track(player, c) end)
	if player.Character then track(player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
