"""Build fix/guns_v2.lua [GUNSV2]: the remodelled guns (art/anim/guns/DONE.md + art/guns/manifest/<Gun>.json) into their Tools.
Usage: python -I tools/guns_v2_build.py [--standin] [Gun ...]
  default guns: every gun in DONE.md whose every part has a mesh id. --standin: build EVERY manifest gun with plain Parts the size of
  each mesh's box (tests the rig, attachments, wraps and animations before the meshes are uploaded; never ship a standin build).
The generated Lua (Edit mode, python tools/run_luau_at.py <studio> fix/guns_v2.lua [UNDO]):
  * keeps the old Tool's visual parts in ServerStorage._GunsV1.<Tool> (UNDO puts them back), and the Tool itself (name, attributes,
    Grip, Handle sounds, scripts) in place: the code finds it as before
  * Handle = invisible 0.2 x 0.6 x 0.3 root at the grip (WrapSkip); one MeshPart per manifest part (AssetService:CreateMeshPartAsync)
    at its box centre, colour / material / WrapChannel (A / B; glass = WrapSkip); no collision, no queries, no touch, massless
  * moving parts hang off their parent part by a Motor6D named after the part (pivot = the manifest's); static parts are welded
  * attachments from DONE.md (Muzzle, Grip, ShellEject, Mag, ...); the old Muzzle's light and emitters move to the new Muzzle.
    DualPistols: the code reads Barrel.Muzzle and LeftBarrel.Muzzle, so its two muzzles are put on those parts under that name
Idempotent (Tool attribute GunsV2 = the build stamp; same stamp = nothing to do)."""
import json, os, re, sys, hashlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DONE = os.path.join(ROOT, "art/anim/guns/DONE.md")
MAN = os.path.join(ROOT, "art/guns/manifest")


