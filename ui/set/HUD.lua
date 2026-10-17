-- StarterPlayer/StarterPlayerScripts/Client/GUIs/HUD (ModuleScript)
-- Drives the in-game HUD (StarterGui/HUD): crosshair, "blocked shot" marker,
-- hitmarker and ammo counter. Display only: it never decides anything about combat.
--
-- API:
--   HUD.SetWeapon(displayName?)              -- nil hides the ammo display
--   HUD.SetAmmo(current, max, reloading)
--   HUD.SetBlocked(screenPosition?)          -- Vector2 where cover blocks the shot, nil to hide
--   HUD.ShowHitmarker(zone, killed)        -- [SET] headshots: critical colour (Settings > Damage Numbers > Critical
--                                            Color), a bigger pop, a ring that snaps out and a two-layer "tink" (Edward:
--                                            "the crosshair should be different on critical headshots")
--   HUD.SetCrosshair(visible, aimed)        -- the centre dot: solid while aimed in, 75% see-through otherwise
--   HUD.SetCrosshairVisible(visible)        -- (old name: same as SetCrosshair(visible, true))
--   HUD.ShowDamageFrom(worldPosition)       -- red marker around the screen centre pointing at the shooter

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- // Constants
local HIT_COLORS = {
	Body = Color3.fromRGB(255, 255, 255),
	Limb = Color3.fromRGB(255, 255, 255),
	Head = Color3.fromRGB(255, 92, 124),
	Extremity = Color3.fromRGB(190, 196, 214),
}
local KILL_COLOR = Color3.fromRGB(255, 60, 60)
local HITMARKER_TIME = 0.25

-- // Root
local hud = {}
local gui: ScreenGui?
local hitToken = 0

local function getGui(): ScreenGui
	if not gui then
		gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD") :: ScreenGui
	end
	return gui :: ScreenGui
end

