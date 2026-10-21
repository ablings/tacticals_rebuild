-- ReplicatedStorage.Modules.Shared.Config.WrapConfig (ModuleScript) [WRAPS] 2026-10-21 (Edward: "wraps are textures that can be applied to
-- any weapon regardless of the skin"; v1 = static wraps only). Shared by the server (WrapManager puts the equipped wrap on tools and holster
-- copies, so everyone sees it) and the client (the Kit's Wrap tab previews any wrap, owned or not, on its own model). Pure: no server requires.
--
-- A weapon / skin model's parts carry attribute WrapChannel = "A" (the body) or "B" (the details: trigger guard, barrel, rails, sights,
-- mag...); WrapSkip = true leaves a part alone (lenses, glass, charms). Untagged parts count as "A". (fix/wraps_install.lua tags the
-- templates; new weapons / skins must carry the same attributes.)
-- A wrap has two looks, A and B; "Base" = the part's own look. Inverted swaps them (Edward: inverting changes each part set "to what is
-- on the other part").
--   Look = { Color = Color3?, Material = Enum.Material?, Reflectance = number?,
--            Texture = "rbxassetid://..."?, StudsPerTile = number? (fixed per wrap: a pattern keeps its size on every part),
--            TextureColor = Color3?, TextureTransparency = number? }
--   (later, not v1: Scroll = Vector2 studs/s, ColorCycle = { colours, period } - a client animator; nil now)
-- Wraps[id] = { Name, Rarity = "Common" | "Rare" | "Epic" | "Legendary", Source, Default = true (everyone owns it), Swatch = Color3 | image,
--               A = Look | "Base", B = Look | "Base" }
-- Profile: data.Wraps = { Owned = { [id] = true }, Equipped = { [itemId] = { Id = wrapId | "Random", Inverted = bool } },
--                         Favorites = { [id] = true } }
-- Remotes: ReplicatedStorage.Events.Wraps.Equip:FireServer(itemId, wrapId | "None" | "Random", inverted), .Favorite:FireServer(wrapId, on)
local WrapConfig = {}

local HAZARD = "rbxassetid://135549407863697" -- art/wraps/wrap_hazard.png (512 px, 45 deg stripes, seamless)
local CAMO = "rbxassetid://122898027227994"   -- art/wraps/wrap_camo.png (woodland, seamless)
local CARBON = "rbxassetid://107022133360725" -- art/wraps/wrap_carbon.png (twill weave, seamless)

local function plain(name, color)
	return { Name = name, Rarity = "Common", Source = "Owned by default", Default = true, Swatch = color,
		A = { Color = color, Material = Enum.Material.SmoothPlastic, Reflectance = 0 }, B = "Base" }
end

WrapConfig.Wraps = {
	Beige = plain("Beige", Color3.fromRGB(214, 196, 160)),
	Blue = plain("Blue", Color3.fromRGB(70, 120, 210)),
	Salmon = plain("Salmon", Color3.fromRGB(236, 140, 120)),
	Yellow = plain("Yellow", Color3.fromRGB(238, 200, 60)),
	Glossy = { Name = "Glossy", Rarity = "Common", Source = "Owned by default", Default = true, Swatch = Color3.fromRGB(30, 30, 34),
		A = { Color = Color3.fromRGB(26, 26, 30), Material = Enum.Material.SmoothPlastic, Reflectance = 0.35 }, B = "Base" },
	Hazard = { Name = "Hazard", Rarity = "Rare", Source = "Not available yet", Swatch = HAZARD,
		A = { Color = Color3.fromRGB(24, 24, 26), Material = Enum.Material.SmoothPlastic, Texture = HAZARD, StudsPerTile = 1.2 },
		B = { Color = Color3.fromRGB(28, 34, 58), Material = Enum.Material.SmoothPlastic } },
	Woodland = { Name = "Woodland", Rarity = "Rare", Source = "Not available yet", Swatch = CAMO,
		A = { Color = Color3.fromRGB(74, 82, 52), Material = Enum.Material.SmoothPlastic, Texture = CAMO, StudsPerTile = 2.4 }, B = "Base" },
	Carbon = { Name = "Carbon", Rarity = "Epic", Source = "Not available yet", Swatch = CARBON,
		A = { Color = Color3.fromRGB(34, 34, 38), Material = Enum.Material.SmoothPlastic, Reflectance = 0.12, Texture = CARBON, StudsPerTile = 0.8 },
		B = { Color = Color3.fromRGB(196, 160, 72), Material = Enum.Material.Metal } },
}
WrapConfig.Order = { "Beige", "Blue", "Salmon", "Yellow", "Glossy", "Hazard", "Woodland", "Carbon" }