def parse_done():
    guns, cur = {}, None
    for line in open(DONE, encoding="utf-8"):
        m = re.match(r"^### (\w+)", line)
        if m:
            cur = guns.setdefault(m.group(1), {"ids": {}, "att": []})
            continue
        if not cur: continue
        if line.startswith("| ") and not line.startswith("| Part") and not line.startswith("|---"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 7:
                mid = re.search(r"(\d{6,})", cells[6])
                cur["ids"][cells[0]] = ("rbxassetid://" + mid.group(1)) if mid else ""
        if line.startswith("Attachments:"):
            for name, part, x, y, z in re.findall(r"`(\w+)` on (\w+) at \(([-\d.]+), ([-\d.]+), ([-\d.]+)\)", line):
                cur["att"].append((name, part, float(x), float(y), float(z)))
    return guns


def lua_v3(v): return f"Vector3.new({v[0]}, {v[1]}, {v[2]})"


def gun_lua(gun, done, standin):
    man = json.load(open(os.path.join(MAN, gun + ".json"), encoding="utf-8"))
    parts = []
    for p in man["parts"]:
        mid = done["ids"].get(p["name"], "")
        moving = not str(p.get("motion", "static")).startswith("static")
        glass = p.get("wrap") == "skip" or p.get("material") == "Glass"
        parts.append("\t\t{ name = %s, parent = %s, mesh = %s, pivot = %s, centre = %s, size = %s, colour = Color3.fromRGB(%d, %d, %d), material = %s, wrap = %s, moving = %s, glass = %s },\n" % (
            json.dumps(p["name"]), json.dumps(p["motor_part0"]), json.dumps("" if standin else mid), lua_v3(p["pivot"]), lua_v3(p["bbox_centre"]),
            lua_v3(p["size"]), *p["colour"], json.dumps(p.get("material", "SmoothPlastic")), json.dumps(p.get("wrap", "A")),
            "true" if moving else "false", "true" if glass else "false"))
    att = []
    for name, part, x, y, z in done["att"]:
        if gun == "DualPistols" and name == "Muzzle": part = "Barrel"
        if gun == "DualPistols" and name == "LeftMuzzle": part, name = "LeftBarrel", "Muzzle"
        att.append(f"\t\t{{ name = {json.dumps(name)}, part = {json.dumps(part)}, pos = Vector3.new({x}, {y}, {z}) }},\n")
    return f"\t[{json.dumps(gun)}] = {{\n\thandle = {lua_v3(man['handle']['size'])},\n\tparts = {{\n{''.join(parts)}\t}},\n\tattachments = {{\n{''.join(att)}\t}},\n\t}},\n"


BODY = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local AssetService = game:GetService("AssetService")
local Weapons = RS.Repository.Weapons
local res = {}

local backup = SS:FindFirstChild("_GunsV1")
if not backup and not UNDO then
	backup = Instance.new("Folder")
	backup.Name = "_GunsV1"
	backup:SetAttribute("Readme", "[GUNSV2] the old gun models' visual parts (fix/guns_v2.lua UNDO puts them back)")
	backup.Parent = SS
end

local function visualChildren(tool: Tool)
	local list = {}
	for _, c in tool:GetChildren() do
		if c:IsA("BasePart") and c.Name ~= "Handle" then table.insert(list, c) end
	end
	return list
end

local function undoGun(tool: Tool)
	local saved = backup and backup:FindFirstChild(tool.Name)
	if not saved then return "no backup" end
	local handle = tool:FindFirstChild("Handle")
	-- the muzzle flash set leaves the new muzzle FIRST (destroying the part would destroy it); copies on a second muzzle go
	local muzzleKids, first = {}, nil
	for _, m in tool:GetDescendants() do
		if m:IsA("Attachment") and m.Name == "Muzzle" and m:FindFirstAncestorWhichIsA("BasePart"):GetAttribute("GunsV2Part") then
			if not first then
				first = m
				for _, k in m:GetChildren() do k.Parent = nil table.insert(muzzleKids, k) end
			end
		end
	end
	for _, c in tool:GetChildren() do
		if c:IsA("BasePart") and c:GetAttribute("GunsV2Part") then c:Destroy() end
	end
	for _, a in (handle and handle:GetChildren() or {}) do
		if a:IsA("Attachment") or a:IsA("Motor6D") or a:IsA("WeldConstraint") then a:Destroy() end
	end
	local oldHandle = saved:FindFirstChild("HandleLook")
	if handle and oldHandle then
		handle.Size = oldHandle:GetAttribute("Size")
		handle.Transparency = oldHandle:GetAttribute("Transparency")
		handle.Color = oldHandle:GetAttribute("Color")
		handle:SetAttribute("WrapSkip", nil)
		handle:SetAttribute("WrapChannel", oldHandle:GetAttribute("WrapChannel"))
		oldHandle:Destroy()
	end
	for _, c in saved:GetChildren() do
		c.Parent = (c:IsA("Attachment") and handle) or tool
	end
	for _, m in tool:GetDescendants() do
		if m:IsA("Attachment") and m.Name == "Muzzle" and #m:GetChildren() == 0 then
			for _, k in muzzleKids do k.Parent = m end
			break
		end
	end
	saved:Destroy()
	tool:SetAttribute("GunsV2", nil)
	return "restored"
end

local function buildGun(tool: Tool, spec)
	local handle = tool:FindFirstChild("Handle") :: BasePart
	assert(handle, tool.Name .. " has no Handle")
	-- pass 1: every mesh first (nothing changed if one fails)
	local made = {}
	for _, p in spec.parts do
		local part
		if p.mesh ~= "" then
			local ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(p.mesh)) end)
			assert(ok and mp, tool.Name .. "." .. p.name .. ": mesh " .. p.mesh .. " did not load: " .. tostring(mp))
			part = mp
		else
			part = Instance.new("Part")
			part:SetAttribute("GunsV2Standin", true)
		end
		part.Name = p.name
		part.Size = p.size
		made[p.name] = { part = part, spec = p }
	end
	-- the old look goes to the backup
	local saved = Instance.new("Folder")
	saved.Name = tool.Name
	local muzzleKids = {}
	for _, m in tool:GetDescendants() do
		if m:IsA("Attachment") and m.Name == "Muzzle" then
			for _, k in m:GetChildren() do table.insert(muzzleKids, k) end
			break -- one flash set; a second muzzle gets copies (the old second set stays with the old parts in the backup)
		end
	end
	local look = Instance.new("Configuration")
	look.Name = "HandleLook"
	look:SetAttribute("Size", handle.Size)
	look:SetAttribute("Transparency", handle.Transparency)
	look:SetAttribute("Color", handle.Color)
	look:SetAttribute("WrapChannel", handle:GetAttribute("WrapChannel"))
	look.Parent = saved
	for _, k in muzzleKids do k.Parent = nil end
	for _, c in visualChildren(tool) do c.Parent = saved end
	for _, a in handle:GetChildren() do
		if a:IsA("Attachment") then a.Parent = saved end
	end
	saved.Parent = backup
	-- the new rig
	handle.Size = spec.handle
	handle.Transparency = 1
	handle:SetAttribute("WrapSkip", true)
	handle:SetAttribute("WrapChannel", nil)
	local hcf = handle.CFrame
	for _, p in spec.parts do
		local part = made[p.name].part
		part.CFrame = hcf * CFrame.new(p.centre)
		part.Color = p.colour
		local okM, mat = pcall(function() return Enum.Material[p.material] end)
		part.Material = okM and mat or Enum.Material.SmoothPlastic
		if p.glass then part.Transparency = 0.35 part:SetAttribute("WrapSkip", true) else part:SetAttribute("WrapChannel", p.wrap == "B" and "B" or "A") end
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		part:SetAttribute("GunsV2Part", true)
		part.Parent = tool
	end
	for _, p in spec.parts do
		local part = made[p.name].part
		local p0 = p.parent == "Handle" and handle or (made[p.parent] and made[p.parent].part)
		assert(p0, tool.Name .. "." .. p.name .. ": parent " .. p.parent .. " missing")
		if p.moving then
			local pivot = hcf * CFrame.new(p.pivot)
			local m = Instance.new("Motor6D")
			m.Name = p.name
			m.Part0, m.Part1 = p0, part
			m.C0 = p0.CFrame:ToObjectSpace(pivot)
			m.C1 = part.CFrame:ToObjectSpace(pivot)
			m.Parent = p0
		else
			local w = Instance.new("WeldConstraint")
			w.Name = "GunsV2Weld"
			w.Part0, w.Part1 = p0, part
			w.Parent = part
		end
	end
	local muzzle
	for _, a in spec.attachments do
		local host = a.part == "Handle" and handle or (made[a.part] and made[a.part].part)
		if host then
			local at = Instance.new("Attachment")
			at.Name = a.name
			at.Parent = host
			at.CFrame = host.CFrame:ToObjectSpace(hcf * CFrame.new(a.pos))
			if a.name == "Muzzle" and not muzzle then muzzle = at end
		end
	end
	-- the muzzle flash light and emitters ride the new muzzle(s): the first old set to the first, copies to any second
	local muzzles = {}
	for _, d in tool:GetDescendants() do if d:IsA("Attachment") and d.Name == "Muzzle" then table.insert(muzzles, d) end end
	for i, mz in muzzles do
		for _, k in muzzleKids do
			if i == 1 then k.Parent = mz elseif not mz:FindFirstChild(k.Name) then k:Clone().Parent = mz end
		end
	end
	tool:SetAttribute("GunsV2", STAMP)
	local n = 0 for _ in made do n += 1 end
	return n .. " parts, " .. #muzzles .. " muzzle(s)"
