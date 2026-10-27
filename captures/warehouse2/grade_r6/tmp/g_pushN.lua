char = lp.Character; hum = char:FindFirstChildOfClass("Humanoid"); root = char:FindFirstChild("HumanoidRootPart")
local function push(name, e0, n0, e1, n1)
	place(e0, n0, 0, e1 - e0, n1 - n0)
	local top, maxN, minN = -1e9, -1e9, 1e9
	hum:MoveTo(W(e1, n1, 0))
	local t0 = os.clock()
	while os.clock() - t0 < 4 do
		local p = plan(root.Position)
		maxN, minN = math.max(maxN, p.Y), math.min(minN, p.Y)
		top = math.max(top, feet())
		if os.clock() - t0 > 1 then hum.Jump = true end
		task.wait(0.05)
	end
	log(string.format("push %-14s ended %s  n %.2f..%.2f  top feet %.2f", name, where(), minN, maxN, top))
end
local WHICH = "N" --@WHICH
if WHICH == "S" then
	push("S centre", 0, -50, 0, -75)
	push("S e-9.5 edge", -9.5, -50, -9.5, -75)
	push("S e+9.5 diag", 4, -50, 12, -75)
else
	push("N centre", 0, 50, 0, 75)
	push("N e+9.5 edge", 9.5, 50, 9.5, 75)
	push("N e-9.5 diag", -4, 50, -12, 75)
end
return table.concat(LOG, "\n")
