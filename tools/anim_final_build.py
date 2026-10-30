"""Build fix/anim_final_1030.lua [ANIMFINAL] from fix/anim_final_1030/* and the edit list below, checking every anchor against
dumps of the places first. Usage: python -I tools/anim_final_build.py [src_dir ...]
(default: out/anim_final/src_test out/anim_final/src_match out/anim_final/src_lobby if present, else src_test_pre; dumps made
with out/move_rework/rbxl_src.py <place.rbxl> <dir>).
Indentation in this file: 4 spaces at the start of a line = one tab in the Lua sources (T() converts).
Each edit (old, new): old must occur exactly once (token boundary) in every place that has the script, unless the place already
has new. Scripts marked optional are skipped where missing."""
import os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ROUND = 1


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
AFREQ = 'local okAF1030, AL1030 = pcall(function() return require(game:GetService("ReplicatedStorage").Modules.Shared:FindFirstChild("AnimLib")) end) -- [ANIMFINAL]'

# --------------------------------------------------------------------------------------------------------------------------
WEAPONCONFIG = [
    E('''table.insert(WeaponConfig.Loadout, "DualPistols")
''', '''table.insert(WeaponConfig.Loadout, "DualPistols")
do -- [ANIMFINAL] each gun family's own animation set (AnimFinalConfig.GunPrefixes); a clip its set doesn't have yet plays from
    -- the fallback set (Pistol), so nothing goes missing while the sets are being made
    local okAF, AFc = pcall(function() return require(script.Parent:FindFirstChild("AnimFinalConfig")) end)
    if okAF and type(AFc) == "table" and AFc.Enabled ~= false then
        for id, prefix in AFc.GunPrefixes or {} do
            local w = WeaponConfig.Weapons[id]
            if w then w.AnimationSourcePrefix = prefix; w.AnimationFallbackPrefix = AFc.GunFallbackPrefix end
        end
        -- an id written in this table (the Revolver's old placeholders) gives way to a FINAL clip of the same name (built by the
        -- animators' pipeline: attribute SourceHash) once that clip is published (PublishedId), or in Studio (it plays its source)
        local repo = game:GetService("ReplicatedStorage"):FindFirstChild("Repository")
        local srcs = repo and repo:FindFirstChild("AnimationSources")
        local studio = game:GetService("RunService"):IsStudio()
        for _, w in WeaponConfig.Weapons do
            for name, aid in w.Animations or {} do
                local src = aid ~= "" and srcs and srcs:FindFirstChild((w.AnimationSourcePrefix or "") .. name)
                if src and src:GetAttribute("SourceHash") and (src:GetAttribute("PublishedId") or studio) then w.Animations[name] = "" end
            end
        end
    end
end
'''),
]

