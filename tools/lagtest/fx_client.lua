-- Client: TP = "x,y,z" (teleport, optional) then throw GADGET toward AT ("x,y,z") with power POW
local p = game.Players.LocalPlayer
local char = p.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local function v(s) local x, y, z = s:match("([-%d.]+),([-%d.]+),([-%d.]+)"); return x and Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
local tp, at = v("{{TP}}"), v("{{AT}}")
if tp and root then root.CFrame = CFrame.new(tp) task.wait(0.3) end
if "{{GADGET}}" == "" or "{{GADGET}}" == "{{" .. "GADGET}}" then return "tp only" end
local dir = at and (at - root.Position).Unit or root.CFrame.LookVector
dir = (dir + Vector3.new(0, 0.25, 0)).Unit
game.ReplicatedStorage.Events.Combat.ThrowGadget:FireServer("{{GADGET}}", dir, tonumber("{{POW}}") or 0.6, "Throw", 0)
return "thrown {{GADGET}} from " .. tostring(root.Position)
