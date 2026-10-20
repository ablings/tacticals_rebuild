-- fix/hud_overlap.lua [HUDFIT] 2026-10-20, UI audit at phone size (UI session, out/a_phone_match_1.png). Both places where present.
--   TutorialController: the objective / dialogue panel sat at the bottom (offset -66) and covered the hotbar's item tiles on a phone.
--     It now anchors in Scale above the hotbar (bottom edge at 82% of the screen height) on every screen size.
--     (It only shows in tutorials; in Studio it auto-starts in any bot match because TutorialConfig.AutoStartInStudio.)
--   StealthController: the NOISE meter was Offset-sized at the bottom-left and ran into the health bar on small screens. It's now
--     built like the health bar: 1920x1080 design px on a UIKit canvas, then Kit.toScale (Scale only), just above the health box.
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local C = game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers

local edits = {}
local function edit(inst, old, new) if inst then table.insert(edits, { inst, old, new }) end end

edit(C:FindFirstChild("TutorialController"),
	"local PANEL_POS = UDim2.new(0.5, 0, 1, -66)\n",
	"local PANEL_POS = UDim2.fromScale(0.5, 0.82) -- [HUDFIT] above the hotbar on any screen (was 66 px from the bottom: covered the item tiles on phones)\n")

edit(C:FindFirstChild("StealthController"),
	[[	local gui = Instance.new("ScreenGui")
	gui.Name = "StealthUI"
	gui.ResetOnSpawn = false
	meterFrame = Instance.new("Frame")
	meterFrame.AnchorPoint = Vector2.new(0, 1)
	meterFrame.Position = UDim2.new(0, 18, 1, -18)
	meterFrame.Size = UDim2.fromOffset(150, 30)
	meterFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	meterFrame.BackgroundTransparency = 0.35
	meterFrame.BorderSizePixel = 0
	meterFrame.Parent = gui
]],
	[[	local gui = Instance.new("ScreenGui")
	gui.Name = "StealthUI"
	gui.ResetOnSpawn = false
	-- [HUDFIT] built in 1920x1080 design px on a UIKit canvas like the health bar, then Kit.toScale (Scale only): sits just above the
	-- health box (which spans y 928..1016 at x 28), so the two never overlap on any screen size
	gui.IgnoreGuiInset = true
	local Kit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
	local canvas = Kit.canvas(gui)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = canvas
	meterFrame = Instance.new("Frame")
	meterFrame.AnchorPoint = Vector2.new(0, 1)
	meterFrame.Position = UDim2.fromOffset(28, 1080 - 64 - 88 - 10)
	meterFrame.Size = UDim2.fromOffset(230, 50)
	meterFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	meterFrame.BackgroundTransparency = 0.35
	meterFrame.BorderSizePixel = 0
	meterFrame.Parent = root
]])
edit(C:FindFirstChild("StealthController"),
	[[	meterFill.Parent = bar
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
]],
	[[	meterFill.Parent = bar
	Kit.toScale(root) -- [HUDFIT]
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
]])

-- [HUDFIT] bigger meter + label (the UI audit: NOISE text was ~6 px on a phone after Kit.toScale)
edit(C:FindFirstChild("StealthController"),
	"\tmeterLabel.Position = UDim2.fromOffset(8, 2)\n\tmeterLabel.Size = UDim2.new(1, -16, 0, 14)\n",
	"\tmeterLabel.Position = UDim2.fromOffset(12, 4)\n\tmeterLabel.Size = UDim2.new(1, -24, 0, 24)\n")
edit(C:FindFirstChild("StealthController"),
	"\tmeterLabel.TextSize = 11\n",
	"\tmeterLabel.TextSize = 20\n")
edit(C:FindFirstChild("StealthController"),
	"\tbar.Position = UDim2.fromOffset(8, 19)\n\tbar.Size = UDim2.new(1, -16, 0, 5)\n",
	"\tbar.Position = UDim2.fromOffset(12, 34)\n\tbar.Size = UDim2.new(1, -24, 0, 8)\n")

local out, sources = {}, {}
for _, e in edits do sources[e[1]] = sources[e[1]] or e[1].Source end
for i, e in edits do
	local s = sources[e[1]]
	local old, new = e[2], e[3]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then
		table.insert(out, e[1].Name .. i .. "=")
	else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found in " .. e[1].Name)
		sources[e[1]] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, e[1].Name .. i .. "+")
	end
end
for inst, s in sources do
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
end
return table.concat(out, " ")
