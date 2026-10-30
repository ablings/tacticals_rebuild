local S=game:GetService('Stats')
local out={}
for _,p in ipairs({'FrameTime','RenderCPUFrameTime','RenderGPUFrameTime','HeartbeatTimeMs','PhysicsStepTimeMs','InstanceCount','PrimitivesCount','DataReceiveKbps','DataSendKbps','ContactsCount','MovingPrimitivesCount'}) do
  local ok,v=pcall(function() return S[p] end)
  table.insert(out,p..'='..tostring(ok and v or ('ERR '..tostring(v))))
end
local ok,v=pcall(function() return S:GetTotalMemoryUsageMb() end)
table.insert(out,'TotalMem='..tostring(v))
for _,c in ipairs(S:GetChildren()) do
  table.insert(out,'child '..c.Name..' '..c.ClassName)
  for _,d in ipairs(c:GetChildren()) do
    local ok2,val=pcall(function() return d:GetValueString() end)
    table.insert(out,'   '..d.Name..' = '..tostring(ok2 and val or 'x')..' #'..#d:GetChildren())
  end
end
local ok3,r=pcall(function() return settings().Rendering.QualityLevel end) table.insert(out,'Q='..tostring(r))
local ok4,r4=pcall(function() return settings().Rendering.EditQualityLevel end) table.insert(out,'EQ='..tostring(r4))
local ok5,sa=pcall(function() return game:GetService('SceneAnalysisService') end) table.insert(out,'SA='..tostring(ok5)..' '..tostring(sa))
return table.concat(out,'\n')
