-- ServerScriptService.DualGrip (Script, hub + match places) [DUALGRIP] 2026-10-21: the Dual Pistols' left gun sits in the LEFT hand.
-- The tool template welds both guns to its Handle (the right hand's grip), so the left gun floated 1.1 studs off the right hand
-- (notes/weapon_abilities.md "Not done"). While the tool is held, each left part (LeftSlide / LeftFrame / LeftGrip / LeftBarrel)
-- is re-welded to the character's LeftHand as the mirror image of its right twin (RightSlide / RightFrame / Handle / Barrel) in
-- the RightHand; back in the Backpack it's welded to the Handle again at its template offset. Animations move the hands, so the
-- guns follow whatever pose the arms are in. Installed by fix/dual_grip_install.lua.
local Players = game:GetService("Players")

local PAIRS = { LeftSlide = "RightSlide", LeftFrame = "RightFrame", LeftGrip = "Handle", LeftBarrel = "Barrel" }

-- the mirror of a hand-local CFrame across the hand's X axis (R15 hands share one orientation at rest, so RightHand * rel
-- reflected through the body's mid-plane is LeftHand * mirror(rel))
local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- a Weld with an explicit C0 (part = to * offset): a WeldConstraint takes its offset from wherever each machine sees the parts
-- when it appears, so the client kept the old spot
local function weldTo(part: BasePart, to: BasePart, offset: CFrame)
	for _, w in part:GetChildren() do
		if w:IsA("WeldConstraint") or (w:IsA("Weld") and w.Name == "DualGripWeld") then w:Destroy() end
	end
	local w = Instance.new("Weld")
	w.Name = "DualGripWeld"
	w.Part0, w.Part1 = to, part
	w.C0, w.C1 = offset, CFrame.identity
	w.Parent = part
end

local function hook(tool: Tool)
	if tool:GetAttribute("DualGripHooked") then return end
	tool:SetAttribute("DualGripHooked", true)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return end
	-- template offsets (left part relative to the Handle), taken before anything moves
	local home = {}
	for left in PAIRS do
		local p = tool:FindFirstChild(left)
		if p and p:IsA("BasePart") then home[left] = handle.CFrame:ToObjectSpace(p.CFrame) end
	end
	local function place()
		local character = tool.Parent
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local rh, lh = character and character:FindFirstChild("RightHand"), character and character:FindFirstChild("LeftHand")
		if hum and rh and lh then
			-- wait for the RightGrip weld, so the right gun is where it'll stay
			for _ = 1, 30 do
				if rh:FindFirstChild("RightGrip") then break end
				task.wait()
			end
			if tool.Parent ~= character then return end
			for left, right in PAIRS do
				local lp, rp = tool:FindFirstChild(left), tool:FindFirstChild(right)
				if lp and rp then
					weldTo(lp, lh, mirror(rh.CFrame:ToObjectSpace(rp.CFrame)))
				end
			end
		else
			-- in the Backpack (or dropped): back on the Handle
			for left, offset in home do
				local lp = tool:FindFirstChild(left)
				if lp then
					weldTo(lp, handle, offset)
				end
			end
		end
	end
	tool:GetPropertyChangedSignal("Parent"):Connect(function() task.defer(place) end)
	task.defer(place)
end

local function watch(container: Instance)
	for _, d in container:GetChildren() do
		if d:IsA("Tool") and d.Name == "DualPistols" then hook(d) end
	end
	container.ChildAdded:Connect(function(d)
		if d:IsA("Tool") and d.Name == "DualPistols" then hook(d) end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(watch)
	if player.Character then watch(player.Character) end
	local bp = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if bp then watch(bp) end
	player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) end end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end