end

for gun, spec in GUNS do
	local tool = Weapons:FindFirstChild(gun)
	if not tool then
		table.insert(res, gun .. " n/a")
	elseif UNDO then
		table.insert(res, gun .. " " .. (tool:GetAttribute("GunsV2") and undoGun(tool) or "="))
	elseif tool:GetAttribute("GunsV2") == STAMP then
		table.insert(res, gun .. " =")
	else
		if tool:GetAttribute("GunsV2") then undoGun(tool) end -- an older build: back to the old look, then the new one
		table.insert(res, gun .. " + " .. buildGun(tool, spec))
	end
end
if UNDO and backup and #backup:GetChildren() == 0 then backup:Destroy() end
return (UNDO and "UNDO " or "") .. "GUNSV2 " .. STAMP .. ": " .. table.concat(res, " | ")
'''


def main():
    args = sys.argv[1:]
    standin = "--standin" in args
    want = [a for a in args if not a.startswith("--")]
    done = parse_done()
    guns = []
    for g, d in done.items():
        if want and g not in want: continue
        if not os.path.exists(os.path.join(MAN, g + ".json")): continue
        man = json.load(open(os.path.join(MAN, g + ".json"), encoding="utf-8"))
        ready = all(d["ids"].get(p["name"]) for p in man["parts"])
        if standin or ready: guns.append(g)
        else: print(f"{g}: mesh ids missing ({sum(1 for p in man['parts'] if not d['ids'].get(p['name']))} parts) - skipped")
    body = "".join(gun_lua(g, done[g], standin) for g in guns)
    stamp = ("standin-" if standin else "") + hashlib.sha1(body.encode()).hexdigest()[:10]
    head = ("-- fix/guns_v2.lua [GUNSV2] (GENERATED by tools/guns_v2_build.py from art/anim/guns/DONE.md + art/guns/manifest; never hand-edit)\n"
            "-- " + ("STANDIN BUILD (plain Parts, tests only: never ship)" if standin else "the remodelled guns with their uploaded meshes") + "\n"
            "local UNDO = false --@UNDO\n" f"local STAMP = {json.dumps(stamp)}\n" "local GUNS = {\n")
    out = os.path.join(ROOT, "fix/guns_v2_standin.lua" if standin else "fix/guns_v2.lua")
    open(out, "w", encoding="utf-8", newline="\n").write(head + body + "}\n" + BODY)
    print(f"wrote {os.path.relpath(out, ROOT)}: {', '.join(guns) or 'no guns'} (stamp {stamp})")


if __name__ == "__main__":
    main()
