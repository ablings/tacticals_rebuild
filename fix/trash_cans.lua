-- fix/trash_cans.lua [TRASHCAN] 2026-10-21 (Edward via the main PC: RIVALS-style red trash cans in Training, "Trash Can / Change Weapons",
-- opening the free weapon picker). Training already has 9 swap bins (LobbyMap.Training.Extras.SwapBins, prompt "Weapon Crate / Change
-- Weapon", key F, attribute TrainingBin -> TrainingBinsController opens the picker). This restyles them as red trash cans: the crate parts
-- go to ServerStorage._TrashCanUndo (for UNDO), a can is built in their place (Parts: body, ribs, rim, lid, handle), and the prompt text
-- becomes "Trash Can" / "Change Weapons". Key stays F (Q is Take Cover). Lobby working copy only. Idempotent; UNDO = true restores.
-- (Parts, not a Blender mesh: a mesh version can replace the "TrashCan" model later without touching the prompt.)
local UNDO = false --@UNDO
local SS = game:GetService("ServerStorage")
local bins = workspace.LobbyMap.Training.Extras:FindFirstChild("SwapBins")
assert(bins, "no SwapBins")
local stash = SS:FindFirstChild("_TrashCanUndo")
if not stash and not UNDO then stash = Instance.new("Folder") stash.Name = "_TrashCanUndo" stash.Parent = SS end

local RED = Color3.fromRGB(196, 38, 36)
local DARK = Color3.fromRGB(40, 40, 44)
local function part(parent, name, shape, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = name == "Body"
	p.CanQuery = name == "Body"
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local n = 0
for i, m in bins:GetChildren() do
	if not m:IsA("Model") then continue end
	local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
	local key = "Bin" .. i
	if UNDO then
		local can = m:FindFirstChild("TrashCan")
		if can then
			if prompt then prompt.Parent = nil end
			can:Destroy()
			local old = stash and stash:FindFirstChild(key)
			if old then for _, c in old:GetChildren() do c.Parent = m end old:Destroy() end
			local holder = m:FindFirstChild(prompt and prompt:GetAttribute("_HomePart") or "") or m:FindFirstChildWhichIsA("BasePart")
			if prompt and holder then
				prompt.Parent = holder
				prompt.ObjectText, prompt.ActionText = "Weapon Crate", "Change Weapon"
				prompt:SetAttribute("_HomePart", nil)
			end
			n += 1
		end
		continue
	end
	if m:FindFirstChild("TrashCan") then n += 1 continue end
	local pivot = m:GetPivot()
	-- the floor under the crate: the can stands on it
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { m }
	local down = workspace:Raycast(pivot.Position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	local floorY = down and down.Position.Y or (pivot.Position.Y - 1.25)
	local base = CFrame.new(pivot.Position.X, floorY, pivot.Position.Z) * pivot.Rotation
	-- crate parts out (kept for UNDO); the prompt's part name is remembered
	local old = Instance.new("Folder")
	old.Name = key
	old.Parent = stash
	if prompt then prompt:SetAttribute("_HomePart", prompt.Parent.Name) prompt.Parent = nil end
	for _, c in m:GetChildren() do c.Parent = old end
	local can = Instance.new("Model")
	can.Name = "TrashCan"
	can.Parent = m
	local H, R = 3.2, 1.25 -- waist-high, R15 scale
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
	local body = part(can, "Body", Enum.PartType.Cylinder, Vector3.new(H, R * 2, R * 2), base * CFrame.new(0, H / 2, 0) * up, RED, Enum.Material.Metal)
	for _, y in { 0.7, 1.6, 2.5 } do
		part(can, "Rib", Enum.PartType.Cylinder, Vector3.new(0.12, R * 2 + 0.08, R * 2 + 0.08), base * CFrame.new(0, y, 0) * up, RED:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal)
	end
	part(can, "Base", Enum.PartType.Cylinder, Vector3.new(0.18, R * 2 + 0.1, R * 2 + 0.1), base * CFrame.new(0, 0.09, 0) * up, DARK, Enum.Material.Metal)
	part(can, "Rim", Enum.PartType.Cylinder, Vector3.new(0.16, R * 2 + 0.16, R * 2 + 0.16), base * CFrame.new(0, H - 0.04, 0) * up, DARK, Enum.Material.Metal)
	part(can, "Lid", Enum.PartType.Cylinder, Vector3.new(0.22, R * 2 + 0.06, R * 2 + 0.06), base * CFrame.new(0, H + 0.12, 0) * up, RED:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Metal)
	part(can, "Handle", Enum.PartType.Block, Vector3.new(0.9, 0.18, 0.22), base * CFrame.new(0, H + 0.33, 0), DARK, Enum.Material.Metal)
	can.PrimaryPart = body
	m.PrimaryPart = body
	if prompt then
		prompt.ObjectText = "Trash Can"
		prompt.ActionText = "Change Weapons"
		prompt.Parent = body
	end
	n += 1
end
if UNDO and stash and #stash:GetChildren() == 0 then stash:Destroy() end
return (UNDO and "UNDO " or "TRASHCAN ") .. n .. " bins"
