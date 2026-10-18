-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- Plays a looping idle on the lobby NPCs (stock Roblox R15 idle) with a small random offset each
local IDLE = "rbxassetid://507766388"
-- [PSEUDOLOBBY] on a match place the map only comes into Workspace after a match (ServerStorage.PseudoLobby): run on every arrival
local function run(map)
local folder = map:WaitForChild("NPCs", 30)
if not folder then return end
for _, m in folder:GetChildren() do
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local a = Instance.new("Animation")
		a.AnimationId = IDLE
		local ok, track = pcall(animator.LoadAnimation, animator, a)
		if ok and track and #animator:GetPlayingAnimationTracks() == 0 then
			track.Looped = true
			task.delay(math.random() * 1.5, function() track:Play(0.3, 1, 0.9 + math.random() * 0.2) end)
		end
	end
end
end
local now = workspace:FindFirstChild("LobbyMap")
if now then task.spawn(run, now) end
workspace.ChildAdded:Connect(function(c) if c.Name == "LobbyMap" then task.spawn(run, c) end end)
