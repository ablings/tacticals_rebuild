-- fix/anim_final_1030_tests.lua [ANIMFINAL] unit + install checks (Edit mode, after fix/anim_final_1030.lua).
-- python tools/run_luau_at.py <studio id> fix/anim_final_1030_tests.lua
-- Requires fresh CLONES of the modules (the plugin VM caches require per instance). Stand-in clips are made under
-- names that cannot clash ("AFT_*" plus the logical names' first candidates only while a test runs) and removed after.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local pass, fail, lines = 0, 0, {}
local function ok(c, msg)
	if c then pass += 1 else fail += 1 table.insert(lines, "FAIL " .. msg) end
end

local Shared = RS.Modules.Shared
local function fresh(m: ModuleScript)
	local c = m:Clone()
	c.Parent = m.Parent
	local r = require(c)
	c:Destroy()
	return r
end
-- AnimLib requires Config.AnimFinalConfig through script.Parent: clone it beside the original so it finds it
local AF = fresh(Shared.Config.AnimFinalConfig)
local AL = fresh(Shared.AnimLib)
local DA = fresh(SSS.Shared.DeathAnims)
ok(type(AF.Clips) == "table" and AF.Enabled ~= nil, "AnimFinalConfig loads")
ok(type(AL.Load) == "function" and type(AL.GunPrefix) == "function", "AnimLib loads")

-- DeathAnims.Pick: each case decided by the rule it names
local function pick(kind, zone, cover, rel) return DA.Pick({ config = AL.Config, kind = kind, zone = zone, coverState = cover, rel = rel }) end
ok(pick("Gun", "Head", nil, Vector3.new(0, 0, -10)) == "DeathHeadshot", "headshot kill -> DeathHeadshot")
ok(pick("Frag", nil, nil, Vector3.new(0, 0, -10)) == "DeathExplosion", "frag kill -> DeathExplosion")
ok(pick("Gun", "Body", "Cover", Vector3.new(0, 0, -10)) == "DeathInCover", "in cover, shot from the front -> DeathInCover (cover rule)")
ok(pick("Gun", "Body", nil, Vector3.new(0, 0, -10)) == "DeathFromFront", "shot from the front -> DeathFromFront")
ok(pick("Gun", "Body", nil, Vector3.new(0, 0, 10)) == "DeathFromBehind", "shot from behind -> DeathFromBehind")
ok(pick("Gun", "Body", nil, Vector3.new(10, 0, 0)) == "DeathSide", "shot from the right -> DeathSide")
ok(pick("Gun", "Body", nil, Vector3.new(-3, 0, -10)) == "DeathFromFront", "17 deg off the front -> still DeathFromFront")
ok(pick("Melee", "Back", nil, nil) == "DeathAny", "no direction -> DeathAny")
ok(pick("Gun", "Body", "None", Vector3.new(0, 0, 10)) == "DeathFromBehind", "CoverState None is not cover")

-- stand-in clips: one KeyframeSequence copied under the names the tests need
local srcRoot = RS.Repository.AnimationSources
local seed = srcRoot:FindFirstChildWhichIsA("KeyframeSequence")
ok(seed ~= nil, "AnimationSources has a KeyframeSequence to copy for stand-ins")
local made = {}
local function standIn(name)
	if srcRoot:FindFirstChild(name) or not seed then return end
	local c = seed:Clone()
	c.Name = name
	c:SetAttribute("PublishedId", nil)
	c.Parent = srcRoot
	table.insert(made, c)
end
for _, n in { "AFT_Own", "AFT_Fb", "HitFlinchF", "HitFlinchB", "HitFlinchL", "HitFlinchR", "HitHeadshot" } do standIn(n) end

-- GunPrefix: own set first, else the fallback set, else the own prefix
ok(AL.GunPrefix({ AnimationSourcePrefix = "AFT_", AnimationFallbackPrefix = "X" }, "Own") == "AFT_", "GunPrefix: own clip -> own prefix")
ok(AL.GunPrefix({ AnimationSourcePrefix = "NOPE_", AnimationFallbackPrefix = "AFT_" }, "Fb") == "AFT_", "GunPrefix: missing own clip -> fallback prefix")
ok(AL.GunPrefix({ AnimationSourcePrefix = "NOPE_", AnimationFallbackPrefix = "NOPE2_" }, "Zz") == "NOPE_", "GunPrefix: nowhere -> own prefix")
ok(AL.First({ "NoSuchClip_1030", "AFT_Own" }) == "AFT_Own", "First skips a missing name")
ok(AL.First({ "NoSuchClip_1030" }) == nil, "First of missing names is nil")

-- HitClip: the side the shot came from, in the body's space
local m = Instance.new("Model")
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.CFrame = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10)) -- faces -Z
root.Parent = m
local head = Instance.new("Part")
head.Name = "Head"
head.Position = Vector3.new(0, 4.5, 0)
head.Parent = m
m.Parent = workspace
local chest = Vector3.new(0, 3, 0)
ok(AL.HitClip(m, chest, Vector3.new(0, 0, 1)) == "HitFlinchF", "shot travelling +Z from the front -> HitFlinchF")
ok(AL.HitClip(m, chest, Vector3.new(0, 0, -1)) == "HitFlinchB", "shot from behind -> HitFlinchB")
ok(AL.HitClip(m, chest, Vector3.new(-1, 0, 0)) == "HitFlinchR", "shot from the right side -> HitFlinchR")
ok(AL.HitClip(m, chest, Vector3.new(1, 0, 0)) == "HitFlinchL", "shot from the left side -> HitFlinchL")
ok(AL.HitClip(m, Vector3.new(0, 4.6, 0), Vector3.new(1, 0, 0)) == "HitHeadshot", "hit at the head -> HitHeadshot (any side)")
m:Destroy()
-- Cooldown
local key = Instance.new("Folder") key.Parent = workspace
ok(AL.Cooldown(key, 10) == true and AL.Cooldown(key, 10) == false, "Cooldown: once per window")
key:Destroy()
for _, c in made do c:Destroy() end

