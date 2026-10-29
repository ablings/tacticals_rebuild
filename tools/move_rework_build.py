"""Build fix/move_rework_1029.lua [MOVE1029] from the edit list below, checking every anchor against the current sources first.
Usage: python -I tools/move_rework_build.py [src_dir ...]   (default: out/move_rework/src_match out/move_rework/src_lobby,
       dumps of match_place_ref.rbxl and Tacticals_rebuild.rbxl made with out/move_rework/rbxl_src.py)
Indentation in this file: 4 spaces at the start of a line = one tab in the Lua sources (T() converts).
Each edit: (old, new) - old must occur exactly once (at a token boundary) in every place that has the script, unless the
place already has new (then it counts as installed). Scripts marked optional are skipped in a place that lacks them
(the lobby has no tutorial or AI scripts)."""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ROUND = 4


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
MGR = "ServerScriptService.ServerScripts.[Server] Init.GameManager.Managers."

# ---------------------------------------------------------------------------------------------------------------------------
COVERCONFIG = [
    E('''    PeekTime = 0.18,        -- time to lean out / rise up. Higher = less "peek-and-hide" abuse
''', '''    PeekTime = 0.115,       -- [MOVE1029] was 0.18 (36% quicker): time to lean out / rise up. Higher = less "peek-and-hide" abuse
'''),
    E('''    DoubleVaultWindow = 1.2,   -- after a running vault lands: Space alone (no Shift) vaults straight back into cover
    SilentVaultSlowdown = 1.7, -- Space alone: the vault takes this many times longer (quiet), then you settle into the nearest cover
    SilentVaultCoverReach = 16, -- ...within this many studs of where you land
    VaultTime = 0.34375, -- [MOVE2] was 0.55: Edward's 2x faster (0.275), then base -20% (/0.8)
''', '''    DoubleVaultWindow = 1.2,   -- after a vault lands: Space vaults straight back into cover
    -- [MOVE1029] ONE VAULT (Edward 2026-10-29): Space at vaultable low cover always does this fast vault, sprinting or not.
    -- The slow "silent" vault (SilentVaultSlowdown / SilentVaultCoverReach) is gone; Q during a vault still lands you in cover.
    VaultTime = 0.34375, -- [MOVE2] was 0.55: Edward's 2x faster (0.275), then base -20% (/0.8)
    VaultNoiseRange = 24,      -- [MOVE1029] the AI hears a vault this far away (lost in steam, like a reload)
'''),
    E('''        Climb = "", -- [CLIMB] climb on top of deep / head-high cover (one shot)
''', '''        Climb = "", -- [CLIMB] climb on top of deep / head-high cover (one shot)
        PullUp = "", -- [MOVE1029] grab a ledge and pull up (one shot); until the animator's clip exists the Climb track plays
'''),
    E('''    ClimbTime = 0.62,
''', '''    ClimbTime = 0.62,
    -- [MOVE1029] PULL-UP (Edward 2026-10-29): Space, standing or mid-hop, facing any surface whose top is no higher than your
    -- standing head top over the floor you're on and that has room to stand: grab the edge and pull up. The server checks
    -- every one (MovementManager: the ledge is there, no ceiling, no NoClimb part, nothing in the way). NoClimb = true on a
    -- part (or any ancestor) means it is never climbed.
    PullUpMaxHeight = 5.1,     -- studs over the floor you stand on (standing head top measured in Play: 5.09)
    PullUpMinHeight = 1.2,     -- lower than this is a step, not a climb
    PullUpReach = 2.2,         -- studs from the body to the ledge's face
    PullUpStandDepth = 1.4,    -- room to stand: the top must carry a square this wide around the spot
    PullUpTime = 0.5,          -- seconds for the pull-up, plus PullUpTimePerStud per stud of rise
    PullUpTimePerStud = 0.06,
    -- the animator's PullUp clip (art/anim/pullup_lean/DONE.md, published under the group; source CoverPullUp carries the id):
    -- ledges PullUpKeyedMin..PullUpMaxHeight over your floor play it and move the body along its root path (t, y over the start
    -- floor, z forward; authored for a 4.5 top and a face 1.6 ahead, offsets blended in over the first 0.10 s); lower ones
    -- keep the Climb clip
    PullUpKeyedMin = 4.0,
    PullUpRootKeys = "0.00,2.80,0.00;0.03,3.01,-0.15;0.05,3.22,-0.30;0.10,3.35,-0.60;0.14,3.60,-0.68;0.17,3.85,-0.75;0.20,4.10,-0.82;0.24,4.35,-0.90;0.27,4.78,-1.04;0.30,5.20,-1.17;0.34,5.62,-1.31;0.35,5.85,-1.39;0.37,6.05,-1.45;0.40,6.55,-1.88;0.43,7.05,-2.30;0.44,7.00,-2.36;0.50,6.70,-2.70;0.62,7.30,-2.70;0.70,7.46,-2.70",
'''),
    E('''    -- Blind fire (left click in cover without aiming)
''', '''    -- [MOVE1029] PEEK TURN + FIRE GATE (Edward 2026-10-29: "when I peek I can shoot instantly before I fully turn ... The turn
    -- should be faster, but you can only shoot when you've fully turned to the peek angle")
    PeekTurnRate = 1700,       -- degrees/second at most: turning out to the peek angle in cover (the camera's own is 1000)
    PeekTurnSharpness = 40,    -- ...and how hard it eases in (was 25)
    PeekSnapSharpness = 16,    -- sliding out past the edge while peeking (SnapSharpness otherwise)
    PeekFireMaxAngle = 10,     -- degrees: the body (and the gun with it) must face within this of the aim before a peek shot
                               -- or a throw out of a peek leaves (any aimed / hip shot out of cover too)
    FireBufferTime = 0.6,      -- a click during the turn is held this long and fires the moment you're round
    FireFacingTolerance = 22,  -- server: a shot further than this from where the body faced during the shooter's lag window is refused
    BlindFacingTolerance = 115, -- server: ...for blind fire and shots fired mid vault / dash / dive
    FacingRecheck = 0.1,       -- server: seconds it waits for the newest facing before refusing a shot on facing
    FacingParallaxStuds = 2,   -- server: the gun / camera offset: a shot d studs long gets atan(this / d) more (close shots)
    -- [MOVE1029] LEAN: at the peek pose of a side peek (a tall cover edge, the side-peek end of low cover), the key toward the edge
    -- you can't slide past (A at a left edge, D at a right edge; the stick toward it; the Lean button on a phone) leans you out.
    -- Real for everyone: the server keeps it (character attribute Lean), every client draws it, the hit check rewinds it.
    LeanRoll = 17,             -- degrees the upper body rolls out about the waist
    LeanShift = 0.35,          -- studs the waist slides out (the shoulder and gun end ~0.73 out, the head ~1.0)
    LeanTime = 0.12,           -- seconds to lean out (and back)
    LeanCameraRoll = 4,        -- degrees the camera rolls with it
    LeanCameraShift = 0.6,     -- studs the camera slides out with it
    LeanInputDot = 0.5,        -- how directly the key / stick must point at the edge
    -- [MOVE1029] a shot's facing (character attribute FaceYaw, set by the server before the hit): other clients turn the
    -- shooter's body to it at once, hold it this long, then hand back to the replicated body at FaceReturnRate deg/s
    FaceHoldTime = 0.6,
    FaceReturnRate = 720,

    -- Blind fire (left click in cover without aiming)
'''),
    E('''        Brace = "",         -- near miss: flinch and tuck in against the cover
''', '''        Brace = "",         -- near miss: flinch and tuck in against the cover
        -- [MOVE1029] leaning out at a side peek (the animator's clips; until they exist the lean is a procedural waist roll).
        -- The waist roll + shift stay procedural (they are the hit check's model): a clip adds the arms / head only.
        LeanLeft = "", LeanRight = "", LeanLeftCrouch = "", LeanRightCrouch = "",
'''),
]

