import json, sys, os
def wrap(p):
    t = open(p, encoding="utf-8").read()
    if os.path.basename(p) == "cap_lib.lua":
        return "local C = (function()\n" + t + "\nend)()\n"
    return t + "\n"
pre = "".join(wrap(p) for p in sys.argv[4:])
src = pre + open(sys.argv[1], encoding="utf-8").read()
print(json.dumps({"code": src, "studio_id": sys.argv[2], "datamodel_type": sys.argv[3]}))
