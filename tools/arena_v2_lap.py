"""Run one Arena v2 lap step on the Play client: the helpers in tools/arena_v2_lap_lib.lua + a step snippet.
    python tools/arena_v2_lap.py <sid> <step.lua | -c code>      (the snippet ends with: return table.concat(LOG, "\\n"))"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lookdev"))
from run import call  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sid = sys.argv[1]
snippet = sys.argv[3] if sys.argv[2] == "-c" else open(sys.argv[2], encoding="utf-8").read()
lib = open(os.path.join(HERE, "arena_v2_lap_lib.lua"), encoding="utf-8").read()
print(call("execute_luau", {"studio_id": sid, "datamodel_type": "Client", "code": lib + "\n" + snippet}, timeout=600))