# ---------------------------------------------------------------------------------------------------------------------------
COVER = [
    E('''            animation.AnimationId = id
''', '''            animation.AnimationId = id
            animation.Name = "Cover" .. name -- [MOVE1029] so every client can tell a lean clip is playing (AimPoseController)
'''),
    # requires + the MoveAction helper + lean state
    E('''local Config = require(Shared:WaitForChild("Config"):WaitForChild("CoverConfig"))
''', '''local Config = require(Shared:WaitForChild("Config"):WaitForChild("CoverConfig"))
local MoveRules = require(Shared:WaitForChild("MoveRules")) -- [MOVE1029] lean / pull-up / wall-cover / peek-gate rules
-- [MOVE1029] MoveAction (client -> server): "Cover" state + lean, "Vault" (the AI hears it), "PullUp" (the server checks it)
local function moveAction(kind: string, ...)
    local ev = ReplicatedStorage:FindFirstChild("Events")
    ev = ev and ev:FindFirstChild("Movement")
    ev = ev and ev:FindFirstChild("MoveAction")
    if ev then ev:FireServer(kind, ...) end
end
'''),
    E('''local lastShotAt = -math.huge -- WeaponController reports shots; a hop waits for the shot to finish
''', '''local lastShotAt = -math.huge -- WeaponController reports shots; a hop waits for the shot to finish
local leanTarget = 0 -- [MOVE1029] -1 / 0 / 1: leaning out to the body's left / right this frame (side peek + key toward the edge)
local leanNow = 0 -- [MOVE1029] the eased lean you see (AimPoseController / CameraController read it)
local leanButtonHeld = false -- [MOVE1029] the phone's Lean button
local sentState, sentLean = nil, 0 -- [MOVE1029] what the server last heard (MoveAction "Cover")
'''),
    # wall cover
    E('''local function isUsableWall(hit: RaycastResult?): boolean
    return hit ~= nil and hit.Instance.CanCollide and (hit.Normal * FLAT).Magnitude > 0.7
        and not hit.Instance:GetAttribute("NotCover")
end
''', '''local function isUsableWall(hit: RaycastResult?): boolean
    -- [MOVE1029] WallCover: on a map that turns it on (MapInfo.WallCover / map attribute), its wall proxies are tall cover too
    return hit ~= nil and hit.Instance.CanCollide and (hit.Normal * FLAT).Magnitude > 0.7
        and (not hit.Instance:GetAttribute("NotCover") or MoveRules.IsWallCover(hit.Instance))
end
'''),
    E('''        if part.CanCollide and not part:GetAttribute("NotCover") and faceToward(part, hit.Position) then
''', '''        if part.CanCollide and (not part:GetAttribute("NotCover") or MoveRules.IsWallCover(part)) and faceToward(part, hit.Position) then -- [MOVE1029]
'''),
    E('''    if part:GetAttribute("NotCover") or not part.CanCollide then return nil end
    local only = localPlayer:GetAttribute("MoveTarget")
''', '''    if (part:GetAttribute("NotCover") and not MoveRules.IsWallCover(part)) or not part.CanCollide then return nil end -- [MOVE1029]
    local only = localPlayer:GetAttribute("MoveTarget")
'''),
    # exit cover: no lean
    E('''    crouched = false
    peekBlend = 0
    blindUntil = 0
    stopCoverTracks()
''', '''    crouched = false
    peekBlend = 0
    blindUntil = 0
    leanTarget = 0 -- [MOVE1029]
    stopCoverTracks()
'''),
    # one vault
    E('''-- Space = SILENT vault: slower and quiet. Shift + Space = RUNNING vault: fast, carries your momentum,
-- and you can aim and fire while going over. Either way you land on your feet; press Q during the vault
-- to land straight in cover, or E to sneak to the cover under your crosshair once you're down.
local function startVault(c, fast: boolean?)
    local root = rootPart :: BasePart
    local duration = (fast and Config.VaultTime or Config.VaultTime * (Config.SilentVaultSlowdown or 1.7)) / mobility() -- [ABILITY]
''', '''-- [MOVE1029] ONE VAULT (Edward 2026-10-29): Space vaults fast, sprinting or not (the slow silent vault is gone). It carries
-- your momentum, you can aim and fire while going over, the AI can hear it. You land on your feet; press Q during the vault
-- to land straight in cover, or E to sneak to the cover under your crosshair once you're down.
local function startVault(c, fast: boolean?)
    local root = rootPart :: BasePart
    fast = true -- [MOVE1029] one vault
    local duration = Config.VaultTime / mobility() -- [ABILITY]
'''),
    E('''    if not fast and character then character:SetAttribute("SilentMove", true) end
    lastVaulted = c.part
    return true
''', '''    moveAction("Vault", from, landing) -- [MOVE1029] a vault is heard (the server tells the AI)
    lastVaulted = c.part
    return true
'''),
    # pull-up: the climb spot rule + a ledge finder
    E('''-- the top surface just behind the wall's face, if you can stand there; nil when it is too high or there's no headroom
local function climbSpot(c): Vector3?
    local root = rootPart :: BasePart
    local hum = humanoid :: Humanoid
    local rootOffset = hum.HipHeight + root.Size.Y / 2
    local inset = math.clamp(c.depth / 2, 0.8, 1.6)
    local at = c.point - c.normal * inset
    local down = castWorld(Vector3.new(at.X, root.Position.Y + CLIMB_MAX_ABOVE_ROOT + 0.5, at.Z), Vector3.new(0, -(CLIMB_MAX_ABOVE_ROOT + 4), 0))
    if not down or down.Normal.Y < 0.7 then return nil end
    local topY = down.Position.Y
    if topY > root.Position.Y + CLIMB_MAX_ABOVE_ROOT or topY < root.Position.Y - rootOffset + 1 then return nil end
    local stand = Vector3.new(at.X, topY + rootOffset, at.Z)
''', '''-- the top surface just behind the wall's face, if you can stand there; nil when it is too high or there's no headroom
-- [MOVE1029] PULL-UP rule: the top may be up to your standing head top over the floor you're on (mid-hop: the floor under
-- you), it must carry a PullUpStandDepth square, nothing NoClimb, no ceiling over the way up
local function climbSpot(c): Vector3?
    local root = rootPart :: BasePart
    local hum = humanoid :: Humanoid
    local _ = CLIMB_MAX_ABOVE_ROOT
    if MoveRules.IsNoClimb(c.part) then return nil end
    local rootOffset = hum.HipHeight + root.Size.Y / 2
    local below = castWorld(root.Position, Vector3.new(0, -(rootOffset + 8), 0))
    local floorY = below and below.Position.Y or (root.Position.Y - rootOffset)
    local maxTop = floorY + (Config.PullUpMaxHeight or 5.1)
    local inset = math.clamp(c.depth / 2, 0.8, 1.6)
    local at = c.point - c.normal * inset
    local down = castWorld(Vector3.new(at.X, maxTop + 0.5, at.Z), Vector3.new(0, -(maxTop + 1 - floorY), 0))
    if not down or down.Normal.Y < 0.7 or MoveRules.IsNoClimb(down.Instance) then return nil end
    local topY = down.Position.Y
    if not MoveRules.PullUpHeightOk(floorY, topY, Config) then return nil end
    local half = (Config.PullUpStandDepth or 1.4) / 2
    for _, o in { Vector3.new(half, 0, 0), Vector3.new(-half, 0, 0), Vector3.new(0, 0, half), Vector3.new(0, 0, -half) } do
        local d2 = castWorld(Vector3.new(at.X + o.X, topY + 0.6, at.Z + o.Z), Vector3.new(0, -1.2, 0))
        if not d2 or math.abs(d2.Position.Y - topY) > 0.3 or MoveRules.IsNoClimb(d2.Instance) then return nil end
    end
    -- no climbing up through a ceiling: clear straight up from the top of your head to standing height on the ledge
    local headY = root.Position.Y + 2.1
    if topY + rootOffset * 2 > headY and castWorld(Vector3.new(root.Position.X, headY - 0.3, root.Position.Z), Vector3.new(0, topY + rootOffset * 2 + 0.3 - headY, 0)) then return nil end
    local stand = Vector3.new(at.X, topY + rootOffset, at.Z)
'''),
    E('''local function startClimb(c, stand: Vector3): boolean
    local root = rootPart :: BasePart
    local hum = humanoid :: Humanoid
    local from = root.Position
    local rise = math.max(stand.Y - from.Y, 0.5)
    local duration = ((Config.ClimbTime or 0.62) + rise * 0.06) / mobility() -- [ABILITY]
''', '''-- [MOVE1029] PULL-UP: any surface ahead (not only cover) you could climb: (cover info, stand point) or nil
local function findLedge()
    if not isAlive() then return nil, nil end
    local root = rootPart :: BasePart
    local hum = humanoid :: Humanoid
    local dirs = {}
    local camLook = (crosshairOverride and crosshairOverride[2] or workspace.CurrentCamera.CFrame.LookVector) * FLAT
    if hum.MoveDirection.Magnitude > 0.1 then table.insert(dirs, hum.MoveDirection.Unit) end
    if camLook.Magnitude > 0.1 then table.insert(dirs, camLook.Unit) end
    table.insert(dirs, (root.CFrame.LookVector * FLAT).Unit)
    local reach = (Config.PullUpReach or 2.2) + 1
    for _, dir in dirs do
        for _, dy in { 0.8, -0.5, -1.6 } do
            local hit = castWorld(root.Position + Vector3.new(0, dy, 0), dir * reach)
            if hit and hit.Instance.CanCollide and (hit.Normal * FLAT).Magnitude > 0.7 and -(hit.Normal * FLAT).Unit:Dot(dir) > 0.5
                and not MoveRules.IsNoClimb(hit.Instance) then
                local c = coverFromHit(hit)
                local stand = climbSpot(c)
                if stand then return c, stand end
            end
        end
    end
    return nil, nil
end

local function startClimb(c, stand: Vector3): boolean
    local root = rootPart :: BasePart
    local hum = humanoid :: Humanoid
    local from = root.Position
    local rise = math.max(stand.Y - from.Y, 0.5)
    local duration = ((Config.PullUpTime or Config.ClimbTime or 0.62) + rise * (Config.PullUpTimePerStud or 0.06)) / mobility() -- [ABILITY] [MOVE1029]
'''),
    E('''    local track = playMoveTrack("Climb")
    if track and track.Length > 0 then track:AdjustSpeed(track.Length / duration) end
    vault = { from = from, over = face, to = stand, facing = -c.normal, start = os.clock(), track = track, fromCover = false, part = c.part,
        duration = duration, fast = false, climb = true }
    return true
''', '''    -- [MOVE1029] the animator's PullUp clip for a chest-to-head-high ledge, moved along its root path; lower: the Climb clip
    local rootOffset = hum.HipHeight + root.Size.Y / 2
    local below = castWorld(from, Vector3.new(0, -(rootOffset + 8), 0))
    local floorY = below and below.Position.Y or (from.Y - rootOffset)
    local h = (stand.Y - rootOffset) - floorY
    local keys = nil
    local track
    if h >= (Config.PullUpKeyedMin or 4.0) and type(Config.PullUpRootKeys) == "string" then
        track = playMoveTrack("PullUp")
        if track then
            keys = {}
            for t, y, z in Config.PullUpRootKeys:gmatch("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
                table.insert(keys, { tonumber(t), tonumber(y), tonumber(z) })
            end
            duration = keys[#keys][1] / mobility()
        end
    end
    if not track then track = playMoveTrack("Climb") end
    if track and track.Length > 0 then track:AdjustSpeed(track.Length / duration) end
    local faceDist = math.max(((c.point - from) * FLAT):Dot(-c.normal), 0.5)
    vault = { from = from, over = face, to = stand, facing = -c.normal, start = os.clock(), track = track, fromCover = false, part = c.part,
        duration = duration, fast = false, climb = true, keys = keys, keyH = h, keyD = faceDist, keyFloor = floorY }
    moveAction("PullUp", from, stand) -- [MOVE1029] the server checks it (and drops you back if it can't find that ledge)
    return true
'''),
    # Q-mid-vault fallback: no more silent-vault settle
    E('''                        if found then
                            savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
                            enterCover(found)
                        else
                            controller._SettleIntoCover(nil)
                        end
''', '''                        if found then
                            savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
                            enterCover(found)
                        end -- [MOVE1029] (the silent vault's 16-stud sneak to cover is gone)
'''),
    # lean + state, every frame in cover
    E('''    local suppressed = os.clock() < suppressUntil
    if suppressed then wantPeek = false end
    peekBlend = moveToward(peekBlend, wantPeek and 1 or 0, dt / (suppressed and Config.PeekTime * 0.5 or Config.PeekTime))
''', '''    local suppressed = os.clock() < suppressUntil
    if suppressed then wantPeek = false end
    peekBlend = moveToward(peekBlend, wantPeek and 1 or 0, dt / (suppressed and Config.PeekTime * 0.5 or Config.PeekTime))
    -- [MOVE1029] LEAN: at the full pose of a side peek, the key (stick, Lean button) toward the edge you can't slide past
    -- leans you out to that side. AimPoseController draws it (yours from here, everyone else's from the Lean attribute).
    leanTarget = 0
    if cover.peekMode == "side" and peekBlend >= 0.999 and wantPeek then
        local edgeDir = cover.tangent * cover.side
        if moveInput:Dot(edgeDir) > (Config.LeanInputDot or 0.5) or leanButtonHeld then
            leanTarget = edgeDir:Dot(root.CFrame.RightVector) >= 0 and 1 or -1
        end
    end
'''),
    E('''    local alpha = 1 - math.exp(-Config.SnapSharpness * dt)
    -- Just carried on onto this piece (pillar -> box): glide onto its face instead of being yanked. The new
''', '''    local snap = Config.SnapSharpness
    if peekBlend > 0 and Config.PeekSnapSharpness then snap = Config.PeekSnapSharpness end -- [MOVE1029] a quicker step out to peek
    local alpha = 1 - math.exp(-snap * dt)
    -- Just carried on onto this piece (pillar -> box): glide onto its face instead of being yanked. The new
'''),
    # Space: one vault, pull-ups
    E('''local function onJumpKey(_, inputState: Enum.UserInputState)
    if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
''', '''local function onJumpKey(_, inputState: Enum.UserInputState)
    if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
    -- [MOVE1029] PULL-UP mid-hop: Space in the air facing a ledge you can reach grabs it (before the double-tap dive)
    if isAlive() and not vault and not move and not dive and not cover and not isGrounded() and not localPlayer:GetAttribute("SneakDisabled") then
        local ledge, stand = findLedge()
        if ledge and stand and startClimb(ledge, stand) then return Enum.ContextActionResult.Sink end
    end
'''),
    E('''        if not (localPlayer:GetAttribute("SneakDisabled") and not sprintHeld()) then
            pendingJump = { at = os.clock(), fast = sprintHeld() }
        end
''', '''        pendingJump = { at = os.clock(), fast = true } -- [MOVE1029] one vault
'''),
    E('''    local fast = sprintHeld()
    -- Tutorial 1 teaches only the running vault: Space alone (the silent vault) is switched off there -
    -- except going straight back over the wall you just vaulted, which is always a running vault
    if localPlayer:GetAttribute("SneakDisabled") and not fast then
        if revault then fast = true
        elseif cover or target or findNearbyCover() then return Enum.ContextActionResult.Sink end
    end
''', '''    local fast = true -- [MOVE1029] one vault: Space always vaults fast, sprinting or not
'''),
    E('''    -- In cover, Space never jumps (it only vaults)
    if cover then return Enum.ContextActionResult.Sink end
''', '''    -- In cover, Space never jumps (it only vaults)
    if cover then return Enum.ContextActionResult.Sink end
    -- [MOVE1029] PULL-UP: facing any ledge up to your standing head top with room to stand on it (never a NoClimb part)
    if not localPlayer:GetAttribute("SneakDisabled") then
        local ledge, stand = findLedge()
        if ledge and stand and startClimb(ledge, stand) then return Enum.ContextActionResult.Sink end
    end
'''),
    # the silent vault's settle: gone
    E('''-- After a silent vault: find the nearest usable cover within reach and sneak into it
function controller._SettleIntoCover(forward: Vector3?)
    if not isAlive() or move or vault or cover then return end
''', '''-- [MOVE1029] (the silent vault and its sneak into the nearest cover are gone: this does nothing now)
function controller._SettleIntoCover(forward: Vector3?)
    if true then return end
    if not isAlive() or move or vault or cover then return end
'''),
    E('''        local hit = not backward and castWorld(waist, dir * (Config.SilentVaultCoverReach or 9), lastVaulted) or nil
''', '''        local hit = not backward and castWorld(waist, dir * 9, lastVaulted) or nil
'''),
    # public API: peek gate, lean, cover state
    E('''function controller.IsSuppressed(): boolean
''', '''-- [MOVE1029] PEEK-FIRE GATE ----------------------------------------------------------------------------------------------
local function yawDeg(v: Vector3): number
    return math.deg(math.atan2(-v.X, -v.Z))
end
-- the full peek pose is reached and the body faces within PeekFireMaxAngle of the aim (no side effects)
local function peekReadyRaw(): boolean
    if not cover or not isAlive() then return true end
    local root = rootPart :: BasePart
    return MoveRules.PeekReady(peekBlend, yawDeg(root.CFrame.LookVector), yawDeg(workspace.CurrentCamera.CFrame.LookVector), Config)
end
-- what the server is told: None / Cover / Turn (aiming out of cover, not round yet) / Peek / Blind / Move
local function coverStateNow(): string
    if not isAlive() then return "None" end
    if move or vault or dive then return "Move" end
    if not cover then return "None" end
    if os.clock() < blindUntil then return "Blind" end
    if CameraController and CameraController.IsAiming() and (cover.isLow or cover.nearEdge) then
        return peekReadyRaw() and "Peek" or "Turn"
    end
    return "Cover"
end
local function syncState(dt: number)
    local st = coverStateNow()
    local lean = 0
    if cover and (st == "Peek" or st == "Turn") and cover.peekMode == "side" and peekBlend >= 0.999 then lean = leanTarget end
    leanNow = MoveRules.Ease(leanNow, lean, dt, Config)
    if st ~= sentState or lean ~= sentLean then
        sentState, sentLean = st, lean
        moveAction("Cover", st, lean)
    end
end
controller._SyncState = syncState
-- WeaponController / GadgetController: may a peek shot (throw) leave now? (tells the server first when it turns true)
function controller.PeekReady(): boolean
    local ready = peekReadyRaw()
    if ready and sentState == "Turn" then syncState(0) end
    return ready
end
-- the lean you see, -1..1 (+ = out to your right)
function controller.GetLean(): number
    return leanNow
end
-- the phone's Lean button shows only while this is true (a full side peek)
function controller.CanLean(): boolean
    return cover ~= nil and cover.peekMode == "side" and peekBlend >= 0.999 and CameraController ~= nil and CameraController.IsAiming()
end
function controller.SetLeanButton(on: boolean)
    leanButtonHeld = on == true
end
function controller.CoverState(): string
    return coverStateNow()
end

function controller.IsSuppressed(): boolean
'''),
    E('''    local alreadyOut = os.clock() < blindUntil
    blindUntil = os.clock() + Config.BlindFireRaiseTime + Config.BlindFireHoldTime
    local thisCover = cover
    task.delay(alreadyOut and 0 or Config.BlindFireRaiseTime, function()
        if cover == thisCover then shoot() end
    end)
''', '''    local alreadyOut = os.clock() < blindUntil
    blindUntil = os.clock() + Config.BlindFireRaiseTime + Config.BlindFireHoldTime
    local thisCover = cover
    task.delay(alreadyOut and 0 or Config.BlindFireRaiseTime, function()
        if cover == thisCover then
            syncState(0) -- [MOVE1029] the server hears "Blind" before the shot
            shoot()
        end
    end)
'''),
    # Start: lean button, refusal, per-frame sync, test hook
    E('''    RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, update)
''', '''    RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, update)
    -- [MOVE1029] every frame: ease the lean, tell the server the cover state when it changes
    RunService.Heartbeat:Connect(function(dt) syncState(dt) end)
    -- [MOVE1029] the server refused a pull-up (it found no such ledge, a ceiling, a NoClimb part): back to where it started
    localPlayer:GetAttributeChangedSignal("PullUpRefused"):Connect(function()
        if vault and vault.climb and rootPart then
            local from = vault.from
            finishMovement()
            rootPart.CFrame = CFrame.new(from) * rootPart.CFrame.Rotation
            rootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    -- [MOVE1029] the phone's Lean button (TouchControlsController shows it while you peek at a side edge)
    task.spawn(function()
        local ok, IA = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
        if ok and IA and IA.Bind then
            IA.Bind("Lean", function(state) leanButtonHeld = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change end)
        end
    end)
'''),
    E('''        hook.OnInvoke = function(action: string, origin: Vector3?, look: Vector3?)
            crosshairOverride = origin and look and { origin, look.Unit } or nil
''', '''        hook.OnInvoke = function(action: string, origin: Vector3?, look: Vector3?)
            -- [MOVE1029] "State": the peek / lean / gate state; "LeanButton", true/false: hold the phone's Lean button
            if action == "State" then
                return { peekBlend = peekBlend, peekReady = peekReadyRaw(), lean = leanNow, leanTarget = leanTarget, state = coverStateNow(),
                    sent = sentState, inCover = cover ~= nil, peekMode = cover and cover.peekMode, nearEdge = cover and cover.nearEdge,
                    side = cover and cover.side, vaulting = vault ~= nil, climbing = vault ~= nil and vault.climb == true, canLean = controller.CanLean() }
            end
            if action == "LeanButton" then
                leanButtonHeld = (origin :: any) == true
                return leanButtonHeld
            end
            if action == "Ledge" then
                local c, stand = findLedge()
                return c and { part = c.part:GetFullName(), stand = stand } or false
            end
            crosshairOverride = origin and look and { origin, look.Unit } or nil
'''),
]

