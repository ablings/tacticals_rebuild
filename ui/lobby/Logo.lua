-- ReplicatedStorage.UIKit.Logo (UI session 2026-10-20, Edward: "the loading screens for finding a match and transitioning from
-- servers look bland they should utilize our logo"). The TACTICALS logo as the intro builds it at rest: the bone / olive frame
-- plus the nine letters from the letter atlas, laid out in "logo pixels" (1024 x 346) and placed in Scale of the logo frame.
--   Logo.Build(parent, { Position, Size, AnchorPoint, ZIndex, Glow = true }) -> Frame (aspect-locked 1024:346)
--   Logo.Breathe(frame)  -- a slow, small scale pulse (screens with a running script; a TeleportGui clone stays still)
local Logo = {}

Logo.IMG = {
	Frame = "rbxassetid://78445006727868",   -- the frame with the letters removed (bone / olive), teal-fixed (tac_logo_frame, 2026-10-21;
	                                          -- the old 81042695231423 had 200 stray teal pixels on the olive half)
	Letters = "rbxassetid://117542693397702", -- atlas: the nine letters
	Glow = "rbxasset://textures/ui/Glow.png",
}
local STAGE = Vector2.new(1024, 346)
-- letter, home x, home y (top-left in the frame), atlas rect {x, y, w, h} (same table as intro/LoadingScreen.lua)
local LETTERS = {
	{ "T", 53, 38, { 0, 0, 425, 231 } },
	{ "A", 94, 84, { 624, 0, 210, 200 } },
	{ "C", 289, 79, { 230, 233, 130, 176 } },
	{ "T", 388, 79, { 0, 233, 124, 177 } },
	{ "I", 464, 79, { 126, 233, 102, 177 } },
	{ "C", 530, 79, { 362, 233, 139, 176 } },
	{ "A", 575, 82, { 427, 0, 195, 205 } },
	{ "L", 765, 82, { 503, 233, 112, 174 } },
	{ "S", 832, 86, { 836, 0, 153, 188 } },
}

local function SP(x, y) return UDim2.fromScale(x / STAGE.X, y / STAGE.Y) end

-- (2026-10-21, Edward: "the logos are pixelated", on phone / tablet, "only for a moment, then sharp") a logo shown before its
-- images finished downloading draws a low-res pass first. The module preloads the frame + letter atlas the moment anything
-- requires it (at join), and Build keeps a logo invisible until that's done, then fades it in (8 s cap: never hidden for good).
Logo.Ready = false
function Logo.Preload()
	if Logo._preloading then return end
	Logo._preloading = true
	task.spawn(function()
		pcall(function() game:GetService("ContentProvider"):PreloadAsync({ Logo.IMG.Frame, Logo.IMG.Letters }) end)
		Logo.Ready = true
	end)
end
local function revealWhenReady(f)
	local images = {}
	for _, d in f:GetChildren() do
		if d:IsA("ImageLabel") and d.Name ~= "Glow" then
			images[d] = d.ImageTransparency
			d.ImageTransparency = 1
		end
	end
	task.spawn(function()
		local t0 = os.clock()
		while not Logo.Ready and os.clock() - t0 < 8 do task.wait(0.1) end
		local TweenService = game:GetService("TweenService")
		for img, tr in images do
			if img.Parent then TweenService:Create(img, TweenInfo.new(0.2), { ImageTransparency = tr }):Play() end
		end
	end)
end

function Logo.Build(parent, props)
	props = props or {}
	local z = props.ZIndex or 5
	local f = Instance.new("Frame")
	f.Name = "TacticalsLogo"
	f.BackgroundTransparency = 1
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	f.Position = props.Position or UDim2.fromScale(0.5, 0.42)
	f.Size = props.Size or UDim2.fromScale(0.5, 0.5)
	f.ZIndex = z
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = STAGE.X / STAGE.Y
	ar.Parent = f
	if props.Glow ~= false then
		local g = Instance.new("ImageLabel")
		g.Name = "Glow"
		g.BackgroundTransparency = 1
		g.Image = Logo.IMG.Glow
		g.ImageColor3 = Color3.fromRGB(138, 156, 74)
		g.ImageTransparency = 0.72
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(1.35, 2.2)
		g.ZIndex = z
		g.Parent = f
	end
	local frame = Instance.new("ImageLabel")
	frame.Name = "Frame"
	frame.BackgroundTransparency = 1
	frame.Image = Logo.IMG.Frame
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z + 1
	frame.Parent = f
	for i, L in LETTERS do
		local r = L[4]
		local l = Instance.new("ImageLabel")
		l.Name = "Letter" .. i
		l.BackgroundTransparency = 1
		l.Image = Logo.IMG.Letters
		l.ImageRectOffset = Vector2.new(r[1], r[2])
		l.ImageRectSize = Vector2.new(r[3], r[4])
		l.Position = SP(L[2], L[3])
		l.Size = SP(r[3], r[4])
		l.ZIndex = z + 2 + i
		l.Parent = f
	end
	if not Logo.Ready then Logo.Preload(); revealWhenReady(f) end
	f.Parent = parent
	return f
end

function Logo.Breathe(f)
	local s = f:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = f
	local TweenService = game:GetService("TweenService")
	local tw = TweenService:Create(s, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.03 })
	tw:Play()
	local glow = f:FindFirstChild("Glow")
	if glow then
		TweenService:Create(glow, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.6 }):Play()
	end
	return tw
end

Logo.Preload() -- at require (join): by the time a match-found / deploy / teleport screen needs the logo it is already sharp
return Logo