WEAPONCONTROLLER = [
    # requires + state
    E('''local MoveRules = require(Shared:WaitForChild("MoveRules")) -- [MOVE1029]
''', '''local MoveRules = require(Shared:WaitForChild("MoveRules")) -- [MOVE1029]
local AnimLib1030 = require(Shared:WaitForChild("AnimLib")) -- [ANIMFINAL] clips by name (AnimFinalConfig)
local AF1030 = AnimLib1030.Config -- [ANIMFINAL]
local drawnThisLife1030 = false -- [ANIMFINAL] the Draw clip plays on the first pull-out of a life, the quick Equip after that
local lastFightAt1030 = -math.huge -- [ANIMFINAL] last shot / hit / damage taken (no inspect for Weapon.InspectFightLock)
'''),
    # per-clip prefix with the fallback set
    E('''        local pub = id == "" and pubRoot and pubRoot:FindFirstChild((config.AnimationSourcePrefix or "") .. name)
''', '''        local pub = id == "" and pubRoot and pubRoot:FindFirstChild(AnimLib1030.GunPrefix(config, name) .. name) -- [ANIMFINAL] own set, else the fallback set
'''),
    E('''            local source = sources and sources:FindFirstChild((config.AnimationSourcePrefix or "") .. name)
''', '''            local source = sources and sources:FindFirstChild(AnimLib1030.GunPrefix(config, name) .. name) -- [ANIMFINAL]
'''),
    # the extra clips
    E('''                if ok then
                    track.Priority = Enum.AnimationPriority.Action4
                    tracks["Draw" .. suffix] = track
                end
            end
        end
    end
    return tracks
end
''', '''                if ok then
                    track.Priority = Enum.AnimationPriority.Action4
                    tracks["Draw" .. suffix] = track
                end
            end
        end
    end
    -- [ANIMFINAL] the final pass: <Prefix>Holster / Draw / Inspect / ReloadEmpty / ReloadTactical / the shell-by-shell clips
    -- (AnimFinalConfig.GunExtras), from the gun's OWN set only (a pistol holster on a rifle would look wrong)
    if AF1030.Enabled ~= false then
        for _, base in AF1030.GunExtras do
            for _, suffix in { "", "Left" } do
                local t = AnimLib1030.Load(animator, (config.AnimationSourcePrefix or "") .. base .. suffix, Enum.AnimationPriority.Action4, false)
                if t then tracks[base .. suffix] = t end
            end
        end
    end
    return tracks
end
'''),
    # cancel stops every reload clip
    E('''    for _, name in { "Reload", "ReloadLeft" } do
        local track = eq.tracks and eq.tracks[name]
''', '''    for _, name in { "Reload", "ReloadLeft", "ReloadEmpty", "ReloadEmptyLeft", "ReloadTactical", "ReloadTacticalLeft", "ReloadStart", -- [ANIMFINAL]
        "ReloadStartLeft", "ReloadShell", "ReloadShellLeft", "ReloadEnd", "ReloadEndLeft", "ReloadEndEmpty", "ReloadEndEmptyLeft" } do
        local track = eq.tracks and eq.tracks[name]
'''),
    # tactical / empty / shell start
    E('''    playAnimation("Reload")
    if WeaponFeel then WeaponFeel.Reload(config.ReloadTime) end -- [FEEL] the gun rolls up and out mid-reload
    do -- [ABILITY] the reload animation fits the gun's ReloadTime (the speed ladder)
        local track = equipped and ((gunHand < 0 and equipped.tracks.ReloadLeft) or equipped.tracks.Reload)
        if track and track.Length > 0 then track:AdjustSpeed(track.Length / config.ReloadTime) end
    end
''', '''    local reloadClip = controller._ReloadClip(config) -- [ANIMFINAL] tactical / empty / the shell-by-shell start
    controller._StopInspect()
    equipped.reloadEmpty1030 = getAmmo() == 0
    playAnimation(reloadClip)
    if WeaponFeel then WeaponFeel.Reload(config.ReloadTime) end -- [FEEL] the gun rolls up and out mid-reload
    do -- [ABILITY] the reload animation fits the gun's ReloadTime (the speed ladder); [ANIMFINAL] the chosen clip, its own length
        -- kept to the code's time (an empty reload takes as long as a tactical one: the server's ReloadTime is unchanged)
        local track = equipped and ((gunHand < 0 and equipped.tracks[reloadClip .. "Left"]) or equipped.tracks[reloadClip])
        local fit = (reloadClip == "ReloadStart" and config.ShellReload) and config.ShellReload.StartDelay or config.ReloadTime
        if track and track.Length > 0 then track:AdjustSpeed(track.Length / fit) end
        if reloadClip == "ReloadStart" and config.ShellReload then -- the first shell's clip after the start
            local thisEquipS, thisReloadS = equipped, equipped.reloadId
            task.delay(config.ShellReload.StartDelay, function()
                if equipped == thisEquipS and thisEquipS.reloadId == thisReloadS and isReloading() then controller._PlayShell(config) end
            end)
        end
    end
'''),
    # no firing while holstering; inspect cut by a shot
    E('''    if now < (equipped.drawEndsAt or 0) then return end -- [MOVE2] still drawing the gun
''', '''    if now < (equipped.drawEndsAt or 0) then return end -- [MOVE2] still drawing the gun
    if equipped.holsterAt1030 then return end -- [ANIMFINAL] putting it away
'''),
    E('''function controller._Shoot(config, spreadDegrees: number)
''', '''function controller._Shoot(config, spreadDegrees: number)
    lastFightAt1030 = os.clock() -- [ANIMFINAL]
    controller._StopInspect()
'''),
    # sprint: the body's sprint clip carries the gun low
    E('''    local wanted = (gunHand < 0 and equipped.tracks[base .. "Left"]) or equipped.tracks[base] or equipped.tracks.Hold
''', '''    local wanted = (gunHand < 0 and equipped.tracks[base .. "Left"]) or equipped.tracks[base] or equipped.tracks.Hold
    if controller._SprintLow() then wanted = nil end -- [ANIMFINAL] sprinting: the body's sprint clip carries the gun low
'''),
    # draw only on the first pull-out
    E('''        local drawName = thisEquip.tracks.Draw and "Draw" or "Equip" -- [MOVE2] from the holster when there is a draw animation
''', '''        local drawName = thisEquip.tracks.Draw and "Draw" or "Equip" -- [MOVE2] from the holster when there is a draw animation
        if AF1030.Weapon.DrawFirstPullOutOnly and drawnThisLife1030 and thisEquip.tracks.Equip then drawName = "Equip" end -- [ANIMFINAL]
        drawnThisLife1030 = true
'''),
    E('''    shotId = 0
    gunHand = 1
''', '''    shotId = 0
    gunHand = 1
    drawnThisLife1030 = false -- [ANIMFINAL] a new life draws from the holster again
'''),
    # shell-by-shell clips on each shell; the end clip
    E('''    table.insert(equipped.connections, tool:GetAttributeChangedSignal("Ammo"):Connect(function()
        if config.ShellReload and tool:GetAttribute("Reloading") == true then setCountdown("Reload", config.ShellReload.ShellTime) end
    end))
''', '''    table.insert(equipped.connections, tool:GetAttributeChangedSignal("Ammo"):Connect(function()
        if config.ShellReload and tool:GetAttribute("Reloading") == true then setCountdown("Reload", config.ShellReload.ShellTime) end
        -- [ANIMFINAL] the next shell's clip while the reload goes on
        if config.ShellReload and tool:GetAttribute("Reloading") == true and equipped == thisEquipR
            and (tool:GetAttribute("Ammo") or 0) < config.MagazineSize then controller._PlayShell(config) end
    end))
    table.insert(equipped.connections, tool:GetAttributeChangedSignal("Reloading"):Connect(function() -- [ANIMFINAL] the end clip
        if tool:GetAttribute("Reloading") == true or not config.ShellReload or equipped ~= thisEquipR then return end
        if os.clock() - lastFireTime < 0.3 then return end -- a shot cut it: no end clip
        local endClip = (thisEquipR.reloadEmpty1030 and thisEquipR.tracks.ReloadEndEmpty) and "ReloadEndEmpty" or "ReloadEnd"
        for _, n in { "ReloadShell", "ReloadShellLeft" } do
            local t = thisEquipR.tracks[n]
            if t and t.IsPlaying then t:Stop(0.08) end
        end
        playAnimation(endClip)
    end))
'''),
    # inspect key
    E('''    ContextActionService:BindAction("WeaponReload", onInput, false, Binds.Key(localPlayer, "Reload", keys.Reload), Enum.KeyCode.ButtonX) -- [PAD] X (Edward 2026-10-20)
''', '''    ContextActionService:BindAction("WeaponReload", onInput, false, Binds.Key(localPlayer, "Reload", keys.Reload), Enum.KeyCode.ButtonX) -- [PAD] X (Edward 2026-10-20)
    -- [ANIMFINAL] Inspect (AnimFinalConfig.Weapon.InspectKey, Settings bind "Inspect"). Above the gun bash (2500) on the same key:
    -- a refused inspect (aiming, fight-locked, an enemy close) passes the key on, so F still bashes
    ContextActionService:BindActionAtPriority("WeaponInspect1030", function(_, inputState)
        if inputState == Enum.UserInputState.Begin and controller.Inspect() then return Enum.ContextActionResult.Sink end
        return Enum.ContextActionResult.Pass
    end, false, 3000, Binds.Key(localPlayer, "Inspect", AF1030.Weapon.InspectKey))
'''),
    E('''    ContextActionService:UnbindAction("WeaponReload")
''', '''    ContextActionService:UnbindAction("WeaponReload")
    ContextActionService:UnbindAction("WeaponInspect1030") -- [ANIMFINAL]
'''),
    # fight lock from hits / damage
    E('''    HitConfirm.OnClientEvent:Connect(function(zone: string, _damage: number, killed: boolean, headshot: boolean?, kind: string?)
''', '''    HitConfirm.OnClientEvent:Connect(function(zone: string, _damage: number, killed: boolean, headshot: boolean?, kind: string?)
        lastFightAt1030 = os.clock() -- [ANIMFINAL]
'''),
    E('''    Combat:WaitForChild("DamageTaken").OnClientEvent:Connect(function(source: Vector3)
''', '''    Combat:WaitForChild("DamageTaken").OnClientEvent:Connect(function(source: Vector3)
        lastFightAt1030 = os.clock() -- [ANIMFINAL]
        controller._StopInspect()
'''),
    # the new functions (before Start)
    E('''-- // Start
function controller.Start()
''', '''-- // [ANIMFINAL] holster / inspect / reload clips / sprint pose (AnimFinalConfig.Weapon)
-- which reload clip: the shotgun's Start; an empty magazine's ReloadEmpty; a round still in the gun's ReloadTactical; else Reload
function controller._ReloadClip(config): string
    local tr = equipped and equipped.tracks or {}
    if config.ShellReload and tr.ReloadStart then return "ReloadStart" end
    if config.ShellReload then return "Reload" end
    if getAmmo() == 0 then
        if AF1030.Weapon.EmptyReloadClip and tr.ReloadEmpty then return "ReloadEmpty" end
        return "Reload"
    end
    if tr.ReloadTactical then return "ReloadTactical" end
    return "Reload"
end

function controller._PlayShell(config)
    if not equipped or not equipped.tracks.ReloadShell then return end
    for _, n in { "ReloadStart", "ReloadStartLeft" } do
        local t = equipped.tracks[n]
        if t and t.IsPlaying then t:Stop(0.06) end
    end
    local track = (gunHand < 0 and equipped.tracks.ReloadShellLeft) or equipped.tracks.ReloadShell
    if not track then return end
    track:Play(0.06)
    if track.Length > 0 then track:AdjustSpeed(track.Length / config.ShellReload.ShellTime * (AF1030.Weapon.ShellClipSpeed or 1)) end
end

-- sprinting with the gun out (not aiming): the body's sprint clip shows the gun low, so the Hold / Lowered poses step aside
function controller._SprintLow(): boolean
    if AF1030.Enabled == false or not AF1030.Weapon.SprintPose or not equipped then return false end
    local Move = Get("MovementController")
    if not (Move and Move.IsSprinting and Move.IsSprinting()) then return false end
    if CameraController and CameraController.IsAiming and CameraController.IsAiming() then return false end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude < AF1030.Loco.SprintSpeed then return false end
    local Cover = Get("CoverController")
    if Cover and Cover.IsInCover and Cover.IsInCover() then return false end
    return AnimLib1030.Clip("Sprint") ~= nil or AnimLib1030.Clip("SprintPistol") ~= nil
end

function controller._StopInspect()
    if not equipped then return end
    for _, n in { "Inspect", "InspectLeft" } do
        local t = equipped.tracks and equipped.tracks[n]
        if t and t.IsPlaying then t:Stop(0.1) end
    end
end

local function enemyNear1030(range: number): boolean
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local list = {}
    for _, p in Players:GetPlayers() do
        if p ~= localPlayer and p.Character and not (p:GetAttribute("Team") ~= nil and p:GetAttribute("Team") == localPlayer:GetAttribute("Team")) then
            table.insert(list, p.Character)
        end
    end
    for _, b in game:GetService("CollectionService"):GetTagged("Bot") do table.insert(list, b) end
    for _, m in list do
        local r = m:FindFirstChild("HumanoidRootPart")
        local h = m:FindFirstChildOfClass("Humanoid")
        if r and h and h.Health > 0 and (r.Position - root.Position).Magnitude <= range then return true end
    end
    return false
end

-- Inspect: not while aiming, reloading, drawing or holstering, nor within InspectFightLock of a fight, nor with an enemy close
function controller.Inspect(): boolean
    if AF1030.Enabled == false or not equipped or not isAlive() then return false end
    local track = (gunHand < 0 and equipped.tracks.InspectLeft) or equipped.tracks.Inspect
    if not track or track.IsPlaying then return track ~= nil end
    if CameraController.IsAiming() or isReloading() or controller.IsDrawing() or equipped.holsterAt1030 then return false end
    if os.clock() - lastFightAt1030 < AF1030.Weapon.InspectFightLock then return false end
    if enemyNear1030(AF1030.Weapon.InspectNearEnemy) then return false end
    track:Play(0.15)
    return true
end

-- Studio tests: which of the gun's clips are playing, and which exist
function controller._AnimDebug()
    local playing, have = {}, {}
    for k, t in (equipped and equipped.tracks or {}) do
        table.insert(have, k)
        if t.IsPlaying then table.insert(playing, k) end
    end
    table.sort(playing) table.sort(have)
    return { playing = playing, have = have, holstering = equipped ~= nil and equipped.holsterAt1030 ~= nil, ammo = getAmmo() }
end

-- Holster: play the gun's Holster clip and call done() when it ends (no shot meanwhile). false = no clip: switch at once.
function controller.Holster(done): boolean
    if AF1030.Enabled == false or not AF1030.Weapon.HolsterWait or not equipped or not isAlive() then return false end
    local track = (gunHand < 0 and equipped.tracks.HolsterLeft) or equipped.tracks.Holster
    if not track or track.Length <= 0 then return false end
    local eq = equipped
    cancelReloadFx(eq)
    controller._StopInspect()
    local t = math.min(track.Length, AF1030.Weapon.HolsterMaxWait)
    eq.holsterAt1030 = os.clock()
    for _, name in POSE_NAMES do
        local p = eq.tracks[name]
        if p and p.IsPlaying then p:Stop(0.08) end
    end
    eq.activePose = false -- no pose comes back while it goes away
    track:Play(0.05)
    track:AdjustSpeed(track.Length / t)
    task.delay(t, function()
        if equipped == eq then eq.holsterAt1030 = nil end
        done()
    end)
    return true
end

-- // Start
function controller.Start()
'''),
    # while inspecting: aiming cuts it
    E('''    -- Automatic fire: keep shooting while the trigger is held (fire() enforces the fire rate)
''', '''    if equipped and CameraController.IsAiming() then controller._StopInspect() end -- [ANIMFINAL] aiming cuts the inspect
    -- Automatic fire: keep shooting while the trigger is held (fire() enforces the fire rate)
'''),
]

