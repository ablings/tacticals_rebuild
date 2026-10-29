--@lib
local rig = workspace._AnimStage.StageRig
local SRC = game.ReplicatedStorage.Repository.AnimationSources
local out = {}
for _, gunName in { "Pistol", "AutoRifle" } do
	local tool = game.ReplicatedStorage.Repository.Weapons[gunName]
	local mz = tool:FindFirstChild("Muzzle", true)
	local off = tool.Handle.CFrame:Inverse() * mz.WorldCFrame
	local function muzzle()
		local w = L.fkRig(rig)
		return w.RightHand * rig.RightHand.RightGripAttachment.CFrame * tool.Grip:Inverse() * off
	end
	L.pose(rig, { { SRC.PistolHold, 0 } })
	local m0 = muzzle()
	for _, n in { "CoverLeanLeft", "CoverLeanRight", "CoverLeanLeftCrouch" } do
		local base = n:find("Crouch") and { { SRC.CoverCrouchPeek, 0 } } or { { SRC.PistolHold, 0 } }
		L.pose(rig, base); local b = muzzle()
		table.insert(base, { SRC[n], 0 })
		L.pose(rig, base)
		local m1 = muzzle()
		table.insert(out, string.format("%s %s muzzle dx=%.2f dy=%.2f dz=%.2f fwd %s", gunName, n, m1.X - b.X, m1.Y - b.Y, m1.Z - b.Z, tostring(m1.LookVector)))
	end
end
return table.concat(out, "\n")
