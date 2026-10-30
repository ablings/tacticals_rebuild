"""Build fix/move_feel_1030.lua [MOVEFEEL] from fix/move_feel_1030/* and the edit list below, checking every anchor against
dumps of the places first. Usage: python -I tools/move_feel_build.py [src_dir ...]
(default: out/move_feel/src and any out/move_feel/src_* dumps; dumps made with out/move_rework/rbxl_src.py <place.rbxl> <dir>).
Indentation here: 4 spaces at the start of a line = one tab in the Lua sources (T() converts).
Each edit (old, new): old must occur exactly once (token boundary) in every place that has the script, unless it already has new."""
import os, sys, glob

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ROUND = 1
DIR = "fix/move_feel_1030"


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
MFREQ = 'local MF1030 = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MoveFeelConfig")) -- [MOVEFEEL]'

MOVEMENT = [
    E('''local SetStance = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Movement"):WaitForChild("SetStance")
''', '''local SetStance = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Movement"):WaitForChild("SetStance")
''' + MFREQ + '''
local pendingSlide1030: number? = nil -- [MOVEFEEL] a slide asked for in the air / just before its cooldown ended
'''),
    # the crouch idle / walk / slide play over the gun Hold (which keys the legs)
    E('''            if ok then
                track.Looped = true
                result[name] = track
''', '''            if ok then
                track.Looped = true
                if name ~= "Slide" and MF1030.Enabled ~= false and MF1030.LocoPriority and Enum.AnimationPriority[MF1030.LocoPriority] then track.Priority = Enum.AnimationPriority[MF1030.LocoPriority] end -- [MOVEFEEL] over the gun Hold
                result[name] = track
'''),
    # the slide's turn to its direction kept the speed (setting the CFrame zeroed it for a frame: 25 -> 7 studs/s)
    E('''    root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
    local c = getControls()
    if c then c:Disable() end
    setPose("Slide")
''', '''    local keepV1030 = root.AssemblyLinearVelocity -- [MOVEFEEL]
    root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
    if MF1030.Enabled ~= false then root.AssemblyLinearVelocity = dir * math.max((keepV1030 * FLAT).Magnitude, Config.Slide.EndSpeed) + Vector3.new(0, keepV1030.Y, 0) end -- [MOVEFEEL] no one-frame stall
    local c = getControls()
    if c then c:Disable() end
    setPose("Slide")
'''),
    # crouch / slide pose fades from the config
    E('''            if not track.IsPlaying then track:Play(0.2) end
            if speed then track:AdjustSpeed(speed) end
        elseif track.IsPlaying then
            track:Stop(0.2)
''', '''            if not track.IsPlaying then track:Play(MF1030.Fades.CrouchPose) end -- [MOVEFEEL] (0.2)
            if speed then track:AdjustSpeed(speed) end
        elseif track.IsPlaying then
            track:Stop(trackName == "Slide" and MF1030.Fades.SlideOut or MF1030.Fades.CrouchPose) -- [MOVEFEEL] (0.2)
'''),
    # the buffered slide: queue
    E('''-- // Input
local function onInputBegan(input: InputObject, gameProcessed: boolean)
''', '''-- [MOVEFEEL] a slide pressed while sprinting in the air, or in the last Buffer.Slide s of its cooldown: queued, done on the first
-- frame it can be (no dead press, no crouch instead)
local function queueSlide1030(): boolean
    local B = MF1030.Buffer
    if MF1030.Enabled == false or not B or B.Enabled == false then return false end
    if not isAlive() or not sprinting or crouched or sliding then return false end
    if CoverController and (CoverController.IsInCover() or CoverController.IsMoving()) then return false end
    local inAir = (humanoid :: Humanoid).FloorMaterial == Enum.Material.Air
    local left = Config.Slide.Cooldown - (os.clock() - lastSlide)
    if inAir or (left > 0 and left <= B.Slide) then
        pendingSlide1030 = os.clock()
        return true
    end
    return false
end

-- // Input
local function onInputBegan(input: InputObject, gameProcessed: boolean)
'''),
    E('''    if slideKey and Binds.Matches(localPlayer, "Slide", input, nil) then
''', '''    if slideKey and Binds.Matches(localPlayer, "Slide", input, nil) then
        if queueSlide1030() then return end -- [MOVEFEEL]
'''),
    E('''    -- sprinting: C slides instead of crouching ([SET] unless Easy Slide is off)
''', '''    if localPlayer:GetAttribute("Setting_EasySlide") ~= false and queueSlide1030() then return end -- [MOVEFEEL] buffered slide
    -- sprinting: C slides instead of crouching ([SET] unless Easy Slide is off)
'''),
    # the buffered slide: do it
    E('''    if updateSlide() then return end
''', '''    if pendingSlide1030 then -- [MOVEFEEL] the buffered slide, on the first frame it can happen
        local B = MF1030.Buffer
        if os.clock() - pendingSlide1030 > B.Slide + 0.25 or not sprinting or crouched then
            pendingSlide1030 = nil
        elseif not sliding and (humanoid :: Humanoid).FloorMaterial ~= Enum.Material.Air and os.clock() - lastSlide > Config.Slide.Cooldown
            and not (CoverController and (CoverController.IsInCover() or CoverController.IsMoving())) then
            pendingSlide1030 = nil
            startSlide()
        end
    end
    if updateSlide() then return end
'''),
]