# activePose = false while holstering: updatePose must not restart a pose. It compares equipped.activePose == wanted;
# false ~= nil/track, so guard it:
WEAPONCONTROLLER.append(E('''local function updatePose()
    if not equipped then return end
''', '''local function updatePose()
    if not equipped then return end
    if equipped.holsterAt1030 then return end -- [ANIMFINAL] going away: no pose
'''))

WEAPONEFFECTS = [
    E('''    local humanoid = closest and closest:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    local track = flinchTracks[animator]
''', '''    local humanoid = closest and closest:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    do -- [ANIMFINAL] directional flinch / headshot snap (AnimFinalConfig.Hits). Another player's body flinches on its own client
        -- (its track replicates to everyone): here only your own body and bots, so nobody sees a flinch twice
        ''' + AFREQ + '''
        if okAF1030 and AL1030 and AL1030.Config.Enabled ~= false and AL1030.Config.Hits.Enabled then
            local owner = Players:GetPlayerFromCharacter(closest)
            if owner and owner ~= Players.LocalPlayer then return end
            local name = AL1030.HitClip(closest, position, dir)
            if name then
                if not AL1030.Cooldown(closest, AL1030.Config.Hits.FlinchCooldown) then return end
                local t = AL1030.Load(animator, name, AL1030.Config.Hits.Priority, false)
                if t then t:Play(0) return end
            end
        end
    end
    local track = flinchTracks[animator]
'''),
    E('''local function flinch(position: Vector3)
''', '''local function flinch(position: Vector3, dir: Vector3?) -- [ANIMFINAL] dir = the shot's travel direction
'''),
    E('''            flinch(endPos)
''', '''            flinch(endPos, direction.Unit) -- [ANIMFINAL]
'''),
    # the new guns' shell: out of the ShellEject port, the gun's own round mesh (GUNSV2 tools have both)
    E('''            local casing = Instance.new("Part")
            casing.Name = "Casing"
            casing.Shape = Enum.PartType.Cylinder
            casing.Size = Vector3.new(0.18, 0.07, 0.07)
            casing.Color = Color3.fromRGB(196, 156, 72)
            casing.Material = Enum.Material.Metal
            casing.Reflectance = 0.2
            casing.CanQuery = false
            casing.CanTouch = false
            casing.CFrame = handle.CFrame * CFrame.new((math.random() - 0.5) * 0.2, 0.3, -0.3)
            casing.Parent = workspace
''', '''            -- [ANIMFINAL] a GUNSV2 gun: its own shell mesh (Round / LoadShell) out of its ShellEject attachment
            local eject1030 = tool:FindFirstChild("ShellEject", true)
            local round1030 = tool:FindFirstChild("Round", true) or tool:FindFirstChild("LoadShell", true)
            local casing
            if round1030 and round1030:IsA("BasePart") and eject1030 and eject1030:IsA("Attachment") then
                casing = round1030:Clone()
                casing:ClearAllChildren()
                for k in casing:GetAttributes() do casing:SetAttribute(k, nil) end
                casing.Name = "Casing"
                casing.Transparency = 0
                casing.Massless = false
                casing.CanCollide = true
                casing.CanQuery = false
                casing.CanTouch = false
                casing.Anchored = false
                casing.CFrame = eject1030.WorldCFrame
            else
                casing = Instance.new("Part")
                casing.Name = "Casing"
                casing.Shape = Enum.PartType.Cylinder
                casing.Size = Vector3.new(0.18, 0.07, 0.07)
                casing.Color = Color3.fromRGB(196, 156, 72)
                casing.Material = Enum.Material.Metal
                casing.Reflectance = 0.2
                casing.CanQuery = false
                casing.CanTouch = false
                casing.CFrame = handle.CFrame * CFrame.new((math.random() - 0.5) * 0.2, 0.3, -0.3)
            end
            casing.Parent = workspace
'''),
]

