-- fix/stealth_callout_style.lua [CALLOUTSTYLE] 2026-10-21 (UI session, match place): the enemy's speech bubble in the tutorial
-- (StealthController.showCallout, e.g. "Cover me - reloading!") had two AI-UI tells: a thin red bar down its left edge and
-- Builder Sans. Now: the same dark plate with a red lip under it (red = enemy) and Oswald Bold. StealthController lives only
-- in the place (not in the repo). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local M = game:GetService("StarterPlayer"):FindFirstChild("StealthController", true)
assert(M, "no StealthController")
local edits = {
	{ [==[	local tick = Instance.new("Frame")
	tick.AnchorPoint = Vector2.new(0, 0.5)
	tick.Position = UDim2.new(0, -10, 0.5, 0)
	tick.Size = UDim2.new(0, 4, 0.6, 0)
	tick.BackgroundColor3 = Color3.fromRGB(210, 52, 46)
	tick.BorderSizePixel = 0
	tick.Parent = plate
]==], [==[	-- [CALLOUTSTYLE] a red lip under the plate (red = enemy) instead of a thin bar down the left edge
	local tick = Instance.new("Frame")
	tick.Name = "Lip"
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position = UDim2.new(0.5, 0, 1, -3)
	tick.Size = UDim2.new(1, 32, 0, 7) -- (+32: the plate's 16 px padding each side)
	tick.BackgroundColor3 = Color3.fromRGB(170, 40, 34)
	tick.BorderSizePixel = 0
	tick.ZIndex = 0
	tick.Parent = plate
	local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 6) tc.Parent = tick
]==] },
	{ [==[pad.PaddingLeft = UDim.new(0, 20) pad.PaddingRight = UDim.new(0, 16) pad.Parent = plate]==],
	  [==[pad.PaddingLeft = UDim.new(0, 16) pad.PaddingRight = UDim.new(0, 16) pad.Parent = plate]==] },
	{ [==[	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)]==],
	  [==[	label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold) -- [CALLOUTSTYLE] was Builder Sans]==] },
}
local s = M.Source:gsub("\r\n", "\n")
local out = {}
for i, e in edits do
	local old, new = e[1], e[2]
	if UNDO then old, new = new, old end
	if s:find(new, 1, true) then table.insert(out, i .. "=") else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "StealthController would not parse: " .. tostring(err))
if M.Source ~= s then M.Source = s end
return "StealthController " .. table.concat(out, " ")
