-- fix/clip_featured_stage.lua (2026-10-17 overnight glitch pass; overnight_report item 15): the Outfitters featured dais is
-- only ~1.6 studs high, so players step onto the turntable and stand on the outfit. An invisible clip box over the dais
-- keeps them off. CanQuery / CanTouch off: shots, clicks and prompts pass straight through; only bodies are blocked.
-- Idempotent. `python tools/run_luau.py fix/clip_featured_stage.lua UNDO` removes it.
local UNDO = false --@UNDO
local stage = workspace.LobbyMap.Polish.Shop.Round3.FeaturedStage
local dais = stage:FindFirstChild("Dais")
local old = stage:FindFirstChild("Clip_FeaturedStage")
if UNDO then
	if old then old:Destroy() return "clip removed" end
	return "not applied"
end
assert(dais, "Dais not found")
local clip = old or Instance.new("Part")
clip.Name = "Clip_FeaturedStage"
clip.Anchored = true
clip.CanCollide = true
clip.CanQuery = false
clip.CanTouch = false
clip.Transparency = 1
clip.CastShadow = false
clip.Locked = true
-- the dais is a 6 x 6 plate (its long axes are Y and Z of a part rotated onto its side): cover it with a 6.4 x 8 x 6.4 box
local top = dais.Position.Y + 0.35
clip.Size = Vector3.new(6.4, 8, 6.4)
clip.CFrame = CFrame.new(dais.Position.X, top + 4, dais.Position.Z)
clip.Parent = stage
return ("clip at %s size %s"):format(tostring(clip.Position), tostring(clip.Size))