HOTBAR = [
    E('''local function select(slot: number)
    local hum = humanoidOf()
    if not hum then return end
''', '''local function select(slot: number, afterHolster: boolean?)
    local hum = humanoidOf()
    if not hum then return end
    do -- [ANIMFINAL] putting the gun away waits for its Holster clip (WeaponController.Holster), then the switch goes on
        local held = heldTool()
        local W = Get("WeaponController")
        local Gad = Get("GadgetController")
        local canSwitch = slot == MELEE or (slot == GADGET and Gad ~= nil and Gad.GetCharges() > 0)
        if not afterHolster and canSwitch and held and held:GetAttribute("WeaponId") and W and W.Holster then
            if W.Holster(function()
                if humanoidOf() == hum and heldTool() == held then select(slot, true) end
            end) then return end
        end
    end
'''),
    E('''    if slashTrack then slashTrack:Play(0.05) end
''', '''    do -- [ANIMFINAL] the item's own swing (AnimFinalConfig.Melee): the knife's heavy (slide lunge) and backstab, the bat's charged
        -- swing, the katana / shield sets; the gun-butt bash is QuickMeleeBash. Nothing made yet -> the config's clip as before
        local alt = nil
        ''' + AFREQ + '''
        local set = okAF1030 and AL1030 and AL1030.Config.Enabled ~= false and AL1030.Config.Melee[quick and "Quick" or (tool and tool:GetAttribute("MeleeId") or "")]
        if set then
            local logical = "Swing"
            if kind == "Lunge" and set.Lunge then logical = "Lunge"
            elseif kind == "Charged" and set.Charged then logical = "Charged"
            elseif set.Backstab and not quick then
                -- the server decides a backstab; the clip guesses it the same way (the nearest enemy in reach facing away)
                local root = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart")
                local best, bestD = nil, AL1030.Config.MeleeBackstabRange or 6
                local list = {}
                for _, p in game:GetService("Players"):GetPlayers() do if p.Character and p.Character ~= hum.Parent then table.insert(list, p.Character) end end
                for _, b in game:GetService("CollectionService"):GetTagged("Bot") do table.insert(list, b) end
                for _, m in list do
                    local r = m:FindFirstChild("HumanoidRootPart")
                    local h = m:FindFirstChildOfClass("Humanoid")
                    if root and r and h and h.Health > 0 and (r.Position - root.Position).Magnitude < bestD then best, bestD = r, (r.Position - root.Position).Magnitude end
                end
                if best and root then
                    local flat = Vector3.new(1, 0, 1)
                    local look = best.CFrame.LookVector * flat
                    local toYou = (root.Position - best.Position) * flat
                    if look.Magnitude > 0.01 and toYou.Magnitude > 0.01 and look.Unit:Dot(toYou.Unit) < -MeleeConfig.BackstabAngle then logical = "Backstab" end
                end
            end
            local name = AL1030.First(set[logical]) or AL1030.First(set.Swing)
            alt = name and AL1030.Load(hum:FindFirstChildOfClass("Animator"), name, Enum.AnimationPriority.Action4, false)
        end
        if alt then alt:Play(0.05) elseif slashTrack then slashTrack:Play(0.05) end
    end
'''),
]

