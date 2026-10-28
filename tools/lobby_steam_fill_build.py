"""Embed the shared steam-fill sources (fix/steam_fill/{SteamMask,SteamCloud,ShootableConfig_Fill}.lua) into
fix/lobby_steam_fill.lua (between --@@BEGIN / --@@END SOURCES). Lobby pad duels [LOBBYSTEAM]; the match places use
tools/steam_fill_build.py with the same files. Usage (from tacticals_rebuild): python tools/lobby_steam_fill_build.py"""
import os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FIX = os.path.join(ROOT, "fix", "lobby_steam_fill.lua")
SRC = os.path.join(ROOT, "fix", "steam_fill")
FILES = {"SteamMask": "SteamMask.lua", "SteamCloud": "SteamCloud.lua", "FillBlock": "ShootableConfig_Fill.lua"}


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s or ("[" + "=" * n + "[") in s:
        n += 1
    return "[" + "=" * n + "[\n" + s + "]" + "=" * n + "]"


lines = []
for k, f in FILES.items():
    text = open(os.path.join(SRC, f), encoding="utf-8").read().replace("\r\n", "\n")
    lines.append(f"SOURCES.{k} = {long_string(text)}")
block = "--@@BEGIN SOURCES\n" + "\n".join(lines) + "\n--@@END SOURCES"
fix = open(FIX, encoding="utf-8").read()
fix = re.sub(r"--@@BEGIN SOURCES.*?--@@END SOURCES", lambda _: block, fix, flags=re.S)
open(FIX, "w", encoding="utf-8", newline="\n").write(fix)
print("embedded", len(FILES), "sources into fix/lobby_steam_fill.lua")