COVER.append(E('''        local position = a:Lerp(b, alpha)
        if stopAtBarrier(root, position) then return true end -- [GLASS]
        root.CFrame = CFrame.lookAt(position, position + vault.facing)
''', '''        local position = a:Lerp(b, alpha)
        if vault.keys then
            -- [MOVE1029] the PullUp clip's root path (DONE.md): y over the start floor, z forward; the ledge-height and face-distance
            -- offsets blend in over the hop (0..0.10 s); after TopReached the body eases onto the stand spot
            local keys, tk = vault.keys, alpha * vault.keys[#vault.keys][1]
            local k2 = 2
            while k2 < #keys and keys[k2][1] < tk do k2 += 1 end
            local k1 = keys[k2 - 1]
            local kk = keys[k2]
            local f = math.clamp((tk - k1[1]) / math.max(kk[1] - k1[1], 1e-3), 0, 1)
            local y, z = k1[2] + (kk[2] - k1[2]) * f, k1[3] + (kk[3] - k1[3]) * f
            local blend = math.clamp(tk / 0.10, 0, 1)
            y += (vault.keyH - 4.5) * blend
            z -= (vault.keyD - 1.6) * blend
            local flatFrom = Vector3.new(vault.from.X, 0, vault.from.Z)
            local p = flatFrom + vault.facing * -z
            local settle = math.clamp((tk - 0.5) / 0.2, 0, 1)
            p = p:Lerp(Vector3.new(vault.to.X, 0, vault.to.Z), settle)
            position = Vector3.new(p.X, vault.keyFloor + y, p.Z):Lerp(vault.to, settle)
        end
        if stopAtBarrier(root, position) then return true end -- [GLASS]
        root.CFrame = CFrame.lookAt(position, position + vault.facing)
'''))
COVER.append(E('''    for name, track in (coverTracks or {}) do
        local weight = weights[name] or 0
''', '''    -- [MOVE1029] the animator's lean clips carry the lean pose (crouched versions in low cover / crouched), weighted by the lean
    if leanNow ~= 0 then
        weights[(leanNow > 0 and "LeanRight" or "LeanLeft") .. (low and "Crouch" or "")] = math.abs(leanNow)
    end
    for name, track in (coverTracks or {}) do
        local weight = weights[name] or 0
'''))