GADGET = [
    E('''local function loadTracks(humanoid: Humanoid)
    if trackOwner == humanoid and tracks then return tracks end
    tracks, trackOwner = {}, humanoid
''', '''local tracksFor1030 = nil -- [ANIMFINAL] the gadget the tracks were loaded for (its own clips)
local function loadTracks(humanoid: Humanoid)
    if trackOwner == humanoid and tracks and tracksFor1030 == kitGadget() then return tracks end
    tracks, trackOwner = {}, humanoid
    tracksFor1030 = kitGadget()
'''),
    E('''            if ok then
                track.Priority = Enum.AnimationPriority.Action4
                tracks[name] = track
            end
        end
    end
    return tracks
end
''', '''            if ok then
                track.Priority = Enum.AnimationPriority.Action4
                tracks[name] = track
            end
        end
    end
    do -- [ANIMFINAL] the gadget's own clips over the Smoke set (AnimFinalConfig.Gadgets): Frag / Flash throws, the Frag pin pull
        -- and cook hold, the landmine set-down (a tap), the medkit
        ''' + AFREQ + '''
        local set = okAF1030 and AL1030 and AL1030.Config.Enabled ~= false and AL1030.Config.Gadgets[kitGadget()]
        if set then
            for name, list in set do
                local t = AL1030.Load(animator, AL1030.First(list), Enum.AnimationPriority.Action4, name == "Hold")
                if t then tracks[name] = t end
            end
        end
    end
    return tracks
end
'''),
    E('''        ThrowGadget:FireServer(kitGadget(), aimDirection(), 1, "Use", 0)
        return true
''', '''        ThrowGadget:FireServer(kitGadget(), aimDirection(), 1, "Use", 0)
        local use1030 = loadTracks(humanoid).Use -- [ANIMFINAL] the medkit clip (stops when the channel ends: BodyAnimController)
        if use1030 then use1030:Play(0.1) end
        return true
'''),
    E('''    local t = loadTracks(humanoid)
    local gm = gadgetMode()
    if gm == "Roll" or gm == "Light" then
''', '''    local t = loadTracks(humanoid)
    if t.Press then t.Press:Play(0.05) end -- [ANIMFINAL] the Frag's pin pull on the press (the cook starts)
    local gm = gadgetMode()
    if gm == "Roll" or gm == "Light" then
'''),
]

