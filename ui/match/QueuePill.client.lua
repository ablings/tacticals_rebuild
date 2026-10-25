-- QueuePill (match places, StarterPlayerScripts, LocalScript) [PLAYQUEUE] (Edward 2026-10-25, lead session).
-- Play Again queues you from the match server itself with the lobby's online queue (the lead's MatchmakingManager, installed
-- in the match places); a match found teleports you straight into a new match server with the players you were matched with.
-- This is LobbyHud's "Searching for players" pill (same look, texts and clock) in its own ScreenGui above every match screen
-- (VictoryScreen 13, MatchScoreboard 14, MatchResult 15), so the search shows over Victory / Defeat and the results as well as
-- in the after-match lobby. LobbyHud hides its own pill in the match places (it is only built once the after-match map is out).
-- Data: player attributes MM_Queue (queue id), MM_Status (Searching | Found | Teleporting), MM_Since (server time); the X asks
-- the server to CancelMatch (Events.Lobby.Request). Built in 1920x1080 design px on the 16:9 canvas, then Kit.toScale (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local PseudoLobby = require(UIKit:WaitForChild("PseudoLobby"))
if not PseudoLobby.MatchPlace() then return end -- the hub: LobbyHud's own pill
local Kit = require(UIKit:WaitForChild("Kit"))
local RUI = UIKit:WaitForChild("Rivals")
local RTheme = require(RUI:WaitForChild("Theme"))
local RKit = require(RUI:WaitForChild("Kit"))
local RAssets = require(RUI:WaitForChild("Assets"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyConfig"))
local Request = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby"):WaitForChild("Request")

local player = Players.LocalPlayer
local new = Kit.new
local RC = RTheme.color
local R_BOLD = Font.new(RTheme.font.medium.Family, Enum.FontWeight.Bold)

local gui = new("ScreenGui", { Name = "QueuePill", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 16, Parent = player:WaitForChild("PlayerGui") })
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = Kit.canvas(gui) })

-- the lobby pill 1:1 (LobbyHud "Searching"): a 540 x 80 dark pill, corner 8, top centre at y 105, the six-point sparkle,
-- status over mode, the clock right-aligned to x 430 and the red X that cancels
local seek = new("Frame", { Name = "Searching", Position = UDim2.fromOffset(692, 105), Size = UDim2.fromOffset(540, 80), BackgroundColor3 = RC.textDark,
	BackgroundTransparency = 0.1, Visible = false, ZIndex = 10, Parent = root }, { RKit.corner(8) })
new("ImageLabel", { BackgroundTransparency = 1, Image = RAssets.tasks and RAssets.tasks.star6 or "", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(60, 60), ZIndex = 11, Parent = seek })
local status = RKit.label({ Name = "Status", Text = "Searching for players.", FontFace = RTheme.font.medium, TextSize = 21, TextColor3 = RC.text,
	Position = UDim2.fromOffset(74, 10), Size = UDim2.fromOffset(300, 28), ZIndex = 11, Parent = seek })
local mode = RKit.label({ Name = "Mode", Text = "", FontFace = R_BOLD, TextSize = 27, TextColor3 = RC.text, Position = UDim2.fromOffset(74, 38), Size = UDim2.fromOffset(320, 32),
	ZIndex = 11, Parent = seek })
local clock = RKit.label({ Name = "Clock", Text = "0:00", FontFace = R_BOLD, TextSize = 30, TextColor3 = RC.text, TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(100, 80), ZIndex = 11, Parent = seek })
local x = RKit.closeButton(UDim2.fromOffset(76, 52))
x.Position = UDim2.fromOffset(448, 14)
x.ZIndex = 11
x.Parent = seek
x.Activated:Connect(function() pcall(Request.InvokeServer, Request, "CancelMatch") end)
Kit.toScale(root)
-- top centre (the lobby spot) normally; the top-left corner while Victory / Defeat or the results card is up, so it never covers
-- their DEFEAT / VICTORY header (top centre)
local HOME, CORNER = seek.Position, UDim2.fromScale(40 / 1920, 40 / 1080)
local pg = player.PlayerGui
local function resultsUp()
	for _, n in { "MatchResult", "VictoryScreen", "MatchScoreboard" } do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") and g.Enabled then return true end
	end
	return false
end

RunService.Heartbeat:Connect(function()
	local q, st = player:GetAttribute("MM_Queue"), player:GetAttribute("MM_Status")
	-- (round 3) PQ_Waiting: Play Again pressed during the Victory beat, the search starts once the match results are saved
	local saving = player:GetAttribute("PQ_Waiting") == true and st == nil
	seek.Visible = (q ~= nil and st ~= nil) or saving
	if not seek.Visible then return end
	local want = resultsUp() and CORNER or HOME
	if seek.Position ~= want then seek.Position = want end
	local def = Config.QueueById and Config.QueueById(q)
	local e = workspace:GetServerTimeNow() - (player:GetAttribute("MM_Since") or workspace:GetServerTimeNow())
	local searching = st == "Searching"
	status.Text = saving and "Saving match results..." or (searching and ("Searching for players" .. string.rep(".", 1 + math.floor(e) % 3)) or "Match found!")
	status.TextColor3 = (searching or saving) and RC.text or RC.green
	mode.Text = def and ((def.Ranked and "Ranked " or "") .. tostring(def.Mode or def.Id or "")) or ""
	local sec = math.max(0, math.floor(e))
	clock.Text = string.format("%d:%02d", sec // 60, sec % 60)
	x.Visible = searching and not saving
end)
