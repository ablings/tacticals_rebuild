-- strip.lua (needs cap_lib as C; prepend `local JOB = {clip=, times={...}, gun=, view="side"|"game"|"fp", left=bool}`)
-- Lays out one anchored puppet per time in a row for the view and returns the camera for screen_capture.
C.clear()
local O = C.O
local n = #JOB.times
local gap = JOB.gap or 4.2
local cams = {}
local fov = JOB.fov or 18
for i, t in JOB.times do
	local poses = C.pose({ { JOB.clip, t, 1 } })
	local off
	if JOB.view == "side" then
		off = Vector3.new(0, 0, (i - (n + 1) / 2) * gap)
	else
		off = Vector3.new((i - (n + 1) / 2) * gap * 1.4, 0, 0)
	end
	C.puppet("P" .. i, poses, CFrame.new(O + off + Vector3.new(0, 3, 0)), JOB.gun, { left = JOB.left })
end
local width = (n - 1) * gap * (JOB.view == "side" and 1 or 1.4) + 5
local dist = (width / 2) / math.tan(math.rad(fov / 2)) * 0.62 + 6
local camPos, look
if JOB.view == "side" then
	camPos = O + Vector3.new(dist, 3.6, 0)
	look = O + Vector3.new(0, 3.2, 0)
else -- "game": from behind the right shoulder, a little above (the gameplay camera's angle)
	camPos = O + Vector3.new(dist * 0.18, 3.6 + dist * 0.12, dist)
	look = O + Vector3.new(0, 3.6, -4)
end
workspace.CurrentCamera.FieldOfView = fov
return string.format("CAM %.3f %.3f %.3f %.3f %.3f %.3f", camPos.X, camPos.Y, camPos.Z, look.X, look.Y, look.Z)