-- WeaponConfig: the family prefixes (fresh copy of WeaponConfig requires AnimFinalConfig beside it)
local WC = fresh(Shared.Config.WeaponConfig)
for id, prefix in AF.GunPrefixes do
	local w = WC.Weapons[id]
	ok(w ~= nil and w.AnimationSourcePrefix == prefix and w.AnimationFallbackPrefix == AF.GunFallbackPrefix, "WeaponConfig " .. id .. " -> " .. prefix .. " (+ fallback)")
end
ok(WC.Weapons.Pistol.AnimationSourcePrefix == "Pistol" and WC.Weapons.Revolver.AnimationSourcePrefix == "Revolver", "Pistol / Revolver keep their sets")
ok(WC.Weapons.PumpShotgun.ReloadTime == 0.5 and WC.Weapons.Sniper.ReloadTime == 3.0, "reload times unchanged")

-- install checks: every edited script carries the marker and compiles; the modules exist and are ours
local function find(path)
	local node = game
	for seg in path:gmatch("[^%.]+") do node = node and node:FindFirstChild(seg) end
	return node
end
local CC = "StarterPlayer.StarterPlayerScripts.Client.Controllers."
local MG = "ServerScriptService.ServerScripts.[Server] Init.GameManager.Managers."
for _, p in { "ReplicatedStorage.Modules.Shared.Config.WeaponConfig", CC .. "WeaponController", CC .. "WeaponController.WeaponEffects",
	CC .. "HotbarController", CC .. "GadgetController", "ServerScriptService.ServerScripts.[Server] Init.PlayerManager.PlayerRegistry",
	MG .. "CombatManager", MG .. "MeleeManager" } do
	local s = find(p)
	ok(s and s.Source:find("[ANIMFINAL]", 1, true) ~= nil, "marker in " .. p:match("[^%.]+$"))
	ok(s and loadstring(s.Source) ~= nil, "compiles: " .. p:match("[^%.]+$"))
end
for _, p in { "ReplicatedStorage.Modules.Shared.Config.AnimFinalConfig", "ReplicatedStorage.Modules.Shared.AnimLib",
	CC .. "BodyAnimController", "ServerScriptService.Shared.DeathAnims" } do
	local s = find(p)
	ok(s and s:GetAttribute("AnimFinal1030") == true and loadstring(s.Source) ~= nil, "module " .. p:match("[^%.]+$"))
end
ok(RS.Modules.Shared.Config.WeaponConfig:GetAttribute("AnimFinal1030Round") ~= nil, "round stamp")

return ("ANIMFINAL tests: %d passed, %d failed\n%s"):format(pass, fail, table.concat(lines, "\n"))
