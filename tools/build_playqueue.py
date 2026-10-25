"""Build fix/play_again_queue.lua from fix/play_again_queue.tpl.lua + scripts/match/MatchmakingManager.lua ([PLAYQUEUE])."""
import os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
tpl = open(os.path.join(R, "fix", "play_again_queue.tpl.lua"), encoding="utf-8").read()
src = open(os.path.join(R, "scripts", "match", "MatchmakingManager.lua"), encoding="utf-8").read().replace("\r\n", "\n")
assert "]=====]" not in src
out = tpl.replace("__MMSRC__", src)
open(os.path.join(R, "fix", "play_again_queue.lua"), "w", encoding="utf-8", newline="\n").write(out)
print("fix/play_again_queue.lua", len(out))
