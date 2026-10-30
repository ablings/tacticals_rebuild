-- strip.lua (needs cap_lib as C; prepend `local JOB = {clip=, times={...}, gun=, view="side"|"game"|"fp", left=bool}`)
-- Lays out one anchored puppet per time in a row for the view and returns the camera for screen_capture.
C.clear()
local Lg = game.Lighting
Lg.ClockTime = 14.5; Lg.Brightness = 2.5; Lg.ExposureCompensation = 0
Lg.Ambient = Color3.fromRGB(120, 120, 120); Lg.OutdoorAmbient = Color3.fromRGB(170, 170, 165)
Lg.FogEnd = 100000
for _, e in Lg:GetDescendants() do
	if e:IsA("PostEffect") then e.Enabled = false end
	if e:IsA("Atmosphere") then e.Density = 0; e.Haze = 0 end
end
local st = C.stage()
if st:FindFirstChild("Back") then st.Back:Destroy() end
local O = C.O
local n = #JOB.times
local gap = JOB.gap or (JOB.view == "side" and 3.3 or 3.0)
local cams = {}
local fov = JOB.fov or 18
C.attach(JOB.gun)
for i, t in JOB.times do
	local poses = C.pose({ { JOB.clip, t, 1 } })
	local off
	if JOB.view == "side" then
		off = Vector3.new(0, 0, -(i - (n + 1) / 2) * gap)
	else
		off = Vector3.new((i - (n + 1) / 2) * gap * 1.4, 0, 0)
	end
	if JOB.view == "fp" then off = Vector3.zero end
	local pm, w = C.puppet("P" .. i, poses, CFrame.new(O + off + Vector3.new(0, 3, 0)), JOB.gun, { left = JOB.left, hideHead = JOB.view == "fp" })
	if JOB.view == "fp" then
		-- first person: the camera at the eyes (head centre + 0.15 up, 0.2 forward), looking where the body faces
		local head = CFrame.new(O + Vector3.new(0, 3, 0)) * w.Head
		workspace.CurrentCamera.FieldOfView = 70
		local eye = head.Position + Vector3.new(0, 0.15, -0.25)
		return string.format("CAM %.3f %.3f %.3f %.3f %.3f %.3f", eye.X, eye.Y, eye.Z, eye.X, eye.Y - 0.35, eye.Z - 10)
	end
end
local width = (n - 1) * gap * (JOB.view == "side" and 1 or 1.4) + 5
local vp = workspace.CurrentCamera.ViewportSize
local aspect = vp.X / math.max(1, vp.Y)
local dist = (width / 2) / (math.tan(math.rad(fov / 2)) * aspect) + 2
local camPos, look
if JOB.view == "side" then
	camPos = O + Vector3.new(dist, 3.6, 0)
	look = O + Vector3.new(0, 3.2, 0)
else -- "game": from behind the right shoulder, a little above (the gameplay camera's angle)
	camPos = O + Vector3.new(dist * 0.12, 3.5 + dist * 0.08, dist)
	look = O + Vector3.new(0, 3.3, 0)
end
workspace.CurrentCamera.FieldOfView = fov
return string.format("CAM %.3f %.3f %.3f %.3f %.3f %.3f", camPos.X, camPos.Y, camPos.Z, look.X, look.Y, look.Z)
