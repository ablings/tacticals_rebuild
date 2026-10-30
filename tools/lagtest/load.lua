local p = game.Players.LocalPlayer
local t0 = os.clock()
while not (p.Character and p.Character:FindFirstChild("HumanoidRootPart")) and os.clock() - t0 < 30 do task.wait(0.1) end
return string.format("client time() %.1f s at character ready; loaded %s; PlayerGui %d; streaming %s; instances %d",
  time(), tostring(game:IsLoaded()), #p.PlayerGui:GetChildren(), tostring(workspace.StreamingEnabled), game:GetService("Stats").InstanceCount)
