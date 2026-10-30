-- play_give.lua (Server datamodel, Play mode): give the first player the tool JOB_TOOL and equip it, so the game's own
-- WeaponController loads and plays the clips on the real player avatar.
local Players = game:GetService("Players")
local plr = Players:GetPlayers()[1]
if not plr then return "no player" end
local char = plr.Character or plr.CharacterAdded:Wait()
local src = game.ReplicatedStorage.Repository:FindFirstChild(JOB_TOOL, true)
if not src then return "no tool " .. JOB_TOOL end
for _, t in char:GetChildren() do if t:IsA("Tool") then t.Parent = plr.Backpack end end
local tool = plr.Backpack:FindFirstChild(JOB_TOOL) or src:Clone()
tool.Parent = plr.Backpack
char.Humanoid:EquipTool(tool)
local hrp = char.HumanoidRootPart
local kinds = {}
for _, j in char:GetDescendants() do
	if j:IsA("Motor6D") or j:IsA("AnimationConstraint") then kinds[j.ClassName] = (kinds[j.ClassName] or 0) + 1 end
end
return ("equipped %s on %s at %s joints %s"):format(JOB_TOOL, plr.Name, tostring(hrp.Position),
	game:GetService("HttpService"):JSONEncode(kinds))
