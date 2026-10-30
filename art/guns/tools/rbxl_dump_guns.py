"""READ-ONLY dump of gun Tools from a saved .rbxl (never writes it).
Usage: python -I art/guns/tools/rbxl_dump_guns.py <place.rbxl> <out.json> [folderPath like ReplicatedStorage/Repository/Weapons]
Decodes strings, bools, ints, floats, Color3, Color3uint8, Vector3, CFrame, enums and attributes."""
import sys, struct, json, math
import lz4.block, zstandard

data = open(sys.argv[1], "rb").read()
zd = zstandard.ZstdDecompressor()
pos = 32
classes, ids, props, parent = {}, {}, {}, {}


def rs(b, o):
    n = struct.unpack_from("<I", b, o)[0]
    return b[o + 4:o + 4 + n], o + 4 + n


def deint(b, n, width):
    return [bytes(b[j * n + i] for j in range(width)) for i in range(n)]


def refs(b, n):
    out, acc = [], 0
    for chunk in deint(b, n, 4):
        v = struct.unpack(">I", chunk)[0]
        v = (v >> 1) ^ -(v & 1)
        acc += v
        out.append(acc)
    return out


def rfloat(chunk):
    v = struct.unpack(">I", chunk)[0]
    v = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
    return struct.unpack(">f", struct.pack(">I", v))[0]


def floats(b, n):
    return [rfloat(c) for c in deint(b[:4 * n], n, 4)]


def basis_from_id(i):
    # Roblox special rotation ids: index into axis combos
    i -= 1
    xi, yi = i // 6, i % 6
    ax = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]
    X, Y = ax[xi], ax[yi]
    Z = (X[1] * Y[2] - X[2] * Y[1], X[2] * Y[0] - X[0] * Y[2], X[0] * Y[1] - X[1] * Y[0])
    # matrix rows: R = [X Y Z] as columns
    return [X[0], Y[0], Z[0], X[1], Y[1], Z[1], X[2], Y[2], Z[2]]


def attrs(b):
    out = {}
    try:
        n = struct.unpack_from("<I", b, 0)[0]; o = 4
        for _ in range(n):
            k, o = rs(b, o); t = b[o]; o += 1
            if t == 2:
                v, o = rs(b, o); v = v.decode("utf-8", "replace")
            elif t == 3:
                v = bool(b[o]); o += 1
            elif t == 5:
                v = struct.unpack_from("<f", b, o)[0]; o += 4
            elif t == 6:
                v = struct.unpack_from("<d", b, o)[0]; o += 8
            elif t == 0x0F:
                v = struct.unpack_from("<fff", b, o); o += 12
            elif t == 0x11:
                v = struct.unpack_from("<fff", b, o); o += 12
            elif t == 0x0E:
                v = struct.unpack_from("<ff", b, o); o += 8
            else:
                out[k.decode()] = f"<attr type {t}>"; break
            out[k.decode()] = v
    except Exception as e:
        out["_err"] = str(e)
    return out


