-- MapInfo: map registry entry for the match place's own Warehouse (ReplicatedStorage.DuelMaps.Warehouse.MapInfo).
-- [MATCH] 2026-10-16 (notes/match_place_flow.md): a copy of the lobby's generated MapInfo (fix/duel_split_map.lua). In the match
-- place the map is not split: Workspace.Warehouse (WorkspaceName) is the map, at its native position, with MatchSpawns as spawns.
-- The folder's Modes attribute ("1v1") overrides Modes here, as in the lobby (MapRegistry).
return {
	Id = "Warehouse",
	DisplayName = "Warehouse",
	Image = "",
	Modes = { "1v1" },
	Size = Vector3.new(84.000, 22.000, 120.400),
	SpawnSpacing = 4,
	KillDepth = 30,
	WorkspaceName = "Warehouse",
	Dynamic = { "Interactive" },
	SourceOrigin = Vector3.new(-84.200, 0.400, 7.515),
}
