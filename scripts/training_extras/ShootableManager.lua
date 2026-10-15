-- Managers/ShootableManager (server, LOBBY place only; the match place has its own): CombatManager.afterShot calls
-- OnShot(origin, endPos, shooter) for every accepted shot (hits and misses). In the lobby that hook only feeds the
-- Training bullseyes (TrainingTargetsManager). Added by the Training extras (notes/training_extras_done.md).
local manager = {}

function manager.OnShot(origin: Vector3, endPos: Vector3, shooter: Player?)
	local targets = shared.Get and shared.Get("TrainingTargetsManager")
	if targets and targets.OnShot then targets.OnShot(origin, endPos, shooter) end
end

return manager