-- (the ammo now shows on the gun's hotbar tile, bottom right: HotbarController reads hud.GetAmmo)
local lastAmmo = { current = 0, reserve = 0, reloading = false }
function hud.GetAmmo(): (number, number, boolean)
	return lastAmmo.current, lastAmmo.reserve, lastAmmo.reloading
end

function hud.SetWeapon(displayName: string?)
	local ammo = getGui().AmmoDisplay
	ammo.Visible = false
	if displayName then
		ammo.WeaponName.Text = displayName
	end
	if not displayName then
		hud.SetBlocked(nil)
	end
end

function hud.SetAmmo(current: number, reserve: number, reloading: boolean)
	lastAmmo.current, lastAmmo.reserve, lastAmmo.reloading = current, reserve, reloading
	local ammo = getGui().AmmoDisplay
	ammo.Count.Text = `{current} / {reserve}`
	ammo.Count.TextColor3 = current == 0 and Color3.fromRGB(255, 90, 90) or Color3.new(1, 1, 1)
	ammo.Status.Text = reloading and "RELOADING" or (current == 0 and (reserve > 0 and "PRESS R" or "NO AMMO") or "")
end

-- The dot is always there while you're alive (gun, melee or gadget in hand): faint when you're not aimed
-- in, solid the moment you aim.
local CROSSHAIR_IDLE = 0.75 -- transparency when not aimed in
local crosshairAimed = nil
function hud.SetCrosshair(visible: boolean, aimed: boolean)
	local crosshair = getGui().Crosshair
	if crosshair.Visible ~= visible then
		crosshair.Visible = visible
	end
	if crosshairAimed ~= aimed then
		crosshairAimed = aimed
		local info = TweenInfo.new(aimed and 0.08 or 0.18, Enum.EasingStyle.Quad)
		TweenService:Create(crosshair, info, { BackgroundTransparency = aimed and 0 or CROSSHAIR_IDLE }):Play()
		local stroke = crosshair:FindFirstChildOfClass("UIStroke")
		if stroke then
			-- the outline fades with it so the faint dot doesn't become a dark ring
			TweenService:Create(stroke, info, { Transparency = aimed and 0.3 or 1 - (1 - 0.3) * (1 - CROSSHAIR_IDLE) }):Play()
		end
	end
end

function hud.SetCrosshairVisible(visible: boolean)
	hud.SetCrosshair(visible, true)
end

function hud.SetBlocked(screenPosition: Vector2?)
	local marker = getGui().BlockedMarker
	marker.Visible = screenPosition ~= nil
	if screenPosition then
		marker.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	end
end

local function criticalColor(): Color3
	local v = Players.LocalPlayer:GetAttribute("Setting_CriticalColor")
	if typeof(v) == "Color3" then return v end
	local ok, c = pcall(Color3.fromHex, tostring(v or "#ff3232"))
	return ok and c or Color3.fromRGB(255, 50, 50)
end

-- the ring around a headshot hitmarker: snaps out from the marker and fades (Scale of the marker, so it follows its size)
local function headRing(marker: GuiObject, color: Color3)
	local ring = Instance.new("Frame")
	ring.Name = "HeadRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.9, 0.9)
	ring.BackgroundTransparency = 1
	ring.ZIndex = marker.ZIndex + 1
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0.5, 0) corner.Parent = ring
	local stroke = Instance.new("UIStroke") stroke.Color = color stroke.Thickness = 2.5 stroke.Parent = ring
	ring.Parent = marker
	local info = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromScale(2.1, 2.1) }):Play()
	TweenService:Create(stroke, info, { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.35, function() ring:Destroy() end)
end

function hud.ShowHitmarker(zone: string, killed: boolean, headshot: boolean?)
	local root = getGui()
	local marker = root.Hitmarker
	local head = if headshot ~= nil then headshot == true else zone == "Head"
	local color = head and criticalColor() or killed and KILL_COLOR or HIT_COLORS[zone] or HIT_COLORS.Body

	hitToken += 1
	local token = hitToken

	marker.Visible = true
	marker.Size = UDim2.fromOffset(head and 46 or 34, head and 46 or 34)
	TweenService:Create(marker, TweenInfo.new(head and 0.12 or 0.08), { Size = UDim2.fromOffset(head and 30 or 26, head and 30 or 26) }):Play()
	if head then headRing(marker, color) end

	for _, line in marker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = color
			line.BackgroundTransparency = 0
			TweenService:Create(line, TweenInfo.new(HITMARKER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	local sound = root:FindFirstChild("HitSound")
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = head and 1.15 or 1
		sound:Play()
		if head then
			-- the headshot "tink": a second, much higher copy just after the hit
			local tink = sound:Clone()
			tink.PlaybackSpeed = 2.2
			tink.Volume = sound.Volume * 0.8
			tink.Parent = root
			task.delay(0.035, function() tink:Play() end)
			task.delay(1, function() tink:Destroy() end)
		end
	end

	task.delay(HITMARKER_TIME, function()
		if hitToken == token then
			marker.Visible = false
		end
	end)
end

-- // Damage direction markers
local DAMAGE_MARKER_TIME = 1.4
local DAMAGE_MARKER_RADIUS = 110
local activeMarkers = {} -- { frame, source, born }
local markerLoop: RBXScriptConnection?

local function updateMarkers()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for i = #activeMarkers, 1, -1 do
		local m = activeMarkers[i]
		local age = now - m.born
		if age >= DAMAGE_MARKER_TIME then
			m.frame:Destroy()
			table.remove(activeMarkers, i)
		else
			-- Direction to the shooter relative to where the camera faces (flattened)
			local relative = camera.CFrame:VectorToObjectSpace(m.source - camera.CFrame.Position)
			local angle = math.atan2(relative.X, -relative.Z)
			m.frame.Position = UDim2.fromOffset(math.sin(angle) * DAMAGE_MARKER_RADIUS, -math.cos(angle) * DAMAGE_MARKER_RADIUS)
			m.frame.Rotation = math.deg(angle)
			m.frame.BackgroundTransparency = math.clamp((age / DAMAGE_MARKER_TIME) ^ 2, 0, 1)
		end
	end
	if #activeMarkers == 0 and markerLoop then
		markerLoop:Disconnect()
		markerLoop = nil
	end
end

function hud.ShowDamageFrom(source: Vector3)
	local container = getGui().DamageIndicators
	local frame = container.MarkerTemplate:Clone()
	frame.Name = "Marker"
	frame.Visible = true
	frame.Parent = container
	table.insert(activeMarkers, { frame = frame, source = source, born = os.clock() })
	if not markerLoop then
		markerLoop = game:GetService("RunService").RenderStepped:Connect(updateMarkers)
	end
	updateMarkers()
end

return hud