PLAYERREGISTRY = [
    E('''    humanoid.Died:Once(function()
        ragdoll(character)
    end)
''', '''    humanoid.Died:Once(function()
        -- [ANIMFINAL] a death clip by hit direction and cover state first (ServerScriptService.Shared.DeathAnims), then the ragdoll
        local delay1030 = 0
        local sh1030 = game:GetService("ServerScriptService"):FindFirstChild("Shared")
        local da1030 = sh1030 and sh1030:FindFirstChild("DeathAnims")
        if da1030 then
            local ok, d = pcall(function() return require(da1030).Play(character, humanoid) end)
            if ok and type(d) == "number" then delay1030 = d end
        end
        if delay1030 > 0 then
            task.delay(delay1030, function() if character.Parent then ragdoll(character) end end)
        else
            ragdoll(character)
        end
    end)
'''),
]

BOTMANAGER = [
    E('''function Bot:_onDied()
    self.state = "Dead"
    -- ragdoll: swap motors for ball sockets so the body falls naturally
    for _, motor in self.model:GetDescendants() do
''', '''function Bot:_onDied()
    self.state = "Dead"
    -- [ANIMFINAL] the death clip first (ServerScriptService.Shared.DeathAnims, AnimFinalConfig.Death.Bots); the ragdoll waits for
    -- its ground contact (the died event below fires at once, as before)
    local delay1030 = 0
    do
        local sh1030 = game:GetService("ServerScriptService"):FindFirstChild("Shared")
        local da1030 = sh1030 and sh1030:FindFirstChild("DeathAnims")
        local hum1030 = self.model and self.model:FindFirstChildOfClass("Humanoid")
        if da1030 and hum1030 then
            local ok, d = pcall(function() return require(da1030).Play(self.model, hum1030) end)
            if ok and type(d) == "number" then delay1030 = d end
        end
    end
    local model1030 = self.model
    local function ragdoll1030()
    if not model1030 or not model1030.Parent then return end
    -- ragdoll: swap motors for ball sockets so the body falls naturally
    for _, motor in model1030:GetDescendants() do
'''),
    E('''                socket.Parent = motor.Part0
                motor:Destroy()
            end
        end
    end
    self.diedEvent:Fire()
''', '''                socket.Parent = motor.Part0
                motor:Destroy()
            end
        end
    end
    end -- [ANIMFINAL] ragdoll1030
    if delay1030 > 0 then task.delay(delay1030, ragdoll1030) else ragdoll1030() end
    self.diedEvent:Fire()
'''),
]