COVER = [
    E('''local pendingJump: { at: number, fast: boolean, double: boolean? }? = nil -- Space pressed a moment early
''', '''local pendingJump: { at: number, fast: boolean, double: boolean? }? = nil -- Space pressed a moment early
''' + MFREQ + '''
local airJumpAt1030: number? = nil -- [MOVEFEEL] Space pressed in the air with nothing to do: replayed on touchdown
local vaultJumpAt1030: number? = nil -- [MOVEFEEL] Space pressed mid-vault: a climb / pull-up on landing
local replayJump1030 = nil -- [MOVEFEEL] = onJumpKey (assigned once it exists)
'''),
    E('''    -- E pressed during a vault: as soon as you've landed, go to the cover you're pointing at
''', '''    -- [MOVEFEEL] buffered Space: mid-vault -> climb / pull-up on landing; in the air -> the whole Space action on touchdown
    if MF1030.Enabled ~= false and MF1030.Buffer and MF1030.Buffer.Enabled ~= false and not move and not vault and not dive then
        local B = MF1030.Buffer
        if vaultJumpAt1030 then
            local at = vaultJumpAt1030
            vaultJumpAt1030 = nil
            if os.clock() - at <= B.AfterVault and isAlive() and not cover and not localPlayer:GetAttribute("SneakDisabled") then
                local ledge, stand = findLedge()
                if ledge and stand then startClimb(ledge, stand) end
            end
        elseif airJumpAt1030 and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            local at = airJumpAt1030
            airJumpAt1030 = nil
            if os.clock() - at <= B.AirJump and replayJump1030 then replayJump1030("CoverVault", Enum.UserInputState.Begin) end
        end
    elseif vault == nil and move == nil and dive == nil then
        vaultJumpAt1030, airJumpAt1030 = nil, nil
    end
    -- E pressed during a vault: as soon as you've landed, go to the cover you're pointing at
'''),
    E('''    if isAlive() and vault then return Enum.ContextActionResult.Sink end -- (Q mid-vault = cover on landing)
''', '''    if isAlive() and vault then vaultJumpAt1030 = os.clock() return Enum.ContextActionResult.Sink end -- (Q mid-vault = cover on landing) [MOVEFEEL] buffered
'''),
    E('''    -- Hop
    if not isGrounded() or os.clock() < hopLockUntil then return Enum.ContextActionResult.Sink end
''', '''    -- Hop
    if not isGrounded() then airJumpAt1030 = os.clock() return Enum.ContextActionResult.Sink end -- [MOVEFEEL] replayed on touchdown
    if os.clock() < hopLockUntil then return Enum.ContextActionResult.Sink end
'''),
    E('''local function bindCharacter(newCharacter: Model)
    if move or vault or dive then finishMovement() end
''', '''replayJump1030 = onJumpKey -- [MOVEFEEL]

local function bindCharacter(newCharacter: Model)
    vaultJumpAt1030, airJumpAt1030 = nil, nil -- [MOVEFEEL]
    if move or vault or dive then finishMovement() end
'''),
]

COVER.append(E('''    if track then track:Play(0.08, 1, speed or 1) end
''', '''    if track then track:Play((MF1030.Enabled ~= false and MF1030.Fades.MoveIn) or 0.08, 1, speed or 1) end -- [MOVEFEEL] (0.08)
'''))

TARGETS = [
    (CC + "MovementController", MOVEMENT, False),
    (CC + "CoverController", COVER, False),
]

MODULES = [  # (file, parent path, name)
    ("MoveFeelConfig.lua", "ReplicatedStorage.Modules.Shared.Config", "MoveFeelConfig"),
    ("MoveFeelController.lua", "StarterPlayer.StarterPlayerScripts.Client.Controllers", "MoveFeelController"),
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
    open(os.path.join(ROOT, "fix/move_feel_1030.lua"), "w", encoding="utf-8", newline="\n").write("".join(out))
    print("wrote fix/move_feel_1030.lua")


if __name__ == "__main__":
    dirs = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "out/move_feel/src*")))
    dirs = [d for d in dirs if os.path.isdir(d) and not d.endswith("src_pre")] or dirs
    bad = check(dirs)
    if bad:
        print(f"{bad} anchor problems: nothing written"); sys.exit(1)
    build()