function WrapConfig.Owns(data, wrapId: string): boolean
	local w = WrapConfig.Wraps[wrapId]
	if not w then return false end
	if w.Default then return true end
	local wr = type(data) == "table" and data.Wraps
	return type(wr) == "table" and type(wr.Owned) == "table" and wr.Owned[wrapId] == true
end

-- the wrap a profile has on an item (Random resolves to one of the owned wraps; rng optional)
function WrapConfig.EquippedFor(data, itemId: string, rng): (string?, boolean)
	local wr = type(data) == "table" and data.Wraps
	local e = type(wr) == "table" and type(wr.Equipped) == "table" and wr.Equipped[itemId]
	if type(e) ~= "table" or type(e.Id) ~= "string" or e.Id == "None" then return nil, false end
	local id = e.Id
	if id == "Random" then
		local owned = {}
		for _, wid in WrapConfig.Order do if WrapConfig.Owns(data, wid) then table.insert(owned, wid) end end
		if #owned == 0 then return nil, false end
		id = owned[(rng and rng:NextInteger(1, #owned)) or math.random(#owned)]
	end
	if not WrapConfig.Owns(data, id) then return nil, false end
	return id, e.Inverted == true
end

local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }
local syncs = setmetatable({}, { __mode = "k" }) -- [BasePart] = RBXScriptConnection (texture hide follows the part's Transparency)

local function remember(p: BasePart)
	if p:GetAttribute("WrapOrigColor") == nil then
		p:SetAttribute("WrapOrigColor", p.Color)
		p:SetAttribute("WrapOrigMaterial", p.Material.Name)
		p:SetAttribute("WrapOrigReflectance", p.Reflectance)
	end
end

local function clear(p: BasePart)
	for _, c in p:GetChildren() do if c:IsA("Texture") and c.Name == "WrapTexture" then c:Destroy() end end
	if syncs[p] then syncs[p]:Disconnect() syncs[p] = nil end
	if p:GetAttribute("WrapOrigColor") ~= nil then
		p.Color = p:GetAttribute("WrapOrigColor")
		local ok, m = pcall(function() return Enum.Material[p:GetAttribute("WrapOrigMaterial")] end)
		if ok and m then p.Material = m end
		p.Reflectance = p:GetAttribute("WrapOrigReflectance") or 0
	end
end

local function dress(p: BasePart, look)
	if look.Color then p.Color = look.Color end
	if look.Material then p.Material = look.Material end
	if look.Reflectance then p.Reflectance = look.Reflectance end
	if look.Texture then
		local texs = {}
		for _, face in FACES do
			local t = Instance.new("Texture")
			t.Name = "WrapTexture"
			t.Face = face
			t.Texture = look.Texture
			t.StudsPerTileU = look.StudsPerTile or 2
			t.StudsPerTileV = look.StudsPerTile or 2
			t.Color3 = look.TextureColor or Color3.new(1, 1, 1)
			t.Transparency = math.max(look.TextureTransparency or 0, p.Transparency)
			t.Parent = p
			table.insert(texs, t)
		end
		-- a hidden part (holstered gun drawn, scoped view...) hides its wrap texture too: textures ignore the part's Transparency
		local base = look.TextureTransparency or 0
		syncs[p] = p:GetPropertyChangedSignal("Transparency"):Connect(function()
			for _, t in texs do if t.Parent then t.Transparency = math.max(base, p.Transparency) end end
		end)
	end
end

-- Put a wrap on a model (Tool / Model / skin). wrapId nil or unknown = take any wrap off (back to the model's own look).
function WrapConfig.Apply(model: Instance, wrapId: string?, inverted: boolean?)
	local w = wrapId and WrapConfig.Wraps[wrapId]
	local lookA, lookB = w and w.A, w and w.B
	if inverted then lookA, lookB = lookB, lookA end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p:GetAttribute("WrapSkip") then
			remember(p)
			clear(p)
			local look = (p:GetAttribute("WrapChannel") == "B") and lookB or lookA
			if type(look) == "table" then dress(p, look) end
		end
	end
	if model:IsA("Instance") then
		model:SetAttribute("WrapId", w and wrapId or nil)
		model:SetAttribute("WrapInverted", (w and inverted) and true or nil)
	end
end

return WrapConfig
