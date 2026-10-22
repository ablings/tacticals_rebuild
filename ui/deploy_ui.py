"""Deploy the UI session's lobby UI sources into a Studio (Edit mode) through the Studio MCP bridge.
Usage: python ui/deploy_ui.py <studio_id>
Each entry: target path under game, class, source file. Existing scripts keep their instance; only Source changes."""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MCP = os.path.expanduser('~/Documents/rivals_practice/mcpcli.py')
FILES = [
    ("ReplicatedStorage.UIKit", "Theme", "ModuleScript", "matchplace/Theme.lua"),  # (2026-10-20) one palette for both places (was the hub's own copy)
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
    ("ReplicatedStorage.UIKit", "RankArt", "ModuleScript", "ranked/RankArt.lua"),
    ("ReplicatedStorage.UIKit", "KillIcons", "ModuleScript", "match/KillIcons.lua"),  # (2026-10-20) kill feed / killer card silhouettes
    ("ReplicatedStorage.UIKit", "Badges", "ModuleScript", "hud/Badges.lua"),  # (2026-10-20) Roblox verified / Premium glyphs with names
    ("ReplicatedStorage.UIKit", "Logo", "ModuleScript", "lobby/Logo.lua"),  # (2026-10-20) the TACTICALS logo for loading / teleport screens
    ("ReplicatedStorage.UIKit", "RankedScreen", "ModuleScript", "ranked/RankedScreen.lua"),
    ("ReplicatedStorage.UIKit", "Tac", "ModuleScript", "lobby/Tac.lua"),
    ("ReplicatedStorage.UIKit", "Kit", "ModuleScript", "lobby/Kit.lua"),
    ("ReplicatedStorage.UIKit", "ShopScreen", "ModuleScript", "shop/ShopScreen.lua"),
    ("ReplicatedStorage.UIKit", "SettingsData", "ModuleScript", "settings/SettingsData.lua"),
    ("ReplicatedStorage.UIKit", "SettingsKit", "ModuleScript", "settings/SettingsKit.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "SettingsConfig", "ModuleScript", "settings/SettingsConfig.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "WeaponAbilities", "ModuleScript", "settings/WeaponAbilities.lua"),  # Kit screen ability rows (notes/weapon_abilities.md)
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "SettingsEffectsController", "ModuleScript", "settings/SettingsEffectsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "CombatFeedbackController", "ModuleScript", "hud/CombatFeedbackController.lua"),
    ("ReplicatedStorage.UIKit", "PlayerCards", "ModuleScript", "hud/PlayerCards.lua"),
    ("ReplicatedStorage.UIKit", "PartyScreen", "ModuleScript", "hud/PartyScreen.lua"),
    ("ReplicatedStorage.UIKit", "PlayRow", "ModuleScript", "lobby/PlayRow.lua"),
    ("ReplicatedStorage.UIKit", "FlatIcons", "ModuleScript", "lobby/FlatIcons.lua"),
    ("ReplicatedStorage.UIKit", "SettingsTheme", "ModuleScript", "pseudolobby/hub/SettingsTheme.lua"),  # (2026-10-21 lobby revamp) live == this file before the font swap  # (2026-10-21 lobby revamp Phase B) flat cream dock / Settings tab icons
    ("ReplicatedStorage.UIKit", "MissionsScreen", "ModuleScript", "pseudolobby/hub/MissionsScreen.lua"),  # (2026-10-21 lobby revamp) live == this file before the revamp
    ("ReplicatedStorage.UIKit", "PseudoLobby", "ModuleScript", "pseudolobby/PseudoLobby.lua"),  # no-op in the hub; the match places' after-match lobby
    ("ReplicatedStorage.UIKit", "Notify", "ModuleScript", "hud/Notify.lua"),  # RIVALS banner + Inbox (hub + match)
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "TouchControlsController", "ModuleScript", "touch/TouchControlsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "PromptsController", "ModuleScript", "hud/PromptsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "GamepadNavController", "ModuleScript", "hud/GamepadNavController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "MatchFoundGate", "ModuleScript", "hud/MatchFoundGate.lua"),  # (2026-10-19) match found: every lobby UI off, MATCH FOUND only
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
    (C + ".WeaponController", "WeaponFeel", "set/WeaponFeel.lua"),  # [FEEL] (2026-10-21) equip bounce / sway / kick springs
    (C, "MovementController", "set/MovementController.lua"),
    (C, "CoverController", "set/CoverController.lua"),
    (C, "HotbarController", "set/HotbarController.lua"),
    (C, "GadgetController", "set/GadgetController.lua"),
    (C, "HealthBarController", "set/HealthBarController.lua"),
    (C, "TrainingBinsController", "set/TrainingBinsController.lua"),
    (C, "PropController", "set/PropController.lua"),
    (C, "AimPoseController", "set/AimPoseController.lua"),
    (C, "CinematicCamera", "set/CinematicCamera.lua"),
    (C, "ScopeController", "set/ScopeController.lua"),  # (2026-10-18) spectating follows the watched player's scope
    ("ReplicatedStorage.UIKit", "SettingsScreen", "set/SettingsScreen.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.GUIs", "HUD", "set/HUD.lua"),
    (C + ".LobbyUIController", "Armory", "lobby/Armory.lua"),
]

