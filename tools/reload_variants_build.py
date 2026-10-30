"""Build fix/reload_variants.lua [RELOADVAR] from fix/reload_variants/* and the edit list below, checking every anchor against
dumps of the places first. Usage: python -I tools/reload_variants_build.py [src_dir ...]
(default: out/move_feel/src and any out/move_feel/src_* dumps; dumps made with out/move_rework/rbxl_src.py <place.rbxl> <dir>).
Indentation here: 4 spaces at the start of a line = one tab in the Lua sources (T() converts).
Each edit (old, new): old must occur exactly once (token boundary) in every place that has the script, unless it already has new."""
import os, sys, glob

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ROUND = 1
DIR = "fix/reload_variants"


def T(s):
    out = []
    for line in s.split("\n"):
        n = 0
        while line.startswith("    "):
            line = line[4:]
            n += 1
        out.append("\t" * n + line)
    return "\n".join(out)


def E(old, new):
    return (T(old), T(new))


CC = "StarterPlayer.StarterPlayerScripts.Client.Controllers."

WEAPONCONTROLLER = [
    E('''    RunService.RenderStepped:Connect(updateBlockedMarker)
end

return controller
''', '''    RunService.RenderStepped:Connect(updateBlockedMarker)
end

do -- [RELOADVAR] ammo-aware reload variants (fix/reload_variants.lua; ranges in Config.ReloadVariantConfig). Wraps the reload
    -- clip choice and the shell clip from outside: the variant plays in the slot the base clip would have used (so the cancel list,
    -- the left hand and a shot cutting a shell work unchanged) and is fitted to the gun's ReloadTime by the same code as before.
    local okRV, RVC = pcall(function() return require(Shared:WaitForChild("Config"):WaitForChild("ReloadVariantConfig", 5)) end)
    -- (needs the final animation pass's _ReloadClip / _PlayShell and AnimLib: without them, the old reloads stay)
    if okRV and type(RVC) == "table" and type(controller._ReloadClip) == "function" and type(controller._PlayShell) == "function"
        and AnimLib1030 ~= nil then
        local baseReloadClip, basePlayShell = controller._ReloadClip, controller._PlayShell
        local function variantTrack(config, name: string, suffix: string): AnimationTrack?
            local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
            if not animator then return nil end
            local t = AnimLib1030.Load(animator, (config.AnimationSourcePrefix or "") .. name .. suffix, Enum.AnimationPriority.Action4, false)
            if t then
                local okFX, FX = pcall(Get, "ReloadVariantFX")
                if okFX and FX and FX.Hook then FX.Hook(character, t) end
            end
            return t
        end
        -- put every slot this reload swapped back to its own clip
        local function restore(eq)
            for key, orig in (eq.rvOrig or {}) do eq.tracks[key] = orig or nil end
            eq.rvOrig = {}
        end
        local function swap(eq, config, slot: string, variant: string?): boolean
            if not variant then return false end
            local any = false
            for _, suffix in { "", "Left" } do
                local t = variantTrack(config, variant, suffix)
                if t then
                    local key = slot .. suffix
                    if eq.rvOrig[key] == nil then eq.rvOrig[key] = eq.tracks[key] or false end
                    eq.tracks[key] = t
                    any = true
                end
            end
            return any
        end
        controller._ReloadClip = function(config)
            local eq = equipped
            if eq then restore(eq) end
            local clip = baseReloadClip(config)
            if not eq or RVC.Enabled == false then return clip end
            local ammo = getAmmo()
            eq.rvShellN, eq.rvEmptyStart = 0, ammo == 0
            if config.ShellReload then
                if clip == "ReloadStart" and ammo == 0 then swap(eq, config, "ReloadStart", RVC.Shell.StartDry) end
                eq.rvLastClip = clip
                return clip
            end
            local v = RVC.Pick(eq.tool and eq.tool:GetAttribute("WeaponId"), ammo)
            eq.rvLastClip = swap(eq, config, clip, v) and v or clip
            return clip
        end
        controller._PlayShell = function(config)
            local eq = equipped
            if eq and RVC.Enabled ~= false and config.ShellReload then
                for _, suffix in { "", "Left" } do -- a shell slot swapped by the shell before goes back first
                    local key = "ReloadShell" .. suffix
                    if eq.rvOrig and eq.rvOrig[key] ~= nil then eq.tracks[key] = eq.rvOrig[key] or nil eq.rvOrig[key] = nil end
                end
                eq.rvOrig = eq.rvOrig or {}
                local n, ammo = eq.rvShellN or 0, getAmmo()
                local v = nil
                if n == 0 and eq.rvEmptyStart then v = RVC.Shell.First
                elseif ammo >= (config.MagazineSize or 0) - 1 then v = RVC.Shell.Last
                elseif n % 2 == 1 then v = RVC.Shell.Alternate end
                eq.rvShellN = n + 1
                swap(eq, config, "ReloadShell", v)
                eq.rvLastClip = v or "ReloadShell"
            end
            return basePlayShell(config)
        end
    end
end

return controller
'''),
]

