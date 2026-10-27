"""Warehouse 2 Play test helper (build copy only).

    python tools/wh2_play.py setup | clear | start | stop | state
    python tools/wh2_play.py client <step.lua | -c code>      run a step on the Play client (tools/wh2_lap_lib.lua prepended)
    python tools/wh2_play.py server <file.lua | -c code>

setup: StudioTeleportData = me vs bot, 1v1, short vote / loadout, long round; and (TEST ONLY, reverted by clear) BotConfig
       CoverFolders += "Warehouse2/CollisionProxies" - the line the systems agent adds (briefs/systems.md), so the bot can use
       Warehouse 2's cover in this test. Neither change is part of fix/map_warehouse2.lua.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wh2_mcp  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TD = {"Mode": "1v1", "Teams": {"A": ["me"], "B": ["bot"]}, "StudioTimes": {"MapVoteTime": 25, "LoadoutTime": 15, "RoundTime": 900}}
BOT_OLD = 'CoverFolders = { "Warehouse/CollisionProxies" },'
BOT_NEW = 'CoverFolders = { "Warehouse/CollisionProxies", "Warehouse2/CollisionProxies" }, --[[WH2TEST]]'

SETUP = '''local RS = game.ReplicatedStorage
RS:SetAttribute("StudioTeleportData", [==[%s]==])
local bc = RS.Modules.Shared.Config.BotConfig
local src = bc.Source
local a, b = [==[%s]==], [==[%s]==]
if not src:find("WH2TEST", 1, true) then
	local i = src:find(a, 1, true)
	if i then bc.Source = src:sub(1, i - 1) .. b .. src:sub(i + #a) end
end
return RS:GetAttribute("StudioTeleportData") .. " | botcfg patched: " .. tostring(bc.Source:find("WH2TEST", 1, true) ~= nil)'''
CLEAR = '''local RS = game.ReplicatedStorage
RS:SetAttribute("StudioTeleportData", nil)
local bc = RS.Modules.Shared.Config.BotConfig
local src = bc.Source
local a, b = [==[%s]==], [==[%s]==]
local i = src:find(b, 1, true)
if i then bc.Source = src:sub(1, i - 1) .. a .. src:sub(i + #b) end
return "cleared; botcfg test line present: " .. tostring(bc.Source:find("WH2TEST", 1, true) ~= nil)'''

if __name__ == "__main__":
    what = sys.argv[1]
    if what == "setup":
        print(wh2_mcp.lua(SETUP % (json.dumps(TD), BOT_OLD, BOT_NEW)))
    elif what == "clear":
        print(wh2_mcp.lua(CLEAR % (BOT_OLD, BOT_NEW)))
    elif what in ("start", "stop"):
        print(wh2_mcp.call("start_stop_play", {"is_start": what == "start"}))
    elif what == "state":
        print(wh2_mcp.call("get_studio_state", {}))
    elif what in ("client", "server"):
        code = sys.argv[3] if sys.argv[2] == "-c" else open(sys.argv[2], encoding="utf-8").read()
        if what == "client":
            code = open(os.path.join(HERE, "wh2_lap_lib.lua"), encoding="utf-8").read() + "\n" + code
        print(wh2_mcp.lua(code, "Client" if what == "client" else "Server"))
