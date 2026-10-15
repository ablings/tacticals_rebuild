local LM=workspace.LobbyMap
local out={}
for _,k in {LM.Hub1,LM.Rooms2,LM.Rooms3,LM.Showroom.Rooms4} do
 for _,d in k:GetDescendants() do if d:IsA("BasePart") then
  local p,s=d.Position,d.Size
  local o=d.CFrame.Rotation
  table.insert(out,string.format("%s|%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.2f|%s|%s|%s|%s|%s|%s|%s",k.Name,d.Name,p.X,p.Y,p.Z,s.X,s.Y,s.Z,d.Transparency,tostring(d.CanCollide),tostring(d.CanQuery),d.ClassName, tostring(o:FuzzyEq(CFrame.new(),1e-3)), d.Color:ToHex(), d.Material.Name, d.MaterialVariant))
 end end
end
return table.concat(out,"\n")
