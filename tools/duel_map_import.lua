-- Lobby duels: rebuild a serialised match-place map (tools/duel_map_export.lua) in the lobby copy (Edit), in chunks.
-- Target: ServerStorage._DuelSource.<MAP_ID> (a Folder); the export's root nodes (p = 0) become its children.
-- Each created instance carries attribute _PortIdx (the export index) so later chunks can find their parents;
-- tools/duel_map_port.py strips them at the end. MeshParts come from AssetService:CreateMeshPartAsync (cached per MeshId).
local MAP_ID = "Warehouse" --@MAP
local PAYLOAD = [==[{}]==] --@PAYLOAD
local HS = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local data = HS:JSONDecode(PAYLOAD)

local SS = game:GetService("ServerStorage")
local src = SS:FindFirstChild("_DuelSource") or Instance.new("Folder")
src.Name = "_DuelSource"; src.Parent = SS
local root = src:FindFirstChild(MAP_ID) or Instance.new("Folder")
root.Name = MAP_ID; root.Parent = src

local function dec(v)
	if type(v) ~= "table" then return v end
	local t, a = v.t, v.v
	if t == "CF" then return CFrame.new(table.unpack(a)) end
	if t == "V3" then return Vector3.new(a[1], a[2], a[3]) end
	if t == "V2" then return Vector2.new(a[1], a[2]) end
	if t == "C3" then return Color3.new(a[1], a[2], a[3]) end
	if t == "U2" then return UDim2.new(a[1], a[2], a[3], a[4]) end
	if t == "E" then return (Enum :: any)[v.e][v.n] end
	if t == "F" then return Font.new(v.f, Enum.FontWeight[v.w], Enum.FontStyle[v.s]) end
	return nil
end

local byIdx = {}
for _, d in root:GetDescendants() do
	local i = d:GetAttribute("_PortIdx")
	if i then byIdx[i] = d end
end

-- material variants (once)
local MS = game:GetService("MaterialService")
local mvFolder = MS:FindFirstChild("DuelMaps_" .. MAP_ID) or Instance.new("Folder")
mvFolder.Name = "DuelMaps_" .. MAP_ID; mvFolder.Parent = MS
for name, mv in data.matvars or {} do
	if not mvFolder:FindFirstChild(name) then
		local v = Instance.new("MaterialVariant")
		v.Name = name
		v.BaseMaterial = dec(mv.BaseMaterial)
		v.ColorMap = mv.ColorMap; v.NormalMap = mv.NormalMap; v.RoughnessMap = mv.RoughnessMap; v.MetalnessMap = mv.MetalnessMap
		v.StudsPerTile = mv.StudsPerTile
		v.Parent = mvFolder
	end
end

local meshCache = {}
local made, fails = 0, {}
local SKIP_SET = { MeshId = true, CollisionFidelity = true, RenderFidelity = true }
for _, node in data.nodes do
	if byIdx[node.i] then continue end
	local inst
	if node.c == "MeshPart" then
		local id = node.props.MeshId
		local cf = dec(node.props.CollisionFidelity) or Enum.CollisionFidelity.Default
		local rf = dec(node.props.RenderFidelity) or Enum.RenderFidelity.Automatic
		local key = tostring(id) .. "|" .. cf.Name .. "|" .. rf.Name
		local base = meshCache[key]
		if not base then
			local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, id, { CollisionFidelity = cf, RenderFidelity = rf })
			if ok then base = mp; meshCache[key] = mp else table.insert(fails, node.n .. ": " .. tostring(mp)) end
		end
		inst = base and base:Clone() or Instance.new("Part")
		if not base then inst:SetAttribute("_PortMeshMissing", id) end
	else
		local ok, o = pcall(Instance.new, node.c)
		inst = ok and o or Instance.new("Folder")
	end
	inst.Name = node.n
	for k, v in node.props do
		if not SKIP_SET[k] then
			local ok, err = pcall(function() (inst :: any)[k] = dec(v) end)
			if not ok and k ~= "TextureID" and k ~= "DoubleSided" then table.insert(fails, node.n .. "." .. k .. ": " .. tostring(err):sub(1, 80)) end
		end
	end
	for k, v in node.attrs do pcall(inst.SetAttribute, inst, k, dec(v)) end
	for _, t in node.tags do inst:AddTag(t) end
	inst:SetAttribute("_PortIdx", node.i)
	byIdx[node.i] = inst
	inst.Parent = node.p == 0 and root or byIdx[node.p] or root
	made += 1
end
return "made " .. made .. " fails " .. #fails .. "\n" .. table.concat(fails, "\n", 1, math.min(#fails, 25))