while pos < len(data):
    name = data[pos:pos + 4]
    clen, ulen = struct.unpack_from("<II", data, pos + 4)
    pos += 16
    if clen == 0:
        raw = data[pos:pos + ulen]; pos += ulen
    else:
        c = data[pos:pos + clen]; pos += clen
        raw = zd.decompress(c, max_output_size=ulen) if c[:4] == b"\x28\xb5\x2f\xfd" else lz4.block.decompress(c, uncompressed_size=ulen)
    if name == b"INST":
        cid = struct.unpack_from("<I", raw, 0)[0]
        cn, o = rs(raw, 4)
        o += 1
        n = struct.unpack_from("<I", raw, o)[0]
        classes[cid] = cn.decode()
        ids[cid] = refs(raw[o + 4:o + 4 + 4 * n], n)
    elif name == b"PROP":
        cid = struct.unpack_from("<I", raw, 0)[0]
        pn, o = rs(raw, 4)
        pn = pn.decode()
        t = raw[o]; b = raw[o + 1:]; n = len(ids[cid]); vals = None
        try:
            if t == 1:
                vals, q = [], 0
                for _ in range(n):
                    s, q = rs(b, q)
                    vals.append(attrs(s) if pn == "AttributesSerialize" else s.decode("utf-8", "replace"))
            elif t == 2:
                vals = [bool(x) for x in b[:n]]
            elif t == 3:
                vals = []
                for ch in deint(b, n, 4):
                    v = struct.unpack(">I", ch)[0]; vals.append((v >> 1) ^ -(v & 1))
            elif t == 4:
                vals = [round(rfloat(ch), 4) for ch in deint(b, n, 4)]
            elif t == 0x0C:
                r = floats(b, n); g = floats(b[4 * n:], n); bl = floats(b[8 * n:], n)
                vals = [tuple(round(x * 255) for x in (r[i], g[i], bl[i])) for i in range(n)]
            elif t == 0x1A:
                vals = [(b[i], b[n + i], b[2 * n + i]) for i in range(n)]
            elif t == 0x12:
                vals = [struct.unpack(">I", ch)[0] for ch in deint(b, n, 4)]
            elif t == 0x0E:
                x = floats(b, n); y = floats(b[4 * n:], n); z = floats(b[8 * n:], n)
                vals = [(round(x[i], 4), round(y[i], 4), round(z[i], 4)) for i in range(n)]
            elif t == 0x10:
                q = 0; rots = []
                for _ in range(n):
                    rid = b[q]; q += 1
                    if rid == 0:
                        rots.append(list(struct.unpack_from("<9f", b, q))); q += 36
                    else:
                        rots.append(basis_from_id(rid))
                x = floats(b[q:], n); y = floats(b[q + 4 * n:], n); z = floats(b[q + 8 * n:], n)
                vals = [[round(x[i], 4), round(y[i], 4), round(z[i], 4)] + [round(v, 4) for v in rots[i]] for i in range(n)]
        except Exception as e:  # noqa
            vals = None
        for i, ref in enumerate(ids[cid]):
            props.setdefault(ref, {})[pn] = vals[i] if vals else f"<type {t}>"
    elif name == b"PRNT":
        n = struct.unpack_from("<I", raw, 1)[0]
        ch = refs(raw[5:5 + 4 * n], n); pa = refs(raw[5 + 4 * n:5 + 8 * n], n)
        for c_, p_ in zip(ch, pa):
            parent[c_] = p_
    if name == b"END\x00":
        break

cls_of = {r: classes[c] for c, rl in ids.items() for r in rl}
kids = {}
for c_, p_ in parent.items():
    kids.setdefault(p_, []).append(c_)
KEEP = {"Name", "Size", "size", "CFrame", "Color", "Color3uint8", "Material", "Transparency", "CanCollide", "Grip", "GripPos",
        "AttributesSerialize", "Tags", "C0", "C1", "Part0", "Part1", "MeshId", "TextureID", "Position", "Value",
        "Orientation", "MaterialVariantSerialized", "MeshType", "Scale", "Offset", "CFrame", "Shape", "Enabled",
        "SoundId", "TextureId", "ToolTip", "RequiresHandle"}


def node(r, depth=0):
    p = props.get(r, {})
    d = {"class": cls_of[r]}
    for k, v in p.items():
        if k in KEEP:
            d[k] = v
    if depth < 8:
        ch = [node(c, depth + 1) for c in kids.get(r, [])]
        if ch:
            d["children"] = ch
    return d


roots = [r for r in cls_of if r not in parent or parent[r] not in cls_of]
path = (sys.argv[3] if len(sys.argv) > 3 else "ReplicatedStorage/Repository/Weapons").split("/")
cur = [r for r in roots if props.get(r, {}).get("Name") == path[0] or cls_of[r] == path[0]]
for seg in path[1:]:
    cur = [c for r in cur for c in kids.get(r, []) if props.get(c, {}).get("Name") == seg]
out = [node(r) for r in cur]
json.dump(out, open(sys.argv[2], "w"), indent=1)
print("found", len(cur), "nodes;", [len(o.get("children", [])) for o in out])
