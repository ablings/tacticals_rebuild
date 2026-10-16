-- Client/Controllers/LobbyHudController (ModuleScript, auto-loaded): the lobby HUD around the PLAY row and the dock,
-- RIVALS' layout in TACTICALS' look.
--   * Top centre: the scissors pill (the 3D scissors, your count, + opens the scissors shop).
--   * Left: DAILY MISSIONS (the real daily quests with progress, claimable ones flagged) and TO PADS under it.
--   * Right: the server list (Tab toggles): every player with level and wins, you highlighted.
-- Follows the lobby: hidden while a menu is open (LobbyUI disabled), in the Kit room (dock hidden), on a pad and in Training.
-- Built in 1920x1080 design px on a 16:9 canvas, then Kit.toScale (Scale only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LobbyHud = {}

local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyConfig"))
local new, hex = Kit.new, Theme.hex
local player = Players.LocalPlayer

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BONE, FIELD, OLIVE, OLIVE_HI = hex("#ECE8DA"), hex("#969C8C"), hex("#6B7A3A"), hex("#8A9C4A")
local GUN, DEEP, LINE, RED = hex("#1A1D1A"), hex("#0C0E0B"), hex("#40463A"), hex("#D6403A")

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or BONE, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2, Parent = parent })
end
local function brackets(p, color, len, th, z)
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		for _, sz in { Vector2.new(len, th), Vector2.new(th, len) } do
			new("Frame", { Name = "_Bracket", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]),
				Size = UDim2.fromOffset(sz.X, sz.Y), ZIndex = z or 5, Parent = p })
		end
	end
