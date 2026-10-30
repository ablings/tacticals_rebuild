-- proxy_guns.lua: prepend `local MANIFESTS = [==[ {Gun: manifest} ]==]`. Builds ReplicatedStorage._AnimGuns.<Gun> Tools from
-- the modeler's manifests (art/guns/manifest): Handle + one box per part at its bbox, a Motor6D per part named after it
-- (Part0 = parent part, C0/C1 at the pivot, no rotation), like the real remodel. For animation checks and captures only.
local HttpService = game:GetService("HttpService")
local all = HttpService:JSONDecode(MANIFESTS)
local root = game.ReplicatedStorage:FindFirstChild("_AnimGuns") or Instance.new("Folder")
root.Name = "_AnimGuns"; root.Parent = game.ReplicatedStorage
local out = {}
for gunName, m in all do
	local old = root:FindFirstChild(gunName); if old then old:Destroy() end
	local tool = Instance.new("Tool"); tool.Name = gunName; tool.Grip = CFrame.identity; tool.CanBeDropped = false
	local h = Instance.new("Part"); h.Name = "Handle"; h.Size = Vector3.new(0.2, 0.6, 0.3); h.Transparency = 1
	h.CanCollide = false; h.CFrame = CFrame.new(0, 500, 0); h.Parent = tool
	local parts = { Handle = h }
	local defs = {}
	for _, p in m.parts do defs[p.name] = p end
	local function make(name)
		if parts[name] then return parts[name] end
		local d = defs[name]
		local par = make(d.parent)
		local b = Instance.new("Part"); b.Name = name; b.Size = Vector3.new(d.size[1], d.size[2], d.size[3])
		b.CanCollide = false; b.Massless = true
		b.Color = Color3.fromRGB(d.colour[1], d.colour[2], d.colour[3]); b.Material = Enum.Material.SmoothPlastic
		b.CFrame = h.CFrame * CFrame.new(d.bbox_centre[1], d.bbox_centre[2], d.bbox_centre[3])
		b.Parent = tool
		local piv = h.CFrame * CFrame.new(d.pivot[1], d.pivot[2], d.pivot[3])
		local j = Instance.new("Motor6D"); j.Name = name; j.Part0 = par; j.Part1 = b
		j.C0 = par.CFrame:ToObjectSpace(piv); j.C1 = b.CFrame:ToObjectSpace(piv); j.Parent = par
		parts[name] = b
		return b
	end
	for name in defs do make(name) end
	tool.Parent = root
	table.insert(out, gunName .. " " .. #m.parts .. " parts")
end
return table.concat(out, ", ")
