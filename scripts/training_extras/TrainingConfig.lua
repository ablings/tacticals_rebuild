-- ReplicatedStorage/Modules/Shared/Config/TrainingConfig (ModuleScript, lobby place only)
-- Training extras, step 2 of the Training rebuild (notes/training_extras_done.md). Every extra sits behind a flag here.
-- Play-mode switch without editing code: ReplicatedStorage:SetAttribute("TX_<Name>", false) (or true) before Play / at runtime.
-- Names: AliveDummies, GalleryFill, RoomFXBox, Bullseyes, DpsDummies, JumpPads, Tightropes, SwapBins.
-- A missing or broken config means "all off" (every user pcall-requires it and falls back to the old behaviour).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = {
	AliveDummies = 35,                  -- TrainingManager ENEMIES (was 24); TX_AliveDummies = false -> 24
	GalleryFill = true,                 -- gallery spots (EnemySpots with Gallery = true) refill first
	GalleryRespawn = 1,                 -- seconds before a gallery dummy comes back (arena: TrainingManager RESPAWN_DELAY 2)
	RoomFXBox = true,                   -- RoomFX: Training lights on while the camera is inside this box (arena + gallery)
	RoomBox = { Min = Vector3.new(-140, 588, -140), Max = Vector3.new(364, 660, 140) },
	Bullseyes = { Enabled = true, Radius = 1.5, Respawn = 3, MaxRange = 600 },
	DpsDummies = { Enabled = true, Window = 3, MinSpan = 1, Idle = 2.5, Hold = 2 },
	JumpPads = { Enabled = true, Cooldown = 0.6, Headroom = 7, Apex = 6 },
	Tightropes = { Enabled = true },
	SwapBins = { Enabled = true, AllowUnowned = true, Reach = 12 },   -- AllowUnowned: Training-only trial of guns you don't own
	CeilingY = 648,                     -- Training ceiling (floor 600 + 48)
}

-- Is this extra on? The TX_<name> attribute on ReplicatedStorage wins over the value above.
function C.On(name: string): boolean
	local a = ReplicatedStorage:GetAttribute("TX_" .. name)
	if a ~= nil then return a == true end
	local v = C[name]
	if type(v) == "table" then return v.Enabled == true end
	return v ~= nil and v ~= false
end

return C
