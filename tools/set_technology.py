"""Set Lighting.Technology (and optionally PrioritizeLightingQuality) in OUR OWN saved place file, offline.
Scripts cannot read or set Technology, and the Properties panel may hide it, so this patches the .rbxl directly.
Only for our own practice places (never the reference). Close the place in Studio first, then reopen it.
Usage: python tools/set_technology.py <place.rbxl> <tech: 0 Legacy,1 Voxel,2 Compat,3 ShadowMap,4 Future> [plq 0|1] [pylib]"""
import sys, struct, shutil
path, tech = sys.argv[1], int(sys.argv[2])
plq = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] in ("0", "1") else None
if len(sys.argv) > 4: sys.path.insert(0, sys.argv[4])
import lz4.block, zstandard
assert "Downloads" not in path, "never patch a reference place"
data = open(path, "rb").read(); zd = zstandard.ZstdDecompressor(); chunks = []; pos = 32
while pos < len(data):
    name = data[pos:pos + 4]; clen, ulen = struct.unpack_from("<II", data, pos + 4); pos += 16
    if clen == 0: raw = data[pos:pos + ulen]; pos += ulen
    else:
        c = data[pos:pos + clen]; pos += clen
        raw = zd.decompress(c, max_output_size=ulen) if c[:4] == b"\x28\xb5\x2f\xfd" else lz4.block.decompress(c, uncompressed_size=ulen)
    chunks.append([name, raw])
    if name == b"END\x00": break
def rs(b, o):
    n = struct.unpack_from("<I", b, o)[0]; return b[o + 4:o + 4 + n], o + 4 + n
classes = {}; done = []
for ch in chunks:
    name, raw = ch
    if name == b"INST":
        cid = struct.unpack_from("<I", raw, 0)[0]; cn, o = rs(raw, 4); classes[cid] = cn
    elif name == b"PROP":
        cid = struct.unpack_from("<I", raw, 0)[0]; pn, o = rs(raw, 4)
        if classes.get(cid) != b"Lighting": continue
        if pn == b"Technology" and raw[o] == 18:
            ch[1] = raw[:o + 1] + struct.pack(">I", tech) + raw[o + 5:]; done.append(f"Technology={tech}")
        if pn == b"PrioritizeLightingQuality" and raw[o] == 2 and plq is not None:
            ch[1] = raw[:o + 1] + bytes([plq]) + raw[o + 2:]; done.append(f"PrioritizeLightingQuality={plq}")
shutil.copy(path, path + ".bak")
with open(path, "wb") as f:
    f.write(data[:32])
    for name, raw in chunks: f.write(name + struct.pack("<III", 0, len(raw), 0) + raw)
print("patched", done, "(backup .bak)")
