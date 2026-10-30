-- read_r15.lua: prints r15.json for the Blender rig (rest CFrames relative to the floor under the HRP, Motor6D C0/C1,
-- the tool grip RightHand -> Handle for each gun tool found). Edit mode, read-only except a temporary rig it deletes.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local desc = Instance.new("HumanoidDescription")
local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
rig.Parent = workspace
rig:PivotTo(CFrame.new(0, 100, 0))
local hrp = rig.HumanoidRootPart
local hum = rig.Humanoid
local floor = hrp.CFrame * CFrame.new(0, -(hrp.Size.Y / 2 + hum.HipHeight), 0)
local function arr(c) return { c:GetComponents() } end
local out = { parts = {}, joints = {}, hipHeight = hum.HipHeight, guns = {} }
for _, p in rig:GetChildren() do
	if p:IsA("BasePart") then
		out.parts[p.Name] = { cf = arr(floor:ToObjectSpace(p.CFrame)), size = { p.Size.X, p.Size.Y, p.Size.Z } }
	end
end
local kinds = {}
for _, j in rig:GetDescendants() do
	if j:IsA("Motor6D") then
		out.joints[j.Part1.Name] = { name = j.Name, part0 = j.Part0.Name, C0 = arr(j.C0), C1 = arr(j.C1) }
		kinds.Motor6D = (kinds.Motor6D or 0) + 1
	elseif j:IsA("AnimationConstraint") then
		kinds.AnimationConstraint = (kinds.AnimationConstraint or 0) + 1
		local a0, a1 = j.Attachment0, j.Attachment1
		out.joints[a1.Parent.Name] = { name = j.Name, part0 = a0.Parent.Name, C0 = arr(a0.CFrame), C1 = arr(a1.CFrame) }
	end
end
local att = rig.RightHand:FindFirstChild("RightGripAttachment")
out.rightGripAttachment = att and arr(att.CFrame)
-- every gun tool in the place: Tool.Grip (C1 of RightGrip)
for _, t in game:GetDescendants() do
	if t:IsA("Tool") and t:FindFirstChild("Handle") and not out.guns[t.Name] then
		local g = { grip = arr(t.Grip), path = t:GetFullName(), handleSize = { t.Handle.Size.X, t.Handle.Size.Y, t.Handle.Size.Z }, parts = {}, atts = {} }
		for _, d in t:GetDescendants() do
			if d:IsA("BasePart") then
				g.parts[d.Name] = { cf = arr(t.Handle.CFrame:ToObjectSpace(d.CFrame)), size = { d.Size.X, d.Size.Y, d.Size.Z } }
			elseif d:IsA("Attachment") then
				g.atts[d.Name] = arr(t.Handle.CFrame:ToObjectSpace(d.WorldCFrame))
			elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				g.joints = g.joints or {}
				table.insert(g.joints, { d.ClassName, d.Name, d.Part0 and d.Part0.Name, d.Part1 and d.Part1.Name })
			end
		end
		out.guns[t.Name] = g
	end
end
rig:Destroy()

local gp = out.guns["Pistol"] or next(out.guns) and out.guns[next(out.guns)]
local ga = rig and nil
return HttpService:JSONEncode(out)