# ---------------------------------------------------------------------------------------------------------------------------
CAMERA = [
    E('''local Config = require(Shared:WaitForChild("Config"):WaitForChild("CameraConfig"))
''', '''local Config = require(Shared:WaitForChild("Config"):WaitForChild("CameraConfig"))
local CoverCfg1029 = require(Shared:WaitForChild("Config"):WaitForChild("CoverConfig")) -- [MOVE1029] peek turn + lean camera
'''),
    E('''            local maxStep = math.rad(Config.AimTurnRate or 1000) * dt
            local step = math.clamp(diff * smoothing(25, dt), -maxStep, maxStep)
''', '''            -- [MOVE1029] turning out to a peek in cover is quicker (CoverConfig PeekTurnRate / PeekTurnSharpness)
            local turnRate, turnSharp = Config.AimTurnRate or 1000, 25
            if cover and cover.IsInCover and cover.IsInCover() then
                turnRate, turnSharp = CoverCfg1029.PeekTurnRate or turnRate, CoverCfg1029.PeekTurnSharpness or turnSharp
            end
            local maxStep = math.rad(turnRate) * dt
            local step = math.clamp(diff * smoothing(turnSharp, dt), -maxStep, maxStep)
'''),
    E('''    camera.CFrame = CFrame.new(cameraPosition) * rotation

''', '''    camera.CFrame = CFrame.new(cameraPosition) * rotation
    -- [MOVE1029] leaning out: the view slides out with the shoulder and rolls a little (rebuilt from scratch every frame)
    do
        local cc = CoverControllerRef()
        local lean = (cc and cc.GetLean and isAlive()) and cc.GetLean() or 0
        if lean ~= 0 then
            camera.CFrame = camera.CFrame * CFrame.new((CoverCfg1029.LeanCameraShift or 0.6) * lean, 0, 0)
                * CFrame.Angles(0, 0, -math.rad(CoverCfg1029.LeanCameraRoll or 4) * lean)
        end
    end

'''),
]

