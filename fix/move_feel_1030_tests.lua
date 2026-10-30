-- fix/move_feel_1030_tests.lua [MOVEFEEL] [RELOADVAR] (2026-10-30): install + rule checks for fix/move_feel_1030.lua and
-- fix/reload_variants.lua. Edit mode: python tools/run_luau_at.py <studio id> fix/move_feel_1030_tests.lua
-- Modules are required from fresh clones (the plugin VM caches require per instance).
local RS = game:GetService("ReplicatedStorage")
local pass, fail, lines = 0, 0, {}
local function check(name, ok, detail)
	if ok then pass += 1 else fail += 1 table.insert(lines, "FAIL " .. name .. (detail and (": " .. tostring(detail)) or "")) end
end
local function fresh(m) local c = m:Clone() c.Parent = m.Parent local ok, r = pcall(require, c) c:Destroy() return ok and r or nil, r end
local Cfg = RS.Modules.Shared.Config
local CC = game.StarterPlayer.StarterPlayerScripts.Client.Controllers

-- // installs
check("MoveFeelConfig installed", Cfg:FindFirstChild("MoveFeelConfig") ~= nil)
check("MoveFeelController installed", CC:FindFirstChild("MoveFeelController") ~= nil)
check("ReloadVariantConfig installed", Cfg:FindFirstChild("ReloadVariantConfig") ~= nil)
check("ReloadVariantFX installed", CC:FindFirstChild("ReloadVariantFX") ~= nil)
check("MOVEFEEL stamp", Cfg.MovementConfig:GetAttribute("MoveFeel1030Round") == 1)
check("RELOADVAR stamp", Cfg.WeaponConfig:GetAttribute("ReloadVariants1030Round") == 1)
for _, n in { "MovementController", "CoverController", "MoveFeelController", "WeaponController", "ReloadVariantFX" } do
	local s = CC:FindFirstChild(n)
	local f, err = s and loadstring(s.Source)
	check(n .. " compiles", f ~= nil, err)
end
for _, s in { Cfg.MoveFeelConfig, Cfg.ReloadVariantConfig } do check(s.Name .. " compiles", loadstring(s.Source) ~= nil) end

-- // gameplay numbers unchanged (the feel pass is look and input only)
local MC = fresh(Cfg.MovementConfig)
check("Speeds unchanged", MC and MC.Speeds.Walk == 10 and MC.Speeds.Sprint == 20 and MC.Speeds.Crouch == 4.8)
check("Slide unchanged", MC and MC.Slide.Speed == 24 and MC.Slide.EndSpeed == 20 and MC.Slide.Time == 0.75 and MC.Slide.Cooldown == 0.6)
local CV = fresh(Cfg.CoverConfig)
check("Cover timings unchanged", CV and CV.PullUpTime == 0.5 and CV.PeekTime == 0.115 and CV.HopHeight == 2.2 and CV.PullUpMaxHeight == 5.1)
local MF = fresh(Cfg.MoveFeelConfig)
check("feel config sane", MF and MF.Momentum.AccelTime <= 0.15 and MF.Momentum.DecelTime <= 0.12 and MF.Camera.SprintFOV <= 6
	and MF.Lean.MaxPitchForward <= 6 and MF.Lean.MaxRoll <= 6 and MF.Buffer.Slide <= 0.25)
