"""Read Lighting.Technology / LightingStyle / PrioritizeLightingQuality from a saved .rbxl (read-only). Usage: python -I tools/read_technology.py <place.rbxl>. Technology 3 = ShadowMap, 4 = Future."""
import sys, struct, lz4.block, zstandard
data=open(sys.argv[1],"rb").read(); zd=zstandard.ZstdDecompressor(); pos=32; classes={}
def rs(b,o):
    n=struct.unpack_from("<I",b,o)[0]; return b[o+4:o+4+n],o+4+n
while pos<len(data):
    name=data[pos:pos+4]; clen,ulen=struct.unpack_from("<II",data,pos+4); pos+=16
    if clen==0: raw=data[pos:pos+ulen]; pos+=ulen
    else:
        c=data[pos:pos+clen]; pos+=clen
        raw=zd.decompress(c,max_output_size=ulen) if c[:4]==b"\x28\xb5\x2f\xfd" else lz4.block.decompress(c,uncompressed_size=ulen)
    if name==b"INST":
        cid=struct.unpack_from("<I",raw,0)[0]; cn,o=rs(raw,4); classes[cid]=cn
    elif name==b"PROP":
        cid=struct.unpack_from("<I",raw,0)[0]; pn,o=rs(raw,4)
        if classes.get(cid)==b"Lighting" and pn in (b"Technology",b"PrioritizeLightingQuality",b"LightingStyle"):
            print(pn.decode(), raw[o], struct.unpack(">I",raw[o+1:o+5])[0] if raw[o]==18 else raw[o+1])
    if name==b"END\x00": break
