"""Test place installers [TESTPLACE] (notes/test_place.md).
  python tools/test_place_build.py place <studio window name> [UNDO]   the Test place code (after split_build.py place <id> Test)
  python tools/test_place_build.py lobby <studio window name> [--id=<placeId>] [UNDO]   the lobby's ;testplace entry + LobbyConfig.TestPlaceId
  python tools/test_place_build.py stage <studio window name> <MapId> [Extra1,Extra2] [UNDO]   move a DuelMaps map into ServerStorage.StagingMaps
  python tools/test_place_build.py embed                               only refresh the embedded sources
Embeds scripts/testplace/RoundManager_block.lua and scripts/admin/Commands/TestPlace.lua into the fix/ files, then runs the file
through the Studio MCP bridge on the window with that name (looked up every call). Never saves the place."""
import json, os, re, subprocess, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
FORBIDDEN_NAMES = ("tacticals", "Matchmaking", "Ranked", "Tutorial", "Game")  # cloud windows of the live places: never


def read(rel):
    return open(os.path.join(ROOT, rel), encoding='utf-8').read()


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[\n" + s + "]" + "=" * n + "]"


def embed(rel, blocks):
    p = os.path.join(ROOT, rel)
    src = open(p, encoding='utf-8').read()
    body = "".join(f"local {name} = {long_string(read(f))}\n" for name, f in blocks)
    new = re.sub(r'(--@EMBED_BEGIN[^\n]*\n).*?(--@EMBED_END)', lambda m: m.group(1) + body + m.group(2), src, flags=re.S)
    if new != src:
        open(p, 'w', encoding='utf-8', newline='\n').write(new)
    return new


CMD = ("TESTCMD_SRC", "scripts/admin/Commands/TestPlace.lua")


def build_place():
    return embed('fix/test_place_install.lua', [("RM_BLOCK", "scripts/testplace/RoundManager_block.lua"), CMD])


def build_lobby():
    return embed('fix/test_lobby_install.lua', [CMD])


if __name__ == '__main__':
    a = sys.argv[1:]
    if not a or a[0] not in ('place', 'lobby', 'stage', 'embed'):
        sys.exit(__doc__)
    if a[0] == 'embed':
        build_place(); build_lobby(); print('embedded'); sys.exit(0)
    name, rest = a[1], a[2:]
    if name in FORBIDDEN_NAMES:
        sys.exit('refused: ' + name + ' is a live place window')
    if a[0] == 'place':
        code = build_place()
    elif a[0] == 'lobby':
        code = build_lobby()
        pid = next((x.split('=', 1)[1] for x in rest if x.startswith('--id=')), None)
        if pid:
            code = re.sub(r'^local TEST_PLACE_ID = \d+ --@ID', f'local TEST_PLACE_ID = {int(pid)} --@ID', code, flags=re.M)
    else:
        code = read('fix/stage_map.lua')
        mid = next((x for x in rest if x != 'UNDO'), None)
        if not mid:
            sys.exit('give a map id')
        code = re.sub(r'^local MAP = "\w*" --@MAP', f'local MAP = "{mid}" --@MAP', code, flags=re.M)
        extra = [x for x in rest if x not in ('UNDO', mid)]
        if extra:
            lst = ', '.join('"%s"' % e for e in extra[0].split(','))
            code = re.sub(r'^local EXTRA = \{\}', 'local EXTRA = { ' + lst + ' }', code, flags=re.M)
    if 'UNDO' in rest:
        code = re.sub(r'^local UNDO = false --@UNDO', 'local UNDO = true --@UNDO', code, flags=re.M)
    os.environ['HOUSE_STUDIO'] = name
    import house_mcp
    house_mcp.NAME = name
    print(house_mcp.lua(code, 'Edit'))
