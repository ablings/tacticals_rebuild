"""Port a match-place map into the lobby copy by script (lobby duels).
Usage (from tacticals_rebuild): python tools/duel_map_port.py <src_studio> <dst_studio> [MapId] [Root1,Root2]
  export: tools/duel_map_export.lua in <src_studio> (READ-ONLY there), chunked -> out/duels/<MapId>_export.json
  import: tools/duel_map_import.lua in <dst_studio> (Edit) -> ServerStorage._DuelSource.<MapId>, then strips _PortIdx.
Studio ids change on reload: list_roblox_studios first."""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CLI = os.path.expanduser(r"~\Documents\rivals_practice\mcpcli.py")
src_id, dst_id = sys.argv[1], sys.argv[2]
MAP = sys.argv[3] if len(sys.argv) > 3 else "Warehouse"
ROOTS = (sys.argv[4] if len(sys.argv) > 4 else "Warehouse,MatchSpawns").split(",")
OUT = os.path.join(HERE, "..", "out", "duels"); os.makedirs(OUT, exist_ok=True)


def run(sid, code):
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300", MCP_WARMUP="3"))
    os.remove(path)
    if r.returncode: sys.exit("luau failed: " + r.stdout[-2000:] + r.stderr[-1000:])
    return r.stdout.strip()


exp = open(os.path.join(HERE, "duel_map_export.lua"), encoding="utf-8").read()
exp = re.sub(r"^local ROOTS = .*--@ROOTS$", "local ROOTS = { " + ", ".join(f'"{r}"' for r in ROOTS) + " }", exp, flags=re.M)
nodes, matvars, total, i, STEP = [], {}, None, 1, 50
while total is None or i <= total:
    code = re.sub(r"^local CHUNK_FROM.*--@CHUNK$", f"local CHUNK_FROM, CHUNK_TO = {i}, {i + STEP - 1}", exp, flags=re.M)
    d = json.loads(run(src_id, code))
    total = d["total"]; nodes += d["nodes"]; matvars = d["matvars"] or matvars; i += STEP
    print("exported", len(nodes), "/", total)
json.dump({"nodes": nodes, "matvars": matvars}, open(os.path.join(OUT, f"{MAP}_export.json"), "w"), indent=0)

imp = open(os.path.join(HERE, "duel_map_import.lua"), encoding="utf-8").read()
imp = re.sub(r'^local MAP_ID = .*--@MAP$', f'local MAP_ID = "{MAP}"', imp, flags=re.M)
for k in range(0, len(nodes), 60):
    payload = json.dumps({"nodes": nodes[k:k + 60], "matvars": matvars if k == 0 else {}})
    assert "]==]" not in payload
    code = imp.replace("local PAYLOAD = [==[{}]==] --@PAYLOAD", "local PAYLOAD = [==[" + payload + "]==]")
    print(k, run(dst_id, code)[:1500])
print(run(dst_id, f'''local r = game.ServerStorage._DuelSource["{MAP}"]; local n, miss = 0, 0
for _, d in r:GetDescendants() do d:SetAttribute("_PortIdx", nil); n += 1; if d:GetAttribute("_PortMeshMissing") then miss += 1 end end
return "imported " .. n .. " instances, mesh missing " .. miss'''))