end
local function commas(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function LobbyHud.Start()
	local LobbyUI = shared.Get and shared.Get("LobbyUIController")
	local gui = new("ScreenGui", { Name = "LobbyHud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui") })
	local canvas = Kit.canvas(gui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	---------------------------------------------------------------------------------------------- scissors pill
	local pill = new("Frame", { Name = "Scissors", Position = UDim2.fromOffset(840, 26), Size = UDim2.fromOffset(240, 58), BackgroundColor3 = DEEP, BackgroundTransparency = 0.25, Parent = root })
	brackets(pill, LINE, 12, 2)
	local iconHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-22, -12), Size = UDim2.fromOffset(84, 84), ZIndex = 3, Parent = pill })
	local count = label(pill, "...", OSWALD, 36, 62, 0, 120, 58, BONE, Enum.TextXAlignment.Center, 3)
	local plus = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(190, 9), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = OLIVE, ZIndex = 3, Parent = pill },
		{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#A8BC62"), hex("#5B6E2C")) }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = 4, Parent = plus })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 20), BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = 4, Parent = plus })
	Kit.bindButton(plus, { hover = 1.12 })
	plus.Activated:Connect(function() if LobbyUI and LobbyUI.OpenShop then LobbyUI.Close(); LobbyUI.OpenShop("Scissors") end end)

	---------------------------------------------------------------------------------------------- missions widget
	local missions = new("TextButton", { Name = "Missions", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(16, 360), Size = UDim2.fromOffset(372, 260),
		BackgroundColor3 = DEEP, BackgroundTransparency = 0.25, Parent = root })
	brackets(missions, LINE, 14, 2)
	new("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(5, 34), BackgroundColor3 = OLIVE, BorderSizePixel = 0, ZIndex = 3, Parent = missions })
	label(missions, "DAILY MISSIONS", OSWALD, 28, 18, 8, 240, 40, BONE, nil, 3)
	local reset = label(missions, "", OSWALD, 15, 200, 18, 160, 24, FIELD, Enum.TextXAlignment.Right, 3)
	local rows = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(372, 200), ZIndex = 3, Parent = missions })
	missions.Activated:Connect(function() if LobbyUI then LobbyUI.Open("Missions") end end)
	local toPads = new("TextButton", { Name = "ToPads", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(92, 634), Size = UDim2.fromOffset(220, 52), BackgroundColor3 = OLIVE, Parent = root },
		{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#A8BC62"), hex("#5B6E2C")) }) })
	brackets(toPads, BONE, 10, 2, 4)
	label(toPads, "TO PADS  >", OSWALD, 28, 0, 0, 220, 52, BONE, Enum.TextXAlignment.Center, 3)
	Kit.bindButton(toPads, { hover = 1.06 })
	toPads.Activated:Connect(function()
		-- straight to the duel hall, in front of the first pad (not on it)
		local duels = workspace:FindFirstChild("LobbyMap") and workspace.LobbyMap:FindFirstChild("Duels")
		local pad = duels and (duels:FindFirstChild("Pad_1v1_A") or duels:FindFirstChildWhichIsA("Model"))
		local holo = pad and (pad:FindFirstChild("Holo") or pad:FindFirstChildWhichIsA("BasePart", true))
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if holo and hrp then
			-- stand on the hall side of the pad (towards the Duels centre), facing it, camera behind you
			local padPos = pad:GetBoundingBox().Position
			-- the hall centre = the middle of all its pads (Duels is a Folder)
			local sum, n = Vector3.zero, 0
			for _, m in duels:GetChildren() do
				if m:IsA("Model") then sum += m:GetBoundingBox().Position; n += 1 end
			end
			local hallPos = n > 0 and sum / n or padPos + Vector3.new(0, 0, 20)
			local away = Vector3.new(hallPos.X - padPos.X, 0, hallPos.Z - padPos.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
			local _, padSize = pad:GetBoundingBox()
			local spot = padPos + away * (math.max(padSize.X, padSize.Z) / 2 + 7)
			local hit = workspace:Raycast(spot + Vector3.new(0, 12, 0), Vector3.new(0, -50, 0))
			local ground = (hit and hit.Position or spot) + Vector3.new(0, 3, 0)
			hrp.CFrame = CFrame.lookAt(ground, Vector3.new(padPos.X, ground.Y, padPos.Z))
			local cam = workspace.CurrentCamera
			cam.CFrame = CFrame.lookAt(ground + away * 12 + Vector3.new(0, 5, 0), Vector3.new(padPos.X, ground.Y, padPos.Z))
		end
	end)

	---------------------------------------------------------------------------------------------- server list
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	-- a fixed slot (design 330x420); the plate inside is rebuilt to fit the server and converted against the slot
	local board = new("Frame", { Name = "Board", Position = UDim2.fromOffset(1574, 90), Size = UDim2.fromOffset(330, 420), BackgroundTransparency = 1, Parent = root })
	local boardOn = true

	Kit.toScale(root)

	-- the 3D scissors in the pill (the same view icon as the shop's balance pill)
	local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
	ViewIcons.Icon(iconHolder, "Scissors", { hoverTarget = pill, zoom = 1.15 })

	---------------------------------------------------------------------------------------------- data
	local data
	local function questDef(scope, id)
		for _, q in Config.Quests[scope].Pool do if q.Id == id then return q end end
	end
	local lastRows
	local function refresh()
		if not data then return end
		count.Text = commas(data.Credits or 0)
		local q = data.Quests and data.Quests.Daily
		local key = ""
		local entries = {}
		for i, e in (q and q.List) or {} do
			local def = questDef("Daily", e.Id)
			if def then
				local prog = math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - (e.Base or 0), 0, def.Goal)
				table.insert(entries, { def = def, prog = prog, claimed = e.Claimed })
				key ..= def.Id .. prog .. tostring(e.Claimed)
			end
		end
		if key == lastRows then return end
		lastRows = key
		for _, c in rows:GetChildren() do c:Destroy() end
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(372, 200), ZIndex = 3, Parent = rows })
		for i, e in entries do
			local y = (i - 1) * 64
			local done = e.prog >= e.def.Goal
			label(holder, e.def.Text, BOLD, 17, 18, y, 250, 24, e.claimed and FIELD or BONE, nil, 4).TextTruncate = Enum.TextTruncate.AtEnd
			label(holder, e.claimed and "DONE" or (e.prog .. " / " .. e.def.Goal), OSWALD, 18, 250, y, 70, 24, done and OLIVE_HI or FIELD, Enum.TextXAlignment.Right, 4)
			local track = new("Frame", { Position = UDim2.fromOffset(18, y + 30), Size = UDim2.fromOffset(302, 8), BackgroundColor3 = hex("#2A2E26"), BorderSizePixel = 0, ZIndex = 4, Parent = holder })
			new("Frame", { Size = UDim2.fromScale(e.prog / e.def.Goal, 1), BackgroundColor3 = done and OLIVE_HI or BONE, BorderSizePixel = 0, ZIndex = 5, Parent = track })
			label(holder, "+" .. e.def.Reward, OSWALD, 16, 324, y + 18, 44, 24, BONE, Enum.TextXAlignment.Center, 4)
			if done and not e.claimed then
				-- ready to claim: a red flag at the row start (claimed in Missions)
				new("Frame", { Position = UDim2.fromOffset(6, y + 4), Size = UDim2.fromOffset(5, 34), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 5, Parent = holder })
			end
		end
		if #entries == 0 then label(holder, "Loading missions...", BODY, 16, 18, 0, 330, 24, FIELD, nil, 4) end
		Kit.toScale(holder, Vector2.new(372, 200))
		holder.Size = UDim2.fromScale(1, 1)
	end
	local function resetText()
		local left = 86400 - os.time() % 86400
		reset.Text = string.format("NEW IN %dH %dM", left // 3600, left % 3600 // 60)
	end

	local lastBoard
	local function refreshBoard()
		local ps = Players:GetPlayers()
		table.sort(ps, function(a, b)
			local la, lb = a:GetAttribute("Level") or 0, b:GetAttribute("Level") or 0
			if la ~= lb then return la > lb end
			return a.DisplayName < b.DisplayName
		end)
		local key = ""
		for _, p in ps do key ..= p.UserId .. tostring(p:GetAttribute("Level")) .. tostring(p:GetAttribute("Wins")) end
		if key == lastBoard then return end
		lastBoard = key
		for _, c in board:GetChildren() do c:Destroy() end
		local MAX = 9
		local shown = math.min(#ps, MAX)
		local more = #ps - shown
		local h = 36 + shown * 40 + (more > 0 and 26 or 0) + 6
		local plate = new("Frame", { Size = UDim2.fromOffset(330, h), BackgroundColor3 = DEEP, BackgroundTransparency = 0.25, Parent = board })
		brackets(plate, LINE, 12, 2)
		label(plate, "OPERATORS", OSWALD, 20, 14, 4, 200, 30, BONE, nil, 3)
		label(plate, "LV", OSWALD, 15, 210, 8, 50, 22, FIELD, Enum.TextXAlignment.Center, 3)
		label(plate, "WINS", OSWALD, 15, 262, 8, 60, 22, FIELD, Enum.TextXAlignment.Center, 3)
		for i = 1, shown do
			local p = ps[i]
			local y = 36 + (i - 1) * 40
			local me = p == player
			local row = new("Frame", { Position = UDim2.fromOffset(6, y), Size = UDim2.fromOffset(318, 38), BackgroundColor3 = me and OLIVE or GUN, BackgroundTransparency = me and 0.45 or 0.6, BorderSizePixel = 0, ZIndex = 3, Parent = plate })
			local hs = new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(32, 32), ZIndex = 4, Parent = row })
			task.spawn(function()
				local ok, im = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				if ok and hs.Parent then hs.Image = im end
			end)
			label(row, p.DisplayName, BOLD, 16, 42, 0, 160, 38, BONE, nil, 4).TextTruncate = Enum.TextTruncate.AtEnd
			label(row, tostring(p:GetAttribute("Level") or "-"), OSWALD, 18, 206, 0, 50, 38, BONE, Enum.TextXAlignment.Center, 4)
			label(row, tostring(p:GetAttribute("Wins") or "-"), OSWALD, 18, 258, 0, 60, 38, FIELD, Enum.TextXAlignment.Center, 4)
		end
		if more > 0 then label(plate, "+" .. more .. " MORE", OSWALD, 15, 14, 36 + shown * 40, 300, 24, FIELD, nil, 3) end
		Kit.toScale(board, Vector2.new(330, 420))
	end
	UserInputService.InputBegan:Connect(function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.Tab then boardOn = not boardOn end
	end)

	---------------------------------------------------------------------------------------------- follow the lobby
	local function lobbyShown()
		local pg = player.PlayerGui
		local lobby = pg:FindFirstChild("LobbyUI")
		if not lobby or not lobby.Enabled then return false end
		local dock = lobby:FindFirstChild("Dock", true)
		if dock and not dock.Visible then return false end
		if player:GetAttribute("InTraining") or player:GetAttribute("Deploying") then return false end
		return true
	end
	RunService.Heartbeat:Connect(function()
		local on = lobbyShown()
		root.Visible = on
		board.Visible = boardOn
	end)

	task.spawn(function()
		local PlayerData = require(script.Parent.Parent:WaitForChild("Registry"):WaitForChild("PlayerData"))
		local replica = PlayerData:GetMyReplica()
		data = replica.Data
		replica:ListenToRaw(function() refresh() end)
		refresh()
	end)
	task.spawn(function()
		while true do
			resetText()
			refresh()
			refreshBoard()
			task.wait(1)
		end
	end)
end

return LobbyHud
