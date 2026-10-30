-- Server: fire map effects through the game's own Studio test hooks. ACT = arm:<Gadget> | steam:<Map> | glass:<Map>:<n> | alarms | barrels:<Map> | list:<Map>
local SS, HS = game:GetService("ServerStorage"), game:GetService("HttpService")
local act = "{{ACT}}"
local kind, a, b = act:match("^([^:]+):?([^:]*):?(.*)$")
local out = {}
if kind == "arm" then
  local cfg = require(game.ReplicatedStorage.Modules.Shared.Config.GadgetConfig)
  for _, p in game.Players:GetPlayers() do p:SetAttribute("KitGadget", a); p:SetAttribute(cfg[a].ChargesAttribute, 20); p:SetAttribute("KitLocked", false) end
  return "armed " .. a
elseif kind == "steam" then
  local h = SS:FindFirstChild("SteamFillTestHook"); if not h then return "no steam hook" end
  local list = HS:JSONDecode(h:Invoke("valves"))
  for _, v in list do if v.path:find(a, 1, true) == 1 then table.insert(out, v.path .. " " .. tostring(h:Invoke("activate", v.path))) end end
  return "valves " .. #list .. " | " .. table.concat(out, ", ")
elseif kind == "glass" then
  local h = SS:FindFirstChild("GlassTestHook"); if not h then return "no glass hook" end
  local list = HS:JSONDecode(h:Invoke("windows")); local n, max = 0, tonumber(b) or 6
  for _, w in list do if n < max and w.path:find(a, 1, true) == 1 and not w.broken then n += 1; table.insert(out, w.path .. "=" .. tostring(h:Invoke("blast", w.path, 3))) end end
  return "windows " .. #list .. " | " .. table.concat(out, ", ")
elseif kind == "alarms" then
  local h = SS:FindFirstChild("SmokeAlarmTestHook"); if not h then return "no alarm hook" end
  local list = HS:JSONDecode(h:Invoke("alarms"))
  for _, e in list do table.insert(out, e.name .. "=" .. tostring(h:Invoke("shoot", e.name))) end
  return "alarms " .. #list .. " | " .. table.concat(out, ", ")
elseif kind == "barrels" or kind == "list" then
  local m = workspace:FindFirstChild(a)
  for _, d in (m and m:GetDescendants() or {}) do
    if d:IsA("Model") and (d.Name:lower():find("barrel") or d.Name:lower():find("valve")) and d.Parent and d.Parent.Name == "Shootables" then
      local pos = d:GetPivot().Position; table.insert(out, d.Name .. string.format("@%.0f,%.0f,%.0f", pos.X, pos.Y, pos.Z)) end
  end
  return table.concat(out, " ")
end
return "?"