AIMPOSE = [
    E('''local function update(dt: number)
    -- Your own pitch from the camera
''', '''-- [MOVE1029] LEAN (Edward 2026-10-29): at a side peek the upper body rolls out. Yours comes straight from the CoverController;
-- everyone else's from their character attribute Lean (the server's copy: -1 / 0 / 1), eased here the same way the server's
-- hit check eases it (MoveRules.Ease / LeanWaist), so what you see is what the server hits.
local MoveRules = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("MoveRules"))
local leanShown = setmetatable({}, { __mode = "k" }) -- [Model] = eased lean
-- a lean clip already playing on this body (yours, or replicated from its owner) carries the pose: the procedural roll fades out
local leanIds = nil
local function leanClipWeight(character: Model): number
    if not leanIds then
        leanIds = {}
        local src = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository:FindFirstChild("AnimationSources")
        for _, n in { "CoverLeanLeft", "CoverLeanRight", "CoverLeanLeftCrouch", "CoverLeanRightCrouch" } do
            local srcItem = src and src:FindFirstChild(n)
            local id = srcItem and srcItem:GetAttribute("PublishedId")
            if type(id) == "string" and id ~= "" then leanIds[id] = true end
        end
    end
    local hum = character:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    local w = 0
    for _, tr in (animator and animator:GetPlayingAnimationTracks() or {}) do
        local anim = tr.Animation
        if anim and (anim.Name:sub(1, 9) == "CoverLean" or leanIds[anim.AnimationId]) then w = math.max(w, tr.WeightCurrent) end
    end
    return math.clamp(w, 0, 1)
end
local function leanOf(player: Player, character: Model, dt: number): number
    local v
    if player == localPlayer then
        local cc = shared.Get and shared.Get("CoverController")
        v = (cc and cc.GetLean) and cc.GetLean() or 0
    else
        local target = tonumber(character:GetAttribute("Lean")) or 0
        v = MoveRules.Ease(leanShown[character] or 0, target, dt, Config)
        leanShown[character] = v
    end
    if v ~= 0 then v *= 1 - leanClipWeight(character) end
    return v
end
local function bendLean(joint: Instance?, degrees: number, lean: number)
    local obj, prop = jointTarget(joint)
    if not obj or not prop then return end
    (obj :: any)[prop] = restOf(obj, prop) * MoveRules.LeanWaist(lean, Config) * CFrame.Angles(math.rad(degrees), 0, 0)
end

-- [MOVE1029] a shot's facing reaches everyone with the hit (FaceYaw / FaceYawAt, set by the server before the damage), while
-- the shooter's own turn arrives later through physics replication: turn their body (the Root joint) to it at once, so on
-- your screen nobody hits you before facing you; after FaceHoldTime it eases back to the replicated body.
local faceShown = setmetatable({}, { __mode = "k" }) -- [Model] = degrees of turn shown
local function faceTurn(character: Model, dt: number)
    local lower = character:FindFirstChild("LowerTorso")
    local root = character:FindFirstChild("HumanoidRootPart")
    local joint = lower and lower:FindFirstChild("Root")
    if not (root and joint) then return end
    local at = character:GetAttribute("FaceYawAt")
    local want = nil
    if typeof(at) == "number" and workspace:GetServerTimeNow() - at < (Config.FaceHoldTime or 0.6) then
        local look = root.CFrame.LookVector
        local rootYaw = math.deg(math.atan2(-look.X, -look.Z))
        want = ((tonumber(character:GetAttribute("FaceYaw")) or rootYaw) - rootYaw + 180) % 360 - 180
    end
    local cur = faceShown[character] or 0
    if want then
        cur = want
    elseif cur ~= 0 then
        local step = (Config.FaceReturnRate or 720) * dt
        cur = cur > 0 and math.max(cur - step, 0) or math.min(cur + step, 0)
    else
        return
    end
    faceShown[character] = cur
    local obj, prop = jointTarget(joint)
    if obj and prop then (obj :: any)[prop] = restOf(obj, prop) * CFrame.Angles(0, math.rad(cur), 0) end
end

local function update(dt: number)
    -- Your own pitch from the camera
'''),
    E('''            bend(upperTorso:FindFirstChild("Waist"), waist)
''', '''            bendLean(upperTorso:FindFirstChild("Waist"), waist, leanOf(player, character, dt)) -- [MOVE1029] the lean rolls the waist out
            if player ~= localPlayer then faceTurn(character, dt) end -- [MOVE1029] face the shot the server just let through
'''),
]

WEAPON = [
    E('''local WeaponUtil = require(Shared:WaitForChild("WeaponUtil"))
''', '''local WeaponUtil = require(Shared:WaitForChild("WeaponUtil"))
local CoverCfg1029 = require(Shared:WaitForChild("Config"):WaitForChild("CoverConfig")) -- [MOVE1029] the peek-fire gate
local MoveRules = require(Shared:WaitForChild("MoveRules")) -- [MOVE1029]
'''),
    E('''local triggerHeld = false -- automatic guns keep firing while this is true
''', '''local triggerHeld = false -- automatic guns keep firing while this is true
local pendingShotAt, pendingAiming = nil, nil -- [MOVE1029] a click held back by the turn gate (fires once you're round)
'''),
    E('''    -- Automatic: keep an exact rhythm instead of rounding every shot up to the next frame
    if config.FireMode == "Auto" and now - lastFireTime < config.FireInterval * 1.5 then
''', '''    -- [MOVE1029] PEEK-FIRE GATE (Edward 2026-10-29: "you can only shoot when you've fully turned to the peek angle"): a peek
    -- shot waits for the full peek pose, any other aimed / hip shot until the body faces where it goes (PeekFireMaxAngle).
    -- The click is held (FireBufferTime) and leaves the moment you're round; a held trigger fires then too. Blind fire and
    -- shots mid vault / dash (above) stay instant.
    if not controller._TurnReady(aiming) then
        pendingShotAt, pendingAiming = now, aiming
        if not aiming then
            CameraController.FaceCamera(config.HipFireFaceTime)
            updatePose()
        end
        return
    end
    pendingShotAt = nil
    -- Automatic: keep an exact rhythm instead of rounding every shot up to the next frame
    if config.FireMode == "Auto" and now - lastFireTime < config.FireInterval * 1.5 then
'''),
    E('''-- Fires one shot now (after all checks). Used by aimed, hip and blind fire.
function controller._Shoot(config, spreadDegrees: number)
''', '''-- [MOVE1029] is the body round to the aim? In cover while aiming: the CoverController's peek gate; else the facing.
function controller._TurnReady(aiming: boolean): boolean
    local Cover = Get("CoverController")
    if Cover and Cover.IsInCover() and aiming and Cover.PeekReady then return Cover.PeekReady() end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return true end
    local a = MoveRules.FlatAngle(root.CFrame.LookVector, workspace.CurrentCamera.CFrame.LookVector)
    return a == nil or a <= (CoverCfg1029.PeekFireMaxAngle or 10)
end

-- Fires one shot now (after all checks). Used by aimed, hip and blind fire.
function controller._Shoot(config, spreadDegrees: number)
'''),
    E('''    -- Automatic fire: keep shooting while the trigger is held (fire() enforces the fire rate)
    if triggerHeld and equipped and equipped.config.FireMode == "Auto" then
''', '''    -- [MOVE1029] a click held back by the turn gate: it fires the moment the body is round (same aim state, within FireBufferTime)
    if pendingShotAt then
        if not equipped or not isAlive() or os.clock() - pendingShotAt > (CoverCfg1029.FireBufferTime or 0.6)
            or CameraController.IsAiming() ~= pendingAiming then
            pendingShotAt = nil
        elseif controller._TurnReady(pendingAiming) then
            pendingShotAt = nil
            fire()
        end
    end
    -- Automatic fire: keep shooting while the trigger is held (fire() enforces the fire rate)
    if triggerHeld and equipped and equipped.config.FireMode == "Auto" then
'''),
]

