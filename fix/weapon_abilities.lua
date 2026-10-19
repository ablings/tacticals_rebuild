-- fix/weapon_abilities.lua [ABILITY] 2026-10-19, Phase 1 of Edward's weapon identities (notes/weapon_abilities.md).
-- Both places (hub + match). Idempotent; UNDO swaps every edit back.
--   WeaponConfig: the speed ladder (MoveSpeed = run / crouch / slide / dash to cover / vault, and ReloadTime), Pistol Quickdraw
--     (tight hip fire), Silenced Pistol Whisper (SoundScale: every sound it makes carries less), Mini Uzi Run and Gun
--     (RunAndGun: firing / aiming don't stop a sprint, full speed aimed in, AimSprintSpread when aimed in at a run),
--     Automatic Rifle 30-round magazine, Semi-Auto Precision Rhythm (Rhythm), Sniper one-shot headshot (HeadshotKills:
--     no drop-off on the head), and WeaponConfig.Mobility(character) for the movement code.
--   CombatManager: Precision Rhythm stacks (player attribute RhythmStacks 0..3: a hit in a row +5% damage each, a miss
--     resets, a new gun / life resets), and the reload noise the AI hears scales with the gun's SoundScale.
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local WC = RS.Modules.Shared.Config.WeaponConfig
local CM = game:GetService("ServerScriptService").ServerScripts["[Server] Init"].GameManager.Managers.CombatManager

local CONFIG_ANCHOR = "-- Link every weapon to its class (missing fields fall back to the class)\n"
local CONFIG_BLOCK = [[
-- [ABILITY] 2026-10-19 one identity per gun (Edward: notes/weapon_abilities.md; Kit screen text in Config.WeaponAbilities).
-- These override the table above.
--   Speed ladder, fastest first: MoveSpeed scales running, crouching, sliding, the dash to cover and vaults
--   (WeaponConfig.Mobility); ReloadTime follows the same order.
--                  MoveSpeed  Reload
--   Pistol           1.06      1.3    Quickdraw: accurate from the hip
--   (Dual Pistols    1.04      1.4    not in the game yet)
--   Suppressed       1.03      1.5    Whisper: every sound it makes carries less (SoundScale)
--   Mini Uzi         1.00      1.7    Run and Gun: shoots and aims in at a full run (85% accuracy aimed at a run)
--   Revolver         0.97      2.0
--   Auto Rifle       0.94      2.2    30-round magazine
--   (Pump Shotgun    0.91       -     not in the game yet)
--   Semi-Auto        0.89      2.5    Precision Rhythm: +5% damage per hit in a row, up to 3; a miss resets
--   Sniper           0.85      3.0    a headshot always kills (no drop-off on the head)
do
	local W = WeaponConfig.Weapons
	for id, v in { Pistol = { 1.06, 1.3 }, SilencedPistol = { 1.03, 1.5 }, MiniUzi = { 1.0, 1.7 }, Revolver = { 0.97, 2.0 },
		AutoRifle = { 0.94, 2.2 }, SemiAuto = { 0.89, 2.5 }, Sniper = { 0.85, 3.0 } } do
		if W[id] then W[id].MoveSpeed, W[id].ReloadTime = v[1], v[2] end
	end
	W.Pistol.HipFireSpread = 1.75 -- Quickdraw (class Pistol: 3.5)
	W.SilencedPistol.SoundScale = 0.35 -- Whisper: reload / dry-fire / draw sounds reach 35% as far (the shot itself: Loudness)
	W.MiniUzi.RunAndGun = true -- firing doesn't stop a sprint, and you can sprint aimed in
	W.MiniUzi.AimMoveSpeed = 1 -- full speed aimed in
	W.MiniUzi.AimSprintSpread = 1.5 -- degrees of spread aimed in at a run (aimed in standing: 0)
	W.MiniUzi.HipFireSpread = 4 -- a little tighter than the SMG class (5)
	W.AutoRifle.MagazineSize, W.AutoRifle.ReserveAmmo = 30, 120
	W.SemiAuto.Rhythm = { PerStack = 0.05, MaxStacks = 3 }
	W.Sniper.HeadshotKills = true
end

-- Movement multiplier of the gun this character is holding (1 with no gun / melee)
function WeaponConfig.Mobility(character: Model?): number
	local tool = character and character:FindFirstChildOfClass("Tool")
	local config = tool and WeaponConfig.Weapons[tool:GetAttribute("WeaponId") or ""]
	return config and config.MoveSpeed or 1
end

]]
local DMG_OLD = "\tlocal dmg = config.Damage[zone]\n"
local DMG_NEW = "\tlocal dmg = config.Damage[zone]\n"
	.. "\tif zone == \"Head\" and config.HeadshotKills then return math.max(1, math.floor(dmg + 0.5)) end -- [ABILITY] no drop-off\n"

local edits = {
	{ WC, CONFIG_ANCHOR, CONFIG_BLOCK .. CONFIG_ANCHOR },
	{ WC, DMG_OLD, DMG_NEW },
	-- Precision Rhythm helper, before the fire handler
	{ CM, "local function onFire(player: Player, shotId: any, origin: any, direction: any, hitPart: any, hitPosition: any)\n",
		"-- [ABILITY] Semi-Auto Precision Rhythm: each hit in a row adds PerStack damage (up to MaxStacks); a miss resets it.\n"
		.. "-- Player attribute RhythmStacks = the stacks the NEXT hit gets (crosshair pips). Shots the server rejects for lag change nothing.\n"
		.. "local function rhythm(player: Player, config, hit: boolean): number\n"
		.. "\tlocal R = config.Rhythm\n"
		.. "\tif not R then return 1 end\n"
		.. "\tlocal stacks = player:GetAttribute(\"RhythmStacks\") or 0\n"
		.. "\tif not hit then\n"
		.. "\t\tif stacks ~= 0 then player:SetAttribute(\"RhythmStacks\", 0) end\n"
		.. "\t\treturn 1\n"
		.. "\tend\n"
		.. "\tplayer:SetAttribute(\"RhythmStacks\", math.min(stacks + 1, R.MaxStacks))\n"
		.. "\treturn 1 + R.PerStack * stacks\n"
		.. "end\n\n"
		.. "local function onFire(player: Player, shotId: any, origin: any, direction: any, hitPart: any, hitPosition: any)\n" },
	{ CM, "\t\treturn finish(\"muzzle behind cover\")\n",
		"\t\trhythm(player, config, false) -- [ABILITY]\n\t\treturn finish(\"muzzle behind cover\")\n" },
	{ CM, "\tif hitPart == nil then return finish() end -- clean miss\n\tif not victimCharacter or not claimedHit then return finish(\"hit data invalid\") end\n",
		"\tif hitPart == nil or not victimCharacter then rhythm(player, config, false) end -- [ABILITY] a miss (or a wall) resets the rhythm\n"
		.. "\tif hitPart == nil then return finish() end -- clean miss\n\tif not victimCharacter or not claimedHit then return finish(\"hit data invalid\") end\n" },
	{ CM, "\tlocal damage = WeaponConfig.DamageAt(config, zone, distance)\n",
		"\tlocal damage = WeaponConfig.DamageAt(config, zone, distance)\n"
		.. "\tif config.Rhythm then damage = math.max(1, math.floor(damage * rhythm(player, config, true) + 0.5)) end -- [ABILITY]\n" },
	-- a new gun starts the rhythm over
	{ CM, "\ttool:SetAttribute(\"WeaponId\", weaponId)\n",
		"\ttool:SetAttribute(\"WeaponId\", weaponId)\n\tplayer:SetAttribute(\"RhythmStacks\", config.Rhythm and 0 or nil) -- [ABILITY]\n" },
	-- Whisper: the AI hears a quiet gun's reload from closer
	{ CM, "bots.HearNoise(root.Position, ShootableConfig.ReloadHearRange or 22)",
		"bots.HearNoise(root.Position, (ShootableConfig.ReloadHearRange or 22) * (state.config.SoundScale or 1)) --[[ABILITY]]" },
}

local out = {}
local sources = {}
for _, e in edits do sources[e[1]] = sources[e[1]] or e[1].Source end
for i, e in edits do
	local s = sources[e[1]]
	local old, new = e[2], e[3]
	if UNDO then old, new = new, old end
	if s:find(new, 1, true) then
		table.insert(out, i .. " already")
	else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found in " .. e[1].Name)
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique")
		sources[e[1]] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. " ok")
	end
end
for inst, s in sources do
	local okf, perr = loadstring(s)
	assert(okf, inst.Name .. " would not parse: " .. tostring(perr))
	if inst.Source ~= s then inst.Source = s end
end
return table.concat(out, ", ")
