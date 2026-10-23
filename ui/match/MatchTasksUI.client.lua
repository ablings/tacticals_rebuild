-- StarterPlayerScripts.MatchTasksUI (UI session 2026-10-22, Edward: "yeah do number 1"): RIVALS keeps its Daily Tasks panel on
-- screen during a match (left, ~0.5-19 % of the width, from ~37 % of the height) and the rows tick as you get eliminations.
-- This draws the same panel as the lobby's Daily Missions (LobbyHudController) in the match place, from the server's
-- Player attribute "MatchQuests" = JSON list of { Id, Text, Short, Stat, Goal, Reward, Progress } (Base optional). Nothing shows
-- until the server sends it. A row whose progress went up pulses; a done row turns green with the lime check.
-- Shown only while the match HUD is (DuelHUD on, no loadout / map vote, no result screen). Design px 1920x1080, then Scale.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local Kit = require(UIKit:WaitForChild("Kit"))
local Rivals = UIKit:WaitForChild("Rivals")
local RTheme = require(Rivals:WaitForChild("Theme"))
local RKit = require(Rivals:WaitForChild("Kit"))
local okA, RAssets = pcall(function() return require(Rivals:WaitForChild("Assets", 5)) end)
RAssets = okA and RAssets or {}
local RC = RTheme.color
local FONT = RTheme.font.bold
local new = Kit.new or function(cls, props, kids)
	local o = Instance.new(cls)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	for _, k in kids or {} do k.Parent = o end
	o.Parent = props.Parent
	return o
end

local GEN = RAssets.gen or {}
-- the same solid white glyphs as the lobby panel (LobbyHudController GEN_GLYPH)
local GLYPH = {
	Kills = GEN.tasks_elims, Headshots = Kit.glyph and Kit.glyph("headshot", GEN.tasks_elims) or GEN.tasks_elims, CoverKills = GEN.row_crouch,
	MeleeKills = GEN.kit_cat_knife, GadgetsThrown = GEN.kit_cat_grenade,
	Wins = Kit.glyph and Kit.glyph("trophy", Kit.ICONS.trophy) or Kit.ICONS.trophy, MatchesPlayed = Kit.glyph and Kit.glyph("play", Kit.ICONS.play) or Kit.ICONS.play,
}
local SHORT = { Kills = "Eliminations", Headshots = "Headshots", MeleeKills = "Melee kills", CoverKills = "Cover kills",
	GadgetsThrown = "Gadgets", Wins = "Win matches", MatchesPlayed = "Play matches" }