WEAPON.append(E('''function controller.Start()
    CameraController = Get("CameraController")

''', '''function controller.Start()
    CameraController = Get("CameraController")
    -- [MOVE1029] Studio-only test hook: press / release the trigger like the mouse does, read the shot count
    if RunService:IsStudio() then
        local hook = Instance.new("BindableFunction")
        hook.Name = "WeaponTestHook"
        hook.OnInvoke = function(action: string, down: boolean?)
            if action == "Trigger" then
                onInput("WeaponFire", down and Enum.UserInputState.Begin or Enum.UserInputState.End)
            end
            return { shots = shotId, pending = pendingShotAt ~= nil, lastFire = lastFireTime, now = os.clock() }
        end
        hook.Parent = localPlayer:WaitForChild("PlayerScripts")
    end

'''))

GADGET = [
    E('''    task.delay(delay, function()
        local _, h = getParts()
        if h and charges() > 0 then
            ThrowGadget:FireServer(kitGadget(), direction, p, mode, side)
        end
    end)
''', '''    task.delay(delay, function()
        -- [MOVE1029] thrown out of a peek: it leaves once the peek pose is full (a throw from cover without aiming stays instant)
        local Cover = shared.Get and shared.Get("CoverController")
        local Cam = shared.Get and shared.Get("CameraController")
        local t0 = os.clock()
        while Cover and Cover.PeekReady and Cover.IsInCover() and Cam and Cam.IsAiming() and not Cover.PeekReady() and os.clock() - t0 < 0.6 do
            task.wait()
        end
        local _, h = getParts()
        if h and charges() > 0 then
            ThrowGadget:FireServer(kitGadget(), direction, p, mode, side)
        end
    end)
'''),
]

TOUCH = [
    E('''    { id = "Dash", action = "Dash", glyph = "»", x = 0.752, y = 0.515, s = 0.10 },
''', '''    { id = "Dash", action = "Dash", glyph = "»", x = 0.752, y = 0.515, s = 0.10 },
    { id = "Lean", action = "Lean", glyph = "⇋", x = 0.83, y = 0.49, s = 0.10, peek = true }, -- [MOVE1029] only while peeking at a side edge
'''),
    E('''local function refresh()
''', '''-- [MOVE1029] the Lean button shows only while you're at a full side peek (where A / D toward the edge would lean)
local function leanShown(): boolean
    local cc = shared.Get and shared.Get("CoverController")
    return cc ~= nil and cc.CanLean ~= nil and cc.CanLean() == true
end
local function refresh()
'''),
    E('''        m.btn.Visible = editing or ((inCombat or b.lobby) and setting(id .. " Enabled", b.id ~= "Slide"))
''', '''        m.btn.Visible = editing or ((inCombat or b.lobby) and setting(id .. " Enabled", b.id ~= "Slide") and (not b.peek or leanShown())) -- [MOVE1029]
'''),
]

# ---------------------------------------------------------------------------------------------------------------------------
HITREWIND = [
    E('''local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
''', '''local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- [MOVE1029] the lean (every client draws it from the Lean attribute; this rewinds it) and the peek-fire facing gate
local MoveRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("MoveRules"))
local LeanCfg = require(game:GetService("ReplicatedStorage").Modules.Shared.Config.CoverConfig)
'''),
    E('''    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for model, tr in tracks do
''', '''    RunService.Heartbeat:Connect(function(dtHB)
        local now = os.clock()
        for model, tr in tracks do
'''),
    E('''            tr.cf[tr.n] = tr.root.CFrame
''', '''            tr.cf[tr.n] = tr.root.CFrame
            -- [MOVE1029] the lean as every client eases it from the Lean attribute
            tr.leanNow = MoveRules.Ease(tr.leanNow or 0, tonumber(model:GetAttribute("Lean")) or 0, dtHB or 1 / 60, LeanCfg)
            tr.lean = tr.lean or {}
            tr.lean[tr.n] = tr.leanNow
'''),
    E('''    local best = boxDistance(hitPart.CFrame, hitPart.Size, hitPosition)
    local detail = { rewound = hitPart.CFrame, now = hitPart.CFrame, size = hitPart.Size, age = 0, window = 0, ping = 0 }
''', '''    -- [MOVE1029] a leaning victim: the upper body is where every client draws it (MoveRules.LeanPart), now and rewound
    local tr0 = tracks[victimCharacter]
    local nowCF = hitPart.CFrame
    -- the server's own copy of the body may already show the lean (a lean clip replicated from its owner): count it once
    local ut = victimCharacter:FindFirstChild("UpperTorso")
    local posed = tr0 ~= nil and ut ~= nil and math.abs(math.deg(math.asin(math.clamp(tr0.root.CFrame:VectorToObjectSpace(ut.CFrame.UpVector).X, -1, 1))))
        > (LeanCfg.LeanRoll or 17) * 0.5
    if posed then tr0 = nil end
    if tr0 and (tr0.leanNow or 0) ~= 0 then nowCF = MoveRules.LeanPart(tr0.root.CFrame, hitPart.CFrame, hitPart.Name, tr0.leanNow, LeanCfg) end
    local best = boxDistance(nowCF, hitPart.Size, hitPosition)
    local detail = { rewound = nowCF, now = nowCF, size = hitPart.Size, age = 0, window = 0, ping = 0 }
'''),
    E('''            local cf = tr.cf[i] * rel
            local d = boxDistance(cf, hitPart.Size, hitPosition)
''', '''            local cf = tr.cf[i] * rel
            local li = (not posed) and tr.lean and tr.lean[i] or 0
            if li ~= 0 then cf = MoveRules.LeanPart(tr.cf[i], cf, hitPart.Name, li, LeanCfg) end -- [MOVE1029]
            local d = boxDistance(cf, hitPart.Size, hitPosition)
'''),
    E('''    return best <= HitRewind.Tolerance, best, detail
end

return HitRewind
''', '''    return best <= HitRewind.Tolerance, best, detail
end

-- [MOVE1029] PEEK-FIRE GATE: where this character faced during the last `window` seconds (newest last)
function HitRewind.FacingsWithin(character: Model, window: number): { Vector3 }
    local out = {}
    local tr = tracks[character]
    if tr then
        local now = os.clock()
        for i, t in tr.t do
            if now - t <= window + 1 / 30 then table.insert(out, tr.cf[i].LookVector) end
        end
        if tr.root.Parent then table.insert(out, tr.root.CFrame.LookVector) end
    else
        local root = character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then table.insert(out, root.CFrame.LookVector) end
    end
    return out
end

-- CombatManager runs this on every player shot: refused while the shooter's own report says the peek turn is still running
-- (character attribute CoverState "Turn"), or when the shot leaves further than FireFacingTolerance from every facing of the
-- shooter's lag window (+ `extra` seconds). Returns ok, reason.
function HitRewind.FireGate(shooter: Player, character: Model, direction: Vector3, extra: number?, dist: number?): (boolean, string?)
    local state = character:GetAttribute("CoverState")
    if state == "Turn" then return false, "still turning to the peek" end
    local ok, ping = pcall(shooter.GetNetworkPing, shooter)
    ping = ok and tonumber(ping) or 0.1
    local window = math.clamp(ping * 2 + HitRewind.Interp, HitRewind.MinWindow, HitRewind.MaxWindow) + (extra or 0)
    local tol = MoveRules.FacingTolerance(state, LeanCfg, dist)
    local good, best = MoveRules.FacingOk(direction, HitRewind.FacingsWithin(character, window), tol)
    if good then return true, nil end
    return false, ("facing %.0f deg away from the shot (allowed %.0f, state %s, %.0f studs)"):format(best, tol, tostring(state or "None"), dist or -1)
end
function HitRewind.FacingRecheck(): number
    return LeanCfg.FacingRecheck or 0.1
end

return HitRewind
'''),
]

