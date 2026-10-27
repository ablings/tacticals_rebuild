"""Look-dev helper for the arena surface test (only the two sessions of this task).
  python tools/lookdev/run.py lua <sid> <file.lua | -c code>      run Luau in Edit
  python tools/lookdev/run.py cap <sid> <capture_id> x,y,z x,y,z   screen capture -> out/<capture_id>_1.png
sid: 'dev' = practice/arena_lookdev.rbxl, 'ref' = the temp read-only copy of the RIVALS arena, or a studio id."""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SIDS = {"dev": "0dfb8ee0-5013-4c8e-91b1-8cbb984988bc", "ref": "d8e95510-7e1c-4388-bab0-617e220edfdc"}
EXE = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions", "version-7aaa6838d36c4448", "StudioMCP.exe")


def call(tool, args, timeout=300):
    fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump(args, open(p, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, os.path.join(HERE, "mcpcli.py"), "call", tool, p], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", cwd=os.path.dirname(os.path.dirname(HERE)),
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT=str(timeout), STUDIO_MCP_EXE=EXE, MCP_WARMUP="2"))
    os.remove(p)
    return (r.stdout.strip() or r.stderr[-1500:])


if __name__ == "__main__":
    mode, sid = sys.argv[1], SIDS.get(sys.argv[2], sys.argv[2])
    if mode == "lua":
        code = sys.argv[4] if sys.argv[3] == "-c" else open(sys.argv[3], encoding="utf-8").read()
        print(call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": code}))
    elif mode == "cap":
        cam = [float(v) for v in sys.argv[4].split(",")]; at = [float(v) for v in sys.argv[5].split(",")]
        print(call("screen_capture", {"studio_id": sid, "capture_id": sys.argv[3], "camera_position": cam, "look_at_position": at}))