TARGETS = [
    (CC + "WeaponController", WEAPONCONTROLLER, False),
]

MODULES = [  # (file, parent path, name)
    ("ReloadVariantConfig.lua", "ReplicatedStorage.Modules.Shared.Config", "ReloadVariantConfig"),
    ("ReloadVariantFX.lua", "StarterPlayer.StarterPlayerScripts.Client.Controllers", "ReloadVariantFX"),
]


def boundary_ok(s, a, b):
    import re
    ident = re.compile(r"[\w]")
    if a > 0 and ident.match(s[a]) and ident.match(s[a - 1]): return False
    if b < len(s) and ident.match(s[b - 1]) and ident.match(s[b]): return False
    return True


def check(dirs):
    bad = 0
    for d in dirs:
        for path, edits, optional in TARGETS:
            f = os.path.join(d, path + ".lua")
            if not os.path.exists(f):
                print(f"{os.path.basename(d)}: {path.split('.')[-1]} {'n/a' if optional else 'MISSING'}")
                if not optional: bad += 1
                continue
            s = open(f, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
            marks = []
            for i, (old, new) in enumerate(edits, 1):
                if new in s: marks.append(f"{i}="); continue
                n = s.count(old)
                if n != 1:
                    marks.append(f"{i}!{n}"); bad += 1; continue
                a = s.find(old)
                if not boundary_ok(s, a, a + len(old)):
                    marks.append(f"{i}!b"); bad += 1; continue
                s = s.replace(old, new, 1)
                marks.append(f"{i}+")
            print(f"{os.path.basename(d)}: {path.split('.')[-1]} {' '.join(marks)}")
    return bad


def lua_long(s):
    lv = 1
    while ("]" + "=" * lv + "]") in s: lv += 1
    return "[" + "=" * lv + "[\n" + s + "]" + "=" * lv + "]"


def build():
    head = open(os.path.join(ROOT, DIR, "installer_head.lua"), encoding="utf-8").read()
    body = open(os.path.join(ROOT, DIR, "installer_body.lua"), encoding="utf-8").read()
    out = [head, f"local ROUND = {ROUND}\n", "local MODULES = {\n"]
    for fn, parent, name in MODULES:
        src = open(os.path.join(ROOT, DIR, fn), encoding="utf-8").read()
        out.append(f"\t{{ parent = {parent!r}, name = {name!r}, src = {lua_long(src)} }},\n".replace("'", '"'))
    out.append("}\nlocal TARGETS = {\n")
    for path, edits, optional in TARGETS:
        out.append(f"\t{{ path = {lua_long(path)}, optional = {'true' if optional else 'false'}, soft = false, edits = {{\n")
        for old, new in edits:
            out.append(f"\t\t{{ {lua_long(old)}, {lua_long(new)} }},\n")
        out.append("\t} },\n")
    out.append("}\n")
    out.append(body)
    open(os.path.join(ROOT, "fix/reload_variants.lua"), "w", encoding="utf-8", newline="\n").write("".join(out))
    print("wrote fix/reload_variants.lua")


if __name__ == "__main__":
    dirs = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "out/move_feel/src*")))
    dirs = [d for d in dirs if os.path.isdir(d) and not d.endswith("src_pre")] or dirs
    bad = check(dirs)
    if bad:
        print(f"{bad} anchor problems: nothing written"); sys.exit(1)
    build()
