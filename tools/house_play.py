"""House Play test helper (build copy only: out/house/build.rbxl).
    python tools/house_play.py setup [1v1|3v3] | clear | start | stop | state
    python tools/house_play.py client <step.lua | -c code>     (tools/house_lap_lib.lua prepended)
    python tools/house_play.py server <file.lua | -c code>
setup: StudioTeleportData = me vs bot(s), short vote / loadout, long rounds (test only; clear removes it)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import house_mcp  # noqa: E402
HERE = os.path.dirname(os.path.abspath(__file__))
def td(mode):
    n = int(mode[0])
    return {"Mode": mode, "Teams": {"A": ["me"] + ["bot"] * (n - 1), "B": ["bot"] * n},
            "StudioTimes": {"MapVoteTime": 20, "LoadoutTime": 10, "RoundTime": 900}}
SETUP = 'game.ReplicatedStorage:SetAttribute("StudioTeleportData", [==[%s]==]) return game.ReplicatedStorage:GetAttribute("StudioTeleportData")'
CLEAR = 'game.ReplicatedStorage:SetAttribute("StudioTeleportData", nil) return "cleared"'
if __name__ == "__main__":
    what = sys.argv[1]
    if what == "setup":
        print(house_mcp.lua(SETUP % json.dumps(td(sys.argv[2] if len(sys.argv) > 2 else "1v1"))))
    elif what == "clear":
        print(house_mcp.lua(CLEAR))
    elif what in ("start", "stop"):
        print(house_mcp.call("start_stop_play", {"is_start": what == "start"}))
    elif what == "state":
        print(house_mcp.call("get_studio_state", {}))
    elif what in ("client", "server"):
        code = sys.argv[3] if sys.argv[2] == "-c" else open(sys.argv[2], encoding="utf-8").read()
        if what == "client":
            code = open(os.path.join(HERE, "house_lap_lib.lua"), encoding="utf-8").read() + "\n" + code
        print(house_mcp.lua(code, "Client" if what == "client" else "Server"))
