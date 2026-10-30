-- Static cost census of a place (read-only). ROOT = path like "Workspace" or "game"; DEPTH = breakdown depth under each root.
local roots = {}
for name in string.gmatch("{{ROOTS}}", "[^,]+") do
  local inst = game
  for seg in string.gmatch(name, "[^%.]+") do inst = inst and inst:FindFirstChild(seg) end
  if inst then table.insert(roots, inst) end
end
local function blank() return {inst=0,parts=0,mesh=0,union=0,visible=0,shadow=0,unanch=0,lights=0,lightsOn=0,shadowLights=0,
  pe=0,peOn=0,peRate=0,beams=0,trails=0,fx=0,tex=0,decal=0,sa=0,gui=0,guiEl=0,scripts=0,sounds=0,meshIds={},texIds={},meshAssets=0} end
local function addId(set, id) if id and id ~= "" then set[id] = true end end
local function scan(root, t)
  for _, d in ipairs(root:GetDescendants()) do
    t.inst += 1
    if d:IsA("BasePart") then
      t.parts += 1
      if d:IsA("MeshPart") then t.mesh += 1; addId(t.meshIds, d.MeshId); addId(t.texIds, d.TextureID)
      elseif d:IsA("UnionOperation") then t.union += 1 end
      if d.Transparency < 1 then t.visible += 1; if d.CastShadow then t.shadow += 1 end end
      if not d.Anchored then t.unanch += 1 end
    elseif d:IsA("Light") then
      t.lights += 1; if d.Enabled then t.lightsOn += 1; if d.Shadows then t.shadowLights += 1 end end
    elseif d:IsA("ParticleEmitter") then t.pe += 1; if d.Enabled then t.peOn += 1; t.peRate += d.Rate end
    elseif d:IsA("Beam") then t.beams += 1
    elseif d:IsA("Trail") then t.trails += 1
    elseif d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then t.fx += 1
    elseif d:IsA("Texture") then t.tex += 1; addId(t.texIds, d.Texture)
    elseif d:IsA("Decal") then t.decal += 1; addId(t.texIds, d.Texture)
    elseif d:IsA("SurfaceAppearance") then t.sa += 1
      for _, p in ipairs({"ColorMap","NormalMap","RoughnessMap","MetalnessMap"}) do local ok,v = pcall(function() return d[p] end); if ok then addId(t.texIds, v) end end
    elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then t.gui += 1
    elseif d:IsA("GuiObject") then t.guiEl += 1
    elseif d:IsA("LuaSourceContainer") then t.scripts += 1
    elseif d:IsA("Sound") then t.sounds += 1
    elseif d:IsA("SpecialMesh") then t.meshAssets += 1; addId(t.meshIds, d.MeshId); addId(t.texIds, d.TextureId)
    end
  end
end
local function n(set) local c = 0 for _ in pairs(set) do c += 1 end return c end
local function fmt(name, t)
  return string.format("%s | inst %d | parts %d (mesh %d, union %d) visible %d shadowCast %d unanch %d | lights %d on %d shadowed %d | PE %d on %d rate %.0f | beams %d trails %d fx %d | tex %d decal %d SA %d uniqTex %d | uniqMesh %d | gui %d el %d | scripts %d sounds %d",
    name, t.inst, t.parts, t.mesh, t.union, t.visible, t.shadow, t.unanch, t.lights, t.lightsOn, t.shadowLights, t.pe, t.peOn, t.peRate,
    t.beams, t.trails, t.fx, t.tex, t.decal, t.sa, n(t.texIds), n(t.meshIds), t.gui, t.guiEl, t.scripts, t.sounds)
end
local out = {}
local minInst = tonumber("{{MIN}}") or 300
for _, r in ipairs(roots) do
  local tot = blank(); scan(r, tot); table.insert(out, fmt("TOTAL " .. r:GetFullName(), tot))
  for _, c in ipairs(r:GetChildren()) do
    local t = blank(); scan(c, t)
    if t.inst >= minInst or t.lightsOn > 0 or t.peOn > 0 then table.insert(out, "  " .. fmt(c.Name .. " [" .. c.ClassName .. "]", t)) end
  end
end
local L = game:GetService("Lighting")
table.insert(out, string.format("Lighting tech %s style %s GlobalShadows %s ShadowSoftness %.2f | Streaming %s | instances %d",
  tostring(select(2,pcall(function() return L.Technology end))), tostring(pcall(function() return L.LightingStyle end) and L.LightingStyle), tostring(L.GlobalShadows), L.ShadowSoftness,
  tostring(workspace.StreamingEnabled), game:GetService("Stats").InstanceCount))
for _, c in ipairs(L:GetChildren()) do
  local e = c:IsA("PostEffect") and (" enabled=" .. tostring(c.Enabled)) or ""
  table.insert(out, "  Lighting." .. c.Name .. " [" .. c.ClassName .. "]" .. e)
end
return table.concat(out, "\n")
