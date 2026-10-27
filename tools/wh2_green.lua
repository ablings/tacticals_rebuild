-- tools/wh2_green.lua: read-only. Every visible part, Texture, SurfaceGui text / frame in Warehouse2 + Warehouse2Exterior whose
-- colour reads green (G above both R and B by 6+, saturation > 0.12), grouped by model/name with the area; plus any
-- MaterialVariant in MaterialService or on a part. Round 6 rule: olive only on two crates.
local HS = game:GetService("HttpService")
local MS = game:GetService("MaterialService")
local function green(c)
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	return g >= r + 6 and g >= b + 6 and mx > 0 and (mx - mn) / mx > 0.12
end
local groups, variants, partsWithVariant, nArt = {}, {}, {}, 0
local function add(key, area) local g = groups[key] or { n = 0, area = 0 } g.n += 1 g.area += area groups[key] = g end
for _, root in { workspace:FindFirstChild("Warehouse2"), workspace:FindFirstChild("Warehouse2Exterior") } do
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			nArt += 1
			if d.MaterialVariant ~= "" then table.insert(partsWithVariant, d:GetFullName()) end
			if green(d.Color) then
				local s = d.Size
				add(d.Parent.Name .. "/" .. d.Name .. " " .. tostring(d.BrickColor) .. (" (%d,%d,%d)"):format(d.Color.R * 255, d.Color.G * 255, d.Color.B * 255), 2 * (s.X * s.Y + s.Y * s.Z + s.X * s.Z))
			end
		elseif d:IsA("TextLabel") and d.TextTransparency < 1 and green(d.TextColor3) then
			add("TEXT " .. d.Text .. " on " .. d.Parent.Parent:GetFullName(), 1)
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 and green(d.BackgroundColor3) then
			add("FRAME on " .. d.Parent.Parent:GetFullName(), 1)
		elseif d:IsA("Texture") and d.Transparency < 1 and green(d.Color3) then
			add("TEXTURE on " .. d.Parent:GetFullName(), 1)
		end
	end
end
for _, v in MS:GetDescendants() do if v:IsA("MaterialVariant") then table.insert(variants, v.Name) end end
local list = {}
for k, g in groups do table.insert(list, { k = k, n = g.n, area = math.floor(g.area * 10 + 0.5) / 10 }) end
table.sort(list, function(a, b) return a.area > b.area end)
return HS:JSONEncode({ green = list, materialVariants = variants, partsWithVariant = partsWithVariant, visibleParts = nArt })
