"""Offline check of saved .rbxl files for the [PERFSET] install: counts markers in the decompressed chunks."""
import struct, sys, lz4.block, zstandard
def chunks(path):
    d = open(path, "rb").read(); pos = 32; zd = zstandard.ZstdDecompressor()
    while pos < len(d):
        name = d[pos:pos+4]; clen, ulen = struct.unpack("<II", d[pos+4:pos+12]); pos += 16
        if clen == 0: raw = d[pos:pos+ulen]; pos += ulen
        else:
            c = d[pos:pos+clen]; pos += clen
            raw = zd.decompress(c, max_output_size=ulen) if c[:4] == b"\x28\xb5\x2f\xfd" else lz4.block.decompress(c, uncompressed_size=ulen)
        yield name, raw
        if name == b"END\0": break
for f in sys.argv[1:]:
    blob = b"".join(r for n, r in chunks(f))
    print(f"{f}: [PERFSET] x{blob.count(b'[PERFSET]')}, Fewer Lights row {b'name = \"Fewer Lights\"' in blob}, Setting_LowEffects {b'Setting_LowEffects' in blob}, _PerfSetOrig {b'_PerfSetOrig' in blob}")
