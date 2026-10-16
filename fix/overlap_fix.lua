--[[ fix/overlap_fix.lua : overlap sweep (Edward 2026-10-15: "a lot of overlap on the walls in certain rooms").
Tacticals_rebuild.rbxl (LOCAL copy) only. Runs after place_hub1, hub2, place_rooms2, place_rooms3, place_showroom. Never touches Training.
Idempotent (every move is computed from the original CFrame/Size kept in attributes Overlap_OrigCF / Overlap_OrigSize).
UNDO = true puts everything back. Runner: python tools/run_luau.py fix/overlap_fix.lua [UNDO]. Report: notes/overlap_fix.md.
Fix table generated offline from the kit generators' primitives (tools/*_kit.py re-run without Blender; coplanar same-facing faces
within 0.025 that are visible from a room volume). Each entry: mesh, axis (1 x, 2 y, 3 z), anchor, scale k, translate t:
new face coordinate = anchor + (old - anchor) * k + t. Moves are <= 0.07 studs.
]]
local UNDO = false --@UNDO
local LM = workspace:WaitForChild("LobbyMap")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end

local FIX = {
	{"H_DuelsDoor__band_olive", 1, -90.0000, 0.9860000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_DuelsDoor__trim_metal", 1, -90.0000, 0.9860000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_DuelsDoor__wall_light", 1, -90.0000, 0.9860000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__band_olive", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__trim_metal", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__wall_body", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__wall_dark", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__wall_kick", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__wall_light", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_WallW__wall_upper", 1, -90.0000, 0.9920000, 0.000}, -- hub W wall back face z-fought the Duels east cladding at x -95
	{"H_TunnelPortal__wall_light", 3, 0.0000, 0.9963636, 0.000}, -- coplanar with its wall on the opening side
	{"H_TunnelPortal__band_olive", 3, 0.0000, 0.9936364, 0.000}, -- coplanar with its wall on the opening side
	{"H_TunnelPortal__trim_metal", 3, 0.0000, 0.9936364, 0.000}, -- coplanar with its wall on the opening side
	{"H_GateN__band_olive", 1, 0.0000, 0.9929825, 0.000}, -- coplanar with its wall on the opening side
	{"H_GateS__band_olive", 1, 0.0000, 0.9929825, 0.000}, -- coplanar with its wall on the opening side
	{"H_DuelsDoor__band_olive", 3, 0.0000, 0.9931034, 0.000}, -- coplanar with its wall on the opening side
	{"S_Door__band_olive", 1, 0.0000, 1.0040816, 0.000}, -- decor flush with its wall ends: grown to stand proud
	{"A_Door__band_olive", 1, 0.0000, 1.0040816, 0.000}, -- decor flush with its wall ends: grown to stand proud
	{"SR_Backdrop__band_olive", 1, 0.0000, 1.0029851, 0.000}, -- decor flush with its wall ends: grown to stand proud
	{"D_Door__band_olive", 3, 0.0000, 0.9927273, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"D_Door__trim_metal", 3, 0.0000, 0.9872727, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"D_West__band_olive", 3, 0.0000, 0.9911111, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"D_West__trim_metal", 3, 0.0000, 0.9844444, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"D_West__band_olive", 1, 0.0000, 1.0000000, -0.030}, -- Pass-side face flush with wall
	{"D_West__trim_metal", 1, 0.0000, 1.0000000, -0.060}, -- Pass-side face flush with wall/band
	{"D_Pass__band_olive", 3, 0.0000, 0.9911111, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"E_Portal__band_olive", 3, 0.0000, 0.9963636, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"E_Portal__trim_metal", 3, 0.0000, 0.9936364, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"E_Portal__trim_metal", 1, 0.0000, 1.0000000, -0.040}, -- flush with band at x 105
	{"H_Tunnel__band_olive", 3, 0.0000, 0.9936364, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"H_Tunnel__door_leaf", 3, 0.0000, 0.9964286, 0.000}, -- decor flush with its wall: inner face moved into the opening
	{"H_BaysN__door_leaf", 3, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"H_BaysS__door_leaf", 3, 0.0000, 1.0000000, 0.040}, -- coplanar face offset
	{"H_BaysN__label_cream", 3, 0.0000, 1.0000000, -0.030}, -- coplanar face offset
	{"H_BaysS__label_cream", 3, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"H_Catwalks__trim_metal", 2, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"H_Catwalks__beam_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"H_Skylight__neon_olive", 2, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"D_Lines__neon_cream", 2, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"D_Lines__neon_olive", 2, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"D_Base__wall_dark", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"E_Mouth__wall_light", 2, 0.0000, 1.0000000, 0.040}, -- coplanar face offset
	{"E_Mouth__band_olive", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"S_Displays__trim_metal", 2, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"H_GateN__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"H_GateS__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"S_Door__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"A_Door__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"D_Door__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"E_Portal__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"D_Pass__band_olive", 2, 0.0000, 1.0000000, -0.040}, -- coplanar face offset
	{"H_Stairs__trim_metal", 2, 0.0000, 1.0000000, 0.030}, -- coplanar face offset
	{"E_Lines__neon_cream", 2, 0.0000, 1.0000000, 0.020}, -- coplanar face offset
	{"H_DuelsDoor__trim_metal", 3, 0.0000, 0.9872727, 0.000}, -- doorway jamb z +-5.5: trim, hub wall band and wall body coplanar
	{"H_WallW__band_olive", 3, 0.0000, 0.9945455, 0.000}, -- doorway jamb z +-5.5 (band 0.03 proud of the wall body)
	-- lap1 (notes/lap1.md, Play-mode coplanar ray sweep tools/lap_zscan.lua):
	{"H_DuelsDoor__trim_metal", 2, 0.0000, 1.0000000, -0.040}, -- lintel soffit y 24.000 coplanar with H_WallW__wall_body soffit (718 px)
	{"D_Lines__neon_cream", 2, 0.0000, 1.0000000, 0.030}, -- 2nd +0.03: cream vs olive lines 0.001 apart, cream vs D_Pads plate tops
	{"SR_Stage__dark_metal", 3, 0.0000, 1.0000000, 0.030}, -- stage front z 5.55 coplanar with the SR_Signs label plate (Kit-menu frame)
}
-- old geometry still visible: Props.Rotor (two old wall fans, now buried in the hub E wall face x 88) -> hidden;
-- FX.FX3 Beacon x4 in the Duels hall (z +-43.2, 1.8 off the new wall face z +-45) -> float 1.8 off the new wall, piers stand there: hidden + untagged (LobbyFX drives their Transparency by tag)

local KITS = {LM:FindFirstChild("Hub1"), LM:FindFirstChild("Rooms2"), LM:FindFirstChild("Rooms3")}
local sr = LM:FindFirstChild("Showroom"); if sr and sr:FindFirstChild("Rooms4") then table.insert(KITS, sr.Rooms4) end
local byName = {}
for _, k in KITS do for _, d in k:GetDescendants() do if d:IsA("MeshPart") then byName[d.Name] = d end end end

local function hideOne(inst)
	if inst:GetAttribute("OverlapHidden") then return 0 end
	if inst:IsA("BasePart") then
		inst:SetAttribute("Overlap_T", inst.Transparency); inst:SetAttribute("Overlap_C", inst.CanCollide)
		inst:SetAttribute("Overlap_Q", inst.CanQuery); inst:SetAttribute("Overlap_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
	elseif inst:IsA("Decal") then inst:SetAttribute("Overlap_T", inst.Transparency); inst.Transparency = 1
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("SurfaceGui") then
		inst:SetAttribute("Overlap_E", inst.Enabled); inst.Enabled = false
	else return 0 end
	inst:SetAttribute("OverlapHidden", true); return 1
end
local function unhideOne(inst)
	if not inst:GetAttribute("OverlapHidden") then return 0 end
	if inst:IsA("BasePart") then
		inst.Transparency = inst:GetAttribute("Overlap_T"); inst.CanCollide = inst:GetAttribute("Overlap_C")
		inst.CanQuery = inst:GetAttribute("Overlap_Q"); inst.CanTouch = inst:GetAttribute("Overlap_Tc")
	elseif inst:IsA("Decal") then inst.Transparency = inst:GetAttribute("Overlap_T")
	else inst.Enabled = inst:GetAttribute("Overlap_E") end
	for _, a in {"OverlapHidden", "Overlap_T", "Overlap_C", "Overlap_Q", "Overlap_Tc", "Overlap_E"} do inst:SetAttribute(a, nil) end
	return 1
end

if UNDO then
	local n, h = 0, 0
	for _, d in LM:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Overlap_OrigCF") then
			d.CFrame = d:GetAttribute("Overlap_OrigCF"); if d:GetAttribute("Overlap_OrigSize") then d.Size = d:GetAttribute("Overlap_OrigSize") end
			d:SetAttribute("Overlap_OrigCF", nil); d:SetAttribute("Overlap_OrigSize", nil); n += 1
		end
		if d:GetAttribute("Overlap_Tags") then for _, t in string.split(d:GetAttribute("Overlap_Tags"), ",") do game:GetService("CollectionService"):AddTag(d, t) end; d:SetAttribute("Overlap_Tags", nil) end
		h += unhideOne(d)
	end
	say("UNDO: restored", n, "parts, unhidden", h)
	return table.concat(log, "\n")
end

-- 1. kit nudges
local per = {}
for _, f in FIX do per[f[1]] = per[f[1]] or {}; table.insert(per[f[1]], f) end
local moved, missing = 0, {}
for name, list in per do
	local p = byName[name]
	if not p then table.insert(missing, name); continue end
	if p:GetAttribute("Overlap_OrigCF") == nil then p:SetAttribute("Overlap_OrigCF", p.CFrame); p:SetAttribute("Overlap_OrigSize", p.Size) end
	local cf0, s0 = p:GetAttribute("Overlap_OrigCF"), p:GetAttribute("Overlap_OrigSize")
	local lo = {cf0.X - s0.X / 2, cf0.Y - s0.Y / 2, cf0.Z - s0.Z / 2}
	local hi = {cf0.X + s0.X / 2, cf0.Y + s0.Y / 2, cf0.Z + s0.Z / 2}
	for _, f in list do
		local ax, anc, k, t = f[2], f[3], f[4], f[5]
		local a, b = anc + (lo[ax] - anc) * k + t, anc + (hi[ax] - anc) * k + t
		lo[ax], hi[ax] = math.min(a, b), math.max(a, b)
	end
	p.Size = Vector3.new(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
	p.CFrame = cf0.Rotation + Vector3.new((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
	moved += 1
end
say("kit meshes nudged", moved, #missing > 0 and ("MISSING " .. table.concat(missing, ",")) or "")

-- 2. old geometry
local rot = LM.Props:FindFirstChild("Rotor")
if rot then local n = 0; for _, d in rot:GetDescendants() do n += hideOne(d) end; for _, d in LM.Props:GetChildren() do if d.Name == "Rotor" and d ~= rot then for _, e in d:GetDescendants() do n += hideOne(e) end end end; say("Props.Rotor hidden", n) end
local CS = game:GetService("CollectionService")
local fx3 = LM.FX:FindFirstChild("FX3")
if fx3 then
	local n = 0
	for _, b in fx3:GetChildren() do
		if b.Name == "Beacon" and b:IsA("BasePart") and b.Position.X < -95 then
			-- a first version moved them onto the wall face (they then cut into D_Piers): put back, then hide + untag
			if b:GetAttribute("Overlap_OrigCF") then b.CFrame = b:GetAttribute("Overlap_OrigCF"); b:SetAttribute("Overlap_OrigCF", nil) end
			if not b:GetAttribute("OverlapHidden") then
				if CS:HasTag(b, "LobbyBeacon") then CS:RemoveTag(b, "LobbyBeacon"); b:SetAttribute("Overlap_Tags", "LobbyBeacon") end
				for _, d in b:GetDescendants() do n += hideOne(d) end
				n += hideOne(b)
			end
		end
	end
	say("Duels FX3 beacons hidden (LobbyBeacon untagged)", n)
end
return table.concat(log, "\n")
