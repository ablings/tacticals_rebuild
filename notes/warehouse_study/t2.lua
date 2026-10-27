local HS=game:GetService("HttpService")
local w=workspace.Warehouse
local res={proxies={},spawns={},interactive={},visuals_summary={},lights={},shootables={},props={},camskin={}}
local function rec(p)
  local cf=p.CFrame
  local rx,ry,rz=cf:ToOrientation()
  return {name=p.Name,class=p.ClassName,shape=(p:IsA("Part") and tostring(p.Shape) or nil),pos={cf.X,cf.Y,cf.Z},size={p.Size.X,p.Size.Y,p.Size.Z},rot={math.deg(rx),math.deg(ry),math.deg(rz)},
    collide=p.CanCollide,query=p.CanQuery,transp=p.Transparency,mat=tostring(p.Material),color={math.floor(p.Color.R*255+.5),math.floor(p.Color.G*255+.5),math.floor(p.Color.B*255+.5)},group=p.CollisionGroup,
    attrs=p:GetAttributes(),tags=game:GetService("CollectionService"):GetTags(p),parent=p.Parent and p.Parent.Name}
end
for _,p in ipairs(w.CollisionProxies:GetChildren()) do if p:IsA("BasePart") then table.insert(res.proxies,rec(p)) end end
for _,p in ipairs(workspace.MatchSpawns:GetDescendants()) do if p:IsA("BasePart") then table.insert(res.spawns,rec(p)) end end
for _,p in ipairs(w.Interactive:GetDescendants()) do if p:IsA("BasePart") then table.insert(res.interactive,rec(p)) end end
for _,p in ipairs(w.Shootables:GetDescendants()) do if p:IsA("BasePart") then table.insert(res.shootables,rec(p)) end end
for _,p in ipairs(w.CamSkin:GetDescendants()) do if p:IsA("BasePart") then table.insert(res.camskin,rec(p)) end end
for _,m in ipairs(w.Props:GetChildren()) do local cf,sz=m:GetBoundingBox(); table.insert(res.props,{name=m.Name,pos={cf.X,cf.Y,cf.Z},size={sz.X,sz.Y,sz.Z}}) end
for _,l in ipairs(w:GetDescendants()) do if l:IsA("Light") then local h=l.Parent; local pp=h:IsA("BasePart") and h.Position or (h:IsA("Attachment") and h.WorldPosition) or Vector3.zero
  table.insert(res.lights,{class=l.ClassName,host=h:GetFullName(),pos={pp.X,pp.Y,pp.Z},b=l.Brightness,r=l.Range,shadows=l.Shadows,enabled=l.Enabled,color={math.floor(l.Color.R*255),math.floor(l.Color.G*255),math.floor(l.Color.B*255)}}) end end
-- visuals summary by class
local cls={}
for _,d in ipairs(w.Visuals:GetDescendants()) do cls[d.ClassName]=(cls[d.ClassName] or 0)+1 end
res.visuals_summary=cls
local wc={}
for _,d in ipairs(w:GetDescendants()) do wc[d.ClassName]=(wc[d.ClassName] or 0)+1 end
res.warehouse_classes=wc
res.warehouse_attrs=w:GetAttributes(); res.warehouse_tags=game:GetService("CollectionService"):GetTags(w)
local cf,sz=w:GetBoundingBox(); res.bbox={pos={cf.X,cf.Y,cf.Z},size={sz.X,sz.Y,sz.Z}}
return HS:JSONEncode(res)
