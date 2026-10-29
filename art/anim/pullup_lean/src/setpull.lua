--@lib
local rig = workspace._AnimStage.StageRig
local ks = game.ReplicatedStorage.Repository.AnimationSources.CoverPullUp
local R = {}
for _, e in string.split(ks:GetAttribute("RootKeys"), ";") do local a = string.split(e, ","); table.insert(R, { tonumber(a[1]), tonumber(a[2]), tonumber(a[3]) }) end
local y, z = R[#R][2], R[#R][3]
for i = 1, #R - 1 do
	if T >= R[i][1] - 1e-6 and T <= R[i + 1][1] + 1e-6 then
		local u = (T - R[i][1]) / (R[i + 1][1] - R[i][1]); y = R[i][2] + (R[i + 1][2] - R[i][2]) * u; z = R[i][3] + (R[i + 1][3] - R[i][3]) * u; break
	end
end
L.pose(rig, { { ks, T } })
L.puppet(rig, GUN, CFrame.new(0, 800 + y, z))
return string.format("t=%.3f root %.2f %.2f", T, y, z)
