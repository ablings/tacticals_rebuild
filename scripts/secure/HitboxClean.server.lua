-- ServerScriptService.HitboxClean (Script, hub + match places) [HITDEBUG] 2026-10-18, Edward: dying "fully behind a pillar".
-- Hats, hair, backpacks and other accessories are not hitboxes: every character's accessory parts get CanQuery = false (and
-- CanTouch = false), so shots (and anything else raycasting for characters) pass straight through them to the body.
-- CombatManager also rejects any hit claimed on an accessory (fix/hit_debug.lua). Body parts are untouched.
local Players = game:GetService("Players")

local function clean(part: Instance)
	if part:IsA("BasePart") and part:FindFirstAncestorOfClass("Accessory") then
		part.CanQuery = false
		part.CanTouch = false
	end
end

local function watch(model: Instance)
	if not (model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")) then return end
	for _, d in model:GetDescendants() do clean(d) end
	model.DescendantAdded:Connect(clean)
end

local function onCharacter(character: Model)
	-- accessories are added a moment after the character appears
	watch(character)
	task.delay(1, function() for _, d in character:GetDescendants() do clean(d) end end)
end

Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(onCharacter) end)
for _, p in Players:GetPlayers() do
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
-- bots and dummies (humanoid models that aren't players)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") and d.Parent then task.defer(watch, d.Parent) end
end)
for _, d in workspace:GetDescendants() do if d:IsA("Humanoid") and d.Parent then watch(d.Parent) end end
