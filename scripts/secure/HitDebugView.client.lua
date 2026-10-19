-- StarterPlayerScripts.HitDebugView (LocalScript, hub + match places) [HITDEBUG] 2026-10-18: draws the server's hit reports
-- (RemoteEvent ReplicatedStorage.HitDebug, sent only to players with ;hitdebug on). Local only, gone after HOLD seconds:
--   green / red box  the hit part where the SERVER rewound it to for this shot (accepted / rejected)
--   blue outline     the same part where it is now on the server
--   yellow dot       the point the shooter's game claimed it hit, and a thin line from the shot origin
--   label            shooter > victim, part, ACCEPTED (zone) or REJECTED: why, rewound N ms back / window, shooter ping
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local HOLD = 4
local remote = ReplicatedStorage:WaitForChild("HitDebug", 60)
if not remote then return end

local folder = Instance.new("Folder")
folder.Name = "HitDebugView"
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in props do (p :: any)[k] = v end
	p.Parent = folder
	Debris:AddItem(p, HOLD)
	return p
end

remote.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then return end
	local good = info.accepted == true
	if typeof(info.rewound) == "CFrame" and typeof(info.size) == "Vector3" then
		part({ CFrame = info.rewound, Size = info.size, Color = good and Color3.fromRGB(70, 220, 90) or Color3.fromRGB(230, 60, 50), Transparency = 0.45 })
	end
	if typeof(info.now) == "CFrame" and typeof(info.size) == "Vector3" then
		local box = part({ CFrame = info.now, Size = info.size, Transparency = 1 })
		local sel = Instance.new("SelectionBox")
		sel.Adornee = box
		sel.Color3 = Color3.fromRGB(60, 150, 255)
		sel.LineThickness = 0.03
		sel.Parent = box
	end
	if typeof(info.point) == "Vector3" then
		local dot = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), CFrame = CFrame.new(info.point), Color = Color3.fromRGB(255, 220, 60) })
		if typeof(info.origin) == "Vector3" then
			local len = (info.point - info.origin).Magnitude
			part({ Size = Vector3.new(0.05, 0.05, len), CFrame = CFrame.lookAt(info.origin, info.point) * CFrame.new(0, 0, -len / 2),
				Color = Color3.fromRGB(255, 220, 60), Transparency = 0.5 })
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(7, 1.6)
		gui.StudsOffset = Vector3.new(0, 1.4, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Adornee = dot
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.25
		label.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		label.TextColor3 = good and Color3.fromRGB(140, 255, 150) or Color3.fromRGB(255, 140, 130)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = string.format("%s > %s (%s)\n%s\nrewound %s ms / window %s ms, ping %s ms",
			tostring(info.shooter), tostring(info.victim), tostring(info.part),
			good and ("ACCEPTED " .. tostring(info.reason)) or ("REJECTED: " .. tostring(info.reason)),
			tostring(info.ageMs or "-"), tostring(info.windowMs or "-"), tostring(info.pingMs or "-"))
		label.Parent = gui
		gui.Parent = dot
	end
end)
