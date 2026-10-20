-- fix/movement_spec.lua [MOVE2] (2026-10-19, Edward's movement spec via the main PC lead; notes/movement_spec.md)
-- Run in Edit mode (execute_luau) in BOTH working copies. Idempotent: the first run keeps each edited module's original source
-- in ServerStorage._MOVE2_Originals (StringValues) and every run re-applies the edits to that original. Set UNDO = true to put
-- the originals back. Lobby walk / no-run lives in scripts/lobby/LobbyMovement.client.lua (installed separately).
--   MovementConfig  Edward 25 / 30->25, then base speeds -20%: Walk 10, Sprint 20, Crouch 4.8, Slide 24->20; crouch sprint removed
--   CoverConfig     Sneak 8, Dash 24, Roll 22.4, Sprint 24.8, CoverWalk 8, Dive 27.2, VaultTime 0.34375 (Edward 0.275 / 0.8)
--   WeaponConfig    MoveSpeed per gun; GadgetMoveSpeed 1.1; Mobility() = held gadget (player attribute HeldSlot) / gun / melee
--   MeleeConfig     MoveSpeed per melee item
--   MoveGuard       LIMIT 42 -> 48 (flag-only; legit top is now cover sprint 31 x Fists 1.3 = 40.3)
--   WeaponConfig    DrawTime per gun (C3: "wait until your gun is fully pulled out to shoot it and aim in"); back guns longer
--   CombatManager   rejects a shot sooner than DrawTime x DrawTimeTolerance after the gun went into the hand (state.equippedAt)
local UNDO = false --@UNDO

local RS, SS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"), game:GetService("ServerScriptService")
local Config = RS.Modules.Shared.Config

local WEAPON_BLOCK = [==[
-- [MOVE2] 2026-10-19 Edward: movement multipliers per item ("lets see how that works"). Reload times unchanged.
do
	local W = WeaponConfig.Weapons
	for id, v in { Pistol = 1.25, DualPistols = 1.2, SilencedPistol = 1.15, MiniUzi = 1.1, Revolver = 1.05, AutoRifle = 1,
		PumpShotgun = 1, SemiAuto = 1, Sniper = 0.9 } do
		if W[id] then W[id].MoveSpeed = v end
	end
end
-- [MOVE2] draw time (s): no firing or aiming in until the gun is out. Hip guns quick, back-carried guns slower.
do
	local W = WeaponConfig.Weapons
	for id, v in { Pistol = 0.3, SilencedPistol = 0.35, DualPistols = 0.4, Revolver = 0.4, MiniUzi = 0.4,
		AutoRifle = 0.6, PumpShotgun = 0.65, SemiAuto = 0.65, Sniper = 0.8 } do
		if W[id] then W[id].DrawTime = v end
	end
end
WeaponConfig.DrawTimeTolerance = 0.75 -- [MOVE2] the server allows a shot from 75% of DrawTime after the equip reached it
WeaponConfig.GadgetMoveSpeed = 1.1 -- [MOVE2] holding the gadget slot (no Tool: HotbarController sets player attribute HeldSlot)

-- [MOVE2] movement multiplier of what this character holds: the gadget slot, a gun's MoveSpeed, a melee item's MoveSpeed, else 1
function WeaponConfig.Mobility(character: Model?): number
	local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
	if player and player:GetAttribute("HeldSlot") == "Gadget" then return WeaponConfig.GadgetMoveSpeed end
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool then return 1 end
	local config = WeaponConfig.Weapons[tool:GetAttribute("WeaponId") or ""]
	if config then return config.MoveSpeed or 1 end
	local meleeId = tool:GetAttribute("MeleeId")
	if meleeId then
		local ok, melee = pcall(function() return require(script.Parent.MeleeConfig).Weapons[meleeId] end)
		if ok and melee and melee.MoveSpeed then return melee.MoveSpeed end
	end
	return 1
end

return WeaponConfig]==]

local MELEE_BLOCK = [==[
-- [MOVE2] 2026-10-19 Edward: movement multipliers per melee item
for id, v in { Fists = 1.3, Knife = 1.25, Bat = 1.1, Katana = 1.1, RiotShield = 0.7 } do
	if MeleeConfig.Weapons[id] then MeleeConfig.Weapons[id].MoveSpeed = v end
end

return MeleeConfig]==]

-- { module, { {old, new}, ... } }: each old must appear exactly once in the original
local EDITS = {
	-- (2026-10-19, Edward: "slow everyones speed down by 20%", final pick: the BASE speeds x0.8, item multipliers unchanged)
	{ Config.MovementConfig, {
		{ "\t\tWalk = 12.5,", "\t\tWalk = 10, -- [MOVE2] was 12.5 (base -20%)" },
		{ "\t\tSprint = 23,", "\t\tSprint = 20, -- [MOVE2] was 23 (25, then base -20%)" },
		{ "\t\tCrouch = 6,", "\t\tCrouch = 4.8, -- [MOVE2] was 6 (base -20%)" },
		{ "\t\tCrouchSprint = 16,  -- Shift while crouched: fast silent strides. Costs stamina (faster drain than sprinting).\n", "" },
		{ "\t\tCrouchSprintDrain = 28, -- per second (about 3.5s of fast strides from full)\n", "" },
		{ "\t\tSpeed = 30,", "\t\tSpeed = 24, -- [MOVE2] was 30 (base -20%)" },
		{ "\t\tEndSpeed = 9,", "\t\tEndSpeed = 20, -- [MOVE2] was 9 (25, then base -20%);" },
	} },
	{ Config.CoverConfig, {
		{ "\tCoverWalkSpeed = 10,", "\tCoverWalkSpeed = 8, -- [MOVE2] was 10 (base -20%)" },
		{ "MoveSpeeds = { Sneak = 9, Dash = 26, Roll = 28, Sprint = 31 },",
		  "MoveSpeeds = { Sneak = 8, Dash = 24, Roll = 22.4, Sprint = 24.8 }, --[[ [MOVE2] were 9 / 26 / 28 / 31: Edward's 10 / 30, then base -20% ]]" },
		{ "\tDiveSpeed = 34,", "\tDiveSpeed = 27.2, -- [MOVE2] was 34 (base -20%)" },
		{ "\tVaultTime = 0.55,", "\tVaultTime = 0.34375, -- [MOVE2] was 0.55: Edward's 2x faster (0.275), then base -20% (/0.8)" },
	} },
	{ Config.WeaponConfig, { { "\nreturn WeaponConfig", "\n" .. WEAPON_BLOCK } } },
	{ Config.MeleeConfig, { { "\nreturn MeleeConfig", "\n" .. MELEE_BLOCK } } },
	{ SSS:FindFirstChild("CombatManager", true), {
		{ "\ttool:GetPropertyChangedSignal(\"Parent\"):Connect(function()\n\t\tlocal character = player.Character\n",
		  "\ttool:GetPropertyChangedSignal(\"Parent\"):Connect(function()\n\t\tlocal character = player.Character\n\t\tif tool.Parent == character then state.equippedAt = os.clock() end -- [MOVE2] draw time starts\n" },
		{ "\t\tif now - state.lastFire < interval * V.FireIntervalTolerance then\n",
		  "\t\t-- [MOVE2] draw time: no shot before the gun is out\n\t\tif state.equippedAt and now - state.equippedAt < (config.DrawTime or 0) * (WeaponConfig.DrawTimeTolerance or 0.75) then\n\t\t\treturn finish(\"still drawing\")\n\t\tend\n\t\tif now - state.lastFire < interval * V.FireIntervalTolerance then\n" },
	} },
	{ SSS:FindFirstChild("MoveGuard", true), { { "local LIMIT = 42\n", "local LIMIT = 48 -- [MOVE2] was 42 (cover sprint 31 x Fists 1.3 = 40.3)\n" } } },
}

local bin = SS:FindFirstChild("_MOVE2_Originals")
if not bin then bin = Instance.new("Folder"); bin.Name = "_MOVE2_Originals"; bin.Parent = SS end
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording(UNDO and "MOVE2 undo" or "MOVE2 movement spec")
local log = {}
for _, e in EDITS do
	local mod, list = e[1], e[2]
	assert(mod, "missing module")
	local key = mod:GetFullName():gsub("[%.%[%] ]", "_")
	local orig = bin:FindFirstChild(key)
	if UNDO then
		if orig then mod.Source = orig.Value; orig:Destroy(); table.insert(log, "restored " .. mod.Name) end
	else
		if not orig then
			orig = Instance.new("StringValue"); orig.Name = key; orig.Value = mod.Source; orig.Parent = bin
		end
		local src = orig.Value
		for _, pair in list do
			local a, b = src:find(pair[1], 1, true)
			assert(a, mod.Name .. ": edit anchor not found: " .. pair[1]:sub(1, 60))
			assert(not src:find(pair[1], b + 1, true), mod.Name .. ": edit anchor not unique: " .. pair[1]:sub(1, 60))
			src = src:sub(1, a - 1) .. pair[2] .. src:sub(b + 1)
		end
		mod.Source = src
		table.insert(log, mod.Name .. " (" .. #list .. " edits)")
	end
end
if UNDO and #bin:GetChildren() == 0 then bin:Destroy() end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return (UNDO and "UNDO: " or "MOVE2: ") .. table.concat(log, ", ")
