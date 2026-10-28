-- tools/wh2_r9.lua: Warehouse 2 round 9 finishing pass, applied live to the build copy (the installer fix/map_warehouse2.lua
-- carries the same three changes, so a rebuild gives the same result). Idempotent. Lighting is not touched (night look B).
-- 1. olive crates C03 / C04: SurfaceAppearance tint (160,215,255) -> (170,215,170). Under the cool moonlit fill the old tint
--    rendered hue 132 / sat 0.19 (cold grey-green); the new one renders hue 69 / sat 0.53 at quality 21 (Tacticals olive 73 / 0.53).
-- 2. loose carton by each spawn: its side faces get no direct light (the fill lamp is straight overhead, the wall lights'
--    cones end before it, ShadowMap has no bounce) and the ambient on tan is crushed to 0 by tone mapping: a black cube.
--    Colour, material, CastShadow, a lighter tint and kit meshes all stayed >= 83 % near-black; so the four side faces get a
--    cardboard skin (SurfaceGui, LightInfluence 0.75) with a tape strip: sides render ~32 instead of 0. Position unchanged.
-- 3. DrumLabel_S (the BAY 01 plate on the door drum) 0.03 toward the room: front face 0.103 -> 0.133 off the drum (>= 0.12).
local UNDO = false --@UNDO
local W = workspace:WaitForChild("Warehouse2")
local out = {}

local OLIVE_TINT = UNDO and Color3.fromRGB(160, 215, 255) or Color3.fromRGB(170, 215, 170)
for _, n in { "C03", "C04" } do
	for _, sa in W.Cover[n]:GetDescendants() do
		if sa:IsA("SurfaceAppearance") then sa.Color = OLIVE_TINT end
	end
end
table.insert(out, "olive tint " .. tostring(OLIVE_TINT))

local nSkin = 0
for _, p in W.Props.Cartons:GetChildren() do
	for _, g in p:GetChildren() do
		if g:IsA("SurfaceGui") then g:Destroy() end
	end
	if not UNDO then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
			local g = Instance.new("SurfaceGui")
			g.Name = "Skin_" .. face.Name
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 40
			g.LightInfluence = 0.75
			g.Brightness = 1
			g.ClipsDescendants = true
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = p.Color
			f.Parent = g
			local tape = Instance.new("Frame")
			tape.Name = "Tape"
			tape.AnchorPoint = Vector2.new(0.5, 0)
			tape.Position = UDim2.fromScale(0.5, 0)
			tape.Size = UDim2.fromScale(0.14, 0.32)
			tape.BorderSizePixel = 0
			tape.BackgroundColor3 = Color3.fromRGB(196, 170, 128)
			tape.Parent = f
			g.Parent = p
			nSkin += 1
		end
	end
end
table.insert(out, "carton skins " .. nSkin)

local label = W.Visuals.Doors:FindFirstChild("DrumLabel_S")
if label then
	-- built at world z -354.505 (plan n -54.53..-54.48); round 9: -354.475 (n -54.50..-54.45)
	local z = UNDO and -354.505 or -354.475
	label.Position = Vector3.new(label.Position.X, label.Position.Y, z)
	table.insert(out, string.format("DrumLabel_S z %.3f", label.Position.Z))
end
return table.concat(out, " | ")
