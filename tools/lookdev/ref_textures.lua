-- READ-ONLY: dump every Texture in the RIVALS arena copy with its part's CFrame and size
local out = {}
for _, t in workspace:GetDescendants() do
	if t:IsA("Texture") and t.Parent:IsA("BasePart") then
		local p = t.Parent
		local cf = p.CFrame
		local rx, ry, rz = cf:ToOrientation()
		table.insert(out, string.format("%s|%s|%.3f,%.3f,%.3f|%.1f,%.1f,%.1f|%.2f,%.2f,%.2f|%s|%.3f|%.3f|%.2f|%.2f|%s|%.2f|%d,%d,%d",
			p.ClassName, p.Name, p.Size.X, p.Size.Y, p.Size.Z, math.deg(rx), math.deg(ry), math.deg(rz),
			cf.X, cf.Y, cf.Z, t.Face.Name, t.OffsetStudsU, t.OffsetStudsV, t.StudsPerTileU, t.StudsPerTileV, t.Texture,
			t.Transparency, t.Color3.R*255, t.Color3.G*255, t.Color3.B*255))
	end
end
local L = game.Lighting
table.insert(out, ("LIGHT clock %.2f lat %.1f bright %.2f exp %.2f amb %s out %s sun %s"):format(L.ClockTime, L.GeographicLatitude, L.Brightness, L.ExposureCompensation, tostring(L.Ambient), tostring(L.OutdoorAmbient), tostring(L:GetSunDirection())))
return table.concat(out, "\n")
