"""Builds fix/install_training_extras.lua (Training extras, step 2) from scripts/training_extras/*.lua plus the minimal,
commented edits to three existing scripts. Run: python tools/build_training_extras.py, then
python tools/run_luau.py fix/install_training_extras.lua [UNDO]   (Tacticals_rebuild.rbxl only).
The installer is idempotent: originals of edited scripts are kept once in ServerStorage._TX_Originals (StringValues) and every
run re-applies the edits to that original. UNDO restores the originals and removes every new module / remote."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "scripts", "training_extras")

MGR = 'game.ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers'
CTL = 'game.StarterPlayer.StarterPlayerScripts.Client.Controllers'
NEW = [  # (parent expr, name, file)
    ('game.ReplicatedStorage.Modules.Shared.Config', "TrainingConfig", "TrainingConfig.lua"),
    (MGR, "TrainingExtrasManager", "TrainingExtrasManager.lua"),
    (MGR, "ShootableManager", "ShootableManager.lua"),
    (MGR, "TrainingTargetsManager", "TrainingTargetsManager.lua"),
    (MGR, "TrainingDpsManager", "TrainingDpsManager.lua"),
    (MGR, "TrainingBinsManager", "TrainingBinsManager.lua"),
    (CTL, "TrainingPadsController", "TrainingPadsController.lua"),
    (CTL, "TrainingTargetsController", "TrainingTargetsController.lua"),
    (CTL, "TrainingBinsController", "TrainingBinsController.lua"),
]

TM_A_OLD = "local ENEMIES, HEAL_DELAY, CORPSE_TIME, RESPAWN_DELAY, HEALTH = 24, 2.5, 3, 2, 150\n"
TM_A_NEW = TM_A_OLD + (
    "-- [TX] Training extras (notes/training_extras_done.md): alive count + gallery-first from Shared.Config.TrainingConfig\n"
    "local TXok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)\n"
    "if TXok and TX.On(\"AliveDummies\") then ENEMIES = TX.AliveDummies end   -- [TX] 24 -> 35\n")
TM_B_OLD = ("\tlocal list = {}\n"
            "\tfor _, s in spots:GetChildren() do if not used[s] then table.insert(list, s) end end\n"
            "\tif #list == 0 then return nil end\n")
TM_B_NEW = ("\tlocal list, gal = {}, {}   -- [TX] BaseParts only (a sub-folder no longer breaks it); gallery spots refill first\n"
            "\tfor _, s in spots:GetDescendants() do if s:IsA(\"BasePart\") and not used[s] then table.insert(list, s)\n"
            "\t\tif s:GetAttribute(\"Gallery\") == true then table.insert(gal, s) end end end\n"
            "\tif TXok and TX.On(\"GalleryFill\") and #gal > 0 then return gal[math.random(1, #gal)] end   -- [TX]\n"
            "\tif #list == 0 then return nil end\n")
TM_C_OLD = "\t\t\ttask.delay(RESPAWN_DELAY, function() used[spot] = nil; spawnEnemy() end)\n"
TM_C_NEW = ("\t\t\tlocal wait = (TXok and TX.On(\"GalleryFill\") and spot:GetAttribute(\"Gallery\") == true) and TX.GalleryRespawn or RESPAWN_DELAY   -- [TX]\n"
            "\t\t\ttask.delay(wait, function() used[spot] = nil; spawnEnemy() end)\n")

RF_A_OLD = "local ROOM_RADIUS = {Training = 175}   -- the huge training room (pass 31)\n"
RF_A_NEW = RF_A_OLD + (
    "-- [TX] Training extras (notes/training_extras_done.md): Training lights use a box over the arena + gallery\n"
    "-- (TrainingConfig.RoomBox, flag RoomFXBox) instead of the 175 sphere, so they stay off at the Showroom (Kit menu) camera.\n"
    "local TXok, TX = pcall(function() return require(game:GetService(\"ReplicatedStorage\"):WaitForChild(\"Modules\"):WaitForChild(\"Shared\"):WaitForChild(\"Config\"):WaitForChild(\"TrainingConfig\", 10)) end)\n"
    "local function inBox(p, b) return p.X >= b.Min.X and p.X <= b.Max.X and p.Y >= b.Min.Y and p.Y <= b.Max.Y and p.Z >= b.Min.Z and p.Z <= b.Max.Z end\n")
RF_B_OLD = "\t\tlocal on = c ~= nil and (p - c).Magnitude < (ROOM_RADIUS[h:GetAttribute(\"Room\")] or RADIUS)\n"
RF_B_NEW = ("\t\tlocal on = c ~= nil and (p - c).Magnitude < (ROOM_RADIUS[h:GetAttribute(\"Room\")] or RADIUS)\n"
            "\t\tif h:GetAttribute(\"Room\") == \"Training\" and TXok and TX and TX.On(\"RoomFXBox\") then on = inBox(p, TX.RoomBox) end   -- [TX]\n")

WC_OLD = "\tif CoverController and CoverController.IsHopping() then return end\n"
WC_NEW = ("\t-- [TX] Training jump pads (notes/training_extras_done.md): airborne from a pad you may shoot; normal rule again on landing\n"
          "\tlocal TXpads = Get(\"TrainingPadsController\")\n"
          "\tif CoverController and CoverController.IsHopping() and not (TXpads and TXpads.IsPadFlight and TXpads.IsPadFlight()) then return end\n")

EDITS = [  # (script expr, key, [(old, new)])
    (MGR + ".TrainingManager", "TrainingManager", [(TM_A_OLD, TM_A_NEW), (TM_B_OLD, TM_B_NEW), (TM_C_OLD, TM_C_NEW)]),
    ('game.StarterPlayer.StarterPlayerScripts.RoomFX', "RoomFX", [(RF_A_OLD, RF_A_NEW), (RF_B_OLD, RF_B_NEW)]),
    (CTL + ".WeaponController", "WeaponController", [(WC_OLD, WC_NEW)]),
]

def lstr(s):
    n = 0
    while ("]" + "=" * n + "]") in s: n += 1
    return "[" + "=" * n + "[\n" + s + "]" + "=" * n + "]"

out = ['''--[[ fix/install_training_extras.lua : Training extras (step 2) in Tacticals_rebuild.rbxl (LOCAL copy only). GENERATED by
tools/build_training_extras.py from scripts/training_extras/*.lua: edit those, then rebuild. Idempotent; UNDO restores.
Report: notes/training_extras_done.md ]]
local UNDO = false --@UNDO
local SS = game:GetService("ServerStorage")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local ORIG = SS:FindFirstChild("_TX_Originals")
if not ORIG and not UNDO then ORIG = Instance.new("Folder"); ORIG.Name = "_TX_Originals"; ORIG.Parent = SS end
local function ensureOriginal(key, scr)
	local v = ORIG:FindFirstChild(key)
	if not v then v = Instance.new("StringValue"); v.Name = key; v.Value = scr.Source; v.Parent = ORIG end
	return v.Value
end
''']
out.append("local NEW = {")
for parent, name, f in NEW:
    src = open(os.path.join(SRC, f), encoding="utf-8").read()
    out.append("\t{function() return " + parent + ' end, "' + name + '", ' + lstr(src) + "},")
out.append("}")
out.append("local EDITS = {")
for expr, key, pairs in EDITS:
    ps = ", ".join("{" + lstr(o) + ", " + lstr(n) + "}" for o, n in pairs)
    out.append(f"\t{{function() return {expr} end, \"{key}\", {{{ps}}}}},")
out.append("}")
out.append('''
if UNDO then
	for _, e in EDITS do
		local scr = e[1](); local v = ORIG and ORIG:FindFirstChild(e[2])
		if v then scr.Source = v.Value; say("restored", e[2]) end
	end
	for _, n in NEW do
		local par = n[1](); local m = par:FindFirstChild(n[2])
		if m and m:GetAttribute("TX_New") then m:Destroy(); say("removed", n[2]) end
	end
	for _, r in {"TargetPop", "SwapWeapon"} do local x = game.ReplicatedStorage.Events.Training:FindFirstChild(r); if x then x:Destroy(); say("removed remote", r) end end
	if ORIG then ORIG:Destroy() end
	say("UNDO done")
	return table.concat(log, "\\n")
end
for _, n in NEW do
	local par = n[1]()
	local m = par:FindFirstChild(n[2])
	if m and not m:GetAttribute("TX_New") then error("a module named " .. n[2] .. " already exists at " .. m:GetFullName() .. " (not ours)") end
	if not m then m = Instance.new("ModuleScript"); m.Name = n[2]; m:SetAttribute("TX_New", true); m.Parent = par end
	m.Source = n[3]
	say("module", m:GetFullName(), #n[3])
end
for _, e in EDITS do
	local scr = e[1]()
	local src = ensureOriginal(e[2], scr)
	for i, pair in e[3] do
		local a, b = string.find(src, pair[1], 1, true)
		if not a then error("edit " .. e[2] .. " #" .. i .. ": original text not found") end
		local first = select(2, string.gsub(string.sub(src, 1, a), "\\n", "")) + 1
		src = string.sub(src, 1, a - 1) .. pair[2] .. string.sub(src, b + 1)
		local n = select(2, string.gsub(pair[2], "\\n", ""))
		say("edit", e[2], "#" .. i, "lines", first .. "-" .. (first + n - 1))
	end
	scr.Source = src
end
return table.concat(log, "\\n")
''')
open(os.path.join(ROOT, "fix", "install_training_extras.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(out))
print("written fix/install_training_extras.lua")
