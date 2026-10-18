"""Snapshot the hub-only client scripts the after-match pseudo lobby needs (owned by other sessions / the original game)
from the lobby Studio into ui/pseudolobby/hub/, so the match deploy runs from files.
Usage: python ui/pseudolobby/snapshot_hub.py <lobby studio_id>"""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
MCP = os.path.expanduser('~/Documents/rivals_practice/mcpcli.py')
SPS = "StarterPlayer.StarterPlayerScripts"
C = SPS + ".Client.Controllers"
# (parent, name, class): the hub's lobby look + menus. Left out on purpose: training / range / exfil / pads / arena loader /
# AssetCheck (the lead greys those out: "available in the hub").
HUB = [
    (SPS, "HeliRotorFX", "LocalScript"), (SPS, "LobbyScreensFX", "LocalScript"), (SPS, "LeaderboardScreen", "LocalScript"),
    (SPS, "WorldMoodFX", "LocalScript"), (SPS, "LobbyLabels", "LocalScript"), (SPS, "LobbyTickers", "LocalScript"),
    (SPS, "LobbyFX", "LocalScript"), (SPS, "RoomFX", "LocalScript"),
    (C, "BillboardController", "ModuleScript"), (C, "LobbyFeaturesFXController", "ModuleScript"), (C, "LobbyScreensController", "ModuleScript"),
    (C + ".LobbyUIController", "Icons", "ModuleScript"), (C + ".LobbyUIController", "Style", "ModuleScript"),
    (C + ".LobbyUIController", "Shop", "ModuleScript"), (C + ".LobbyUIController", "Tooltip", "ModuleScript"),
    ("ReplicatedStorage.UIKit", "Theme", "ModuleScript"), ("ReplicatedStorage.UIKit", "Assets", "ModuleScript"),
    ("ReplicatedStorage.UIKit", "HotkeysPage", "ModuleScript"), ("ReplicatedStorage.UIKit", "MissionsScreen", "ModuleScript"),
    ("ReplicatedStorage.UIKit", "ViewIcons", "ModuleScript"), ("ReplicatedStorage.UIKit", "SettingsTheme", "ModuleScript"),
]
def main(sid):
    man = []
    for parent, name, cls in HUB:
        code = f"local o=game for s in string.gmatch('{parent}.{name}','[^%.]+') do o=o and o:FindFirstChild(s) end return o and o.Source or 'MISSING'"
        jp = os.path.join(HERE, '_q.json')
        json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(jp, 'w'))
        r = subprocess.run([sys.executable, MCP, 'call', 'execute_luau', jp], capture_output=True, text=True, encoding='utf-8',
                           env=dict(os.environ, PYTHONIOENCODING='utf-8'))
        src = r.stdout
        if src.endswith('\n'): src = src[:-1]
        if src.strip() == 'MISSING' or not src.strip():
            print('MISSING', parent, name); continue
        fn = f"{name}.lua"
        open(os.path.join(HERE, 'hub', fn), 'w', encoding='utf-8', newline='').write(src)
        man.append([parent, name, cls, 'pseudolobby/hub/' + fn])
        print(f'{name}: {len(src)} chars')
    os.remove(jp)
    json.dump(man, open(os.path.join(HERE, 'hub', 'manifest.json'), 'w'), indent=1)
main(sys.argv[1])