COMBAT = [
    E('''    local head = character:FindFirstChild("Head")
    if not head or (origin - head.Position).Magnitude > V.MaxOriginOffset then
''', '''    -- [MOVE1029] PEEK-FIRE GATE (Edward 2026-10-29: "on the enemy's screen it looks like I shot them without looking"): the
    -- shot must leave roughly where the body faced at some moment of the shooter's lag window (HitRewind.FireGate), and never
    -- while the shooter's own report says the peek turn is still running. The newest facing may still be on its way: one
    -- short recheck before a refusal on facing. Refusals are logged in Studio (finish -> logReject).
    do
        local gateDist = isValidVector(hitPosition) and (hitPosition - origin).Magnitude or state.config.Range
        local gateOk, gateWhy = HitRewind.FireGate(player, character, direction, nil, gateDist)
        if not gateOk and gateWhy ~= "still turning to the peek" then
            task.wait(HitRewind.FacingRecheck())
            if getEquippedWeapon(player) ~= tool then return finish("weapon gone during the facing recheck") end
            gateOk, gateWhy = HitRewind.FireGate(player, character, direction, HitRewind.FacingRecheck(), gateDist)
        end
        if not gateOk then return finish("peek gate: " .. tostring(gateWhy)) end
        -- the shot's facing goes to every client BEFORE the hit (a character's turn reaches other players through physics
        -- replication, measured ~0.4 s behind damage in a two-player test: the victim saw the hit while the shooter still
        -- looked away). AimPoseController turns the shooter's body to FaceYaw at once; a new facing waits one frame first.
        local fy = math.floor(math.deg(math.atan2(-direction.X, -direction.Z)) + 0.5)
        local prevYaw, prevAt = character:GetAttribute("FaceYaw"), character:GetAttribute("FaceYawAt") or 0
        character:SetAttribute("FaceYaw", fy)
        character:SetAttribute("FaceYawAt", workspace:GetServerTimeNow())
        if type(prevYaw) ~= "number" or workspace:GetServerTimeNow() - prevAt > 0.3 or math.abs((fy - prevYaw + 180) % 360 - 180) > 5 then
            RunService.Heartbeat:Wait()
            if getEquippedWeapon(player) ~= tool then return finish("weapon gone before the hit") end
        end
    end
    local head = character:FindFirstChild("Head")
    if not head or (origin - head.Position).Magnitude > V.MaxOriginOffset then
'''),
]

GADGETMGR = [
    E('''    local cookPress = mode == "Cook" -- [COOK]
    if mode ~= "Roll" then mode = "Throw" end
''', '''    local cookPress = mode == "Cook" -- [COOK]
    if mode ~= "Roll" then mode = "Throw" end
    -- [MOVE1029] no throw out of a peek before the peek turn is done (the thrower's own report; a throw without aiming stays allowed)
    if not cookPress and mode == "Throw" and player.Character and player.Character:GetAttribute("CoverState") == "Turn" then return end
'''),
]

MOVEMENT = [
    E('''function manager.Start()
    SetStance.OnServerEvent:Connect(onSetStance)
end
''', '''-- [MOVE1029] MoveAction (client -> server), Edward's 2026-10-29 mechanics:
--   "Cover", state, lean   the cover state (None / Cover / Turn / Peek / Blind / Move) -> character attribute CoverState (the
--                          peek-fire gate in CombatManager / GadgetManager), and the lean (-1 / 0 / 1, only at a peek) ->
--                          character attribute Lean (every client draws it, HitRewind rewinds it). Only "Turn" and a lean
--                          OUT are rate limited: a message that lifts a restriction or brings the lean back always lands.
--   "Vault", from, to      the AI hears a vault (BotManager.HearNoise, VaultNoiseRange; lost in steam)
--   "PullUp", from, stand  checked here: the ledge is there and in reach, not NoClimb, room to stand, no ceiling over the
--                          way up, nothing (no window barrier) in the way. A refusal is flagged (MoveFlags, like MoveGuard),
--                          logged, the client drops back (player attribute PullUpRefused) and the server puts the body back.
local Players1029 = game:GetService("Players")
local CoverCfg = require(ReplicatedStorage.Modules.Shared.Config.CoverConfig)
local MoveRules = require(ReplicatedStorage.Modules.Shared:WaitForChild("MoveRules"))
local okOpenings, Openings = pcall(function() return require(ReplicatedStorage.Modules.Shared:WaitForChild("Openings", 5)) end)
local okSteam, SteamMask = pcall(function() return require(ReplicatedStorage.Modules.Shared:WaitForChild("SteamMask", 5)) end)
local IS_STUDIO = game:GetService("RunService"):IsStudio()
local STATES = { None = true, Cover = true, Turn = true, Peek = true, Blind = true, Move = true }
local coverLimiter = RateLimiter.NewRateLimiter(15)
local vaultLimiter = RateLimiter.NewRateLimiter(4)
local pullLimiter = RateLimiter.NewRateLimiter(4)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isVec(v: any): boolean
    return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e5
end

-- map geometry only: no characters, and (like the client's rays) no set dressing or shootables
local function mapRay(origin: Vector3, dir: Vector3): RaycastResult?
    local ignore = {}
    for _, p in Players1029:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
    for _, m in workspace:GetChildren() do
        for _, n in { "Props", "Shootables" } do
            local f = m:FindFirstChild(n)
            if f then table.insert(ignore, f) end
        end
    end
    rayParams.FilterDescendantsInstances = ignore
    return workspace:Raycast(origin, dir, rayParams)
end

local function refusePullUp(player: Player, character: Model, from: Vector3, why: string)
    player:SetAttribute("MoveFlags", (player:GetAttribute("MoveFlags") or 0) + 1)
    warn(("[MovementManager] pull-up refused for %s: %s (flag %d)"):format(player.Name, why, player:GetAttribute("MoveFlags")))
    player:SetAttribute("PullUpRefused", os.clock())
    task.delay(0.8, function()
        local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
        if root and root.Position.Y - from.Y > 1 and player.Character == character then
            character:PivotTo(CFrame.new(from) * root.CFrame.Rotation)
        end
    end)
end

-- the same rule as the client's climbSpot, with the server's own rays; returns ok, why
local function checkPullUp(character: Model, root: BasePart, hum: Humanoid, from: Vector3, stand: Vector3): (boolean, string?)
    local rootOffset = hum.HipHeight + root.Size.Y / 2
    if (root.Position - from).Magnitude > 6 then return false, "started away from the body" end
    local flat = Vector3.new(stand.X - from.X, 0, stand.Z - from.Z).Magnitude
    if flat > (CoverCfg.PullUpReach or 2.2) + 3.2 then return false, ("too far forward (%.1f)"):format(flat) end
    local below = mapRay(from, Vector3.new(0, -(rootOffset + 8), 0))
    local floorY = below and below.Position.Y or (from.Y - rootOffset)
    local topClaim = stand.Y - rootOffset
    local down = mapRay(Vector3.new(stand.X, topClaim + 1, stand.Z), Vector3.new(0, -2, 0))
    if not down or down.Normal.Y < 0.7 or math.abs(down.Position.Y - topClaim) > 0.6 then return false, "no ledge there" end
    if MoveRules.IsNoClimb(down.Instance) then return false, "NoClimb: " .. down.Instance:GetFullName() end
    local topY = down.Position.Y
    local okH, whyH = MoveRules.PullUpHeightOk(floorY, topY - 0.3, CoverCfg)
    if not okH then return false, whyH end
    if mapRay(Vector3.new(stand.X, topY + 0.2, stand.Z), Vector3.new(0, rootOffset * 2, 0)) then return false, "no headroom on the ledge" end
    local headY = from.Y + 2.1
    if topY + rootOffset * 2 > headY and mapRay(Vector3.new(from.X, headY - 0.3, from.Z), Vector3.new(0, topY + rootOffset * 2 + 0.2 - headY, 0)) then
        return false, "a ceiling over the way up"
    end
    local a, b = Vector3.new(from.X, topY + 0.6, from.Z), Vector3.new(stand.X, topY + 0.6, stand.Z)
    if (b - a).Magnitude > 0.05 and mapRay(a, b - a) then return false, "something in the way over the edge" end
    if okOpenings and Openings and Openings.BarrierBetween and (Openings.BarrierBetween(from, stand) or Openings.BarrierBetween(a, b)) then
        return false, "a window barrier"
    end
    return true, nil
end

local function onMoveAction(player: Player, kind: any, a: any, b: any)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not (root and hum) or hum.Health <= 0 then return end
    if kind == "Cover" then
        if type(a) ~= "string" or not STATES[a] then return end
        local lean = (b == 1 or b == -1) and b or 0
        if a ~= "Peek" and a ~= "Turn" then lean = 0 end
        if (a == "Turn" or lean ~= 0) and not coverLimiter:CheckRate(player) then return end
        character:SetAttribute("CoverState", a ~= "None" and a or nil)
        character:SetAttribute("Lean", lean ~= 0 and lean or nil)
    elseif kind == "Vault" then
        if not vaultLimiter:CheckRate(player) or not isVec(a) or (root.Position - a).Magnitude > 8 then return end
        local bots = shared.Get and shared.Get("BotManager")
        if bots and bots.HearNoise then bots.HearNoise(root.Position, CoverCfg.VaultNoiseRange or 24, true) end
    elseif kind == "PullUp" then
        if not pullLimiter:CheckRate(player) or not isVec(a) or not isVec(b) then return end
        local ok, why = checkPullUp(character, root, hum, a, b)
        if not ok then refusePullUp(player, character, a, why or "?") elseif IS_STUDIO then
            print(("[MovementManager] pull-up ok for %s: %.1f studs up"):format(player.Name, b.Y - a.Y))
        end
    end
end
manager._CheckPullUp = checkPullUp -- (tests)

function manager.Start()
    SetStance.OnServerEvent:Connect(onSetStance)
    local moveEv = ReplicatedStorage.Events.Movement:FindFirstChild("MoveAction") -- [MOVE1029]
    if moveEv then moveEv.OnServerEvent:Connect(onMoveAction) end
end
'''),
]

