-- Lobby duels: serialise a match-place map (instance tree + properties) to JSON, READ-ONLY.
-- Run in the match place (studio 331cb3a0) through tools/duel_map_port.py; the import side is tools/duel_map_import.lua.
-- ROOTS lists the Workspace children to export; MATVARS the MaterialVariant names those parts use.
-- Output: { nodes = { {i, p, c, n, props, attrs, tags} ... }, matvars = {...} } with typed values (see enc).
local ROOTS = { "Warehouse", "MatchSpawns" } --@ROOTS
local CHUNK_FROM, CHUNK_TO = 1, 1e9 --@CHUNK
local HS = game:GetService("HttpService")

local PROPS = {
	BasePart = { "CFrame", "Size", "Color", "Material", "MaterialVariant", "Transparency", "Reflectance", "CanCollide", "CanQuery",
		"CanTouch", "CastShadow", "Anchored", "Massless", "Locked", "TopSurface", "BottomSurface", "LeftSurface", "RightSurface",
		"FrontSurface", "BackSurface" },
	Part = { "Shape" },
	MeshPart = { "MeshId", "TextureID", "CollisionFidelity", "RenderFidelity", "DoubleSided" },
	Model = { "WorldPivot" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "AlphaMode", "Color" },
	SurfaceGui = { "Face", "PixelsPerStud", "SizingMode", "CanvasSize", "LightInfluence", "Brightness", "AlwaysOnTop",
		"ClipsDescendants", "ZOffset", "Enabled", "MaxDistance" },
	GuiObject = { "Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "Rotation",
		"ZIndex", "Visible", "ClipsDescendants" },
	TextLabel = { "Text", "FontFace", "TextColor3", "TextScaled", "TextSize", "TextStrokeTransparency", "TextStrokeColor3",
		"TextTransparency", "TextXAlignment", "TextYAlignment", "RichText", "TextWrapped", "LineHeight" },
	Light = { "Brightness", "Color", "Shadows", "Enabled" },
	PointLight = { "Range" },
	SpotLight = { "Range", "Angle", "Face" },
	SurfaceLight = { "Range", "Angle", "Face" },
	ProximityPrompt = { "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "KeyboardKeyCode", "RequiresLineOfSight",
		"Style", "Enabled", "UIOffset", "Exclusivity" },
	Attachment = { "CFrame" },
}

local function enc(v)
	local t = typeof(v)
	if t == "CFrame" then return { t = "CF", v = { v:GetComponents() } } end
	if t == "Vector3" then return { t = "V3", v = { v.X, v.Y, v.Z } } end
	if t == "Vector2" then return { t = "V2", v = { v.X, v.Y } } end
	if t == "Color3" then return { t = "C3", v = { v.R, v.G, v.B } } end
	if t == "UDim2" then return { t = "U2", v = { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } } end
	if t == "EnumItem" then return { t = "E", e = tostring(v.EnumType), n = v.Name } end
	if t == "Font" then return { t = "F", f = v.Family, w = v.Weight.Name, s = v.Style.Name } end
	if t == "string" or t == "number" or t == "boolean" then return v end
	return nil
end

local list, index = {}, {}
for _, rn in ROOTS do
	local r = workspace:FindFirstChild(rn)
	if r then
		table.insert(list, r)
		for _, d in r:GetDescendants() do table.insert(list, d) end
	end
end
for i, inst in list do index[inst] = i end

local nodes = {}
for i = CHUNK_FROM, math.min(CHUNK_TO, #list) do
	local inst = list[i]
	local props = {}
	for cls, names in PROPS do
		if inst:IsA(cls) then
			for _, pn in names do
				local ok, v = pcall(function() return inst[pn] end)
				if ok then props[pn] = enc(v) end
			end
		end
	end
	local attrs = {}
	for k, v in inst:GetAttributes() do attrs[k] = enc(v) end
	table.insert(nodes, { i = i, p = index[inst.Parent] or 0, c = inst.ClassName, n = inst.Name, props = props, attrs = attrs,
		tags = inst:GetTags() })
end

local matvars = {}
local usedVar = {}
for _, inst in list do if inst:IsA("BasePart") and inst.MaterialVariant ~= "" then usedVar[inst.MaterialVariant] = true end end
for _, v in game:GetService("MaterialService"):GetDescendants() do
	if v:IsA("MaterialVariant") and usedVar[v.Name] then
		matvars[v.Name] = { BaseMaterial = enc(v.BaseMaterial), ColorMap = v.ColorMap, NormalMap = v.NormalMap,
			RoughnessMap = v.RoughnessMap, MetalnessMap = v.MetalnessMap, StudsPerTile = v.StudsPerTile }
	end
end
return HS:JSONEncode({ total = #list, nodes = nodes, matvars = matvars })