# small source patches to scripts the UI session doesn't own (idempotent)
PATCHES = [
    # pads wait for real players in Studio too (RIVALS); set true to test a full bay alone
    "local m = game.ReplicatedStorage.Modules.Shared.Config.LobbyConfig; m.Source = m.Source:gsub('LobbyConfig%.StudioSoloStart = true', 'LobbyConfig.StudioSoloStart = false')",
    # (2026-10-20) LobbyUIController.Icons (Studio-only source; snapshot in pseudolobby/hub/Icons.lua): the Riot Shield shows its
    # face (plate in XY, front at -Z = the icon camera's side) instead of the melee side view that drew it edge-on (Kit, picker)
    r'''local m = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.LobbyUIController:FindFirstChild("Icons")
    if m and not m.Source:find("RiotShield", 1, true) then
        local ins = "\tif itemId == \"RiotShield\" then\n\t\tlocal s = cloneTool(\"Melee\", itemId)\n\t\tif #s:GetChildren() > 0 then return s, CFrame.Angles(math.rad(8), math.rad(-28), 0), 1 end\n\t\ts:Destroy()\n\tend\n"
        local src = m.Source
        local a = src:find('local melee = cloneTool("Melee", itemId)', 1, true)
        if a then
            local ls = a
            while ls > 1 and src:sub(ls - 1, ls - 1) ~= "\n" do ls -= 1 end
            m.Source = src:sub(1, ls - 1) .. ins .. src:sub(ls)
        else
            warn("[deploy] Icons.Item: melee line not found, Riot Shield view not patched")
        end
    end''',
]