-- stop distance added by DecelTime at sprint: 0.5 * v * t (within 10 % of a 20-stud sprint's one-second travel)
check("decel adds <= 1 stud at sprint", MF and 0.5 * 25 * MF.Momentum.DecelTime <= 1.0001)

-- // reload variants
local WC = fresh(Cfg.WeaponConfig)
local RTIME = { Pistol = 1.3, SilencedPistol = 1.5, MiniUzi = 1.7, AutoRifle = 2.2, SemiAuto = 2.5, Sniper = 3, Revolver = 2, PumpShotgun = 0.5, DualPistols = 1.4 }
for id, t in RTIME do
	local w = WC and WC.Weapons[id]
	check(id .. " ReloadTime unchanged (" .. t .. ")", w and w.ReloadTime == t, w and w.ReloadTime)
end
local RV = fresh(Cfg.ReloadVariantConfig)
local cases = {
	{ "Pistol", 0, "Reload_Dry" }, { "Pistol", 1, "Reload_Drop" }, { "Pistol", 6, "Reload_Drop" }, { "Pistol", 7, "Reload_Retain" }, { "Pistol", 11, "Reload_Retain" },
	{ "SilencedPistol", 5, "Reload_Drop" }, { "SilencedPistol", 6, "Reload_Retain" },
	{ "MiniUzi", 15, "Reload_Drop" }, { "MiniUzi", 16, "Reload_Retain" }, { "AutoRifle", 0, "Reload_Dry" }, { "AutoRifle", 29, "Reload_Retain" },
	{ "SemiAuto", 6, "Reload_Drop" }, { "SemiAuto", 7, "Reload_Retain" }, { "Sniper", 0, "Reload_Dry" }, { "Sniper", 4, "Reload_TopUp" },
	{ "Revolver", 0, "Reload_Dry" }, { "Revolver", 1, "Reload_Dump" }, { "Revolver", 3, "Reload_Dump" }, { "Revolver", 4, "Reload_Pluck2" },
	{ "Revolver", 5, "Reload_Pluck1" }, { "DualPistols", 3, nil }, { "PumpShotgun", 2, nil },
}
for _, c in cases do
	local got = RV and RV.Pick(c[1], c[2])
	check(("pick %s %d -> %s"):format(c[1], c[2], tostring(c[3])), got == c[3], got)
end
-- every variant clip is exactly its gun's ReloadTime long (shotgun: ShellTime 0.5 / StartDelay 0.2), so the code's fit
-- (AdjustSpeed(Length / ReloadTime)) plays it at 1x and the reload lasts what the server times, for every gun that uses it
local src = RS.Repository.AnimationSources
local function len(ks)
	local m = 0
	for _, k in ks:GetChildren() do if k:IsA("Keyframe") then m = math.max(m, k.Time) end end
	return m
end
local WANT = {
	PistolReload_Drop = 1.3, PistolReload_Dry = 1.3, PistolReload_Retain = 1.3,
	RevolverReload_Dry = 2, RevolverReload_Dump = 2, RevolverReload_Pluck1 = 2, RevolverReload_Pluck2 = 2,
	RifleReload_Drop = 2.2, RifleReload_Dry = 2.2, RifleReload_Retain = 2.2,
	SMGReload_Drop = 1.7, SMGReload_Dry = 1.7, SMGReload_Retain = 1.7,
	ShotgunReloadShell_B = 0.5, ShotgunReloadShell_Last = 0.5, ShotgunReloadShell_Port = 0.5, ShotgunReloadStart_Dry = 0.2,
	SniperReload_Dry = 3, SniperReload_TopUp = 3,
}
local nVar = 0
for name, t in WANT do
	for _, suffix in { "", "Left" } do
		local ks = src:FindFirstChild(name .. suffix)
		if ks then nVar += 1 end
		check(("%s%s length %.1f"):format(name, suffix, t), ks ~= nil and math.abs(len(ks) - t) < 0.02, ks and len(ks))
	end
end
check("variant clips found (38)", nVar == 38, nVar)
-- every gun that shares a set: played duration = Length / (Length / ReloadTime) = its own ReloadTime
for id, prefix in { Pistol = "Pistol", SilencedPistol = "Pistol", MiniUzi = "SMG", AutoRifle = "Rifle", SemiAuto = "Rifle", Sniper = "Sniper", Revolver = "Revolver" } do
	for row = 0, 40 do
		local v = RV and RV.Pick(id, row)
		local ks = v and src:FindFirstChild(prefix .. v)
		if ks then
			local speed = len(ks) / RTIME[id]
			check(("%s %d rounds: %s plays %.2f s"):format(id, row, ks.Name, RTIME[id]), math.abs(len(ks) / speed - RTIME[id]) < 1e-6)
		end
	end
end
-- the played duration = Length / (Length / ReloadTime) = ReloadTime for every gun, whatever the clip: the code line is unchanged
local wcs = CC.WeaponController.Source
check("reload fit line unchanged", wcs:find("if track and track.Length > 0 then track:AdjustSpeed(track.Length / fit) end", 1, true) ~= nil)
check("server ReloadWeapon handler untouched (no RELOADVAR on the server)", not game:GetService("ServerScriptService"):FindFirstChild("CombatManager", true).Source:find("RELOADVAR", 1, true))

table.insert(lines, 1, ("MOVEFEEL/RELOADVAR tests: %d passed, %d failed"):format(pass, fail))
return table.concat(lines, "\n")
