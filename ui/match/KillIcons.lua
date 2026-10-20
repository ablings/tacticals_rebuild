-- ReplicatedStorage.UIKit.KillIcons (UI session 2026-10-20, Edward: "codex generated silhouettes for headshots and kills like rivals")
-- White silhouettes for the kill feed and the killer card (art: ui/art/killfeed, generated with codex, uploaded under the group).
-- An empty id means "not uploaded yet": the HUD falls back to its old look (the tool render / the ◉ mark).
local KillIcons = {}

KillIcons.status = {
	headshot = "rbxassetid://80464553446215", -- kf_headshot.png
	elim = "rbxassetid://82034441418556",     -- kf_elim.png
	noscope = "rbxassetid://89509376213247",  -- kf_noscope.png
}

-- by item id (the MatchFlow "Kill" payload's weapon); weapon art is 2:1, pointing right
KillIcons.weapons = {
	Pistol = "rbxassetid://80439200589078", SilencedPistol = "rbxassetid://115014803855801", Revolver = "rbxassetid://128783100108648", MiniUzi = "rbxassetid://104306569874932", DualPistols = "rbxassetid://76152134860417", AutoRifle = "rbxassetid://103946133756487", SemiAuto = "rbxassetid://131424197149382",
	PumpShotgun = "rbxassetid://112990123410819", Sniper = "rbxassetid://124629840006017", Fists = "rbxassetid://91644172078126", Knife = "rbxassetid://121222320228086", Bat = "rbxassetid://131947956776242", Katana = "rbxassetid://76010195762918", RiotShield = "rbxassetid://77868434923118",
	Frag = "rbxassetid://112955460888485", Smoke = "rbxassetid://116912040900223", Flash = "rbxassetid://129251794343705", StickyGrenade = "rbxassetid://73779927450523", Landmine = "rbxassetid://96498461847270", Medkit = "rbxassetid://98079969364884",
}

-- a kill's kind when the weapon isn't an item (Edward: every melee and gadget kill shows its icon too)
KillIcons.kinds = { Takedown = "Fists", Explosion = "Frag", Barrel = "Frag", StickyGrenade = "StickyGrenade", Landmine = "Landmine", Melee = "Knife" }

function KillIcons.Weapon(id, kind)
	local a = id and (KillIcons.weapons[id] or (KillIcons.kinds[id] and KillIcons.weapons[KillIcons.kinds[id]]))
	if (not a or a == "") and kind and KillIcons.kinds[kind] then a = KillIcons.weapons[KillIcons.kinds[kind]] end
	return (a and a ~= "") and a or nil
end
function KillIcons.Status(name)
	local a = KillIcons.status[name]
	return (a and a ~= "") and a or nil
end

return KillIcons
