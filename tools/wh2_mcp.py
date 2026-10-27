"""Warehouse 2 build helper: run Luau / call any Studio MCP tool on the Warehouse 2 build copy (out/warehouse2/Warehouse2_build.rbxl).
Usage:
  python tools/wh2_mcp.py lua <file.lua | -> [Edit|Server|Client] [UNDO]     run a Luau file (or stdin) and print the result
  python tools/wh2_mcp.py call <tool> '<json>'                                 any MCP tool (studio_id is filled in)
The studio id is looked up by window name (Warehouse2_build.rbxl) every call, so a reload doesn't break it. Never targets
another Studio: if no instance with that name is connected, it stops."""
import json, os, re, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
CLI = os.path.join(os.path.expanduser("~"), "Documents", "roblox_kits", "tools", "mcpcli.py")
NAME = os.environ.get("WH2_STUDIO", "Warehouse2_build.rbxl")
ENV = dict(os.environ, PYTHONIOENCODING="utf-8", MCP_WARMUP=os.environ.get("MCP_WARMUP", "2"), MCP_TIMEOUT="600")


def raw_call(tool, args):
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump(args, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", tool, path], capture_output=True, text=True, encoding="utf-8",
                       errors="replace", env=ENV)
    os.remove(path)
    return r.stdout + (r.stderr[-1500:] if r.returncode else "")


def studio_id():
    out = raw_call("list_roblox_studios", {})
    m = re.search(r"\{.*\}", out, re.S)
    for s in json.loads(m.group(0))["studios"]:
        if s["name"] == NAME:
            return s["id"]
    sys.exit("no Studio named " + NAME + " connected: " + out[:300])


def call(tool, args):
    args = dict(args); args["studio_id"] = studio_id()
    return raw_call(tool, args)


def lua(code, dm="Edit"):
    return call("execute_luau", {"code": code, "datamodel_type": dm})


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "lua":
        src = sys.argv[2]
        code = sys.stdin.read() if src == "-" else open(src, encoding="utf-8").read()
        rest = sys.argv[3:]
        dm = next((a for a in rest if a in ("Edit", "Server", "Client")), "Edit")
        if "UNDO" in rest:
            code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
        print(lua(code, dm))
    elif what == "call":
        a = sys.argv[3] if len(sys.argv) > 3 else "{}"
        if os.path.isfile(a): a = open(a, encoding="utf-8").read()
        print(call(sys.argv[2], json.loads(a)))
