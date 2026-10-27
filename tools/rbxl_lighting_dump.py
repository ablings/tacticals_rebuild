"""Dump Lighting and its children (Sky, Atmosphere, post effects) from a saved .rbxl, READ-ONLY (never writes the file).
Usage: python -I tools/rbxl_lighting_dump.py <place.rbxl>
Decodes the simple property types (string, bool, int, float, double, Color3, Color3uint8, enum); others are listed by type id."""
import sys, struct
import lz4.block, zstandard

data = open(sys.argv[1], "rb").read()
zd = zstandard.ZstdDecompressor()
pos = 32
classes, ids, props, parent = {}, {}, {}, {}


def rs(b, o):
    n = struct.unpack_from("<I", b, o)[0]
    return b[o + 4:o + 4 + n], o + 4 + n


def deinterleave(b, n, width):
    return [bytes(b[j * n + i] for j in range(width)) for i in range(n)]


def refs(b, n):
    out, acc = [], 0
    for chunk in deinterleave(b, n, 4):
        v = struct.unpack(">I", chunk)[0]
        v = (v >> 1) ^ -(v & 1)
        acc += v
        out.append(acc)
    return out


def rfloat(chunk):
    v = struct.unpack(">I", chunk)[0]
    v = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
    return struct.unpack(">f", struct.pack(">I", v))[0]


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
        t = raw[o]; b = raw[o + 1:]; n = len(ids[cid]); vals = None
        try:
            if t == 1:
                vals, q = [], 0
                for _ in range(n):
                    s, q = rs(b, q); vals.append(s.decode("utf-8", "replace"))
            elif t == 2:
                vals = [bool(x) for x in b[:n]]
            elif t == 3:
                vals = []
                for ch in deinterleave(b, n, 4):
                    v = struct.unpack(">I", ch)[0]; vals.append((v >> 1) ^ -(v & 1))
            elif t == 4:
                vals = [round(rfloat(ch), 4) for ch in deinterleave(b, n, 4)]
            elif t == 5:
                vals = [struct.unpack_from("<d", b, 8 * i)[0] for i in range(n)]
            elif t == 0x0C:
                r = deinterleave(b[:4 * n], n, 4); g = deinterleave(b[4 * n:8 * n], n, 4); bl = deinterleave(b[8 * n:12 * n], n, 4)
                vals = [tuple(round(rfloat(x) * 255) for x in (r[i], g[i], bl[i])) for i in range(n)]
            elif t == 0x1A:
                vals = [(b[i], b[n + i], b[2 * n + i]) for i in range(n)]
            elif t == 0x12:
                vals = [struct.unpack(">I", ch)[0] for ch in deinterleave(b, n, 4)]
        except Exception as e:  # noqa
            vals = None
        for i, ref in enumerate(ids[cid]):
            props.setdefault(ref, {})[pn.decode()] = vals[i] if vals else f"<type {t}>"
    elif name == b"PRNT":
        n = struct.unpack_from("<I", raw, 1)[0]
        ch = refs(raw[5:5 + 4 * n], n); pa = refs(raw[5 + 4 * n:5 + 8 * n], n)
        for c_, p_ in zip(ch, pa):
            parent[c_] = p_
    if name == b"END\x00":
        break

cls_of = {r: classes[c] for c, rl in ids.items() for r in rl}
lighting = [r for r, c in cls_of.items() if c == "Lighting"]
SKIP = {"Tags", "AttributesSerialize", "SourceAssetId", "HistoryId", "UniqueId", "Capabilities", "DefinesCapabilities"}
for L in lighting:
    todo = [L]
    while todo:
        r = todo.pop(0)
        p = props.get(r, {})
        print(f"== {cls_of[r]} '{p.get('Name', '')}'")
        for k in sorted(p):
            if k not in SKIP and k != "Name":
                print(f"   {k} = {p[k]}")
        todo += [c for c, pp in parent.items() if pp == r]
