-- fix/hitinfo.lua [HITINFO] 2026-10-21 (Edward via Roblox training: RIVALS-style hitmarkers, damage numbers and hit flash; the UI
-- session draws them). The shooter's HitConfirm keeps its five client args (zone, damage, killed, headshot, kind) and gains a 6th:
--   info = {
--     pos    = Vector3  -- world point of the hit (guns: the hit point; melee / blasts / abilities: the victim's upper torso)
--     victim = Model    -- the character / dummy hit
--     dealt  = number   -- health actually removed (damage capped by the health left; 0 through a ForceField). Health goes NEGATIVE
--                         on a killing TakeDamage, so it is clamped at 0 before the subtraction (tested: 10 HP + a 30 shot -> dealt 10)
--     source = "Gun" | "Melee" | "Explosion" | "Ability"
--     weapon = string?  -- WeaponId (guns), MeleeId (melee), blast kind ("Frag", "Blast", ...) or ability kind
--     pellet = number?  -- shotgun pellet index (each pellet is its own shot and its own HitConfirm)
--     backstab = true?  -- melee from behind
--   }
-- Fires for every source: each gun shot / pellet (CombatManager), melee (MeleeManager), blasts (ShootableManager in the match places,
-- ArenaShootables in the lobby), abilities (Abilities.hurt). Burn ticks still send no HitConfirm (as before).
-- Both places. Idempotent; UNDO = true swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")

local function patch(inst, edits)
	if not inst then return "missing" end
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		if UNDO then old, new = new, old end
		if s:find(new, 1, true) then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			assert(a, inst.Name .. " edit " .. i .. ": anchor not found")
			assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. ": anchor not unique")
			s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
			table.insert(out, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return inst.Name .. " " .. table.concat(out, " ")
end

local TORSO = "(%s:FindFirstChild(\"UpperTorso\") or %s:FindFirstChild(\"HumanoidRootPart\") or %s:FindFirstChildWhichIsA(\"BasePart\")).Position"
local function torso(v) return TORSO:format(v, v, v) end

local res = {}
table.insert(res, patch(SSS:FindFirstChild("CombatManager", true), {
	{ "\tvictimHumanoid:TakeDamage(damage)\n\n\t-- [DATA] HitConfirm 4th",
	  "\tlocal hpBefore = victimHumanoid.Health -- [HITINFO]\n\tvictimHumanoid:TakeDamage(damage)\n\n\t-- [DATA] HitConfirm 4th" },
	{ "\tCombat.HitConfirm:FireClient(player, zone, damage, victimHumanoid.Health <= 0, headshot)\n",
	  "\t-- [HITINFO] 6th client arg (fix/hitinfo.lua): hit point, victim, health actually removed, source, weapon, pellet\n"
	  .. "\tCombat.HitConfirm:FireClient(player, zone, damage, victimHumanoid.Health <= 0, headshot, nil, { pos = hitPosition, victim = victimCharacter,\n"
	  .. "\t\tdealt = math.clamp(hpBefore - math.max(victimHumanoid.Health, 0), 0, hpBefore), source = \"Gun\", weapon = tool:GetAttribute(\"WeaponId\"),\n"
	  .. "\t\tpellet = type(extra) == \"table\" and type(extra.pellet) == \"number\" and extra.pellet or nil })\n" },
}))
table.insert(res, patch(SSS:FindFirstChild("MeleeManager", true), {
	{ "\tvictimHum:TakeDamage(damage)\n\tbest:SetAttribute(\"LastMeleeHit\"",
	  "\tlocal hpBefore = victimHum.Health -- [HITINFO]\n\tvictimHum:TakeDamage(damage)\n\tbest:SetAttribute(\"LastMeleeHit\"" },
	{ "\tif confirm then confirm:FireClient(player, backstab and \"Head\" or \"Body\", damage, victimHum.Health <= 0) end\n",
	  "\t-- [HITINFO] 6th client arg (fix/hitinfo.lua)\n"
	  .. "\tif confirm then confirm:FireClient(player, backstab and \"Head\" or \"Body\", damage, victimHum.Health <= 0, false, nil, { pos = " .. torso("best") .. ",\n"
	  .. "\t\tvictim = best, dealt = math.clamp(hpBefore - math.max(victimHum.Health, 0), 0, hpBefore), source = \"Melee\",\n"
	  .. "\t\tweapon = quick and tool:GetAttribute(\"WeaponId\") or tool:GetAttribute(\"MeleeId\"), backstab = backstab or nil }) end\n" },
}))
table.insert(res, patch(SSS:FindFirstChild("Abilities", true), {
	{ "\thum:TakeDamage(amount)\n\tlocal confirm = Combat:FindFirstChild(\"HitConfirm\")\n\tif confirm then confirm:FireClient(attacker, \"Body\", amount, hum.Health <= 0, false, confirmKind) end\n",
	  "\tlocal hpBefore = hum.Health -- [HITINFO]\n\thum:TakeDamage(amount)\n\tlocal confirm = Combat:FindFirstChild(\"HitConfirm\")\n"
	  .. "\tif confirm then confirm:FireClient(attacker, \"Body\", amount, hum.Health <= 0, false, confirmKind, { pos = " .. torso("victim") .. ", victim = victim,\n"
	  .. "\t\tdealt = math.clamp(hpBefore - math.max(hum.Health, 0), 0, hpBefore), source = \"Ability\", weapon = attackKind }) end -- [HITINFO] 6th client arg\n" },
}))
-- the blast hurt(): ShootableManager in the match places; in the lobby that script has no damage and ArenaShootables has it
local shoot
for _, n in { "ShootableManager", "ArenaShootables" } do
	local x = SSS:FindFirstChild(n, true)
	if x and x.Source:find("TakeDamage", 1, true) then shoot = x break end
end
table.insert(res, patch(shoot, {
	{ "\thum:TakeDamage(amount)\n\tlocal victim = Players:GetPlayerFromCharacter(character)\n",
	  "\tlocal hpBefore = hum.Health -- [HITINFO]\n\thum:TakeDamage(amount)\n\tlocal victim = Players:GetPlayerFromCharacter(character)\n" },
	{ "\t\tCombat.HitConfirm:FireClient(attacker, \"Body\", amount, hum.Health <= 0)\n",
	  "\t\tCombat.HitConfirm:FireClient(attacker, \"Body\", amount, hum.Health <= 0, false, nil, { pos = " .. torso("character") .. ", victim = character,\n"
	  .. "\t\t\tdealt = math.clamp(hpBefore - math.max(hum.Health, 0), 0, hpBefore), source = \"Explosion\", weapon = kind or \"Blast\" }) -- [HITINFO] 6th client arg\n" },
}))
return (UNDO and "UNDO " or "HITINFO ") .. table.concat(res, " | ")
