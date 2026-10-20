-- ReplicatedStorage.UIKit.KillIcons (UI session 2026-10-20, Edward: "codex generated silhouettes for headshots and kills like rivals")
-- White silhouettes for the kill feed and the killer card (art: ui/art/killfeed, generated with codex, uploaded under the group).
-- An empty id means "not uploaded yet": the HUD falls back to its old look (the tool render / the ◉ mark).
local KillIcons = {}

KillIcons.status = {
	headshot = "", -- kf_headshot.png
	elim = "",     -- kf_elim.png
	noscope = "",  -- kf_noscope.png
}

-- by item id (the MatchFlow "Kill" payload's weapon); weapon art is 2:1, pointing right
KillIcons.weapons = {
	Pistol = "", SilencedPistol = "", Revolver = "", MiniUzi = "", DualPistols = "", AutoRifle = "", SemiAuto = "",
	PumpShotgun = "", Sniper = "", Fists = "", Knife = "", Bat = "", Katana = "", RiotShield = "",
	Frag = "", Smoke = "", Flash = "", StickyGrenade = "", Landmine = "", Medkit = "",
}

-- a kill's kind when the weapon isn't an item (Edward: every melee and gadget kill shows its icon too)
KillIcons.kinds = { Takedown = "Fists", Explosion = "Frag", StickyGrenade = "StickyGrenade", Landmine = "Landmine", Melee = "Knife" }

function KillIcons.Weapon(id, kind)
	local a = id and KillIcons.weapons[id]
	if (not a or a == "") and kind and KillIcons.kinds[kind] then a = KillIcons.weapons[KillIcons.kinds[kind]] end
	return (a and a ~= "") and a or nil
end
function KillIcons.Status(name)
	local a = KillIcons.status[name]
	return (a and a ~= "") and a or nil
end

return KillIcons
