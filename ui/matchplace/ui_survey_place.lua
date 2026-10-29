-- (2026-10-29, UI survey round 2) place-side UI fixes for the stored GUIs and the scripts the ui/ folder has no source for.
-- Runs in EVERY place (deploy_ui.py adds it to the lobby PATCHES and the match MATCH_PATCHES). Idempotent; inside the deploy's
-- ChangeHistory recording (Ctrl+Z undoes it).
--   A7  StarterGui.MainUI.ResetOnSpawn = false (it has no scripts; a duel respawns every round)
--   4   StarterGui.MainUI / StarterGui.HUD: every stored Offset turned into Scale. The 1920 x 1080 design canvas is the reference
--       (the Offsets were 1080p px): Size / Position become Scale of the parent's design size, a pure-px size keeps its shape with
--       a UIAspectRatioConstraint, UICorner / UIPadding / UIListLayout Offsets become Scale.
--   13  off-rule fonts in the lobby's own scripts: BayBoards GothamSSm, ExfilFX Oswald, LobbyRangeClient Gotham -> Rubik
local SG = game:GetService("StarterGui")
local RUBIK = "rbxassetid://12187365977"

local mainUI = SG:FindFirstChild("MainUI")
if mainUI and mainUI:IsA("ScreenGui") then mainUI.ResetOnSpawn = false end

local function toScaleTree(root)
	local n = 0
	local function conv(parent, pw, ph)
		for _, c in parent:GetChildren() do
			if c:IsA("GuiObject") then
				local s, p = c.Size, c.Position
				local w, h = s.X.Scale * pw + s.X.Offset, s.Y.Scale * ph + s.Y.Offset
				local pureOffset = s.X.Scale == 0 and s.Y.Scale == 0 and w > 0 and h > 0
				if s.X.Offset ~= 0 or s.Y.Offset ~= 0 then
					c.Size = UDim2.fromScale(w / pw, h / ph)
					n += 1
					if pureOffset and not c:FindFirstChildOfClass("UIAspectRatioConstraint") then
						local a = Instance.new("UIAspectRatioConstraint")
						a.AspectRatio = w / h
						a.Parent = c
					end
				end
				if p.X.Offset ~= 0 or p.Y.Offset ~= 0 then
					c.Position = UDim2.fromScale((p.X.Scale * pw + p.X.Offset) / pw, (p.Y.Scale * ph + p.Y.Offset) / ph)
					n += 1
				end
				conv(c, math.max(w, 1), math.max(h, 1))
			elseif c:IsA("UICorner") and c.CornerRadius.Offset ~= 0 then
				c.CornerRadius = UDim.new(c.CornerRadius.Scale + c.CornerRadius.Offset / math.max(math.min(pw, ph), 1), 0)
				n += 1
			elseif c:IsA("UIPadding") then
				for _, k in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
					local u = c[k]
					if u.Offset ~= 0 then
						c[k] = UDim.new(u.Scale + u.Offset / ((k == "PaddingLeft" or k == "PaddingRight") and pw or ph), 0)
						n += 1
					end
				end
			elseif c:IsA("UIListLayout") and c.Padding.Offset ~= 0 then
				local along = c.FillDirection == Enum.FillDirection.Horizontal and pw or ph
				c.Padding = UDim.new(c.Padding.Scale + c.Padding.Offset / along, 0)
				n += 1
			end
		end
	end
	conv(root, 1920, 1080)
	return n
end
local converted = 0
for _, name in { "MainUI", "HUD" } do
	local g = SG:FindFirstChild(name)
	if g and g:IsA("ScreenGui") and not g:GetAttribute("UISurveyScale") then
		converted += toScaleTree(g)
		g:SetAttribute("UISurveyScale", true)
	end
end

-- off-rule fonts (lobby scripts; skipped where the script isn't there)
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local function patch(name, pairs_)
	local s = SPS:FindFirstChild(name)
	if not s or s.Source:find("[UISURVEY]", 1, true) then return end
	local src, hits = s.Source, 0
	for _, pr in pairs_ do
		local out, k = src:gsub(pr[1], pr[2])
		src, hits = out, hits + k
	end
	if hits > 0 then s.Source = "-- [UISURVEY] (2026-10-29) fonts -> Rubik (UI survey 13)\n" .. src end
end
patch("BayBoards", { { 'local FONT = "rbxasset://fonts/families/GothamSSm%.json"', 'local FONT = "' .. RUBIK .. '"' } })
patch("ExfilFX", {
	{ "cap%.Font = Enum%.Font%.Oswald", 'cap.FontFace = Font.new("' .. RUBIK .. '", Enum.FontWeight.Bold)' },
	{ "leaveBtn%.Font = Enum%.Font%.Oswald", 'leaveBtn.FontFace = Font.new("' .. RUBIK .. '", Enum.FontWeight.Bold)' },
})
patch("LobbyRangeClient", { { "l%.Font=font or Enum%.Font%.GothamBlack",
	'l.FontFace=Font.new("' .. RUBIK .. '", font==Enum.Font.GothamBold and Enum.FontWeight.SemiBold or Enum.FontWeight.Bold)' } })
print("[UISURVEY] place fixes: " .. converted .. " stored Offsets -> Scale; MainUI ResetOnSpawn " .. tostring(mainUI and mainUI.ResetOnSpawn))
