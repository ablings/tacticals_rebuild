-- UIKit/FlatIcons (ModuleScript): one flat cream icon set for the lobby dock and the Settings tabs (lobby revamp Phase B,
-- 2026-10-21, Edward OK: replaces the glossy 3D renders). Every icon is drawn from Frames in Scale on a square stage, so it
-- follows its holder at any size and needs no uploaded art.
--   FlatIcons.Draw(holder, name, { color = Color3?, ink = Color3?, scale = number? }) -> stage
--   names: kit, missions, shop, codes, settings, video, audio, game, hotkeys, touch, account
local FlatIcons = {}

local CREAM = Color3.fromRGB(236, 230, 210)
local INK = Color3.fromRGB(22, 24, 19)

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end
local function round(f, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0.18, 0)
	c.Parent = f
	return f
end

-- shape helpers in stage fractions (0..1, the stage is square)
local function rect(st, x, y, w, h, color, rot, r)
	return round(frame(st, { Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = color, Rotation = rot or 0, ZIndex = st.ZIndex }), r)
end
local function disc(st, cx, cy, d, color)
	return round(frame(st, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(d, d), BackgroundColor3 = color, ZIndex = st.ZIndex }), UDim.new(0.5, 0))
end
local function bar(st, x1, y1, x2, y2, t, color)
	local dx, dy = x2 - x1, y2 - y1
	return round(frame(st, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromScale(math.sqrt(dx * dx + dy * dy) + t, t), Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = color, ZIndex = st.ZIndex }), UDim.new(0.5, 0))
end
-- a ring: a disc with a smaller disc of the backdrop colour would hide what's behind, so use a stroke sized from the stage
local function ring(st, cx, cy, d, t, color)
	local f = disc(st, cx, cy, d, color)
	f.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Parent = f
	local function fit() s.Thickness = math.max(1, st.AbsoluteSize.X * t) end
	st:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return f
end

local DRAW = {}
function DRAW.kit(st, c, ink) -- a pistol
	rect(st, 0.08, 0.26, 0.8, 0.2, c, 0, UDim.new(0.25, 0))
	rect(st, 0.5, 0.36, 0.22, 0.46, c, 14, UDim.new(0.2, 0))
	ring(st, 0.4, 0.56, 0.2, 0.05, c)
	rect(st, 0.14, 0.31, 0.5, 0.04, ink, 0, UDim.new(0.5, 0))
end
function DRAW.missions(st, c, ink) -- a clipboard with lines
	rect(st, 0.2, 0.14, 0.6, 0.78, c, 0, UDim.new(0.1, 0))
	rect(st, 0.36, 0.06, 0.28, 0.16, ink, 0, UDim.new(0.3, 0))
	rect(st, 0.39, 0.09, 0.22, 0.1, c, 0, UDim.new(0.3, 0))
	for i = 0, 2 do
		disc(st, 0.33, 0.4 + i * 0.16, 0.08, ink)
		rect(st, 0.42, 0.38 + i * 0.16, 0.28, 0.05, ink, 0, UDim.new(0.5, 0))
	end
end
function DRAW.shop(st, c, ink) -- a supply crate
	rect(st, 0.12, 0.34, 0.76, 0.54, c, 0, UDim.new(0.08, 0))
	rect(st, 0.08, 0.2, 0.84, 0.16, c, 0, UDim.new(0.15, 0))
	rect(st, 0.44, 0.2, 0.12, 0.68, ink, 0, UDim.new(0.1, 0))
	rect(st, 0.12, 0.36, 0.76, 0.04, ink, 0, UDim.new(0, 0))
end
function DRAW.codes(st, c, ink) -- a dog tag on its chain
	local t = rect(st, 0.22, 0.24, 0.5, 0.66, c, -18, UDim.new(0.3, 0))
	t.ZIndex = st.ZIndex
	disc(st, 0.39, 0.33, 0.12, ink)
	bar(st, 0.38, 0.32, 0.62, 0.08, 0.04, c)
	bar(st, 0.62, 0.08, 0.8, 0.24, 0.04, c)
	rect(st, 0.33, 0.52, 0.28, 0.05, ink, -18, UDim.new(0.5, 0))
	rect(st, 0.36, 0.62, 0.2, 0.05, ink, -18, UDim.new(0.5, 0))
end
function DRAW.settings(st, c, ink) -- a gear
	for i = 0, 3 do -- four bars through the middle = eight teeth
		local tooth = rect(st, 0, 0, 0.18, 0.9, c, i * 45, UDim.new(0.2, 0))
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.fromScale(0.5, 0.5)
	end
	disc(st, 0.5, 0.5, 0.66, c)
	disc(st, 0.5, 0.5, 0.26, ink)
end
function DRAW.video(st, c, ink) -- a monitor
	rect(st, 0.08, 0.16, 0.84, 0.56, c, 0, UDim.new(0.1, 0))
	rect(st, 0.15, 0.23, 0.7, 0.42, ink, 0, UDim.new(0.06, 0))
	rect(st, 0.44, 0.72, 0.12, 0.12, c, 0, UDim.new(0, 0))
	rect(st, 0.28, 0.82, 0.44, 0.07, c, 0, UDim.new(0.5, 0))
end
function DRAW.audio(st, c, ink) -- a headset
	ring(st, 0.5, 0.5, 0.7, 0.09, c)
	rect(st, 0.1, 0.48, 0.2, 0.38, c, 0, UDim.new(0.35, 0))
	rect(st, 0.7, 0.48, 0.2, 0.38, c, 0, UDim.new(0.35, 0))
end
function DRAW.game(st, c, ink) -- a controller
	rect(st, 0.06, 0.28, 0.88, 0.46, c, 0, UDim.new(0.45, 0))
	rect(st, 0.2, 0.46, 0.2, 0.07, ink, 0, UDim.new(0.3, 0))
	rect(st, 0.265, 0.395, 0.07, 0.2, ink, 0, UDim.new(0.3, 0))
	disc(st, 0.66, 0.44, 0.09, ink)
	disc(st, 0.76, 0.56, 0.09, ink)
end
function DRAW.hotkeys(st, c, ink) -- a keyboard
	rect(st, 0.04, 0.26, 0.92, 0.5, c, 0, UDim.new(0.12, 0))
	for r = 0, 1 do
		for k = 0, 4 do rect(st, 0.12 + k * 0.16, 0.34 + r * 0.14, 0.1, 0.09, ink, 0, UDim.new(0.25, 0)) end
	end
	rect(st, 0.26, 0.62, 0.48, 0.07, ink, 0, UDim.new(0.4, 0))
end
function DRAW.touch(st, c, ink) -- a phone
	rect(st, 0.28, 0.06, 0.44, 0.88, c, 0, UDim.new(0.16, 0))
	rect(st, 0.33, 0.14, 0.34, 0.64, ink, 0, UDim.new(0.08, 0))
	disc(st, 0.5, 0.86, 0.07, ink)
end
function DRAW.account(st, c) -- a person
	disc(st, 0.5, 0.32, 0.36, c)
	rect(st, 0.18, 0.56, 0.64, 0.36, c, 0, UDim.new(0.45, 0))
end

function FlatIcons.Draw(holder: GuiObject, name: string, opts)
	opts = opts or {}
	local k = opts.scale or 1
	local st = frame(holder, { Name = "FlatIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(k, k), ZIndex = (holder.ZIndex or 1) + 1 })
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = st
	local fn = DRAW[name]
	if fn then fn(st, opts.color or CREAM, opts.ink or INK) end
	return st
end
FlatIcons.CREAM, FlatIcons.INK = CREAM, INK

return FlatIcons
