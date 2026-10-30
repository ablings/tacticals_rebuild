"""Move feel Play-test helper for one Studio window (default: the out/move_feel copy).
    python tools/move_feel_play.py [--sid ID] start | stop | state | console
    python tools/move_feel_play.py [--sid ID] client|server|edit <file.lua | -c code> [more files prepended in order]
    python tools/move_feel_play.py [--sid ID] keys '<json actions>'      (user_keyboard_input)
Client code gets tools/move_feel/lib.lua prepended."""
import json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
args = sys.argv[1:]
SID = os.environ.get("MF_SID", "dbb61383-3d6a-43c0-bea8-307ae2b613c4")
if args and args[0] == "--sid":
    SID = args[1]; args = args[2:]
def call(tool, a):
    a = dict(a); a["studio_id"] = SID
    fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump(a, open(p, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", tool, p], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="600"))
    os.remove(p)
    return (r.stdout + r.stderr).strip()
what = args[0]
if what in ("start", "stop"):
    print(call("start_stop_play", {"is_start": what == "start"}))
elif what == "state":
    print(call("get_studio_state", {}))
elif what == "console":
    print(call("get_console_output", {})[-int(args[1]) if len(args) > 1 else -6000:])
elif what == "keys":
    print(call("user_keyboard_input", {"actions": json.loads(args[1]), "datamodel_type": "Client"}))
elif what in ("client", "server", "edit"):
    if args[1] == "-c":
        code = args[2]
    else:
        code = "\n".join(open(f, encoding="utf-8").read() for f in args[1:])
    if what == "client":
        code = open(os.path.join(HERE, "move_feel", "lib.lua"), encoding="utf-8").read() + "\n" + code
    print(call("execute_luau", {"code": code, "datamodel_type": what.capitalize()}))
