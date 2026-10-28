local m = workspace:FindFirstChild("W2_Props_kit")
if not m then return "no W2_Props_kit in Workspace" end
local out = {}
local function info(p)
  local sa = p:FindFirstChildOfClass("SurfaceAppearance")
  return ("%s [%s] size %.3f,%.3f,%.3f pos %.2f,%.2f,%.2f rot %s mesh %s sa %s col %s mat %s"):format(p:GetFullName():gsub("Workspace.W2_Props_kit.", ""), p.ClassName, p.Size.X, p.Size.Y, p.Size.Z, p.Position.X, p.Position.Y, p.Position.Z,
    tostring(Vector3.new(p.CFrame:ToOrientation()) * (180/math.pi)), p:IsA("MeshPart") and p.MeshId or "-", sa and (sa.ColorMap) or "none", tostring(p.Color), p.Material.Name)
end
table.insert(out, "children " .. #m:GetChildren() .. " descendants " .. #m:GetDescendants())
for _, c in m:GetChildren() do
  if c:IsA("BasePart") then table.insert(out, info(c)) else
    local cf, s = c:GetBoundingBox()
    table.insert(out, ("%s [%s] %d kids bbox %.2f,%.2f,%.2f"):format(c.Name, c.ClassName, #c:GetChildren(), s.X, s.Y, s.Z))
    for _, d in c:GetChildren() do if d:IsA("BasePart") then table.insert(out, "   " .. info(d)) else table.insert(out, "   " .. d.Name .. " [" .. d.ClassName .. "]") end end
  end
end
return table.concat(out, "\n")
