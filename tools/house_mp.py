"""Run Luau on one Studio test window by id (multiplayer test: server / Player1 / Player2).
    python tools/house_mp.py <studio_id> <Server|Client> <file.lua | -c code>"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import house_mcp
sid, dm = sys.argv[1], sys.argv[2]
code = sys.argv[4] if sys.argv[3] == "-c" else open(sys.argv[3], encoding="utf-8").read()
print(house_mcp.raw_call("execute_luau", {"studio_id": sid, "datamodel_type": dm, "code": code}))
