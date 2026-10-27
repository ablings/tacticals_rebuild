local O = Vector3.new(-84.2, 0.4, -300)
local out = {}
local function plan(v) local d = v - O return string.format("e%.1f n%.1f h%.1f", -d.X, d.Z, d.Y) end
local cnt = { total = 0, shadowed = 0 }
for _, root in { workspace.Warehouse2, workspace.Warehouse2Exterior } do
  for _, d in root:GetDescendants() do
    if d:IsA("Light") then
      cnt.total += 1
      if d.Shadows then cnt.shadowed += 1 end
      local host = d.Parent
      local pos = host:IsA("BasePart") and host.Position or (host:IsA("Attachment") and host.WorldPosition) or Vector3.zero
      local extra = ""
      if d:IsA("SpotLight") or d:IsA("SurfaceLight") then extra = " ang" .. d.Angle .. " face " .. tostring(d.Face) end
      table.insert(out, string.format("%s %s %s b%.2f r%.0f sh=%s en=%s col=%d,%d,%d%s | %s", root.Name, d.ClassName, plan(pos), d.Brightness, d.Range, tostring(d.Shadows), tostring(d.Enabled), d.Color.R*255, d.Color.G*255, d.Color.B*255, extra, host:GetFullName():gsub("Workspace%.", "")))
    end
  end
end
table.insert(out, 1, "TOTAL " .. cnt.total .. " shadowed " .. cnt.shadowed)
-- neon
local neon = {}
for _, root in { workspace.Warehouse2, workspace.Warehouse2Exterior } do
  for _, d in root:GetDescendants() do
    if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Transparency < 1 then
      table.insert(neon, string.format("%s (%d,%d,%d) %s", d.Name, d.Color.R*255, d.Color.G*255, d.Color.B*255, plan(d.Position)))
    end
  end
end
table.insert(out, "NEON " .. #neon .. ": " .. table.concat(neon, "; "))
return table.concat(out, "\n")