local CHECK_LIME = GEN.tasks_check_lime
local SCISSORS = "rbxassetid://115934367242130" -- (m7, grader B: the lobby widget's bold red reward scissors; the old render read faint)
local BAR_FILL = RC.blue or Color3.fromRGB(40, 150, 255)

local gui = new("ScreenGui", { Name = "MatchTasks", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 11, Enabled = false,
	Parent = player:WaitForChild("PlayerGui") })
local canvas = Kit.canvas(gui)
local holder = new("Frame", { Name = "Holder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
holder:SetAttribute("DesignCanvas", true)

local last = {} -- id -> progress shown last time (for the pulse)
local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function build(list)
	for _, c in holder:GetChildren() do c:Destroy() end
	if #list == 0 then return end
	local ROW = 67
	local H = 58 + #list * ROW
	local tmp = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), Parent = holder })
	-- RIVALS' see-through panel: black fading to the right, at the lobby panel's spot (10, 405)
	local panel = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(10, 405), Size = UDim2.fromOffset(370, H), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = tmp }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.15), NumberSequenceKeypoint.new(1, 1) }) }) })
	local clip = RAssets.tasks and RAssets.tasks.notepad
	if clip then
		new("ImageLabel", { BackgroundTransparency = 1, Image = clip, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 32), ZIndex = 3, Parent = panel })
	end
	local title = RKit.label({ Text = "Daily Missions", FontFace = FONT, TextSize = 26, TextColor3 = RC.text, Position = UDim2.fromOffset(52, 10), Size = UDim2.fromOffset(280, 36), ZIndex = 3, Parent = panel })
	RKit.textStroke(1.5).Parent = title
	local pulses = {}
	for i, q in list do
		local y = 58 + (i - 1) * ROW
		local goal = math.max(1, tonumber(q.Goal) or 1)
		local prog = math.clamp(tonumber(q.Progress) or 0, 0, goal)
		local done = prog >= goal
		new("ImageLabel", { BackgroundTransparency = 1, Image = GLYPH[q.Stat] or GLYPH.Kills or "", ImageColor3 = done and RC.green or RC.white, ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromOffset(14, y + 4), Size = UDim2.fromOffset(30, 30), ZIndex = 4, Parent = panel })
		local name = RKit.label({ Text = SHORT[q.Stat] or q.Short or q.Text or "", FontFace = FONT, TextSize = 24, TextColor3 = done and RC.green or RC.text,
			Position = UDim2.fromOffset(52, y), Size = UDim2.fromOffset(200, 32), ZIndex = 4, Parent = panel })
		RKit.textStroke(1.5).Parent = name
		local back = new("Frame", { Position = UDim2.fromOffset(52, y + 33), Size = UDim2.fromOffset(250, 6), BackgroundColor3 = RC.track or Color3.fromRGB(80, 80, 86),
			BackgroundTransparency = 0.15, ClipsDescendants = true, ZIndex = 4, Parent = panel }, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) }) -- (m7: track 0.35 -> 0.15, RIVALS' bars read solid)
		local was = last[q.Id]
		local frac = prog / goal
		local fill = new("Frame", { Size = UDim2.fromScale((was and math.clamp(was / goal, 0, 1)) or frac, 1), BackgroundColor3 = done and RC.green or BAR_FILL,
			ZIndex = 5, Parent = back }, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
		local row = { fill = fill, frac = frac, up = was ~= nil and prog > was }
		if done then
			row.badge = new("ImageLabel", { BackgroundTransparency = 1, Image = CHECK_LIME or "", ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(318, y - 2),
				Size = UDim2.fromOffset(40, 40), ZIndex = 5, Parent = panel })
		else
			row.badge = RKit.label({ RichText = true, Text = prog .. ' <font size="17">/ ' .. goal .. "</font>", FontFace = FONT, TextSize = 26, TextColor3 = RC.text,
				TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(318, y - 2), Size = UDim2.fromOffset(110, 34), ZIndex = 4, Parent = panel })
			RKit.textStroke(1.5).Parent = row.badge
			new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSORS, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(326, y - 4), Size = UDim2.fromOffset(38, 38),
				ZIndex = 4, Parent = panel })
			local rl = RKit.label({ Text = "×" .. commas(tonumber(q.Reward) or 0), FontFace = FONT, TextSize = 19, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(326 + 38 + 8, y + 40), Size = UDim2.fromOffset(100, 24), ZIndex = 6, Parent = panel })
			RKit.textStroke(1.5).Parent = rl
		end
		table.insert(pulses, row)
		last[q.Id] = prog
	end
	Kit.toScale(tmp)
	tmp.Size = UDim2.fromScale(1, 1)
	for _, r in pulses do
		if Kit.fillTo then Kit.fillTo(r.fill, r.frac, 0.5) else r.fill.Size = UDim2.fromScale(r.frac, 1) end
		if r.up and Kit.pop then Kit.pop(r.badge, 1.3) end
	end
end

local function refresh()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("MatchQuests") or "[]")
	build((ok and type(list) == "table") and list or {})
end
player:GetAttributeChangedSignal("MatchQuests"):Connect(refresh)
player:GetAttributeChangedSignal("QuestTick"):Connect(refresh)
refresh()

-- with the match HUD only (not over the map vote / loadout / Switch Weapons picker / result screen)
RunService.Heartbeat:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	local function on(n) local g = pg and pg:FindFirstChild(n); return g ~= nil and g:IsA("ScreenGui") and g.Enabled end
	local want = player:GetAttribute("MatchQuests") ~= nil and on("DuelHUD") and not on("MatchFlow") and not on("MatchResult") and not on("VictoryScreen")
		and player:GetAttribute("Setting_GameplayHUD") ~= "Minimal"
	if gui.Enabled ~= want then gui.Enabled = want end
end)