COMBAT = [
    E('''    victimHumanoid:SetAttribute("LastHitZone", zone)
''', '''    victimHumanoid:SetAttribute("LastHitZone", zone)
    victimHumanoid:SetAttribute("LastHitFrom", origin) -- [ANIMFINAL] where the hit came from (death by direction)
'''),
    E('''    victimHumanoid:SetAttribute("LastAttacker", 0)
    victimHumanoid:TakeDamage(damage)
''', '''    victimHumanoid:SetAttribute("LastAttacker", 0)
    victimHumanoid:SetAttribute("LastHitFrom", origin) -- [ANIMFINAL]
    victimHumanoid:TakeDamage(damage)
'''),
]

MELEE = [
    E('''    victimHum:SetAttribute("LastHitZone", backstab and "Back" or "Body")
''', '''    victimHum:SetAttribute("LastHitZone", backstab and "Back" or "Body")
    victimHum:SetAttribute("LastHitFrom", root.Position) -- [ANIMFINAL] where the hit came from (death by direction)
'''),
]

SHOOTABLE = [
    E('''    hum:SetAttribute("LastHitZone", nil)
    local hpBefore = hum.Health -- [HITINFO]
''', '''    hum:SetAttribute("LastHitZone", nil)
    hum:SetAttribute("LastHitFrom", from) -- [ANIMFINAL] the blast's centre (nil for burning)
    local hpBefore = hum.Health -- [HITINFO]
'''),
]