# ---- --match: the MATCH PLACE gets the same gameplay [SET] scripts + settings plumbing, so every lobby setting carries
# over (2026-10-16, Edward: "do the recommended"). Its controllers were the lobby originals minus the Training gate (only
# CoverController's tutorial EAutoRush differed, merged into set/CoverController.lua), so the gate is a pass-through shim there.
# Missing parent folders (UIKit) are created. Run it only in the combined match-place pass with the Tacticals session.
MATCH_FILES = [
    ("ReplicatedStorage.Modules.Shared", "TrainingGate", "ModuleScript", "matchplace/TrainingGate.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "TutorialController", "ModuleScript", "tutorial/TutorialController.lua"),  # (2026-10-21) tutorial UI redesign; baseline 8d79ff9 = the live one
    ("ReplicatedStorage.Modules.Shared", "Binds", "ModuleScript", "settings/Binds.lua"),
    ("ReplicatedStorage.UIKit", "Theme", "ModuleScript", "matchplace/Theme.lua"),
    ("ReplicatedStorage.UIKit", "Tac", "ModuleScript", "lobby/Tac.lua"),
    ("ReplicatedStorage.UIKit", "Kit", "ModuleScript", "lobby/Kit.lua"),
    ("ReplicatedStorage.UIKit", "SettingsData", "ModuleScript", "settings/SettingsData.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "SettingsConfig", "ModuleScript", "settings/SettingsConfig.lua"),
    ("ReplicatedStorage.Modules.Shared.Config", "WeaponAbilities", "ModuleScript", "settings/WeaponAbilities.lua"),  # Kit screen ability rows (notes/weapon_abilities.md)
    ("ServerScriptService", "SettingsBridge", "Script", "matchplace/SettingsBridge.server.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "SettingsEffectsController", "ModuleScript", "settings/SettingsEffectsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "CombatFeedbackController", "ModuleScript", "hud/CombatFeedbackController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "TouchControlsController", "ModuleScript", "touch/TouchControlsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "PromptsController", "ModuleScript", "hud/PromptsController.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client.Controllers", "GamepadNavController", "ModuleScript", "hud/GamepadNavController.lua"),
    ("StarterPlayer.StarterPlayerScripts", "MatchFlowUI", "LocalScript", "match/MatchFlowUI.client.lua"),
    ("StarterPlayer.StarterPlayerScripts", "DuelHUD", "LocalScript", "match/DuelHUD.client.lua"),
    ("ReplicatedFirst", "LoadingScreen", "LocalScript", "intro/LoadingScreen.lua"),
    ("ReplicatedStorage.UIKit", "RankArt", "ModuleScript", "ranked/RankArt.lua"),
    ("ReplicatedStorage.UIKit", "KillIcons", "ModuleScript", "match/KillIcons.lua"),  # (2026-10-20) kill feed / killer card silhouettes
    ("ReplicatedStorage.UIKit", "Badges", "ModuleScript", "hud/Badges.lua"),
    ("ReplicatedStorage.UIKit", "Logo", "ModuleScript", "lobby/Logo.lua"),
]
# ---- the after-match pseudo lobby (2026-10-18, lead session's split): the lobby's client side rides along in the match places.
# Own files run as-is (UIKit.PseudoLobby: WaitMap / Active / Guard, no-op in the hub). The hub's lobby look scripts that other
# sessions own come from snapshots (ui/pseudolobby/snapshot_hub.py) as TEMPLATES in ReplicatedStorage.PseudoLobbyClient:
# PseudoLobbyRunner clones them into PlayerScripts each time the map comes out and destroys them when it goes back (the
# server re-sends a fresh map copy every PostMatch, so they must start over). A controller template is a ModuleHost
# LocalScript with the controller as its "Module" child. Left out on purpose (the lead greys them out): training / range /
# exfil / pads / AssetCheck / WorldMoodFX (queue backdrop).
UK, CC = "ReplicatedStorage.UIKit", "StarterPlayer.StarterPlayerScripts.Client.Controllers"
PSEUDO_FILES = [
    (UK, "PseudoLobby", "ModuleScript", "pseudolobby/PseudoLobby.lua"),
    (UK, "Notify", "ModuleScript", "hud/Notify.lua"),
    (UK, "PlayRow", "ModuleScript", "lobby/PlayRow.lua"),
    (UK, "PlayerCards", "ModuleScript", "hud/PlayerCards.lua"),
    (UK, "PartyScreen", "ModuleScript", "hud/PartyScreen.lua"),
    (UK, "PlayScreen", "ModuleScript", "play/PlayScreen.lua"),
    (UK, "CodesScreen", "ModuleScript", "lobby/CodesScreen.lua"),
    (UK, "RankedScreen", "ModuleScript", "ranked/RankedScreen.lua"),
    (UK, "ShopScreen", "ModuleScript", "shop/ShopScreen.lua"),
    (UK, "SettingsKit", "ModuleScript", "settings/SettingsKit.lua"),
    (UK, "SettingsScreen", "ModuleScript", "set/SettingsScreen.lua"),
    (CC, "LobbyHudController", "ModuleScript", "hud/LobbyHudController.lua"),
    (CC, "NameplatesController", "ModuleScript", "hud/NameplatesController.lua"),
    (CC, "LobbyUIController", "ModuleScript", "lobby/LobbyUIController.lua"),
    (CC + ".LobbyUIController", "Armory", "ModuleScript", "lobby/Armory.lua"),
]
PL_FOLDER = "ReplicatedStorage.PseudoLobbyClient"
# the after-match map is the hub's shifted by (0, 0, 2600) (lead session): hub coordinates in the snapshots move with it
HUB_PATCHES = {
    "pseudolobby/hub/RoomFX.lua": [
        ('local c = CENTRES[h:GetAttribute("Room")]',
         'local c = CENTRES[h:GetAttribute("Room")]; if c then c += MAP_SHIFT end -- [PSEUDO] the after-match map sits at +2600 Z'),
        ('local CENTRES = {',
         'local MAP_SHIFT = game:GetService("ReplicatedStorage"):GetAttribute("PseudoLobbyMap") ~= nil and Vector3.new(0, 0, 2600) or Vector3.zero -- [PSEUDO]\nlocal CENTRES = {'),
    ],
}
def _hub():
    man = json.load(open(os.path.join(HERE, 'pseudolobby', 'hub', 'manifest.json'), encoding='utf-8'))
    out = [("StarterPlayer.StarterPlayerScripts", "PseudoLobbyRunner", "LocalScript", "pseudolobby/PseudoLobbyRunner.client.lua")]
    for parent, name, cls, path in man:
        if name in ("Theme", "WorldMoodFX"): continue  # (Theme: the match place's is the same file)
        if name == "UITheme":
            out.append(("ReplicatedStorage.Modules.Shared", "UITheme", "ModuleScript", path))  # the hub's menu look (same API)
        elif cls == "LocalScript":
            out.append((PL_FOLDER, name, "LocalScript", path))
        elif parent == CC:
            out.append((PL_FOLDER, name, "LocalScript", "pseudolobby/ModuleHost.client.lua"))
            out.append((PL_FOLDER + "." + name, "Module", "ModuleScript", path))
        else:
            out.append((parent, name, cls, path))
    return out
MATCH_SET_FILES = [e for e in SET_FILES if e[1] not in ("TrainingBinsController", "Armory", "SettingsScreen")]
# old pass-38 match HUD pieces that DuelHUD / MatchFlowUI replace (see the file)
MATCH_PATCHES = [open(os.path.join(HERE, 'matchplace', 'match_patches.lua'), encoding='utf-8').read()]
# (2026-10-16) the split places: Tutorial / Matchmaking / Ranked are one codebase (ReplicatedStorage.PlaceKind, set by the lead
# session's installer), so they take the match-place UI set. Per-kind differences: notes/place_split.md.
PLACE_KIND = next((k for k in ('tutorial', 'matchmaking', 'ranked') if '--' + k in sys.argv), None)
if '--match' in sys.argv or PLACE_KIND:
    FILES, SET_FILES, PATCHES = MATCH_FILES + PSEUDO_FILES + _hub(), MATCH_SET_FILES, MATCH_PATCHES + [
        # a match place: clients tell it from the hub by this attribute (the lead's server sets it true once the map is out)
        "local RS = game:GetService('ReplicatedStorage'); if RS:GetAttribute('PseudoLobbyMap') == nil then RS:SetAttribute('PseudoLobbyMap', false) end"]


def long_string(s):
    n = 0
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


SKIP = {x for a in sys.argv if a.startswith('--skip=') for x in a[7:].split(',') if x}


def build():
    parts = [
        "local CHS = game:GetService('ChangeHistoryService'); local rec = CHS:TryBeginRecording('Deploy lobby UI (UI session)')",
        "local function at(path) local o = game; for p in path:gmatch('[^%.]+') do o = o:FindFirstChild(p) or error('missing ' .. path) end; return o end",
        "local function dir(path) local o = game; for p in path:gmatch('[^%.]+') do local c = o:FindFirstChild(p); if not c then c = Instance.new('Folder'); c.Name = p; c.Parent = o end; o = c end; return o end",
        "local function put(parent, name, class, src) local s = parent:FindFirstChild(name); if s and s.ClassName ~= class then s:Destroy(); s = nil end; if not s then s = Instance.new(class); s.Name = name; s.Parent = parent end; s.Source = src end",
    ]
    for entry in FILES:
        parent, name, cls, path = entry[:4]
        if parent + '.' + name in SKIP: continue  # --skip=Parent.Name,...: leave someone else's live edit alone
        src = open(os.path.join(HERE, path), encoding='utf-8').read()
        for old, new in HUB_PATCHES.get(path, []):  # small fixes to the hub snapshots for the shifted after-match map
            if src.count(old) != 1: raise SystemExit(f'hub patch no longer matches {path}: re-check it after a new snapshot')
            src = src.replace(old, new)
        parts.append(f"put({'dir' if ('--match' in sys.argv or PLACE_KIND) else 'at'}('{parent}'), '{name}', '{cls}', {long_string(src)})")
    parts.append("local SS = game:GetService('ServerStorage'); local bin = SS:FindFirstChild('_RebuildRemoved') or Instance.new('Folder'); bin.Name = '_RebuildRemoved'; bin.Parent = SS")
    for parent, name, path in SET_FILES:
        if parent + '.' + name in SKIP: continue
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
    out = [(e[0] + '.' + e[1]) for e in FILES]
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
