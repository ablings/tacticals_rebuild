-- ReplicatedStorage.Modules.Shared.Config.WeaponAbilities (UI session 2026-10-19, Edward's weapon design: notes/weapon_abilities.md)
-- One identity per item for the Kit screen: the ability (or perk) name + one line, and 1..5 ratings for the stat bars.
-- The Tacticals session implements the mechanics and may read / tune these numbers here.
--   WeaponAbilities.Items[itemId] = { ability = "Quickdraw", desc = "...", perk = bool?, speed = 1..5, reload = 1..5, accuracy = 1..5 }
--   (perk = true: not an ability, a trait - the Automatic Rifle's magazine, the Sniper's one-shot headshot)
local WeaponAbilities = {}

-- the speed ladder (movement: run, dash to cover, slide, vault; and reload), fastest first
-- (speed / reload bars follow the Tacticals session's WeaponConfig MoveSpeed 0.85..1.06 and ReloadTime 1.3..3.0 s, 2026-10-19)
WeaponAbilities.Ladder = { "Pistol", "DualPistols", "SilencedPistol", "MiniUzi", "Revolver", "AutoRifle", "PumpShotgun", "SemiAuto", "Sniper" }

WeaponAbilities.Items = {
	-- guns
	Pistol = { ability = "Quickdraw", desc = "Accurate from the hip. The fastest movement and reload in the game.", speed = 5.0, reload = 5.0, accuracy = 3 },
	DualPistols = { ability = "Akimbo", desc = "No aiming in, but hip fire is fully accurate and fires twice as fast while you move.", speed = 4.6, reload = 4.5, accuracy = 2.5 },
	SilencedPistol = { ability = "Whisper", desc = "Every sound it makes is quiet: it can't be heard from far away.", speed = 4.5, reload = 4.6, accuracy = 3 },
	MiniUzi = { ability = "Run and Gun", desc = "Full speed while running and shooting. Sprint while aimed in, at 85% accuracy.", speed = 4.1, reload = 4.2, accuracy = 2 },
	Revolver = { ability = "Knockback Shot", desc = "A fully aimed-in hit makes the target dash to the nearest cover.", speed = 3.6, reload = 3.5, accuracy = 4 },
	AutoRifle = { ability = "30-Round Magazine", desc = "No ability: a deep magazine to hold the fight.", perk = true, speed = 3.2, reload = 3.1, accuracy = 3.5 },
	PumpShotgun = { ability = "Door Breaker", desc = "A point-blank hit knocks the target out of cover. Reloads shell by shell.", speed = 2.5, reload = 1.5, accuracy = 1.5 },
	SemiAuto = { ability = "Precision Rhythm", desc = "Each hit in a row adds damage, up to 3. A miss resets it.", speed = 2.4, reload = 2.5, accuracy = 4.5 },
	Sniper = { ability = "One-Shot Headshot", desc = "No ability: a headshot is a one-shot kill.", perk = true, speed = 1.8, reload = 1.4, accuracy = 5 },
	-- melee
	Fists = { ability = "Vault Takedown", desc = "Vault into an enemy by the cover: topple them for a moment and deal 50 damage." },
	Knife = { ability = "Slide Lunge", desc = "Your first swing during or right after a slide lunges forward for bonus damage." },
	Bat = { ability = "Home Run", desc = "Hold to charge: a charged hit knocks the target back, out of cover or off a ledge." },
	Katana = { ability = "Parry", desc = "Right after a swing, bullets from the front are deflected for a moment." },
	RiotShield = { ability = "Bulwark", desc = "Blocks bullets from the front while held. Bash to stun. Slow to move with." },
}

function WeaponAbilities.Get(itemId: string) return WeaponAbilities.Items[itemId] end

return WeaponAbilities
