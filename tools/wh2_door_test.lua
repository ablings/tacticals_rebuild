-- tools/wh2_door_test.lua: run in a Play SERVER (nothing persists). Proves the Warehouse 2 door contract (briefs/systems.md
-- "Warehouse 2 doors"): finds the doors by tag, rolls each up with the reference code, samples the Shutter while it moves (top
-- edge fixed, never above the head, bottom rising), checks Open / Moving, that a body-sized box fits through the open door and
-- not the shut one, then rolls it back down and checks it is exactly the closed shutter again.
local CS = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local HS = game:GetService("HttpService")

-- ===== reference code (the same as in briefs/systems.md) =====
local function rollDoor(door, open, seconds)
	local shutter = door:FindFirstChild("Shutter")
	if not shutter or door:GetAttribute("Moving") or door:GetAttribute("Open") == open then return nil end
	local closedSize, closedCF = shutter:GetAttribute("ClosedSize"), shutter:GetAttribute("ClosedCFrame")
	local h = open and (closedSize.Y - door:GetAttribute("OpenHeight")) or closedSize.Y
	door:SetAttribute("Moving", true)
	-- Size and CFrame tween with the same easing, so the top edge (CFrame.Y + Size.Y / 2) stays put behind the head
	local tween = TweenService:Create(shutter, TweenInfo.new(seconds or door:GetAttribute("RollTime") or 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Size = Vector3.new(closedSize.X, h, closedSize.Z),
		CFrame = closedCF + Vector3.new(0, (closedSize.Y - h) / 2, 0),
	})
	tween.Completed:Once(function()
		door:SetAttribute("Open", open)
		door:SetAttribute("Moving", false)
	end)
	tween:Play()
	return tween
end
-- =============================================================

local out = { doors = {} }
local doors = CS:GetTagged("Warehouse2Door")
out.found = #doors
local map = workspace.Warehouse2
local function bodyFits(door)
	-- a 2 x 5 x 1.2 body box standing in the opening, centred in the wall: does anything collidable overlap it?
	local sh = door.Shutter
	local cf = sh:GetAttribute("ClosedCFrame")
	local closed = sh:GetAttribute("ClosedSize")
	local p = OverlapParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { map }
	p.RespectCanCollide = true
	local floorY = cf.Position.Y - closed.Y / 2
	local hits = workspace:GetPartBoundsInBox(CFrame.new(cf.Position.X, floorY + 2.7, cf.Position.Z), Vector3.new(2, 5, 1.2), p)
	local names = {}
	for _, h in hits do table.insert(names, h.Name) end
	return #hits == 0, names
end
for _, door in doors do
	local r = { name = door.Name, open0 = door:GetAttribute("Open"), moving0 = door:GetAttribute("Moving"), samples = {} }
	local sh = door.Shutter
	local head = map.Visuals.Doors:FindFirstChild("Head_" .. door.Name:sub(-1))
	local headTop = head.Position.Y + head.Size.Y / 2
	r.shutCollide, r.notCover, r.prompts = sh.CanCollide, sh:GetAttribute("NotCover"), #door:GetDescendants() > 0 and (function() local n = 0 for _, d in door:GetDescendants() do if d:IsA("ProximityPrompt") then n += 1 end end return n end)() or 0
	r.fitsShut, r.blockShut = bodyFits(door)
	local top0 = sh.Position.Y + sh.Size.Y / 2
	local tw = rollDoor(door, true, 2)
	r.movingDuring = door:GetAttribute("Moving")
	for i = 1, 5 do
		task.wait(0.45)
		table.insert(r.samples, { t = i * 0.45, h = math.floor(sh.Size.Y * 100) / 100, top = math.floor((sh.Position.Y + sh.Size.Y / 2 - top0) * 1000) / 1000,
			bottomAboveFloor = math.floor((sh.Position.Y - sh.Size.Y / 2 - (top0 - sh:GetAttribute("ClosedSize").Y)) * 100) / 100 })
	end
	if tw.PlaybackState ~= Enum.PlaybackState.Completed then tw.Completed:Wait() end
	task.wait(0.1)
	r.openAfter, r.movingAfter = door:GetAttribute("Open"), door:GetAttribute("Moving")
	r.openHeightLeft = sh.Size.Y
	r.topAboveHead = (sh.Position.Y + sh.Size.Y / 2) - headTop
	r.fitsOpen, r.blockOpen = bodyFits(door)
	r.secondCallWhileOpen = rollDoor(door, true) == nil
	local tw2 = rollDoor(door, false, 2)
	tw2.Completed:Wait()
	task.wait(0.1)
	r.closedAgain = door:GetAttribute("Open") == false and (sh.Size - sh:GetAttribute("ClosedSize")).Magnitude < 1e-3
		and (sh.Position - sh:GetAttribute("ClosedCFrame").Position).Magnitude < 1e-3
	r.fitsShutAgain = bodyFits(door)
	table.insert(out.doors, r)
end
return HS:JSONEncode(out)