TARGETS = [
    ("ReplicatedStorage.Modules.Shared.Config.WeaponConfig", WEAPONCONFIG, False),
    (CC + "WeaponController", WEAPONCONTROLLER, False),
    (CC + "WeaponController.WeaponEffects", WEAPONEFFECTS, False),
    (CC + "HotbarController", HOTBAR, False),
    (CC + "GadgetController", GADGET, False),
    ("ServerScriptService.ServerScripts.[Server] Init.PlayerManager.PlayerRegistry", PLAYERREGISTRY, False),
    (MGR + "BotManager", BOTMANAGER, True),
    (MGR + "CombatManager", COMBAT, False),
    (MGR + "MeleeManager", MELEE, False),
    (MGR + "ShootableManager", SHOOTABLE, "soft"),
    ("ServerScriptService.Shared.ArenaShootables", SHOOTABLE, "soft"),  # the lobby's blast damage
]

MODULES = [  # (file, parent path, name)
    ("AnimFinalConfig.lua", "ReplicatedStorage.Modules.Shared.Config", "AnimFinalConfig"),
    ("AnimLib.lua", "ReplicatedStorage.Modules.Shared", "AnimLib"),
    ("BodyAnimController.lua", "StarterPlayer.StarterPlayerScripts.Client.Controllers", "BodyAnimController"),
    ("DeathAnims.lua", "ServerScriptService.Shared", "DeathAnims"),
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
            if optional == "soft" and any(new not in s and s.count(old) != 1 for old, new in edits):
                print(f"{os.path.basename(d)}: {path.split('.')[-1]} soft: anchor not here, skipped"); continue
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
    head = open(os.path.join(ROOT, "fix/anim_final_1030/installer_head.lua"), encoding="utf-8").read()
    body = open(os.path.join(ROOT, "fix/anim_final_1030/installer_body.lua"), encoding="utf-8").read()
    out = [head, f"local ROUND = {ROUND}\n", "local MODULES = {\n"]
    for fn, parent, name in MODULES:
        src = open(os.path.join(ROOT, "fix/anim_final_1030", fn), encoding="utf-8").read()
        out.append(f"\t{{ parent = {parent!r}, name = {name!r}, src = {lua_long(src)} }},\n".replace("'", '"'))
    out.append("}\nlocal TARGETS = {\n")
    for path, edits, optional in TARGETS:
        out.append(f"\t{{ path = {lua_long(path)}, optional = {'true' if optional else 'false'}, soft = {'true' if optional == 'soft' else 'false'}, edits = {{\n")
        for old, new in edits:
            out.append(f"\t\t{{ {lua_long(old)}, {lua_long(new)} }},\n")
        out.append("\t} },\n")
    out.append("}\n")
    out.append(body)
    open(os.path.join(ROOT, "fix/anim_final_1030.lua"), "w", encoding="utf-8", newline="\n").write("".join(out))
    print("wrote fix/anim_final_1030.lua")


if __name__ == "__main__":
    dirs = sys.argv[1:]
    if not dirs:
        base = os.path.join(ROOT, "out/anim_final")
        dirs = [os.path.join(base, d) for d in ("src_test", "src_match", "src_lobby") if os.path.isdir(os.path.join(base, d))]
        if not dirs: dirs = [os.path.join(base, "src_test_pre")]
    bad = check(dirs)
    if bad:
        print(f"{bad} anchor problems: nothing written"); sys.exit(1)
    build()
