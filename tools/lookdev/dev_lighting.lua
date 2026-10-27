-- arena_lookdev: the Arena map's lighting as the match place shows it. Base = match_place_ref.rbxl's Lighting (read offline with
-- tools/rbxl_lighting_dump.py: Sky = Roblox's default sky, Atmosphere, Bloom, MapGrade), then MapInfo.Lighting from
-- fix/map_arena.lua, formerly fix/map_practice_range.lua (what RoundManager's applyMapEnv sets when the Arena wins the vote). Technology ShadowMap and
-- LightingStyle Realistic are in the file (tools/lookdev/new_blank_rbxl.py). Idempotent.
local L = game:GetService("Lighting")
local base = {
	Ambient = Color3.fromRGB(72, 76, 84), Brightness = 2, ColorShift_Bottom = Color3.new(0, 0, 0), ColorShift_Top = Color3.new(0, 0, 0),
	EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.08, ExposureCompensation = -0.1, FogColor = Color3.fromRGB(192, 192, 192),
	FogEnd = 100000, FogStart = 0, GeographicLatitude = 0, GlobalShadows = true, OutdoorAmbient = Color3.fromRGB(78, 82, 90),
	ShadowSoftness = 0.12, ClockTime = 13,
}
local arena = { -- MapInfo.Lighting (Arena / PracticeRange)
	ClockTime = 15.2, GeographicLatitude = 40, Brightness = 1.6, ExposureCompensation = -0.55,
	Ambient = Color3.fromRGB(86, 86, 88), OutdoorAmbient = Color3.fromRGB(112, 112, 114),
	EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.2, GlobalShadows = true,
}
for k, v in base do L[k] = v end
-- the match place: LightingStyle Realistic (0), Outlines off. A hand-written blank .rbxl carried LightingStyle 0 but Studio opened
-- it as Soft with Outlines on (2026-10-26): set both here and read them back from the saved file (tools/rbxl_lighting_dump.py)
L.LightingStyle = Enum.LightingStyle.Realistic
L.Outlines = false
for k, v in arena do L[k] = v end
local function child(class, name)
	local c = L:FindFirstChild(name)
	if not c then c = Instance.new(class); c.Name = name; c.Parent = L end
	return c
end
local sky = child("Sky", "Sky")
sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = "rbxassetid://6444884337", "rbxassetid://6444884785", "rbxassetid://6444884337"
sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = "rbxassetid://6444884337", "rbxassetid://6444884337", "rbxassetid://6412503613"
sky.SunTextureId, sky.MoonTextureId = "rbxassetid://6196665106", "rbxassetid://6444320592"
sky.SunAngularSize, sky.MoonAngularSize, sky.StarCount, sky.CelestialBodiesShown = 11, 11, 3000, true
local atm = child("Atmosphere", "Atmosphere")
atm.Density, atm.Offset, atm.Haze, atm.Glare = 0.26, 0.05, 1, 0.1
atm.Color, atm.Decay = Color3.fromRGB(214, 220, 228), Color3.fromRGB(150, 160, 176)
local bloom = child("BloomEffect", "Bloom")
bloom.Enabled, bloom.Intensity, bloom.Size, bloom.Threshold = true, 0.4, 24, 1.6
local grade = child("ColorCorrectionEffect", "MapGrade")
grade.Enabled, grade.Brightness, grade.Contrast, grade.Saturation, grade.TintColor = true, 0, 0.14, 0.05, Color3.fromRGB(255, 250, 244)
workspace.CurrentCamera.FieldOfView = 70
local list = {}
for _, c in L:GetChildren() do table.insert(list, c.ClassName .. ":" .. c.Name) end
return ("sun %s | children %s | ws %s"):format(tostring(L:GetSunDirection()), table.concat(list, ","), #workspace:GetChildren())
