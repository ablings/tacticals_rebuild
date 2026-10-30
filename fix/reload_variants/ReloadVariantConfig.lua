-- ReplicatedStorage/Modules/Shared/Config/ReloadVariantConfig (ModuleScript) [RELOADVAR] (2026-10-30, systems session; installed
-- by fix/reload_variants.lua, source fix/reload_variants/ReloadVariantConfig.lua)
-- Ammo-aware reload variants (the animator's art/anim/reload_variants/DONE.md): at reload start the rounds left pick
-- <Prefix>Reload_<Variant>; a clip that doesn't exist (or isn't published, live) falls back to the base reload. Look only: the
-- clip is fitted to the gun's ReloadTime exactly as before (WeaponController's AdjustSpeed(Length / ReloadTime)) and the server's
-- reload timing is untouched.
local C = {}
C.Enabled = true

-- per weapon id: rows { most rounds left, variant } in order; the first row with rounds left <= its number wins
C.Weapons = {
	Pistol = { { 0, "Dry" }, { 6, "Drop" }, { math.huge, "Retain" } },          -- 12 rounds
	SilencedPistol = { { 0, "Dry" }, { 5, "Drop" }, { math.huge, "Retain" } },  -- 10 (shares the Pistol clips)
	MiniUzi = { { 0, "Dry" }, { 15, "Drop" }, { math.huge, "Retain" } },        -- 30 (SMG clips)
	AutoRifle = { { 0, "Dry" }, { 15, "Drop" }, { math.huge, "Retain" } },      -- 30 (Rifle clips)
	SemiAuto = { { 0, "Dry" }, { 6, "Drop" }, { math.huge, "Retain" } },        -- 12 (Rifle clips)
	Sniper = { { 0, "Dry" }, { math.huge, "TopUp" } },                          -- 5
	Revolver = { { 0, "Dry" }, { 3, "Dump" }, { 4, "Pluck2" }, { 5, "Pluck1" } }, -- 6 (6 = full: no reload)
	-- DualPistols: no variants yet (the animator's next round)
}

-- shell by shell (WeaponConfig ShellReload): the start when the tube is empty, the first shell into an empty gun, the shell that
-- fills the tube, and every second shell in between (A = the base ReloadShell, B = this)
C.Shell = { StartDry = "ReloadStart_Dry", First = "ReloadShell_Port", Last = "ReloadShell_Last", Alternate = "ReloadShell_B" }

-- markers on the variant clips that show / hide gun parts, on every body that plays them (each client draws it)
C.PartMarkers = {
	MagHide = { hide = true, default = { "Mag", "MagBase" } },
	MagShow = { hide = false, default = { "Mag", "MagBase" } },
	RoundHide = { hide = true, default = {} },  -- value = Round1 / Round2
	RoundShow = { hide = false, default = {} },
	LoaderShow = { hide = false, default = { "SpeedLoader" } },
	LoaderHide = { hide = true, default = { "SpeedLoader" } },
}

-- "Reload_<Variant>" for this gun and rounds left, or nil (no variants: the base reload)
function C.Pick(weaponId: string?, roundsLeft: number): string?
	local rows = weaponId and C.Weapons[weaponId]
	if not rows then return nil end
	for _, row in rows do
		if roundsLeft <= row[1] then return "Reload_" .. row[2] end
	end
	return nil
end

return C