BOT = [
    E('''local WeaponConfig = require(Shared.Config.WeaponConfig)
''', '''local WeaponConfig = require(Shared.Config.WeaponConfig)
local MoveRulesB = require(Shared:WaitForChild("MoveRules")) -- [MOVE1029] bots obey the peek-fire gate
local CoverCfgB = require(Shared.Config.CoverConfig)
'''),
    E('''    if now - self.lastShot < self.config.FireInterval * Config.ShotPacing then return false end
    self.lastShot = now
''', '''    if now - self.lastShot < self.config.FireInterval * Config.ShotPacing then return false end
    -- [MOVE1029] bots obey the peek-fire gate: turn first, shoot once facing within PeekFireMaxAngle (an anchored bot, or one
    -- held back over 1.2 s, snaps round first: it still never fires facing away)
    do
        self:_face(aimPoint)
        local fa = MoveRulesB.FlatAngle(self.root.CFrame.LookVector, aimPoint - self.root.Position)
        if fa and fa > (CoverCfgB.PeekFireMaxAngle or 10) then
            self.gateSince = self.gateSince or now
            if not (self.root.Anchored or now - self.gateSince > 1.2) then return false end
            self:_face(aimPoint, true)
        end
        self.gateSince = nil
        -- every client turns the bot's body to the shot at once (its own turn reaches them later through replication)
        local fd = aimPoint - self.root.Position
        self.model:SetAttribute("FaceYaw", math.floor(math.deg(math.atan2(-fd.X, -fd.Z)) + 0.5))
        self.model:SetAttribute("FaceYawAt", workspace:GetServerTimeNow())
    end
    self.lastShot = now
'''),
]

TUTCONFIG = [
    E('''        SilentVault = "Slip over the low wall without a sound: press [Space] by itself. As you land, look at the short box by the pillar and tap [E] - you'll sneak into it quietly.",
''', '''        SilentVault = "Vault the low wall with [Space] while he looks away - a vault isn't silent up close. As you land, look at the short box by the pillar and tap [E] - you'll sneak into it quietly.", -- [MOVE1029] one vault
'''),
    E('''    SilentVault = "Slip over the low wall without a sound: tap Jump. As you land, look at the short box by the pillar and tap Dash - you'll sneak into it quietly.",
''', '''    SilentVault = "Vault the low wall with Jump while he looks away - a vault isn't silent up close. As you land, look at the short box by the pillar and tap Dash - you'll sneak into it quietly.", -- [MOVE1029] one vault
'''),
]

TUTCTRL = [
    E('''    VaultedIntoCover = "Silent vault into cover",
''', '''    VaultedIntoCover = "Vault, then sneak into cover", -- [MOVE1029] one vault
'''),
]

INPUTACTIONS = [
    E('''    "Scoreboard", "CameraSwap", "Sprint",
}
''', '''    "Scoreboard", "CameraSwap", "Sprint",
    "Lean", -- [MOVE1029] the phone's Lean button (shown while peeking at a side edge)
}
'''),
]

TARGETS = [
    ("ReplicatedStorage.Modules.Shared.InputActions", False, INPUTACTIONS),
    ("ReplicatedStorage.Modules.Shared.Config.CoverConfig", False, COVERCONFIG),
    (CC + "CoverController", False, COVER),
    (CC + "CameraController", False, CAMERA),
    (CC + "AimPoseController", False, AIMPOSE),
    (CC + "WeaponController", False, WEAPON),
    (CC + "GadgetController", False, GADGET),
    (CC + "TouchControlsController", False, TOUCH),
    ("ServerScriptService.Shared.HitRewind", False, HITREWIND),
    (MGR + "CombatManager", False, COMBAT),
    (MGR + "GadgetManager", False, GADGETMGR),
    (MGR + "MovementManager", False, MOVEMENT),
    (MGR + "BotManager", True, BOT),
    ("ReplicatedStorage.Modules.Shared.Config.TutorialConfig", True, TUTCONFIG),
    (CC + "TutorialController", True, TUTCTRL),
]


def boundary_ok(s, a, b):
    ident = re.compile(r"[A-Za-z0-9_]")
    if a > 0 and ident.match(s[a]) and ident.match(s[a - 1]):
        return False
    if b < len(s) and ident.match(s[b - 1]) and ident.match(s[b]):
        return False
    return True


def check(src_dirs):
    bad = 0
    for path, optional, edits in TARGETS:
        for d in src_dirs:
            f = os.path.join(d, path + ".lua")
            if not os.path.exists(f):
                if not optional:
                    print("MISSING (required)", d, path); bad += 1
                continue
            s = open(f, encoding="utf-8").read().replace("\r\n", "\n")
            for i, (old, new) in enumerate(edits, 1):
                n = s.count(old)
                if s.count(new) and new not in old:
                    continue
                if n != 1:
                    print(f"ANCHOR x{n}: {os.path.basename(d)} {path.split('.')[-1]} edit {i}: {old[:70]!r}"); bad += 1
                    continue
                a = s.find(old)
                if not boundary_ok(s, a, a + len(old)):
                    print(f"BOUNDARY: {path} edit {i}"); bad += 1
                s = s.replace(old, new, 1)
            # every later anchor must still match after the earlier edits
    return bad


def lua_str(s):
    assert "]=====]" not in s
    return "[=====[" + ("\n" if s.startswith("\n") else "") + s + "]=====]"


def emit():
    rules = open(os.path.join(ROOT, "fix", "move_rework_1029", "MoveRules.lua"), encoding="utf-8").read()
    tests = open(os.path.join(ROOT, "fix", "move_rework_1029", "MoveRulesSpec.lua"), encoding="utf-8").read()
    out = [open(os.path.join(ROOT, "fix", "move_rework_1029", "installer_head.lua"), encoding="utf-8").read()]
    out.append(f"local ROUND = {ROUND}\n")
    out.append("local MOVERULES_SRC = " + lua_str(rules) + "\n")
    out.append("local TARGETS = {\n")
    for path, optional, edits in TARGETS:
        out.append(f"\t{{ path = {lua_str(path)}, optional = {'true' if optional else 'false'}, edits = {{\n")
        for old, new in edits:
            out.append(f"\t\t{{ {lua_str(old)}, {lua_str(new)} }},\n")
        out.append("\t} },\n")
    out.append("}\n")
    out.append(open(os.path.join(ROOT, "fix", "move_rework_1029", "installer_body.lua"), encoding="utf-8").read())
    dst = os.path.join(ROOT, "fix", "move_rework_1029.lua")
    open(dst, "w", encoding="utf-8", newline="\n").write("".join(out))
    print("wrote", dst, sum(len(e) for _, _, e in TARGETS), "edits in", len(TARGETS), "scripts")
    # the tests: the unit spec on a fresh copy of the installed module + install checks
    t = ["-- fix/move_rework_1029_tests.lua [MOVE1029] GENERATED by tools/move_rework_build.py (unit spec: fix/move_rework_1029/MoveRulesSpec.lua)\n",
         "-- Edit mode, any place with the install: python tools/run_luau_at.py <studio id> fix/move_rework_1029_tests.lua\n",
         f"local ROUND = {ROUND}\n", tests, "\n", "local TARGET_PATHS = {\n"]
    for path, optional, edits in TARGETS:
        t.append(f"\t{{ {lua_str(path)}, {'true' if optional else 'false'}, {len(edits)} }},\n")
    t.append("}\n")
    t.append(open(os.path.join(ROOT, "fix", "move_rework_1029", "tests_body.lua"), encoding="utf-8").read())
    dst2 = os.path.join(ROOT, "fix", "move_rework_1029_tests.lua")
    open(dst2, "w", encoding="utf-8", newline="\n").write("".join(t))
    print("wrote", dst2)


if __name__ == "__main__":
    dirs = sys.argv[1:] or [os.path.join(ROOT, "out", "move_rework", "src_match"), os.path.join(ROOT, "out", "move_rework", "src_lobby")]
    bad = check(dirs)
    if bad:
        sys.exit(f"{bad} anchor problems: not written")
    emit()
