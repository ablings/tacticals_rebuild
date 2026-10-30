local SRC = game.ReplicatedStorage.Repository.AnimationSources
local out = {}
for _, ks in SRC:GetChildren() do
	if ks:IsA("KeyframeSequence") then
		local parts, n, len = {}, 0, 0
		for _, kf in ks:GetKeyframes() do
			n += 1; len = math.max(len, kf.Time)
			for _, p in kf:GetDescendants() do if p:IsA("Pose") and p.Weight > 0 then parts[p.Name] = true end end
		end
		local pl = {}
		for k in parts do table.insert(pl, k) end
		table.sort(pl)
		table.insert(out, ("%s|%.2f|%s|%s|%d|%s|%s"):format(ks.Name, len, tostring(ks.Loop), ks.Priority.Name, n, tostring(ks:GetAttribute("PublishedId")), table.concat(pl, ",")))
	end
end
table.sort(out)
return table.concat(out, "\n")
