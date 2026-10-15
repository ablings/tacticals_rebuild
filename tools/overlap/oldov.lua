local LM=workspace.LobbyMap
local kits={LM.Hub1,LM.Rooms2,LM.Rooms3,LM.Showroom.Rooms4}
local saved={}
for _,k in kits do for _,d in k:GetDescendants() do if d:IsA("BasePart") then saved[d]=d.CanQuery d.CanQuery=true end end end
local op=OverlapParams.new() op.FilterType=Enum.RaycastFilterType.Include op.FilterDescendantsInstances=kits
local out={}
local skip={Hub1=1,Rooms2=1,Rooms3=1,Training=1,NPCs=1,City=1}
for _,d in LM:GetDescendants() do
 if d:IsA("BasePart") and d.Transparency<0.95 and not skip[d:GetFullName():split(".")[3]] and not d:IsDescendantOf(LM.Showroom.Rooms4) then
  local q0=d.CanQuery
  local hits=workspace:GetPartsInPart(d,op)
  if #hits>0 then local n={} for i=1,math.min(4,#hits) do n[i]=hits[i].Name end table.insert(out,d:GetFullName():sub(19).." -> "..table.concat(n,",")) end
 end
end
for p,q in saved do p.CanQuery=q end
return #out.."\n"..table.concat(out,"\n")
