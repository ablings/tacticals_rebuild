local HS=game:GetService("HttpService")
local w=workspace.Warehouse
local res={collidingNonProxy={},lighting={},player={},meshes={},scripts={}}
for _,p in ipairs(w:GetDescendants()) do
  if p:IsA("BasePart") and not p:IsDescendantOf(w.CollisionProxies) and not p:IsDescendantOf(w.CamSkin) and p.CanCollide then
    table.insert(res.collidingNonProxy,{p:GetFullName(),p.Position.X,p.Position.Y,p.Position.Z,p.Size.X,p.Size.Y,p.Size.Z,p.Transparency})
  end
end
local L=game.Lighting
for _,k in ipairs({"Technology","LightingStyle","PrioritizeLightingQuality","Brightness","Ambient","OutdoorAmbient","ClockTime","ExposureCompensation","GlobalShadows","ShadowSoftness","EnvironmentDiffuseScale","EnvironmentSpecularScale","ColorShift_Top","ColorShift_Bottom","FogEnd","FogColor"}) do
  local ok,v=pcall(function() return L[k] end); res.lighting[k]=ok and tostring(v) or "n/a" end
res.lightingChildren={}
for _,c in ipairs(L:GetChildren()) do local t={class=c.ClassName,name=c.Name}
  for _,k in ipairs({"Enabled","Density","Offset","Color","Decay","Haze","Glare","Intensity","Size","Threshold","Brightness","Contrast","Saturation","TintColor","Spread","SkyboxBk"}) do local ok,v=pcall(function() return c[k] end); if ok then t[k]=tostring(v) end end
  table.insert(res.lightingChildren,t) end
local SP=game.StarterPlayer
for _,k in ipairs({"CharacterWalkSpeed","CharacterJumpHeight","CharacterJumpPower","CharacterUseJumpPower","CharacterMaxSlopeAngle","AutoJumpEnabled","CameraMaxZoomDistance","CameraMode","DevComputerMovementMode"}) do local ok,v=pcall(function() return SP[k] end); res.player[k]=ok and tostring(v) or "n/a" end
res.cameraFOV=workspace.CurrentCamera.FieldOfView
res.streaming=workspace.StreamingEnabled
res.gravity=workspace.Gravity
local ids={}
for _,m in ipairs(w:GetDescendants()) do if m:IsA("MeshPart") then local k=m.MeshId; ids[k]=ids[k] or {n=0,names={}}; ids[k].n+=1; ids[k].names[m.Name]=true end end
for k,v in pairs(ids) do local nm={} for n in pairs(v.names) do table.insert(nm,n) end table.insert(res.meshes,{k,v.n,table.concat(nm,",")}) end
-- scripts that mention vault/crouch/walkspeed
for _,s in ipairs(game:GetDescendants()) do
  if s:IsA("LuaSourceContainer") then
    local ok,src=pcall(function() return s.Source end)
    if ok and src then
      local hits={}
      for _,kw in ipairs({"Vault","vault","Crouch","crouch","WalkSpeed","JumpHeight","JumpPower","Slide","Sprint","sprint"}) do if string.find(src,kw,1,true) then table.insert(hits,kw) end end
      if #hits>0 then table.insert(res.scripts,{s:GetFullName(),table.concat(hits,",")}) end
    end
  end
end
return HS:JSONEncode(res)
