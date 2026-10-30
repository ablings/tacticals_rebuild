-- Client [PERFSET] smoke: the rows exist, every setting on then off again leaves the world as it was
local p = game.Players.LocalPlayer
local SC = require(game.ReplicatedStorage.Modules.Shared.Config.SettingsConfig)
local L = game:GetService("Lighting")
local function state()
  local sh, on = 0, 0
  for _, d in workspace:GetDescendants() do if d:IsA("Light") then if d.Shadows then sh += 1 end if d.Enabled then on += 1 end end end
  return string.format("GS=%s lampShadows=%d lightsOn=%d", tostring(L.GlobalShadows), sh, on)
end
local rows = 0
for _, k in {"Optimized Lighting", "Optimized Textures", "Fewer Lights", "Low Effects", "Hide Far Screens"} do if SC.Rows.Video[k] then rows += 1 end end
local a = state()
for _, k in {"OptimizedLighting", "OptimizedTextures", "FewerLights", "LowEffects", "HideFarScreens"} do p:SetAttribute("Setting_" .. k, true) end
task.wait(1.5); local b = state()
for _, k in {"OptimizedLighting", "OptimizedTextures", "FewerLights", "LowEffects", "HideFarScreens"} do p:SetAttribute("Setting_" .. k, false) end
task.wait(1.5); local c = state()
return "rows " .. rows .. "/5 | off: " .. a .. " | on: " .. b .. " | off again: " .. c .. (a == c and " | RESTORED" or " | NOT RESTORED")
