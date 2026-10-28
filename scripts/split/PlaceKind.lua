-- ReplicatedStorage/Modules/Shared/PlaceKind (ModuleScript)
-- [SPLIT] 2026-10-16 (notes/place_split.md): which split place this is. One codebase serves the Tutorial, Matchmaking and Ranked
-- places; the only per-place difference is the StringValue ReplicatedStorage.PlaceKind ("Tutorial" / "Matchmaking" / "Ranked"),
-- set by fix/split_place_install.lua. No value (or an unknown one) = nil = the old combined match place (81861384114744),
-- whose behaviour is unchanged. Server and client may require it. No side effects.
-- [TESTPLACE] 2026-10-28 (notes/test_place.md): "Test" = the admin-only Test place, where new maps are tried before they reach
-- Matchmaking / Ranked / the lobby. Casual matches only, never the tutorial, and nothing it plays is saved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceKind = {}
PlaceKind.Kinds = { Tutorial = true, Matchmaking = true, Ranked = true, Test = true }

-- "Tutorial" / "Matchmaking" / "Ranked" / "Test", or nil on the old combined place (and in the lobby)
function PlaceKind.Get(): string?
	local v = ReplicatedStorage:FindFirstChild("PlaceKind")
	local kind = v and v:IsA("StringValue") and v.Value or nil
	if kind and PlaceKind.Kinds[kind] then return kind end
	return nil
end

function PlaceKind.Is(kind: string): boolean
	return PlaceKind.Get() == kind
end

-- the starter tutorial may run here (the Tutorial place, or the old combined place)
function PlaceKind.TutorialAllowed(): boolean
	local kind = PlaceKind.Get()
	return kind == nil or kind == "Tutorial"
end

-- a match with this Ranked flag may run here: the Matchmaking and Test places play casual only, the Ranked place ranked
-- only, the Tutorial place none, the old combined place both
function PlaceKind.MatchAllowed(ranked: boolean?): boolean
	local kind = PlaceKind.Get()
	if kind == nil then return true end
	if kind == "Matchmaking" or kind == "Test" then return ranked ~= true end
	if kind == "Ranked" then return ranked == true end
	return false
end

-- [TESTPLACE] the admin-only Test place: progress is never saved here (DataManager opens view-only copies)
function PlaceKind.IsTest(): boolean
	return PlaceKind.Get() == "Test"
end

return PlaceKind
