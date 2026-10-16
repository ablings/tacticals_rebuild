"""Deploy the UI session's lobby UI sources into a Studio (Edit mode) through the Studio MCP bridge.
Usage: python ui/deploy_ui.py <studio_id>
Each entry: target path under game, class, source file. Existing scripts keep their instance; only Source changes."""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MCP = os.path.expanduser('~/Documents/rivals_practice/mcpcli.py')
FILES = [
    ("StarterPlayer.StarterPlayerScripts", "PadUI", "LocalScript", "pads/PadUI.client.lua"),
    ("StarterPlayer.StarterPlayerScripts", "PadBoards", "LocalScript", "pads/PadBoards.client.lua"),
    ("StarterPlayer.StarterPlayerScripts", "MatchFlowUI", "LocalScript", "match/MatchFlowUI.client.lua"),
    ("StarterPlayer.StarterPlayerScripts", "DuelHUD", "LocalScript", "match/DuelHUD.client.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "LobbyHudController", "ModuleScript", "hud/LobbyHudController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "NameplatesController", "ModuleScript", "hud/NameplatesController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "LobbyUIController", "ModuleScript", "lobby/LobbyUIController.lua"),
    ("ServerScriptService", "PublicStats", "Script", "hud/PublicStats.server.lua"),
    ("ReplicatedStorage.UIKit", "PlayScreen", "ModuleScript", "play/PlayScreen.lua"),
    ("ReplicatedStorage.UIKit", "CodesScreen", "ModuleScript", "lobby/CodesScreen.lua"),
    ("ReplicatedStorage.UIKit", "Tac", "ModuleScript", "lobby/Tac.lua"),
    ("ReplicatedStorage.UIKit", "Kit", "ModuleScript", "lobby/Kit.lua"),
    ("ReplicatedStorage.UIKit", "ShopScreen", "ModuleScript", "shop/ShopScreen.lua"),
    ("ReplicatedStorage.UIKit", "SettingsData", "ModuleScript", "settings/SettingsData.lua"),
    ("ReplicatedStorage.UIKit", "SettingsKit", "ModuleScript", "settings/SettingsKit.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "SettingsConfig", "ModuleScript", "settings/SettingsConfig.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "SettingsEffectsController", "ModuleScript", "settings/SettingsEffectsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "CombatFeedbackController", "ModuleScript", "hud/CombatFeedbackController.lua"),
    ("ReplicatedStorage.Modules.Shared", "Binds", "ModuleScript", "settings/Binds.lua"),
    ("ReplicatedFirst", "LoadingScreen", "LocalScript", "intro/LoadingScreen.lua"),  # same file in both places; QuickIntro only in the match place
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
    (C, "PropController", "set/PropController.lua"),
    (C, "AimPoseController", "set/AimPoseController.lua"),
    (C + ".LobbyUIController", "Armory", "lobby/Armory.lua"),
]

# small source patches to scripts the UI session doesn't own (idempotent)
PATCHES = [
    # pads wait for real players in Studio too (RIVALS); set true to test a full bay alone
    "local m = game.ReplicatedStorage.Modules.Shared.Config.LobbyConfig; m.Source = m.Source:gsub('LobbyConfig%.StudioSoloStart = true', 'LobbyConfig.StudioSoloStart = false')",
]


# ---- --match: the MATCH PLACE gets the same gameplay [SET] scripts + settings plumbing, so every lobby setting carries
# over (2026-10-16, Edward: "do the recommended"). Its controllers were the lobby originals minus the Training gate (only
# CoverController's tutorial EAutoRush differed, merged into set/CoverController.lua), so the gate is a pass-through shim there.
# Missing parent folders (UIKit) are created. Run it only in the combined match-place pass with the Tacticals session.
MATCH_FILES = [
    ("ReplicatedStorage.Modules.Shared", "TrainingGate", "ModuleScript", "matchplace/TrainingGate.lua"),
    ("ReplicatedStorage.Modules.Shared", "Binds", "ModuleScript", "settings/Binds.lua"),
    ("ReplicatedStorage.UIKit", "Theme", "ModuleScript", "matchplace/Theme.lua"),
    ("ReplicatedStorage.UIKit", "Tac", "ModuleScript", "lobby/Tac.lua"),
    ("ReplicatedStorage.UIKit", "Kit", "ModuleScript", "lobby/Kit.lua"),
    ("ReplicatedStorage.UIKit", "SettingsData", "ModuleScript", "settings/SettingsData.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "SettingsConfig", "ModuleScript", "settings/SettingsConfig.lua"),
    ("ServerScriptService", "SettingsBridge", "Script", "matchplace/SettingsBridge.server.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "SettingsEffectsController", "ModuleScript", "settings/SettingsEffectsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "CombatFeedbackController", "ModuleScript", "hud/CombatFeedbackController.lua"),
    ("StarterPlayer.StarterPlayerScripts", "MatchFlowUI", "LocalScript", "match/MatchFlowUI.client.lua"),
    ("StarterPlayer.StarterPlayerScripts", "DuelHUD", "LocalScript", "match/DuelHUD.client.lua"),
    ("ReplicatedFirst", "LoadingScreen", "LocalScript", "intro/LoadingScreen.lua"),
]
MATCH_SET_FILES = [e for e in SET_FILES if e[1] not in ("TrainingBinsController", "Armory")]
# old pass-38 match HUD pieces that DuelHUD / MatchFlowUI replace (see the file)
MATCH_PATCHES = [open(os.path.join(HERE, 'matchplace', 'match_patches.lua'), encoding='utf-8').read()]
if '--match' in sys.argv:
    FILES, SET_FILES, PATCHES = MATCH_FILES, MATCH_SET_FILES, MATCH_PATCHES


def long_string(s):
    n = 0
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


def build():
    parts = [
        "local CHS = game:GetService('ChangeHistoryService'); local rec = CHS:TryBeginRecording('Deploy lobby UI (UI session)')",
        "local function at(path) local o = game; for p in path:gmatch('[^%.]+') do o = o:FindFirstChild(p) or error('missing ' .. path) end; return o end",
        "local function dir(path) local o = game; for p in path:gmatch('[^%.]+') do local c = o:FindFirstChild(p); if not c then c = Instance.new('Folder'); c.Name = p; c.Parent = o end; o = c end; return o end",
        "local function put(parent, name, class, src) local s = parent:FindFirstChild(name); if s and s.ClassName ~= class then s:Destroy(); s = nil end; if not s then s = Instance.new(class); s.Name = name; s.Parent = parent end; s.Source = src end",
    ]
    for parent, name, cls, path in FILES:
        src = open(os.path.join(HERE, path), encoding='utf-8').read()
        parts.append(f"put({'dir' if '--match' in sys.argv else 'at'}('{parent}'), '{name}', '{cls}', {long_string(src)})")
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


# ---- guard: never overwrite a script someone else edited since our last deploy (2026-10-16)
# After each deploy the live Source hash of every file we write is stored per studio in _deployed_hashes.json; before the next
# deploy the live hashes are read again and any mismatch aborts (pull it, merge the edit into our source, deploy). --force skips.
HASHES = os.path.join(HERE, '_deployed_hashes.json')

def targets():
    out = [(parent + '.' + name) for parent, name, cls, path in FILES]
    out += [(parent + '.' + name) for parent, name, path in SET_FILES]
    return out

def live_hashes(sid):
    # a fingerprint per script, computed in Studio (full sources would overflow the bridge's 100 KB output)
    paths = targets()
    lua = ("local HS = game:GetService('HttpService') local out = {} "
           "local function at(path) local o = game; for p in path:gmatch('[^%.]+') do o = o and o:FindFirstChild(p) end; return o end "
           "local function fp(src) src = src:gsub(string.char(13), '') local h = 5381 "
           "for i = 1, #src do h = (h * 33 + string.byte(src, i)) % 4294967296 end return #src .. ':' .. h end "
           "for _, p in ipairs(HS:JSONDecode([==[" + json.dumps(paths) + "]==])) do local s = at(p); out[p] = s and fp(s.Source) or 'missing' end "
           "return HS:JSONEncode(out)")
    tmp = os.path.join(HERE, '_hash_payload.json')
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": lua}, open(tmp, 'w', encoding='utf-8'))
    env = dict(os.environ, PYTHONIOENCODING='utf-8', MCP_TIMEOUT='180')
    r = subprocess.run([sys.executable, MCP, 'call', 'execute_luau', tmp], capture_output=True, text=True, env=env, encoding='utf-8', cwd=os.path.dirname(MCP))
    txt = (r.stdout or '').strip()
    return json.loads(txt[txt.find('{'):txt.rfind('}') + 1])


if __name__ == '__main__':
    sid = sys.argv[1]
    force = '--force' in sys.argv
    saved = json.load(open(HASHES, encoding='utf-8')) if os.path.exists(HASHES) else {}
    if sid in saved and not force:
        now = live_hashes(sid)
        changed = [k for k, h in saved[sid].items() if k in now and now[k] != h]
        if changed:
            print('ABORT: edited live since our last deploy (pull + merge first, or --force):')
            for c in changed: print('  ' + c)
            sys.exit(2)
    payload = os.path.join(HERE, '_deploy_payload.json')
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": build()}, open(payload, 'w', encoding='utf-8'))
    env = dict(os.environ, PYTHONIOENCODING='utf-8', MCP_TIMEOUT='300')
    r = subprocess.run([sys.executable, MCP, 'call', 'execute_luau', payload], capture_output=True, text=True, env=env, encoding='utf-8', cwd=os.path.dirname(MCP))
    print((r.stdout or r.stderr).strip()[-400:])
    if 'deployed' in (r.stdout or ''):
        saved[sid] = live_hashes(sid)
        json.dump(saved, open(HASHES, 'w', encoding='utf-8'), indent=1)
