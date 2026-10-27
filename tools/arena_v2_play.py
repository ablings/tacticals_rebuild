"""Arena v2 Play lap helper (match place). Thin wrappers so each lap step is one command.

    python tools/arena_v2_play.py <sid> setup            set StudioTeleportData (me vs bot, 1v1, long round) in Edit
    python tools/arena_v2_play.py <sid> clear            clear it again (Edit) - always before saving
    python tools/arena_v2_play.py <sid> start | stop     Play on / off
    python tools/arena_v2_play.py <sid> state
    python tools/arena_v2_play.py <sid> lua <Edit|Server|Client> <file.lua | -c code>
"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lookdev"))
from run import call  # noqa: E402

TD = {"Mode": "1v1", "Teams": {"A": ["me"], "B": ["bot"]},
      "StudioTimes": {"MapVoteTime": 40, "LoadoutTime": 40, "RoundTime": 900}}


def lua(sid, dm, code, timeout=300):
    return call("execute_luau", {"studio_id": sid, "datamodel_type": dm, "code": code}, timeout=timeout)


if __name__ == "__main__":
    sid, what = sys.argv[1], sys.argv[2]
    if what == "setup":
        td = json.loads(sys.argv[3]) if len(sys.argv) > 3 else TD
        print(lua(sid, "Edit", "game.ReplicatedStorage:SetAttribute('StudioTeleportData', [==[%s]==]) return game.ReplicatedStorage:GetAttribute('StudioTeleportData')" % json.dumps(td)))
    elif what == "clear":
        print(lua(sid, "Edit", "game.ReplicatedStorage:SetAttribute('StudioTeleportData', nil) return tostring(game.ReplicatedStorage:GetAttribute('StudioTeleportData'))"))
    elif what in ("start", "stop"):
        print(call("start_stop_play", {"studio_id": sid, "is_start": what == "start"}))
    elif what == "state":
        print(call("get_studio_state", {"studio_id": sid}))
    elif what == "lua":
        dm = sys.argv[3]
        code = sys.argv[5] if sys.argv[4] == "-c" else open(sys.argv[4], encoding="utf-8").read()
        print(lua(sid, dm, code))
