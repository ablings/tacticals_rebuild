"""Deploy the UI session's lobby UI sources into a Studio (Edit mode) through the Studio MCP bridge.
Usage: python ui/deploy_ui.py <studio_id>
Each entry: target path under game, class, source file. Existing scripts keep their instance; only Source changes."""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MCP = os.path.expanduser('~/Documents/rivals_practice/mcpcli.py')
FILES = [
    ("StarterPlayer.StarterPlayerScripts", "PadUI", "LocalScript", "pads/PadUI.client.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "LobbyHudController", "ModuleScript", "hud/LobbyHudController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "LobbyUIController", "ModuleScript", "lobby/LobbyUIController.lua"),
    ("ServerScriptService", "PublicStats", "Script", "hud/PublicStats.server.lua"),
    ("ReplicatedStorage.UIKit", "PlayScreen", "ModuleScript", "play/PlayScreen.lua"),
    ("ReplicatedStorage.UIKit", "Tac", "ModuleScript", "lobby/Tac.lua"),
    ("ReplicatedStorage.UIKit", "SettingsData", "ModuleScript", "settings/SettingsData.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "SettingsConfig", "ModuleScript", "settings/SettingsConfig.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "SettingsEffectsController", "ModuleScript", "settings/SettingsEffectsController.lua"),
    ("ReplicatedStorage.Modules.Shared", "Binds", "ModuleScript", "settings/Binds.lua"),
]


# [SET] gameplay scripts patched so Settings work (Tacticals session handed these over, 2026-10-16).
# The first deploy copies each original to ServerStorage._RebuildRemoved.SET_<name>_Orig (UNDO = put that Source back).
C = "StarterPlayer.StarterPlayerScripts.Client.Controllers"
SET_FILES = [
    (C, "CameraController", "set/CameraController.lua"),
    (C, "ExplosionController", "set/ExplosionController.lua"),
    (C, "FlashController", "set/FlashController.lua"),
    (C, "WeaponController", "set/WeaponController.lua"),
    (C + ".WeaponController", "WeaponEffects", "set/WeaponEffects.lua"),
    (C, "MovementController", "set/MovementController.lua"),
    (C, "CoverController", "set/CoverController.lua"),
    (C, "HotbarController", "set/HotbarController.lua"),
    (C, "GadgetController", "set/GadgetController.lua"),
    (C, "HealthBarController", "set/HealthBarController.lua"),
    (C, "TrainingBinsController", "set/TrainingBinsController.lua"),
]

# small source patches to scripts the UI session doesn't own (idempotent)
PATCHES = [
    # pads wait for real players in Studio too (RIVALS); set true to test a full bay alone
    "local m = game.ReplicatedStorage.Modules.Shared.Config.LobbyConfig; m.Source = m.Source:gsub('LobbyConfig%.StudioSoloStart = true', 'LobbyConfig.StudioSoloStart = false')",
]


def long_string(s):
    n = 0
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


def build():
    parts = [
        "local CHS = game:GetService('ChangeHistoryService'); local rec = CHS:TryBeginRecording('Deploy lobby UI (UI session)')",
        "local function at(path) local o = game; for p in path:gmatch('[^%.]+') do o = o:FindFirstChild(p) or error('missing ' .. path) end; return o end",
        "local function put(parent, name, class, src) local s = parent:FindFirstChild(name); if s and s.ClassName ~= class then s:Destroy(); s = nil end; if not s then s = Instance.new(class); s.Name = name; s.Parent = parent end; s.Source = src end",
    ]
    for parent, name, cls, path in FILES:
        src = open(os.path.join(HERE, path), encoding='utf-8').read()
        parts.append(f"put(at('{parent}'), '{name}', '{cls}', {long_string(src)})")
    parts.append("local SS = game:GetService('ServerStorage'); local bin = SS:FindFirstChild('_RebuildRemoved') or Instance.new('Folder'); bin.Name = '_RebuildRemoved'; bin.Parent = SS")
    for parent, name, path in SET_FILES:
        src = open(os.path.join(HERE, path), encoding='utf-8').read()
        parts.append(f"do local s = at('{parent}'):FindFirstChild('{name}') or error('missing {name}'); "
                     f"if not bin:FindFirstChild('SET_{name}_Orig') and not s.Source:find('[SET]', 1, true) then local b = s:Clone(); b.Name = 'SET_{name}_Orig'; b:ClearAllChildren(); b.Parent = bin end; "
                     f"s.Source = {long_string(src)} end")
    for code in PATCHES:
        parts.append("do " + code + " end")
    parts.append("if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end")
    parts.append(f"return 'deployed {len(FILES)} files + {len(SET_FILES)} [SET] scripts'")
    return "\n".join(parts)


if __name__ == '__main__':
    sid = sys.argv[1]
    payload = os.path.join(HERE, '_deploy_payload.json')
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": build()}, open(payload, 'w', encoding='utf-8'))
    env = dict(os.environ, PYTHONIOENCODING='utf-8', MCP_TIMEOUT='300')
    r = subprocess.run([sys.executable, MCP, 'call', 'execute_luau', payload], capture_output=True, text=True, env=env, encoding='utf-8', cwd=os.path.dirname(MCP))
    print((r.stdout or r.stderr).strip()[-400:])
