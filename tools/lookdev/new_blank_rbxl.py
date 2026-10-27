"""Write a NEW blank binary place file (.rbxl): Workspace + Lighting only; Studio adds the other services on open.
Lighting.Technology / LightingStyle / PrioritizeLightingQuality are written here because scripts can't set Technology.
Usage: python -I tools/lookdev/new_blank_rbxl.py <out.rbxl> [technology 0-4, default 3 ShadowMap] [lightingStyle 0 Realistic|1 Soft]
Refuses to overwrite an existing file."""
import os, struct, sys

out = sys.argv[1]
tech = int(sys.argv[2]) if len(sys.argv) > 2 else 3
style = int(sys.argv[3]) if len(sys.argv) > 3 else 0
assert not os.path.exists(out), "refusing to overwrite " + out


def s(b):
    b = b.encode() if isinstance(b, str) else b
    return struct.pack("<I", len(b)) + b


def zig(v):
    return ((v << 1) ^ (v >> 31)) & 0xFFFFFFFF


def inter(words):  # big-endian u32 words, byte-interleaved
    bs = [struct.pack(">I", w & 0xFFFFFFFF) for w in words]
    return bytes(bs[i][j] for j in range(4) for i in range(len(bs)))


def refs(rs):
    out, prev = [], 0
    for r in rs:
        out.append(zig(r - prev)); prev = r
    return inter(out)


def chunk(name, body):
    return name + struct.pack("<III", 0, len(body), 0) + body


# class id, class name, referent, props [(name, type, payload)]
insts = [
    (0, "Workspace", 0, [("Name", 1, s("Workspace"))]),
    (1, "Lighting", 1, [("Name", 1, s("Lighting")),
                        ("Technology", 0x12, inter([tech])),
                        ("LightingStyle", 0x12, inter([style])),
                        ("PrioritizeLightingQuality", 2, b"\x01")]),
]
body = b""
for cid, cn, ref, _ in insts:
    body += chunk(b"INST", struct.pack("<I", cid) + s(cn) + b"\x00" + struct.pack("<I", 1) + refs([ref]))
for cid, cn, ref, props in insts:
    for pn, t, payload in props:
        body += chunk(b"PROP", struct.pack("<I", cid) + s(pn) + bytes([t]) + payload)
n = len(insts)
body += chunk(b"PRNT", b"\x00" + struct.pack("<I", n) + refs([i[2] for i in insts]) + refs([-1] * n))
body += chunk(b"END\x00", b"</roblox>")
header = b"<roblox!\x89\xff\x0d\x0a\x1a\x0a" + struct.pack("<HII", 0, n, n) + b"\x00" * 8
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
open(out, "wb").write(header + body)
print("wrote", out, "Technology", tech, "LightingStyle", style)
