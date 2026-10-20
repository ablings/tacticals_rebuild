-- fix/kill_payload.lua [KILLFEED] 2026-10-20 (Edward's RIVALS kill feed via the UI session: weapon silhouettes keyed by item id +
-- headshot / no-scope icons). Every damage source now tags the victim humanoid with
--   LastAttackWeapon  the item id that hit (Pistol / PumpShotgun / Knife / Bat / Fists / StickyGrenade / Landmine / Frag / Barrel ...)
--   LastNoScope       true when a scoped gun (WeaponConfig Scope: the Sniper) hit without being aimed in (the shot's aimed flag)
-- and MatchCore's MatchFlow "Kill" payload carries weapon = LastAttackWeapon (falls back to the killer's Loadout) and noscope.
-- Both places; optional anchors are skipped where a module doesn't have them. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")

local EDITS = {
	-- guns (CombatManager.onFire, an accepted hit): the gun + no-scope from the shot's aimed flag
	{ "CombatManager", "\tvictimHumanoid:SetAttribute(\"LastAttackKind\", \"Gun\")\n",
		"\tvictimHumanoid:SetAttribute(\"LastAttackKind\", \"Gun\")\n"
		.. "\tvictimHumanoid:SetAttribute(\"LastAttackWeapon\", tool:GetAttribute(\"WeaponId\")) -- [KILLFEED]\n"
		.. "\tvictimHumanoid:SetAttribute(\"LastNoScope\", (config.Scope ~= nil and not (type(extra) == \"table\" and extra.aimed == true)) or nil)\n" },
	-- melee (MeleeManager.onSwing): the melee item, or the gun for an [F] gun bash
	{ "MeleeManager", "\tvictimHum:SetAttribute(\"LastAttackKind\", \"Melee\")\n",
		"\tvictimHum:SetAttribute(\"LastAttackKind\", \"Melee\")\n"
		.. "\tvictimHum:SetAttribute(\"LastAttackWeapon\", quick and tool:GetAttribute(\"WeaponId\") or tool:GetAttribute(\"MeleeId\")) -- [KILLFEED]\n"
		.. "\tvictimHum:SetAttribute(\"LastNoScope\", nil)\n" },
	-- blasts / fire (ShootableManager.hurt, match place): the blast kind is the item (Frag / StickyGrenade / Landmine / Barrel / Burn)
	{ "ShootableManager", "\thum:SetAttribute(\"LastAttackKind\", kind or \"Blast\")\n",
		"\thum:SetAttribute(\"LastAttackKind\", kind or \"Blast\")\n"
		.. "\thum:SetAttribute(\"LastAttackWeapon\", kind or \"Blast\") -- [KILLFEED]\n"
		.. "\thum:SetAttribute(\"LastNoScope\", nil)\n", true },
	-- the Kill payload
	{ "MatchCore", "\t\t\t\tweapon = killer and MatchCore.getAttr(killer, \"Loadout\") or nil })\n",
		"\t\t\t\tweapon = humanoid:GetAttribute(\"LastAttackWeapon\") or (killer and MatchCore.getAttr(killer, \"Loadout\")) or nil, -- [KILLFEED]\n"
		.. "\t\t\t\tnoscope = humanoid:GetAttribute(\"LastNoScope\") == true or nil })\n" },
}

local out = {}
for i, e in EDITS do
	local inst = SSS:FindFirstChild(e[1], true)
	local s = inst and inst.Source
	if not s then table.insert(out, e[1] .. " missing") continue end
	local old, new = e[2], e[3]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then table.insert(out, e[1] .. "=") continue end
	local a, b = s:find(old, 1, true)
	if not a and e[4] then table.insert(out, e[1] .. " skipped (no anchor here)") continue end
	assert(a, e[1] .. " anchor not found")
	assert(not s:find(old, b + 1, true), e[1] .. " anchor not unique")
	s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
	local f, err = loadstring(s)
	assert(f, e[1] .. " would not parse: " .. tostring(err))
	inst.Source = s
	table.insert(out, e[1] .. "+")
end
return table.concat(out, " ")
