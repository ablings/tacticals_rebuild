"""Copy ServerStorage.HouseKit (the modeler's imported meshes, uploaded under the group) from one Studio to another through the MCP
bridge: SerializationService bytes, base64 in 90,000-char slices (the bridge caps a result at 100 KB; HttpService is off in the
match places). Same method as tools/pseudolobby_build.py and port 44's Warehouse2Kit copy.
    python tools/house_kit_copy.py <src_studio_id> <dst_studio_id>
The destination's old HouseKit (if any) is moved to ServerStorage._HouseKit_Backup. Prints a fingerprint of both sides
(MeshParts, SurfaceAppearances, sorted MeshIds / texture ids hashed): they must match."""
import base64, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import house_mcp  # noqa: E402

FP = r'''
local k = game.ServerStorage:FindFirstChild("HouseKit")
if not k then return "{}" end
local ids, nm, ns, n = {}, 0, 0, 0
for _, d in k:GetDescendants() do
	n += 1
	if d:IsA("MeshPart") then nm += 1; table.insert(ids, d.MeshId .. "|" .. d.TextureID .. "|" .. d:GetFullName():sub(20)) end
	if d:IsA("SurfaceAppearance") then ns += 1; table.insert(ids, d.ColorMap .. d.NormalMap .. d.RoughnessMap .. d.MetalnessMap) end
end
table.sort(ids)
local s = table.concat(ids, ";")
local h = 0
for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 2147483647 end
return game:GetService("HttpService"):JSONEncode({ instances = n, meshparts = nm, sa = ns, hash = h, models = #k:GetChildren() })'''

EXPORT = r'''
local HS = game:GetService("HttpService")
local SS = game:GetService("SerializationService")
local k = game.ServerStorage:FindFirstChild("HouseKit")
assert(k, "no ServerStorage.HouseKit in the source")
local raw = buffer.tostring(SS:SerializeInstancesAsync({ k }))
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local t = {}
for i = 1, #raw, 3 do
	local a, b, c = string.byte(raw, i, i + 2)
	local v = a * 65536 + (b or 0) * 256 + (c or 0)
	local q = { bit32.extract(v, 18, 6), bit32.extract(v, 12, 6), bit32.extract(v, 6, 6), bit32.extract(v, 0, 6) }
	t[#t + 1] = A:sub(q[1] + 1, q[1] + 1) .. A:sub(q[2] + 1, q[2] + 1) .. (b and A:sub(q[3] + 1, q[3] + 1) or "=") .. (c and A:sub(q[4] + 1, q[4] + 1) or "=")
end
shared.__HouseKitB64 = table.concat(t)
return HS:JSONEncode({ len = #shared.__HouseKitB64, bytes = #raw })'''

IMPORT = r'''
local SS = game:GetService("SerializationService")
local b64 = table.concat(shared.__HouseKitIn or {})
shared.__HouseKitIn = nil
local D = {}
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, 64 do D[string.byte(A, i)] = i - 1 end
local out = {}
for i = 1, #b64, 4 do
	local c1, c2, c3, c4 = string.byte(b64, i, i + 3)
	local v = D[c1] * 262144 + D[c2] * 4096 + (D[c3] or 0) * 64 + (D[c4] or 0)
	out[#out + 1] = string.char(bit32.extract(v, 16, 8))
	if c3 ~= 61 then out[#out + 1] = string.char(bit32.extract(v, 8, 8)) end
	if c4 ~= 61 then out[#out + 1] = string.char(bit32.extract(v, 0, 8)) end
end
local raw = table.concat(out)
assert(#raw == %d, "size " .. #raw)
local list = SS:DeserializeInstancesAsync(buffer.fromstring(raw))
local old = game.ServerStorage:FindFirstChild("HouseKit")
if old then
	local bk = game.ServerStorage:FindFirstChild("_HouseKit_Backup") or Instance.new("Folder")
	bk.Name = "_HouseKit_Backup"; bk.Parent = game.ServerStorage
	old.Name = "HouseKit_" .. os.time(); old.Parent = bk
end
for _, inst in list do inst.Parent = game.ServerStorage end
return "imported " .. #list .. " root(s)"'''


def lua(sid, code):
    return house_mcp.raw_call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": code}).strip()


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    fp_src = json.loads(lua(src, FP))
    d = json.loads(lua(src, EXPORT))
    CHUNK = 90000
    parts = []
    for i in range(0, d["len"], CHUNK):
        part = lua(src, f"return string.sub(shared.__HouseKitB64, {i + 1}, {i + CHUNK})")
        assert len(part) == min(CHUNK, d["len"] - i), f"slice {i}: got {len(part)}"
        parts.append(part)
    lua(src, "shared.__HouseKitB64 = nil return 1")
    b64 = "".join(parts)
    assert len(base64.b64decode(b64)) == d["bytes"], "base64 mismatch"
    lua(dst, "shared.__HouseKitIn = {} return 1")
    for i in range(0, len(b64), CHUNK):
        r = lua(dst, 'table.insert(shared.__HouseKitIn, "' + b64[i:i + CHUNK] + '") return #shared.__HouseKitIn')
        assert r.strip().isdigit(), r[:300]
    print(lua(dst, IMPORT % d["bytes"]))
    fp_dst = json.loads(lua(dst, FP))
    print("source", fp_src)
    print("dest  ", fp_dst)
    print("MATCH" if fp_src == fp_dst else "MISMATCH")
    sys.exit(0 if fp_src == fp_dst else 1)
