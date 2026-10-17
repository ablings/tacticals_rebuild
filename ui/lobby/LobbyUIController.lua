-- StarterPlayerScripts/Client/Controllers/LobbyUIController (ModuleScript)
-- The lobby menu: PLAY (matchmaking), LOADOUT, QUESTS, SHOP (items + bundles) and STORE (Robux).
-- Built in code so it's easy to restyle in one place (see THEME). Reads the player's data from the
-- PlayerData replica and re-renders whenever it changes; every action goes to the server through
-- Events.Lobby.Request, which checks it before anything changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LobbyConfig"))

local Icons = require(script:WaitForChild("Icons"))
local Tac = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Tac")) -- pass 34 deployment-board look
local Armory = require(script:WaitForChild("Armory"))
local Style = require(script:WaitForChild("Style"))
-- SHOP: RIVALS-style shop with 3D art (ReplicatedStorage.UIKit.ShopScreen). The old LobbyUIController.Shop is no longer used.
local Shop = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("ShopScreen"))

local player = Players.LocalPlayer
local LobbyUI = {}

-------------------------------------------------------------------------------
-- Theme
-------------------------------------------------------------------------------
-- Colours come from the shared UITheme. Panel / Panel2 / Panel3 / Line are "roles": Style turns them into
-- the floating look (Panel = invisible, Panel2 = frosted glass, Panel3 = brighter glass, Line borders hidden).
local UITheme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("UITheme"))
local UC = UITheme.Colors
local THEME = {
	Panel = Color3.fromRGB(5, 6, 8),
	Panel2 = Color3.fromRGB(8, 9, 11),
	Panel3 = Color3.fromRGB(58, 60, 68),
	Line = Color3.fromRGB(120, 122, 130),
	Text = UC.Text,
	Sub = UC.Sub,
	Accent = UC.Selected,
	Cyan = UC.Primary,
	Good = UC.Go,
	Bad = UC.Danger,
	Robux = UC.Go,
	Title = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
}
-- SCISSORS are the only currency (stored as data.Credits). The icon is a render of the 3D scissors model.
local SCISSOR_ICON = "rbxassetid://120480559804238"
local CREDIT = "" -- (old glyph; prices now read "2,000 scissors" or show SCISSOR_ICON)
local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-------------------------------------------------------------------------------
-- Small UI helpers
-------------------------------------------------------------------------------
local function new(class: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in children or {} do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function stroke(color, thick, trans)
	return new("UIStroke", { Color = color or THEME.Line, Thickness = thick or 1, Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(p) return new("UIPadding", { PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p), PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p) }) end

local function label(props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Font = THEME.Bold, TextColor3 = THEME.Text, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20), TextWrapped = true,
	})
	for k, v in props do l[k] = v end
	return l
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function duration(sec: number): string
	sec = math.max(0, math.floor(sec))
	local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
	if d > 0 then return `{d}d {h}h` end
	if h > 0 then return `{h}h {m}m` end
	return `{m}m {sec % 60}s`
end

-- A button with hover feedback. Style: accent | cyan | dark | ghost | robux | good | disabled
local STYLES = {
	accent = { bg = UC.Go, text = UC.Text },
	cyan = { bg = UC.Primary, text = UC.Text },
	dark = { bg = THEME.Panel3, text = THEME.Text },
	ghost = { bg = THEME.Panel2, text = THEME.Sub },
	robux = { bg = UC.Go, text = UC.Text },
	good = { bg = UC.Go, text = UC.Text },
	disabled = { bg = THEME.Panel2, text = Color3.fromRGB(140, 146, 170) },
}
local function button(props, onClick)
	local style = STYLES[props.Style or "dark"]
	local b = new("TextButton", {
		AutoButtonColor = false, BackgroundColor3 = style.bg, Text = props.Text or "", TextColor3 = style.text,
		Font = THEME.Title, TextSize = props.TextSize or 15, Size = props.Size or UDim2.new(1, 0, 0, 36),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0, Parent = props.Parent,
	}, { corner(2) })
	local base = style.bg
	b.MouseEnter:Connect(function()
		if props.Style ~= "disabled" then TweenService:Create(b, TI, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15) }):Play() end
	end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = base }):Play() end)
	if onClick and props.Style ~= "disabled" then
		b.Activated:Connect(onClick)
	end
	return b
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local Request, QueueState, NotifyEvent
local replica
local data -- replica.Data
local queueSnap = { bays = {}, modes = {}, players = {} }

local gui, root, rail, toastHost, queuePill, creditLabel, levelLabel
local current = nil     -- open panel id
local railButtons = {}
local loadoutSlot = "Weapon"
local shopTab = "Items"
local pendingBuy = nil  -- id of an item/bundle waiting for a second "confirm" click
local uiScaleMul = 1   -- INTERFACE SIZE setting

local function owns(id: string): boolean
	local item = Config.Items[id]
	return item ~= nil and (item.Default or (data and data.Owned and data.Owned[id] == true))
end

-------------------------------------------------------------------------------
-- Toasts
-------------------------------------------------------------------------------
local function toast(text: string, kind: string?)
	-- Settings > Account > Delivery Mode = Disabled: no pop-ups (UI session 2026-10-16)
	if player:GetAttribute("Setting_DeliveryMode") == "Disabled" then return end
	if not toastHost then return end
	local color = kind == "good" and THEME.Good or kind == "bad" and THEME.Bad or THEME.Cyan
	local t = new("Frame", {
		BackgroundColor3 = THEME.Panel2, BackgroundTransparency = 0.3, Size = UDim2.new(0, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.X, Parent = toastHost,
	}, {
		corner(2),
		new("Frame", { BackgroundColor3 = color, Size = UDim2.new(0, 4, 0, 24), Position = UDim2.new(0, -14, 0.5, -12), BorderSizePixel = 0 }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 18) }),
		label({ Text = text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextSize = 16, TextWrapped = false }),
	})
	task.delay(3.2, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			for _, d in t:GetDescendants() do
				if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play() end
				if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play() end
				if d:IsA("Frame") then TweenService:Create(d, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play() end
				if d:IsA("CanvasGroup") then TweenService:Create(d, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play() end
			end
			task.wait(0.32)
			t:Destroy()
		end
	end)
end
LobbyUI.Toast = toast

local function ask(action: string, ...)
	local ok, res = pcall(Request.InvokeServer, Request, action, ...)
	if not ok then
		toast("Couldn't reach the server", "bad")
		return nil
	end
	if res and res.msg then toast(res.msg, res.ok and "good" or "bad") end
	return res
end

-------------------------------------------------------------------------------
-- Panels
-------------------------------------------------------------------------------
local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		c:Destroy()
	end
end

-- placeholder art for an item card (or the image from LobbyConfig.Images)
local function itemArt(parent, itemId, height)
	local item = Config.Items[itemId]
	local rar = Config.Rarities[item.Rarity] or Config.Rarities.Standard
	local art = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, height), ClipsDescendants = true, Parent = parent,
	}, {
		corner(5),
		new("UIGradient", { Rotation = 35, Color = ColorSequence.new(rar.Color:Lerp(Color3.new(0, 0, 0), 0.55), Color3.fromRGB(14, 15, 17)) }),
	})
	local img = Config.Images[itemId]
	if img and img ~= "" then
		new("ImageLabel", { BackgroundTransparency = 1, Image = img, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, Parent = art })
	else
		-- live 3D model of the item (turns toward you on hover)
		local model, view, zoom = Icons.Item(itemId)
		local icon = Icons.Viewport(art, model, { view = view, zoom = zoom })
		art.MouseEnter:Connect(function() icon.SetHover(true) end)
		art.MouseLeave:Connect(function() icon.SetHover(false) end)
	end
	new("Frame", { BackgroundColor3 = rar.Color, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), Parent = art })
	return art
end

local function priceText(n: number) return `{commas(n)} scissors` end
local function scissorIcon(props)
	local i = new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSOR_ICON, ScaleType = Enum.ScaleType.Fit })
	for k, v in props do if k ~= "Parent" then i[k] = v end end
	i.Parent = props.Parent
	return i
end
LobbyUI.ScissorIcon = SCISSOR_ICON

---------------------------------------------------------------- PLAY
-- The cards are ONLINE queues: every lobby server shares them (MatchmakingManager), so you're matched
-- with anyone searching anywhere. The pads in the Deployment wing are this lobby's own queues.
-- Every queue is separate: 1v1 / 2v2 / 3v3, casual and ranked (ranked opens at Config.RankedLevel).
local playTab = "Casual" -- Casual | Ranked
local PC = { -- the KIT screen's navy + grey palette
	Card = Color3.fromRGB(20, 23, 20), Row = Color3.fromRGB(32, 36, 30), Line = Color3.fromRGB(64, 70, 58),
	Hi = Color3.fromRGB(74, 80, 64), HiLine = Color3.fromRGB(226, 222, 208), Sub = Color3.fromRGB(150, 156, 140),
	Dim = Color3.fromRGB(100, 106, 92), Ranked = Color3.fromRGB(176, 120, 255), Found = Color3.fromRGB(110, 226, 140),
}

local function mmCounts(): { [string]: number }
	local raw = ReplicatedStorage:GetAttribute("MM_Counts")
	local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(raw or "{}") end)
	return (ok and type(t) == "table") and t or {}
end

local function clockText(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function accountLevel(): (number, number, number)
	return Config.AccountLevel((data and data.XP) or 0)
end

local function rankedOpen(): boolean
	return Config.CanPlayRanked((data and data.XP) or 0, RunService:IsStudio())
end

-- what you're searching for online right now (nil when you aren't)
local function onlineSearch()
	local q = player:GetAttribute("MM_Queue")
	local status = player:GetAttribute("MM_Status")
	if not (q and status) then return nil end
	return Config.QueueById(q), status, player:GetAttribute("MM_Since") or workspace:GetServerTimeNow()
end

local function playButton(parent, text: string, kind: string, onClick)
	-- kind: go (grey highlight) | off (dimmed) | cancel | found
	local colors = {
		go = { PC.Hi, PC.HiLine, 0.25, THEME.Text }, off = { PC.Row, PC.Line, 0.3, PC.Dim },
		cancel = { PC.Row, PC.HiLine, 0.2, THEME.Text }, found = { PC.Found:Lerp(PC.Card, 0.55), PC.Found, 0.1, THEME.Text },
	}
	local c = colors[kind] or colors.go
	local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = c[1], BackgroundTransparency = c[3],
		Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48), Parent = parent }, { corner(12), stroke(c[2], kind == "go" and 1.5 or 1, kind == "off" and 0.5 or 0) })
	local l = label({ Text = text, Font = THEME.Title, TextSize = 16, TextColor3 = c[4], TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), Parent = b })
	if onClick and kind ~= "off" and kind ~= "found" then
		b.MouseEnter:Connect(function() TweenService:Create(b, TI, { BackgroundTransparency = math.max(0, c[3] - 0.15) }):Play() end)
		b.MouseLeave:Connect(function() TweenService:Create(b, TI, { BackgroundTransparency = c[3] }):Play() end)
		b.Activated:Connect(onClick)
	end
	return b, l
end

local function tabButton(parent, text: string, on: boolean, accent: Color3, x: number, onClick)
	local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = on and PC.Hi or PC.Row, BackgroundTransparency = on and 0.3 or 0.35,
		Size = UDim2.new(0, 176, 0, 40), Position = UDim2.new(0, x, 0, 0), Parent = parent }, { corner(10), stroke(on and accent or PC.Line, on and 1.5 or 1, on and 0 or 0.5) })
	local l = label({ Text = text, Font = THEME.Title, TextSize = 15, TextColor3 = on and THEME.Text or PC.Sub, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), Parent = b })
	b.Activated:Connect(onClick)
	return b, l
end

local function renderPlay(body)
	-- Pass 33: the PLAY screen as a TACTICALS deployment board (our own look; RIVALS was only a reference for
	-- "big art, few words, ranked visibly locked"). Row 1: three mission cards (1v1 / 2v2 / 3v3, click = deploy / cancel).
	-- Row 2: TRAINING banner + RANKED clearance banner (locked until Config.RankedLevel). Art: Config.PlayArt (Codex).
	clear(body)
	local counts = mmCounts()
	local myQ, myStatus = onlineSearch()
	local onPad = queueSnap.players and queueSnap.players[tostring(player.UserId)]
	local open = rankedOpen()
	if not open then playTab = "Casual" end
	local ranked = playTab == "Ranked"
	local level, into, need = accountLevel()
	local ART = Config.PlayArt or {}
	local OLIVE, BONE, GUN = Color3.fromRGB(107, 122, 58), Color3.fromRGB(236, 232, 218), Color3.fromRGB(26, 29, 26)
	local VIOLET = PC.Ranked
	local accentNow = ranked and VIOLET or OLIVE

	-- tactical corner brackets instead of a full outline
	local function brackets(p, color, len, z)
		local th = 2
		for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			local ax = Vector2.new(c[1], c[2])
			new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = ax, Position = UDim2.fromScale(c[1], c[2]),
				Size = UDim2.fromOffset(len, th), ZIndex = z or 5, Parent = p })
			new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = ax, Position = UDim2.fromScale(c[1], c[2]),
				Size = UDim2.fromOffset(th, len), ZIndex = z or 5, Parent = p })
		end
	end
	local function shade(p, from, to, rot)
		new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = p }, {
			new("UIGradient", { Rotation = rot or 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) }) }) })
	end
	local function hover(b, br)
		b.MouseEnter:Connect(function() for _, f in br do TweenService:Create(f, TI, { BackgroundColor3 = BONE }):Play() end end)
		b.MouseLeave:Connect(function() for _, f in br do TweenService:Create(f, TI, { BackgroundColor3 = f:GetAttribute("Base") }):Play() end end)
	end
	local function bracketFrames(p) local t = {} for _, f in p:GetChildren() do if f:GetAttribute("Base") then table.insert(t, f) end end return t end
	local function tagBase(p, color) for _, f in p:GetChildren() do if f:IsA("Frame") and f.ZIndex == 5 then f:SetAttribute("Base", color) end end end

	-- header: DEPLOY + operator level tag
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = body })
	new("Frame", { BackgroundColor3 = accentNow, BorderSizePixel = 0, Size = UDim2.new(0, 6, 0, 28), Position = UDim2.new(0, 0, 0.5, -14), Parent = top })
	label({ Text = ranked and "DEPLOY  //  RANKED" or "DEPLOY", Font = THEME.Title, TextSize = 28, TextColor3 = ranked and VIOLET or BONE,
		Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 16, 0, 0), Parent = top })
	local tag = new("Frame", { BackgroundColor3 = GUN, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 250, 0, 32), Parent = top }, { corner(4) })
	label({ Text = `OPERATOR  LV {level}`, Font = THEME.Title, TextSize = 14, Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = tag })
	local xb = new("Frame", { BackgroundColor3 = PC.Row, BorderSizePixel = 0, Size = UDim2.new(1, -140, 0, 6), Position = UDim2.new(0, 130, 0.5, -3), Parent = tag })
	new("Frame", { BackgroundColor3 = OLIVE, BorderSizePixel = 0, Size = UDim2.new(math.clamp(into / math.max(need, 1), 0.02, 1), 0, 1, 0), Parent = xb })

	-- row 1: mission cards
	local CARD_H = 236
	local cards = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, CARD_H), Position = UDim2.new(0, 0, 0, 48), Parent = body }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, mode in Config.Modes do
		local q = Config.QueueFor(mode.Id, ranked)
		local mine = myQ ~= nil and q ~= nil and myQ.Id == q.Id
		local b = new("ImageButton", { AutoButtonColor = false, Image = ART[mode.Id] or "", ScaleType = Enum.ScaleType.Crop, BackgroundColor3 = GUN,
			Size = UDim2.new(1 / 3, -8, 1, 0), LayoutOrder = i, ClipsDescendants = true, Parent = cards })
		shade(b, 0.85, 0.05)
		label({ Text = string.format("OP-%02d", i), Font = THEME.Bold, TextSize = 11, TextColor3 = BONE, Size = UDim2.new(0, 60, 0, 14),
			Position = UDim2.new(0, 12, 0, 10), ZIndex = 4, Parent = b })
		if ranked then
			label({ Text = "RANKED", Font = THEME.Title, TextSize = 12, TextColor3 = VIOLET, TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(0, 80, 0, 14), Position = UDim2.new(1, -92, 0, 10), ZIndex = 4, Parent = b })
		end
		-- bottom plate: big mode name, pips, status strip
		local plate = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 92), Position = UDim2.new(0, 12, 1, -100), ZIndex = 4, Parent = b })
		local title = label({ Text = mode.Name, Font = THEME.Title, TextSize = 48, Size = UDim2.new(1, 0, 0, 48), ZIndex = 4, Parent = plate })
		new("UIStroke", { Color = Color3.fromRGB(8, 10, 8), Thickness = 2, Parent = title })
		local pips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 2, 0, 52), ZIndex = 4, Parent = plate }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for t = 1, mode.TeamSize do new("Frame", { BackgroundColor3 = BONE, BorderSizePixel = 0, Size = UDim2.new(0, 10, 0, 10), LayoutOrder = t, ZIndex = 4, Parent = pips }) end
		label({ Text = "VS", Font = THEME.Title, TextSize = 10, TextColor3 = PC.Sub, Size = UDim2.new(0, 20, 0, 12), TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 10, ZIndex = 4, Parent = pips })
		for t = 1, mode.TeamSize do new("Frame", { BackgroundColor3 = PC.Dim, BorderSizePixel = 0, Size = UDim2.new(0, 10, 0, 10), LayoutOrder = 20 + t, ZIndex = 4, Parent = pips }) end
		local strip = new("Frame", { BackgroundColor3 = accentNow, BackgroundTransparency = 0.15, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 0, 1, -22), ZIndex = 4, Parent = plate })
		local status = label({ Text = "", Font = THEME.Title, TextSize = 13, TextColor3 = BONE, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
			ZIndex = 5, Parent = strip })
		local n = q and counts[q.Id] or 0
		local right = label({ Text = `{n} SEARCHING`, Font = THEME.Bold, TextSize = 11, TextColor3 = BONE, TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0), ZIndex = 5, Parent = strip })
		if ranked then
			right.Text = `{n} SEARCHING  ·  ` .. (function()
				local placed, need = player:GetAttribute("RankPlaced") or 0, player:GetAttribute("RankPlacements") or 0
				if need > 0 and placed < need then return "Placements " .. placed .. "/" .. need end
				return (player:GetAttribute("RankName") or "Bronze 1") .. "  " .. tostring(player:GetAttribute("RankElo") or 100) .. " ELO"
			end)()
		end
		brackets(b, mine and BONE or (ranked and VIOLET or PC.Line), 18); tagBase(b, mine and BONE or (ranked and VIOLET or PC.Line))
		if mine and myStatus == "Searching" then
			status.Text = "CANCEL  ·  " .. clockText(workspace:GetServerTimeNow() - (player:GetAttribute("MM_Since") or workspace:GetServerTimeNow()))
			status:SetAttribute("SearchTimer", true); right.Text = ""
			b.Activated:Connect(function() ask("CancelMatch") end)
		elseif mine then
			status.Text = "MATCH FOUND  ·  DEPLOYING"; strip.BackgroundColor3 = PC.Found:Lerp(GUN, 0.3); right.Text = ""
		elseif myQ or onPad then
			b.ImageTransparency = 0.55; title.TextTransparency = 0.4; strip.BackgroundColor3 = PC.Row
			status.Text = myQ and ("SEARCHING " .. string.upper(myQ.Mode)) or "ON A LOBBY PAD"
		else
			status.Text = "DEPLOY  >"
			b.Activated:Connect(function()
				local r = ask("FindMatch", q.Id)
				if r and r.ok then LobbyUI.Close() end
			end)
			hover(b, bracketFrames(b))
		end
	end

	-- row 2: training + ranked clearance banners
	local BAN_H = 104
	local row2 = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, BAN_H), Position = UDim2.new(0, 0, 0, 48 + CARD_H + 12), Parent = body })
	local function banner(x, art)
		local b = new("ImageButton", { AutoButtonColor = false, Image = art or "", ScaleType = Enum.ScaleType.Crop, BackgroundColor3 = GUN,
			Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), ClipsDescendants = true, Parent = row2 })
		shade(b, 0.05, 0.9, 0)
		return b
	end
	-- TRAINING
	local quick = player.PlayerGui:FindFirstChild("ExfilFade") and player.PlayerGui.ExfilFade:FindFirstChild("QuickEnter")
	local tb = banner(0, ART.Training)
	local tt = label({ Text = "TRAINING", Font = THEME.Title, TextSize = 34, Size = UDim2.new(0.7, 0, 0, 38), Position = UDim2.new(0, 18, 0, 16), ZIndex = 4, Parent = tb })
	new("UIStroke", { Color = Color3.fromRGB(8, 10, 8), Thickness = 2, Parent = tt })
	label({ Text = "Practice room  ·  cover, vaults, live targets  ·  up to 10 operators", Font = THEME.Body, TextSize = 13, TextColor3 = PC.HiLine,
		Size = UDim2.new(0.8, 0, 0, 18), Position = UDim2.new(0, 18, 0, 56), ZIndex = 4, Parent = tb })
	label({ Text = myQ and "UNAVAILABLE WHILE SEARCHING" or "ENTER  >", Font = THEME.Title, TextSize = 13, TextColor3 = OLIVE:Lerp(BONE, 0.4),
		Size = UDim2.new(0.8, 0, 0, 16), Position = UDim2.new(0, 18, 1, -26), ZIndex = 4, Parent = tb })
	brackets(tb, PC.Line, 16); tagBase(tb, PC.Line)
	if not myQ then
		hover(tb, bracketFrames(tb))
		tb.Activated:Connect(function() LobbyUI.Close(); if quick then quick:Fire() end end)
	end
	-- RANKED
	local rb = banner(0.5, open and ART.Ranked or nil)
	local rt = label({ Text = "RANKED", Font = THEME.Title, TextSize = 34, TextColor3 = VIOLET, Size = UDim2.new(0.7, 0, 0, 38), Position = UDim2.new(0, 18, 0, 16),
		ZIndex = 4, Parent = rb })
	new("UIStroke", { Color = Color3.fromRGB(8, 10, 8), Thickness = 2, Parent = rt })
	if open then
		label({ Text = "Rated duels  ·  win to climb, lose and you drop", Font = THEME.Body, TextSize = 13, TextColor3 = PC.HiLine,
			Size = UDim2.new(0.8, 0, 0, 18), Position = UDim2.new(0, 18, 0, 56), ZIndex = 4, Parent = rb })
		label({ Text = ranked and "BACK TO CASUAL  >" or "SHOW RANKED QUEUES  >", Font = THEME.Title, TextSize = 13, TextColor3 = VIOLET,
			Size = UDim2.new(0.8, 0, 0, 16), Position = UDim2.new(0, 18, 1, -26), ZIndex = 4, Parent = rb })
		brackets(rb, VIOLET, 16); tagBase(rb, VIOLET); hover(rb, bracketFrames(rb))
		rb.Activated:Connect(function() playTab = ranked and "Casual" or "Ranked"; LobbyUI.Refresh() end)
	else
		rb.BackgroundColor3 = Color3.fromRGB(8, 9, 8)
		label({ Text = "CLEARANCE REQUIRED", Font = THEME.Title, TextSize = 13, TextColor3 = PC.Sub, Size = UDim2.new(0.6, 0, 0, 16),
			Position = UDim2.new(0, 18, 0, 58), ZIndex = 4, Parent = rb })
		local lock = Armory.LockIcon(rb, 44, VIOLET)
		lock.AnchorPoint = Vector2.new(1, 0.5); lock.Position = UDim2.new(1, -22, 0.5, 0)
		for _, d in lock:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex += 4 end end
		label({ Text = `UNLOCKS AT LEVEL {Config.RankedLevel}  ·  YOU ARE LV {level}`, Font = THEME.Title, TextSize = 12, TextColor3 = BONE,
			Size = UDim2.new(0.75, 0, 0, 16), Position = UDim2.new(0, 18, 1, -34), ZIndex = 4, Parent = rb })
		local bar = new("Frame", { BackgroundColor3 = PC.Row, BorderSizePixel = 0, Size = UDim2.new(0.7, -18, 0, 5), Position = UDim2.new(0, 18, 1, -14), ZIndex = 4, Parent = rb })
		new("Frame", { BackgroundColor3 = VIOLET, BorderSizePixel = 0, Size = UDim2.new(math.clamp(level / Config.RankedLevel, 0.02, 1), 0, 1, 0), ZIndex = 4, Parent = bar })
		brackets(rb, PC.Line, 16)
	end

	label({ Text = "Rather play people in this lobby? Walk onto a pad in the DUELS wing.", Font = THEME.Body, TextSize = 13, TextColor3 = PC.Sub,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 48 + CARD_H + 12 + BAN_H + 12), Parent = body })
end

---------------------------------------------------------------- LOADOUT
local function renderLoadout(body)
	clear(body)
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 220, 1, 0), Parent = body }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, slot in Config.Slots do
		local id = data.Loadout[slot] or Config.DefaultLoadout[slot]
		if not Config.Items[id] then id = Config.DefaultLoadout[slot] end
		local selected = slot == loadoutSlot
		local tile = new("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundColor3 = selected and THEME.Panel3 or THEME.Panel2,
			Size = UDim2.new(1, 0, 0, 120), LayoutOrder = i, Parent = left,
		}, { corner(8), stroke(selected and THEME.Accent or THEME.Line, selected and 2 or 1), pad(10) })
		label({ Text = Config.SlotNames[slot], Font = THEME.Title, TextSize = 12, TextColor3 = selected and THEME.Accent or THEME.Sub, Size = UDim2.new(1, 0, 0, 14), Parent = tile })
		local art = itemArt(tile, id, 60)
		art.Position = UDim2.new(0, 0, 0, 20)
		label({ Text = Config.Items[id].Name, TextSize = 14, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), Parent = tile })
		tile.Activated:Connect(function()
			loadoutSlot = slot
			pendingBuy = nil
			LobbyUI.Refresh()
		end)
	end

	local right = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -236, 1, 0), Position = UDim2.new(0, 236, 0, 0),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = body,
	}, {
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
		new("UIGridLayout", { CellSize = UDim2.new(0, 168, 0, 214), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local ids = {}
	for id, item in Config.Items do
		if item.Slot == loadoutSlot then table.insert(ids, id) end
	end
	table.sort(ids, function(a, b)
		local ia, ib = Config.Items[a], Config.Items[b]
		if ia.Price ~= ib.Price then return ia.Price < ib.Price end
		return a < b
	end)
	for i, id in ids do
		local item = Config.Items[id]
		local equipped = data.Loadout[loadoutSlot] == id
		local have = owns(id)
		local card = new("Frame", { BackgroundColor3 = THEME.Panel2, LayoutOrder = i, Parent = right }, {
			corner(8), stroke(equipped and THEME.Accent or THEME.Line, equipped and 2 or 1), pad(8),
		})
		itemArt(card, id, 92)
		label({ Text = item.Name, Font = THEME.Title, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 98), Parent = card })
		label({ Text = item.Desc, Font = THEME.Body, TextSize = 12, TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.new(0, 0, 0, 118), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		local bPos, bSize = UDim2.new(0, 0, 1, -32), UDim2.new(1, 0, 0, 32)
		if equipped then
			button({ Text = "EQUIPPED", Style = "disabled", Size = bSize, Position = bPos, Parent = card })
		elseif have then
			button({ Text = "EQUIP", Style = "accent", Size = bSize, Position = bPos, Parent = card }, function()
				ask("Equip", loadoutSlot, id)
			end)
		else
			local confirm = pendingBuy == id
			local afford = (data.Credits or 0) >= item.Price
			button({ Text = confirm and `CONFIRM {priceText(item.Price)}` or priceText(item.Price),
				Style = (not afford and "disabled") or (confirm and "good" or "dark"), Size = bSize, Position = bPos, Parent = card }, function()
				if pendingBuy ~= id then
					pendingBuy = id
					LobbyUI.Refresh()
					return
				end
				pendingBuy = nil
				local r = ask("BuyItem", id)
				if r and r.ok then ask("Equip", loadoutSlot, id) end
			end)
		end
	end
end

---------------------------------------------------------------- QUESTS
local function questDef(scope, id)
	for _, q in Config.Quests[scope].Pool do
		if q.Id == id then return q end
	end
end

local function resetIn(scope: string): number
	local t = os.time()
	if scope == "Daily" then return 86400 - t % 86400 end
	local day = math.floor(t / 86400)
	local weekday = (day + 3) % 7 -- 0 = Monday
	return (7 - weekday) * 86400 - t % 86400
end

local function renderQuests(body)
	clear(body)
	for col, scope in { "Daily", "Weekly" } do
		local column = new("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(0.5, -8, 1, -26), Position = UDim2.new(col == 1 and 0 or 0.5, col == 1 and 0 or 8, 0, 0), Parent = body,
		}, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local head = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, Parent = column })
		label({ Text = string.upper(scope), Font = THEME.Title, TextSize = 20, Size = UDim2.new(0.5, 0, 1, 0), Parent = head })
		local timer = label({ Text = "", Font = THEME.Bold, TextSize = 13, TextColor3 = THEME.Sub, Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = head })
		timer:SetAttribute("ResetScope", scope)
		timer.Text = "RESETS IN " .. duration(resetIn(scope))

		local q = data.Quests and data.Quests[scope]
		for i, entry in (q and q.List) or {} do
			local def = questDef(scope, entry.Id)
			if not def then continue end
			local prog = math.clamp(((data.Stats and data.Stats[def.Stat]) or 0) - entry.Base, 0, def.Goal)
			local done = prog >= def.Goal
			local ready = done and not entry.Claimed
			local card = new("Frame", { BackgroundColor3 = THEME.Panel2, Size = UDim2.new(1, 0, 0, 100), LayoutOrder = i, Parent = column }, {
				corner(8), stroke(ready and THEME.Good or THEME.Line, ready and 2 or 1), pad(12),
			})
			label({ Text = def.Text, Font = THEME.Bold, TextSize = 15, Size = UDim2.new(1, -110, 0, 20), TextTransparency = entry.Claimed and 0.5 or 0, Parent = card })
			label({ Text = `+{def.Reward}`, Font = THEME.Title, TextSize = 15, TextColor3 = THEME.Accent, Size = UDim2.new(0, 76, 0, 20),
				Position = UDim2.new(1, -100, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
			scissorIcon({ Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -22, 0, -1), Parent = card })
			local bar = new("Frame", { BackgroundColor3 = THEME.Panel3, Size = UDim2.new(1, -110, 0, 10), Position = UDim2.new(0, 0, 0, 38), Parent = card }, { corner(5) })
			new("Frame", { BackgroundColor3 = done and THEME.Good or THEME.Cyan, Size = UDim2.new(prog / def.Goal, 0, 1, 0), Parent = bar }, { corner(5) })
			label({ Text = `{prog} / {def.Goal}`, Font = THEME.Bold, TextSize = 13, TextColor3 = THEME.Sub, Size = UDim2.new(0, 100, 0, 16),
				Position = UDim2.new(0, 0, 0, 54), Parent = card })
			local bSize, bPos = UDim2.new(0, 100, 0, 34), UDim2.new(1, -100, 1, -34)
			if entry.Claimed then
				button({ Text = "CLAIMED", Style = "disabled", Size = bSize, Position = bPos, Parent = card })
			elseif done then
				button({ Text = "CLAIM", Style = "good", Size = bSize, Position = bPos, Parent = card }, function()
					ask("ClaimQuest", scope, i)
				end)
			else
				button({ Text = "IN PROGRESS", Style = "disabled", TextSize = 12, Size = bSize, Position = bPos, Parent = card })
			end
		end
		if not (q and q.List and #q.List > 0) then
			label({ Text = "Loading quests...", TextColor3 = THEME.Sub, LayoutOrder = 1, Parent = column })
		end
	end
	label({ Text = "Quest progress comes from matches. Finish one, come back here and claim it.", Font = THEME.Body, TextSize = 13,
		TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), Parent = body })
end

local function claimableCount(): number
	local n = 0
	if not data or not data.Quests then return 0 end
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests[scope]
		for _, e in (q and q.List) or {} do
			local def = questDef(scope, e.Id)
			if def and not e.Claimed and ((data.Stats[def.Stat] or 0) - e.Base) >= def.Goal then n += 1 end
		end
	end
	return n
end

---------------------------------------------------------------- SHOP (credits)
local function renderShop(body)
	clear(body)
	local tabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = body }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, t in { "Items", "Bundles", "Robux" } do
		button({ Text = t == "Robux" and "R$  ROBUX" or string.upper(t), Style = shopTab == t and (t == "Robux" and "robux" or "accent") or "ghost",
			Size = UDim2.new(0, 130, 1, 0), LayoutOrder = i, Parent = tabs }, function()
			shopTab = t
			pendingBuy = nil
			LobbyUI.Refresh()
		end)
	end
	if shopTab == "Robux" then
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -46), Position = UDim2.new(0, 0, 0, 46), Parent = body })
		LobbyUI.RenderStore(holder)
		return
	end
	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -46), Position = UDim2.new(0, 0, 0, 46),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = body,
	}, { new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }) })

	if shopTab == "Items" then
		new("UIGridLayout", { CellSize = UDim2.new(0, 156, 0, 196), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		local ids = {}
		for id, item in Config.Items do
			if not item.Default then table.insert(ids, id) end
		end
		table.sort(ids, function(a, b)
			local ra, rb = Config.Rarities[Config.Items[a].Rarity].Order, Config.Rarities[Config.Items[b].Rarity].Order
			if ra ~= rb then return ra > rb end
			return Config.Items[a].Price > Config.Items[b].Price
		end)
		for i, id in ids do
			local item = Config.Items[id]
			local card = new("Frame", { BackgroundColor3 = THEME.Panel2, LayoutOrder = i, Parent = list }, { corner(8), stroke(THEME.Line, 1), pad(8) })
			itemArt(card, id, 96)
			label({ Text = item.Name, Font = THEME.Title, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 102), Parent = card })
			label({ Text = `{string.upper(item.Rarity)} {Config.SlotNames[item.Slot]}`, Font = THEME.Bold, TextSize = 11,
				TextColor3 = Config.Rarities[item.Rarity].Color, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 122), Parent = card })
			local bSize, bPos = UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 1, -32)
			if owns(id) then
				button({ Text = "OWNED", Style = "disabled", Size = bSize, Position = bPos, Parent = card })
			else
				local confirm = pendingBuy == id
				local afford = (data.Credits or 0) >= item.Price
				button({ Text = confirm and "CONFIRM" or priceText(item.Price), Style = (not afford and "disabled") or (confirm and "good" or "accent"),
					Size = bSize, Position = bPos, Parent = card }, function()
					if pendingBuy ~= id then pendingBuy = id LobbyUI.Refresh() return end
					pendingBuy = nil
					ask("BuyItem", id)
				end)
			end
		end
	else
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		for i, bundle in Config.Bundles do
			local cost, missing = Config.BundleCost(bundle, owns)
			local full = 0
			for _, id in bundle.Items do full += Config.Items[id].Price end
			local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -8, 0, 130), LayoutOrder = i, Parent = list }, {
				corner(8), stroke(bundle.Color, 1.5), pad(12),
				new("UIGradient", { Rotation = 0, Color = ColorSequence.new(bundle.Color:Lerp(THEME.Panel2, 0.78), THEME.Panel2) }),
			})
			label({ Text = bundle.Name, Font = THEME.Title, TextSize = 24, Size = UDim2.new(0.6, 0, 0, 28), Parent = card })
			if bundle.Tag then
				new("TextLabel", { Text = bundle.Tag, Font = THEME.Title, TextSize = 12, TextColor3 = Color3.fromRGB(20, 16, 10), BackgroundColor3 = THEME.Accent,
					Size = UDim2.new(0, 80, 0, 20), Position = UDim2.new(0, 0, 0, 32), Parent = card }, { corner(4) })
			end
			local chips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.62, 0, 0, 52), Position = UDim2.new(0, 0, 1, -52), Parent = card }, {
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for j, id in bundle.Items do
				local have = owns(id)
				local chip = new("Frame", { BackgroundColor3 = THEME.Panel3, Size = UDim2.new(0, 124, 1, 0), LayoutOrder = j, Parent = chips }, { corner(6), pad(6) })
				label({ Text = Config.Items[id].Name, Font = THEME.Bold, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), Parent = chip })
				label({ Text = have and "OWNED" or Config.SlotNames[Config.Items[id].Slot], Font = THEME.Bold, TextSize = 11,
					TextColor3 = have and THEME.Good or THEME.Sub, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 20), Parent = chip })
			end
			if full > cost and missing > 0 then
				local was = label({ Text = priceText(full), Font = THEME.Bold, TextSize = 14, TextColor3 = THEME.Sub, Size = UDim2.new(0, 170, 0, 18),
					Position = UDim2.new(1, -170, 0, 8), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
				new("Frame", { BackgroundColor3 = THEME.Sub, BorderSizePixel = 0, Size = UDim2.new(0, 70, 0, 2), Position = UDim2.new(0.5, -35, 0.5, -1), Parent = was })
			end
			local bSize, bPos = UDim2.new(0, 170, 0, 40), UDim2.new(1, -170, 1, -40)
			if missing == 0 then
				button({ Text = "OWNED", Style = "disabled", Size = bSize, Position = bPos, Parent = card })
			else
				local key = "bundle:" .. bundle.Id
				local confirm = pendingBuy == key
				button({ Text = confirm and "CONFIRM" or priceText(cost), Style = ((data.Credits or 0) < cost and "disabled") or (confirm and "good" or "accent"),
					Size = bSize, Position = bPos, Parent = card }, function()
					if pendingBuy ~= key then pendingBuy = key LobbyUI.Refresh() return end
					pendingBuy = nil
					ask("BuyBundle", bundle.Id)
				end)
			end
		end
	end
end

---------------------------------------------------------------- STORE (Robux)
local function renderStore(body)
	clear(body)
	label({ Text = "SCISSORS", Font = THEME.Title, TextSize = 16, TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 18), Parent = body })
	local packs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.new(0, 0, 0, 24), Parent = body }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local bundleRow
	for i, p in Config.RobuxProducts do
		if p.Bundle then bundleRow = p continue end
		local card = new("Frame", { BackgroundColor3 = THEME.Panel2, Size = UDim2.new(0.25, -8, 1, 0), LayoutOrder = i, Parent = packs }, {
			corner(8), stroke(THEME.Line, 1), pad(10),
		})
		if p.Tag then
			new("TextLabel", { Text = p.Tag, Font = THEME.Title, TextSize = 11, TextColor3 = Color3.fromRGB(20, 16, 10), BackgroundColor3 = THEME.Accent,
				Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Parent = card },
				{ corner(4), new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
		end
		label({ Text = p.Name, Font = THEME.Title, TextSize = 13, TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 16), Parent = card })
		label({ Text = `{commas(p.Credits)} scissors`, Font = THEME.Title, TextSize = 26, TextColor3 = THEME.Accent, Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.new(0, 0, 0, 34), Parent = card })
		button({ Text = `R$ {p.Robux}`, Style = "robux", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -36), Parent = card }, function()
			ask("BuyRobux", p.Key)
		end)
	end

	if bundleRow then
		local p = bundleRow
		local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0, 186), Parent = body }, {
			corner(8), stroke(THEME.Accent, 1.5), pad(12),
			new("UIGradient", { Color = ColorSequence.new(THEME.Accent:Lerp(THEME.Panel2, 0.8), THEME.Panel2) }),
		})
		label({ Text = p.Name, Font = THEME.Title, TextSize = 22, Size = UDim2.new(0.7, 0, 0, 26), Parent = card })
		local names = {}
		local ownedAll = true
		for _, id in p.Items or {} do
			table.insert(names, Config.Items[id].Name)
			if not owns(id) then ownedAll = false end
		end
		label({ Text = table.concat(names, "  ·  ") .. `  ·  {commas(p.Credits)} scissors`, Font = THEME.Bold, TextSize = 14, TextColor3 = THEME.Sub,
			Size = UDim2.new(0.7, 0, 0, 18), Position = UDim2.new(0, 0, 0, 32), Parent = card })
		if p.Tag then label({ Text = p.Tag, Font = THEME.Title, TextSize = 12, TextColor3 = THEME.Accent, Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), Parent = card }) end
		button({ Text = ownedAll and "OWNED" or `R$ {p.Robux}`, Style = ownedAll and "disabled" or "robux", Size = UDim2.new(0, 170, 0, 40),
			Position = UDim2.new(1, -170, 0.5, -20), Parent = card }, function() ask("BuyRobux", p.Key) end)
	end

	label({ Text = "GAME PASSES", Font = THEME.Title, TextSize = 16, TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 292), Parent = body })
	local passes = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 110), Position = UDim2.new(0, 0, 0, 316), Parent = body }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, p in Config.GamePasses do
		local have = data.Passes and data.Passes[p.Key]
		local card = new("Frame", { BackgroundColor3 = THEME.Panel2, Size = UDim2.new(0.5, -5, 1, 0), LayoutOrder = i, Parent = passes }, {
			corner(8), stroke(have and THEME.Good or THEME.Line, 1), pad(12),
		})
		label({ Text = p.Name, Font = THEME.Title, TextSize = 22, Size = UDim2.new(1, -150, 0, 26), Parent = card })
		label({ Text = p.Desc, Font = THEME.Body, TextSize = 13, TextColor3 = THEME.Sub, Size = UDim2.new(1, -150, 0, 44), Position = UDim2.new(0, 0, 0, 30),
			TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		button({ Text = have and "OWNED" or `R$ {p.Robux}`, Style = have and "disabled" or "robux", Size = UDim2.new(0, 136, 0, 40),
			Position = UDim2.new(1, -136, 0.5, -20), Parent = card }, function() ask("BuyPass", p.Key) end)
	end
end

LobbyUI.RenderStore = renderStore

---------------------------------------------------------------- SETTINGS
-- The SETTINGS screen is its own full-screen menu (ReplicatedStorage.UIKit.SettingsScreen, RIVALS-style,
-- ported from rivals_practice). It saves to the profile (data.Settings) through "SaveSettings";
-- Shared/Config/SettingsConfig applies the values here and in every other place.
local SettingsConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SettingsConfig"))
local SettingsScreen = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("SettingsScreen"))
local rescaleUI -- set in build()

-- the few settings the lobby itself reads (the Shop's hover mode wants its option number)
local localSettings = setmetatable({}, { __index = function(_, k)
	if k == "ShopHover" then -- "Spotlight" | "Off"
		return SettingsConfig.Get(data and data.Settings, "Game", "Shop Hover")
	end
	return nil
end })

local function applySettings()
	SettingsConfig.Apply(data and data.Settings, player)
end

-- (2026-10-17) the touch controls' Layout Editor saves into Settings > Touch (Touch Layout <slot> / Touch Layout Slot)
local touchControlsMod
local function touchControls()
	if touchControlsMod == nil then
		touchControlsMod = false
		pcall(function() touchControlsMod = require(script.Parent:WaitForChild("TouchControlsController", 5)) end)
		if touchControlsMod then
			local function write(key, value)
				local s = SettingsConfig.Sanitize(data and data.Settings)
				s.Profiles[s.Active].Touch = s.Profiles[s.Active].Touch or {}
				s.Profiles[s.Active].Touch[key] = value
				s.Version = 2
				pcall(Request.InvokeServer, Request, "SaveSettings", s)
			end
			touchControlsMod.OnSave = function(slot, json) write("Touch Layout " .. slot, json) end
			touchControlsMod.OnSlot = function(slot) write("Touch Layout Slot", slot) end
		end
	end
	return touchControlsMod or nil
end
local settingsReady = false
local function openSettings(initOnly)
	if not settingsReady then
		settingsReady = true
		SettingsScreen.Init({
			getSettings = function() return data and data.Settings end,
			save = function(s)
				if type(s) == "table" then s.Version = 2 end -- already in Tacticals' hotkey layout (SettingsConfig.Sanitize)
				pcall(Request.InvokeServer, Request, "SaveSettings", s)
			end,
			-- (2026-10-17) Touch > Layout Editor: close Settings, open the drag/resize editor over the touch buttons
			onAction = function(key)
				if key == "Layout Editor" then
					local tc = touchControls()
					if tc and tc.OpenEditor then SettingsScreen.Close(); tc.OpenEditor() end
				end
			end,
			onOpen = function() if gui then gui.Enabled = false end end,
			onClose = function() if gui then gui.Enabled = true end end,
		})
	end
	if initOnly then return end
	if SettingsScreen.IsOpen() then SettingsScreen.Close() else SettingsScreen.Open() end
end
LobbyUI.OpenSettings = openSettings

---------------------------------------------------------------- MISSIONS
-- Full-screen RIVALS-style Tasks layout (ReplicatedStorage.UIKit.MissionsScreen) over the real quests.
local MissionsScreen = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("MissionsScreen"))
local PlayScreen = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("PlayScreen"))
local CodesScreen = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("CodesScreen"))
local codesReady = false
local function openCodes(initOnly)
	if not codesReady then
		codesReady = true
		CodesScreen.Init({
			ask = function(action, ...) local ok, r = pcall(Request.InvokeServer, Request, action, ...) return ok and r end,
			getData = function() return data end,
			onOpen = function() if gui then gui.Enabled = false end end,
			onClose = function() if gui then gui.Enabled = true end end,
		})
	end
	if initOnly then return end
	if CodesScreen.IsOpen() then CodesScreen.Close() else CodesScreen.Open() end
end
-- RANKED (2026-10-17): its own full-screen page (UIKit.RankedScreen), opened from PLAY's Ranked tile
local RankedScreen = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("RankedScreen"))
local rankedReady = false
local function openRanked(initOnly)
	if not rankedReady then
		rankedReady = true
		RankedScreen.Init({
			Config = Config,
			ask = function(action, ...) local ok, r = pcall(Request.InvokeServer, Request, action, ...) return ok and r end,
			toast = function(...) if toast then toast(...) end end,
			onOpen = function() if gui then gui.Enabled = false end end,
			onClose = function() if gui then gui.Enabled = true end end,
		})
	end
	if initOnly then return end
	if RankedScreen.IsOpen() then RankedScreen.Close() else
		if PlayScreen.IsOpen() then PlayScreen.Close() end
		RankedScreen.Open()
	end
end
LobbyUI.OpenRanked = openRanked
local Tooltip = require(script:WaitForChild("Tooltip"))
local missionsReady = false
local function openMissions(initOnly)
	if not initOnly and PlayScreen.IsOpen() then PlayScreen.Close() end
	if not missionsReady then
		missionsReady = true
		MissionsScreen.Init({
			Config = Config, ask = ask, getData = function() return data end,
			tooltip = function(obj, title, body) Tooltip.Attach(obj, title, body) end,
			onOpen = function() if gui then gui.Enabled = false end end,
			onClose = function() if gui then gui.Enabled = true end end,
		})
	end
	if initOnly then return end
	if MissionsScreen.IsOpen() then MissionsScreen.Close() else MissionsScreen.Open() end
end

---------------------------------------------------------------- PLAY (UI session 2026-10-16: full screen, 3D cards; renderPlay above is no longer used)
local playReady = false
local function openPlay(initOnly)
	if not playReady then
		playReady = true
		PlayScreen.Init({
			Config = Config, ask = ask, getData = function() return data end, toast = toast,
			rankedOpen = function() return rankedOpen() end,
			openRanked = function() openRanked() end,
			level = function() return (accountLevel()) end,
			enterTraining = function()
				local fade = player.PlayerGui:FindFirstChild("ExfilFade")
				local quick = fade and fade:FindFirstChild("QuickEnter")
				if quick then quick:Fire() end
			end,
			toPads = function()
				local hud = shared.Get and shared.Get("LobbyHudController")
				if hud and hud.ToPads then hud.ToPads() end
			end,
			onOpen = function() if gui then gui.Enabled = false end end,
			onClose = function() if gui then gui.Enabled = true end end,
		})
	end
	if initOnly then return end
	if PlayScreen.IsOpen() then PlayScreen.Close() else PlayScreen.Open() end
end

---------------------------------------------------------------- CODES
local codeText = ""
local function renderCodes(body)
	clear(body)
	label({ Text = "Got a code from an update, the group or a stream? Redeem it here.", Font = THEME.Body, TextSize = 15,
		TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 22), Parent = body })
	local box = new("TextBox", {
		Text = codeText, PlaceholderText = "ENTER CODE", ClearTextOnFocus = false, Font = THEME.Title, TextSize = 24,
		TextColor3 = THEME.Text, PlaceholderColor3 = Color3.fromRGB(90, 94, 98), BackgroundColor3 = THEME.Panel2,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -200, 0, 60), Position = UDim2.new(0, 0, 0, 40), Parent = body,
	}, { corner(2), new("UIPadding", { PaddingLeft = UDim.new(0, 18) }) })
	Tac.brackets(box, Tac.C.olive, 14)
	box:GetPropertyChangedSignal("Text"):Connect(function() codeText = box.Text end)
	local function redeem()
		local code = codeText:gsub("^%s+", ""):gsub("%s+$", "")
		if code == "" then toast("Type a code first", "bad") return end
		local r = ask("RedeemCode", code)
		if r and r.ok then codeText = "" box.Text = "" end
	end
	box.FocusLost:Connect(function(enter) if enter then redeem() end end)
	button({ Text = "REDEEM  >", Style = "good", TextSize = 18, Size = UDim2.new(0, 186, 0, 60), Position = UDim2.new(1, -186, 0, 40), Parent = body }, redeem)

	local used = {}
	for code in (data.RedeemedCodes or {}) do table.insert(used, code) end
	table.sort(used)
	label({ Text = "REDEEMED", Font = THEME.Title, TextSize = 14, TextColor3 = THEME.Sub, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 124), Parent = body })
	local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -150), Position = UDim2.new(0, 0, 0, 150), Parent = body }, {
		new("UIGridLayout", { CellSize = UDim2.new(0, 190, 0, 40), CellPadding = UDim2.new(0, 8, 0, 8) }),
	})
	if #used == 0 then
		label({ Text = "Nothing yet", TextColor3 = THEME.Sub, Font = THEME.Body, Parent = list })
	end
	for _, code in used do
		new("Frame", { BackgroundColor3 = THEME.Panel2, Parent = list }, {
			corner(2), pad(10), new("Frame", { BackgroundColor3 = Tac.C.olive, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 20), Position = UDim2.new(0, -10, 0, -10) }),
			label({ Text = "✓  " .. code, Font = THEME.Bold, TextSize = 14, TextColor3 = THEME.Good, Size = UDim2.fromScale(1, 1) }),
		})
	end
end

local PANELS = {
	{ Id = "Play", Title = "PLAY", Sub = "Online queues: 1v1, 2v2 and 3v3, casual or ranked", Render = renderPlay },
	{ Id = "Kit", Title = "KIT", Sub = "What you deploy with", Render = renderLoadout },
	{ Id = "Shop", Title = "SHOP", Sub = "Gear, bundles and Robux packs", Render = renderShop },
	{ Id = "Codes", Title = "CODES", Sub = "Redeem rewards", Render = renderCodes },
}

-------------------------------------------------------------------------------
-- Frame building
-------------------------------------------------------------------------------
local panelFrame, panelTitle, panelSub, panelBody

local function setRailSelection()
	for id, b in railButtons do
		local on = id == current
		if b.underline then TweenService:Create(b.underline, TI, { Size = UDim2.new(0, on and 46 or 0, 0, 3) }):Play() end
		if b.text then b.text.TextColor3 = on and THEME.Accent or THEME.Text end
	end
end

local shopReady = false
local function openShop(startTab, initOnly)
	if not shopReady then
		shopReady = true
		Shop.Init({
			Config = Config, Icons = Icons, UITheme = UITheme, toast = toast, ask = ask, owns = owns,
			getData = function() return data end,
			getSetting = function(k) return localSettings[k] end,
			tooltip = function(obj, title, body) Tooltip.Attach(obj, title, body) end,
			onOpen = function() if gui then gui.Enabled = false end end,
			onClose = function() if gui then gui.Enabled = true end end,
			renderStore = function(holder) LobbyUI.RenderStore(holder) end,
			openKit = function(id)
				Shop.Close()
				LobbyUI.Close()
				Armory.Enter(id)
			end,
		})
	end
	if initOnly then return end
	if Shop.IsOpen() and not startTab then Shop.Close() return end
	Shop.Open(startTab)
end

-- (UI session 2026-10-16, standing rule / RIVALS) the full-screen menus are built and preloaded from join: their images plus
-- every mesh their 3D art uses. A menu opened before that's done shows the three loading dots (blur up) and opens when ready.
local menusReady = false
local loadingGui, loadingPending
local function whenReady(fn)
	if menusReady then fn() return end
	if loadingPending then return end -- already waiting: a second click doesn't queue another open
	loadingPending = true
	if not loadingGui then
		local UIKitF = ReplicatedStorage:WaitForChild("UIKit")
		local K = require(UIKitF:WaitForChild("Kit"))
		loadingGui = Instance.new("ScreenGui")
		loadingGui.Name = "MenuLoading"; loadingGui.IgnoreGuiInset = true; loadingGui.ResetOnSpawn = false; loadingGui.DisplayOrder = 40
		local scrim = Instance.new("Frame"); scrim.Size = UDim2.fromScale(1, 1); scrim.BackgroundColor3 = Color3.new(0, 0, 0); scrim.BackgroundTransparency = 0.55; scrim.Parent = loadingGui
		K.loadingDots(K.canvas(loadingGui))
		loadingGui.Parent = player:WaitForChild("PlayerGui")
	end
	loadingGui.Enabled = true
	if gui then gui.Enabled = false end
	task.spawn(function()
		-- (live fix 2026-10-16) never wait forever: after 6 s the menu opens anyway (its art keeps streaming in)
		local t0 = os.clock()
		while not menusReady and os.clock() - t0 < 6 do task.wait() end
		loadingGui.Enabled = false
		loadingPending = false
		local ok, err = pcall(fn)
		if not ok then warn("[MenuOpen] " .. tostring(err)); if gui then gui.Enabled = true end end
	end)
end
-- (live fix 2026-10-16) live, the preload has to really download the whole Repository + every image (Studio has them cached)
-- and assets that fail take long to give up, so it's capped: ready when it finishes or 8 s after it started, whichever is
-- first; the rest keeps loading in the background. Each step's time goes to the console as [MenuPrewarm] (F9 live).
local prewarmStart = os.clock()
local function stepLog(name, t0) print(string.format("[MenuPrewarm] %s %.2fs (since join %.1fs)", name, os.clock() - t0, os.clock() - prewarmStart)) end
local function prewarmMenus()
	print(string.format("[MenuPrewarm] start (%.1fs)", os.clock() - prewarmStart))
	for _, step in { { "Settings", openSettings, true }, { "Missions", openMissions, true }, { "Play", openPlay, true },
		{ "Shop", function() return openShop(nil, true) end }, { "Codes", openCodes, true }, { "Ranked", openRanked, true } } do
		local t0 = os.clock()
		local ok, err = pcall(step[2], step[3])
		stepLog(step[1] .. (ok and "" or (" FAILED " .. tostring(err))), t0)
	end
	local list = {}
	local function add(root)
		if not root then return end
		for _, d in root:GetDescendants() do
			if ((d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "") or d:IsA("MeshPart") or d:IsA("SpecialMesh")
				or d:IsA("SurfaceAppearance") or d:IsA("Decal") then
				table.insert(list, d)
			end
		end
	end
	for _, name in { "ShopUI2", "MissionsUI", "PlayUI", "SettingsUI", "CodesUI" } do add(player.PlayerGui:FindFirstChild(name)) end
	add(ReplicatedStorage:FindFirstChild("Repository"))
	add(ReplicatedStorage:FindFirstChild("UIIcons"))
	local t0 = os.clock()
	local failed, done = 0, false
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list, function(id, status)
				if status ~= Enum.AssetFetchStatus.Success then
					failed += 1
					if failed <= 10 then print("[MenuPrewarm] asset " .. tostring(status) .. " " .. tostring(id)) end
				end
			end)
		end)
		done = true
		stepLog(string.format("preload %d items, %d failed", #list, failed), t0)
	end)
	while not done and os.clock() - t0 < 8 do task.wait(0.1) end
	if not done then stepLog(string.format("preload still running (%d items): menus open anyway", #list), t0) end
	menusReady = true
end
LobbyUI.OpenShop = function(startTab) whenReady(function() openShop(startTab) end) end

-- one full-screen menu at a time (RIVALS): opening one closes the others (UI session 2026-10-16)
local function closeScreens(keep)
	if keep ~= "Play" and PlayScreen.IsOpen() then PlayScreen.Close() end
	if keep ~= "Missions" and MissionsScreen.IsOpen() then MissionsScreen.Close() end
	if keep ~= "Settings" and SettingsScreen.IsOpen and SettingsScreen.IsOpen() then SettingsScreen.Close() end
	if keep ~= "Shop" and Shop.IsOpen and Shop.IsOpen() then Shop.Close() end
	if keep ~= "Codes" and CodesScreen.IsOpen() then CodesScreen.Close() end
	if keep ~= "Ranked" and RankedScreen.IsOpen() then RankedScreen.Close() end
end
LobbyUI.CloseScreens = closeScreens

function LobbyUI.Open(id: string)
	closeScreens(id == "Quests" and "Missions" or id)
	Tooltip.Hide() -- the hovered button's tooltip would stay over the menu
	if id == "Kit" then -- KIT is its own room, not a panel
		LobbyUI.Close()
		Shop.Close()
		Armory.Enter()
		return
	end
	if id == "Shop" then -- the SHOP is full-screen, not a panel
		LobbyUI.Close()
		whenReady(function() openShop() end)
		return
	end
	if id == "Settings" then -- SETTINGS is full-screen too (UIKit.SettingsScreen)
		LobbyUI.Close()
		Shop.Close()
		whenReady(openSettings)
		return
	end
	if id == "Play" then -- PLAY is full-screen too (UIKit.PlayScreen)
		LobbyUI.Close()
		Shop.Close()
		whenReady(openPlay)
		return
	end
	if id == "Codes" then -- CODES is full-screen too (UIKit.CodesScreen, UI session 2026-10-16)
		LobbyUI.Close()
		Shop.Close()
		whenReady(openCodes)
		return
	end
	if id == "Missions" or id == "Quests" then -- MISSIONS is full-screen too (UIKit.MissionsScreen)
		LobbyUI.Close()
		Shop.Close()
		whenReady(openMissions)
		return
	end
	Shop.Close()
	if Armory.IsActive() then return end
	if current == id then
		LobbyUI.Close()
		return
	end
	current = id
	pendingBuy = nil
	for _, p in PANELS do
		if p.Id == id then
			panelTitle.Text = p.Title
			panelSub.Text = p.Sub
		end
	end
	panelFrame.Visible = true
	UITheme.ShowBackdrop("LobbyPanel", 1)
	panelFrame.Position = UDim2.new(0.5, 0, 0.43, 30)
	TweenService:Create(panelFrame, TweenInfo.new(0.32, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0.43, 0) }):Play()
	setRailSelection()
	LobbyUI.Refresh()
end

function LobbyUI.Close()
	current = nil
	pendingBuy = nil
	if panelFrame then panelFrame.Visible = false end
	UITheme.HideBackdrop("LobbyPanel")
	setRailSelection()
end

local refreshQueued = false
function LobbyUI.Refresh()
	if refreshQueued then return end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		if not data then return end
		if creditLabel then creditLabel.Text = commas(data.Credits or 0) end
		if LobbyUI.OnDataRefresh then LobbyUI.OnDataRefresh() end
		if Armory.IsActive() then Armory.Refresh() end
		if Shop.IsOpen() then Shop.Refresh() end
		if MissionsScreen.IsOpen() then MissionsScreen.Refresh() end
		local badge = railButtons.Missions and railButtons.Missions.badge
		if badge then
			local n = claimableCount()
			badge.Visible = n > 0
			badge.Text = tostring(n)
		end
		if current then
			for _, p in PANELS do
				if p.Id == current then p.Render(panelBody) end
			end
		end
	end)
end

local function buildQueuePill()
	queuePill = new("Frame", {
		BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0, 520, 0, 58), Visible = false, Parent = root,
	}, { corner(2), stroke(THEME.Cyan, 1.5) })
	label({ Name = "Mode", Text = "", Font = THEME.Title, TextSize = 24, Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(0, 16, 0, 0), Parent = queuePill })
	label({ Name = "Status", Text = "", Font = THEME.Bold, TextSize = 14, TextColor3 = THEME.Sub, Size = UDim2.new(1, -250, 1, 0), Position = UDim2.new(0, 90, 0, 0), Parent = queuePill })
	label({ Name = "Count", Text = "", Font = THEME.Title, TextSize = 30, TextColor3 = THEME.Accent, Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(1, -170, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = queuePill })
	button({ Text = "LEAVE", Style = "dark", Size = UDim2.new(0, 100, 0, 36), Position = UDim2.new(1, -112, 0.5, -18), Parent = queuePill }, function()
		ask(player:GetAttribute("MM_Queue") and "CancelMatch" or "LeaveQueue")
	end).Name = "Leave"
end

local PlayRow = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("PlayRow"))
local function updatePlayButton()
	-- the PLAY button lives in UIKit.PlayRow (RIVALS play row, Scale-only)
	local oq, ostatus, osince = onlineSearch()
	if oq then -- searching online
		if ostatus == "Searching" then
			PlayRow.SetState("SEARCHING " .. clockText(workspace:GetServerTimeNow() - osince), "busy")
		else
			PlayRow.SetState("MATCH FOUND", "found")
		end
		return
	end
	local mine = queueSnap.players and queueSnap.players[tostring(player.UserId)]
	local bay
	if mine then
		for _, b in queueSnap.bays do
			if b.mode == mine.mode and b.id == mine.bay then bay = b end
		end
	end
	if bay and bay.state == "Countdown" then
		PlayRow.SetState("DEPLOYING " .. tostring(bay.countdown or ""), "busy")
	elseif bay and bay.state == "Deploying" then
		PlayRow.SetState("DEPLOYING...", "busy")
	elseif mine then
		PlayRow.SetState("IN QUEUE · " .. string.upper(mine.mode), "busy")
	else
		PlayRow.SetState("PLAY", "play")
	end
end

local function updateQueuePill()
	updatePlayButton()
	if not queuePill then return end
	-- (UI session 2026-10-16) retired: PadUI shows pads, the HUD's searching plate shows online searches
	queuePill.Visible = false
	do return end
	local oq, ostatus, osince = onlineSearch()
	local st0 = queuePill:FindFirstChildOfClass("UIStroke")
	if oq then -- searching online
		queuePill.Visible = true
		queuePill.Mode.Text = string.upper(oq.Mode)
		queuePill.Mode.TextColor3 = oq.Ranked and PC.Ranked or THEME.Text
		queuePill.Status.Text = (oq.Ranked and "RANKED  ·  " or "") .. (ostatus == "Searching" and "SEARCHING ONLINE" or "MATCH FOUND  ·  DEPLOYING")
		queuePill.Count.Text = ostatus == "Searching" and clockText(workspace:GetServerTimeNow() - osince) or ""
		queuePill.Count.TextSize = 24
		if st0 then st0.Color = ostatus == "Searching" and (oq.Ranked and PC.Ranked or THEME.Cyan) or THEME.Good end
		queuePill.Leave.Visible = ostatus == "Searching"
		return
	end
	queuePill.Count.TextSize = 30
	local mine = queueSnap.players and queueSnap.players[tostring(player.UserId)]
	if not mine then
		queuePill.Visible = false
		return
	end
	local bay
	for _, b in queueSnap.bays do
		if b.mode == mine.mode and b.id == mine.bay then bay = b end
	end
	if not bay then queuePill.Visible = false return end
	queuePill.Visible = true
	queuePill.Mode.Text = string.upper(bay.mode)
	queuePill.Mode.TextColor3 = mine.team == "A" and THEME.Cyan or THEME.Accent
	local st = queuePill:FindFirstChildOfClass("UIStroke")
	if bay.state == "Countdown" then
		queuePill.Status.Text = `BAY {string.format("%02d", bay.id)}  ·  MATCH FOUND  ·  DEPLOYING IN`
		queuePill.Count.Text = tostring(bay.countdown or "")
		st.Color = THEME.Accent
	elseif bay.state == "Deploying" then
		queuePill.Status.Text = `BAY {string.format("%02d", bay.id)}  ·  DEPLOYING...`
		queuePill.Count.Text = ""
		st.Color = THEME.Good
	else
		queuePill.Status.Text = `BAY {string.format("%02d", bay.id)}  ·  TEAM {mine.team}  ·  WAITING FOR PLAYERS`
		queuePill.Count.Text = `{bay.count}/{bay.total}`
		st.Color = THEME.Cyan
	end
	queuePill.Leave.Visible = bay.state ~= "Deploying"
end

local function build()
	gui = new("ScreenGui", {
		Name = "LobbyUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = new("UIScale", { Parent = root })
	local function rescale()
		local cam = workspace.CurrentCamera
		local h = cam and cam.ViewportSize.Y or 900
		local w = cam and cam.ViewportSize.X or 1600
		scale.Scale = math.clamp(math.min(h / 900, w / 1500), 0.5, 1.25) * uiScaleMul
		root.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
	end
	rescaleUI = rescale
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- player card (top left)
	-- (UI session 2026-10-16: the HUD's scissors pill replaces this card; it stays built, hidden, for older callers)
	local card = new("Frame", { Name = "PlayerCard", Visible = false, BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.1, Position = UDim2.new(0, 18, 0, 18), Size = UDim2.new(0, 280, 0, 70), Parent = root }, {
		new("Frame", { BackgroundColor3 = Tac.C.olive, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0) }),
	})
	Tac.brackets(card, Tac.C.line, 12)
	local avatar = new("ImageLabel", { BackgroundColor3 = THEME.Panel3, Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 12, 0, 8), Parent = card }, { corner(2) })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then avatar.Image = img end
	end)
	label({ Text = player.DisplayName, Font = THEME.Title, TextSize = 17, Size = UDim2.new(1, -140, 0, 20), Position = UDim2.new(0, 72, 0, 10), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	levelLabel = label({ Text = "LV 1", Font = THEME.Title, TextSize = 13, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 56, 0, 20), Position = UDim2.new(1, -66, 0, 10), Parent = card })
	scissorIcon({ Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 68, 0, 37), Parent = card })
	creditLabel = label({ Text = "...", Font = THEME.Title, TextSize = 20, Size = UDim2.new(0, 120, 0, 22), Position = UDim2.new(0, 92, 0, 38), Parent = card })
	button({ Text = "+", Style = "robux", TextSize = 20, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -38, 0, 35), Parent = card }, function()
		LobbyUI.Close()
		LobbyUI.OpenShop("Scissors")
	end)

	-- bottom dock: PLAY (+ your avatar and an invite button), then KIT · SHOP · MISSIONS · SETTINGS · CODES
	local Icons = require(script:WaitForChild("Icons"))
	local DOCK_W = 660
	local dock = new("Frame", { Name = "Dock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, DOCK_W, 0, 200), Parent = root })
	-- no bar behind the dock: a soft shade rising from the bottom of the screen keeps the labels readable
	local shade = new("Frame", { Name = "DockShade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 260), ZIndex = 0, Parent = root }, {
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.45) }) }),
	})
	shade:SetAttribute("NoStyle", true)

	local DOCK = {
		{ Id = "Kit", Label = "Kit", Build = function() return Icons.Weapon((data and data.Loadout and data.Loadout.Weapon) or "Pistol") end, View = Icons.GunView, Zoom = 0.95 },
		{ Id = "Shop", Label = "Shop", Build = Icons.Crate, View = CFrame.Angles(math.rad(16), math.rad(28), 0), Zoom = 1.1 },
		{ Id = "Missions", Label = "Missions", Build = Icons.Clipboard, View = CFrame.Angles(math.rad(8), math.rad(-18), math.rad(6)), Zoom = 1.05 },
		{ Id = "Settings", Label = "Settings", Build = Icons.Gear, View = CFrame.Angles(math.rad(10), math.rad(25), 0), Zoom = 1.1 },
		{ Id = "Codes", Label = "Codes", Build = Icons.DogTags, View = CFrame.Angles(math.rad(6), math.rad(-15), 0), Zoom = 1.05 },
	}
	local slotW = DOCK_W / #DOCK
	for i, d in DOCK do
		local btn = new("TextButton", { Name = d.Id, AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
			Size = UDim2.new(0, slotW, 0, 124), Position = UDim2.new(0, (i - 1) * slotW, 1, -124), Parent = dock })
		-- a faint glass disc that lights up on hover (the icon floats on it)
		local disc = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.new(0, 84, 0, 84), Parent = btn }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local iconHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 48),
			Size = UDim2.new(0, 100, 0, 100), Parent = btn })
		local icon = Icons.Viewport(iconHolder, d.Build(), { view = d.View, zoom = d.Zoom })
		local text = label({ Text = d.Label, Font = THEME.Title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -32), Parent = btn })
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.1, Parent = text })
		local underline = new("Frame", { BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0, 0, 0, 3), Parent = btn }, { corner(2) })
		local badge
		if d.Id == "Missions" then
			badge = new("TextLabel", { Text = "", Visible = false, Font = THEME.Title, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
				BackgroundColor3 = Color3.fromRGB(214, 52, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 32, 0, 16),
				Size = UDim2.new(0, 26, 0, 26), ZIndex = 3, Parent = btn }, { corner(13), stroke(Color3.new(1, 1, 1), 2) })
		end
		btn.MouseEnter:Connect(function()
			icon.SetHover(true)
			TweenService:Create(iconHolder, TI, { Size = UDim2.new(0, 116, 0, 116), Position = UDim2.new(0.5, 0, 0, 42) }):Play()
			TweenService:Create(disc, TI, { BackgroundTransparency = 0.88 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			icon.SetHover(false)
			TweenService:Create(iconHolder, TI, { Size = UDim2.new(0, 100, 0, 100), Position = UDim2.new(0.5, 0, 0, 48) }):Play()
			TweenService:Create(disc, TI, { BackgroundTransparency = 1 }):Play()
		end)
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(iconHolder, TweenInfo.new(0.08), { Size = UDim2.new(0, 90, 0, 90) }):Play()
		end)
		btn.Activated:Connect(function()
			TweenService:Create(iconHolder, TI, { Size = UDim2.new(0, 108, 0, 108) }):Play()
			LobbyUI.Open(d.Id)
		end)
		railButtons[d.Id] = { frame = btn, text = text, underline = underline, badge = badge, icon = icon }
	end

	-- the KIT icon follows your equipped sidearm
	local shownWeapon = nil
	LobbyUI.OnDataRefresh = function()
		if levelLabel then levelLabel.Text = "LV " .. (accountLevel()) end
		local w = data and data.Loadout and data.Loadout.Weapon
		if w and w ~= shownWeapon then
			shownWeapon = w
			railButtons.Kit.icon.SetModel(Icons.Weapon(w), Icons.GunView)
		end
	end

	-- PLAY button
	local playRow = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -132),
		Size = UDim2.new(0, 460, 0, 68), Parent = dock })
	local play = new("TextButton", { Name = "Play", AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 250, 0, 62), Parent = playRow }, {
		corner(10), stroke(Color3.fromRGB(18, 34, 10), 2.5),
	})
	local playScale = new("UIScale", { Parent = play })
	local playGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 214, 72), Color3.fromRGB(78, 150, 40)), Parent = play })
	new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, BorderSizePixel = 0, Size = UDim2.new(1, -12, 0.42, 0),
		Position = UDim2.new(0, 6, 0, 4), Parent = play }, { corner(7) })
	local playText = label({ Text = "PLAY", Font = THEME.Title, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = play })
	new("UIStroke", { Color = Color3.fromRGB(18, 34, 10), Thickness = 2.5, Parent = playText })
	play.MouseEnter:Connect(function() TweenService:Create(playScale, TI, { Scale = 1.05 }):Play() end)
	play.MouseLeave:Connect(function() TweenService:Create(playScale, TI, { Scale = 1 }):Play() end)
	play.MouseButton1Down:Connect(function() TweenService:Create(playScale, TweenInfo.new(0.08), { Scale = 0.96 }):Play() end)
	play.Activated:Connect(function()
		TweenService:Create(playScale, TI, { Scale = 1.05 }):Play()
		LobbyUI.Open("Play")
	end)
	LobbyUI._play = { btn = play, text = playText, grad = playGrad }

	-- your avatar + invite friends
	local av = new("ImageLabel", { BackgroundColor3 = THEME.Panel3, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 140, 0.5, 0),
		Size = UDim2.new(0, 58, 0, 58), Parent = playRow }, { corner(29), stroke(Color3.fromRGB(225, 225, 225), 2) })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then av.Image = img end
	end)
	local invite = button({ Text = "+", Style = "dark", TextSize = 24, Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0.5, 206, 0.5, -19), Parent = playRow }, function()
		local SocialService = game:GetService("SocialService")
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			toast("Invites aren't available here (they work in the published game)", "bad")
		end
	end)
	invite:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	stroke(THEME.Line, 1).Parent = invite
	-- the old Offset-based play row stays built (other code reads LobbyUI._play) but hidden: UIKit.PlayRow replaces it
	playRow.Visible = false
	PlayRow.Init({
		lobbyGui = gui, dock = dock,
		onPlay = function() LobbyUI.Open("Play") end,
		onInvite = function()
			local SocialService = game:GetService("SocialService")
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			else
				toast("Invites aren't available here (they work in the published game)", "bad")
			end
		end,
		tooltip = function(obj, title, body) Tooltip.Attach(obj, title, body) end,
	})

	-- centre panel
	-- centre panel: no box at all - it floats over the coloured backdrop (UITheme)
	panelFrame = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
		Size = UDim2.new(0, 880, 0, 580), Visible = false, Parent = root,
	})
	new("Frame", { Name = "TacBar", BackgroundColor3 = Tac.C.olive, BorderSizePixel = 0, Size = UDim2.new(0, 6, 0, 58), Position = UDim2.new(0, 8, 0, 14), Parent = panelFrame })
	panelTitle = label({ Text = "", Font = THEME.Title, TextSize = 30, Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.new(0, 24, 0, 12), Parent = panelFrame })
	panelSub = label({ Text = "", Font = THEME.Bold, TextSize = 15, TextColor3 = THEME.Sub, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.new(0, 26, 0, 52), Parent = panelFrame })
	local closeBtn = new("TextButton", { Name = "Close", AutoButtonColor = false, Text = "", Size = UDim2.new(0, 56, 0, 40), Position = UDim2.new(1, -76, 0, 16), Parent = panelFrame }, {
		new("UICorner", { CornerRadius = UDim.new(0, 2) }),
	})
	UITheme.Fill(closeBtn, Color3.fromRGB(46, 50, 42), Color3.fromRGB(21, 24, 19))
	Tac.hoverBrackets(closeBtn, Tac.brackets(closeBtn, Tac.C.olive, 10))
	closeBtn.MouseEnter:Connect(function() UITheme.Fill(closeBtn, UC.Danger, UC.DangerDark) end)
	closeBtn.MouseLeave:Connect(function() UITheme.Fill(closeBtn, Color3.fromRGB(46, 50, 42), Color3.fromRGB(21, 24, 19)) end)
	for _, r in { 45, -45 } do -- a drawn X (no font glyph)
		new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 22, 0, 5), Rotation = r, Parent = closeBtn }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	closeBtn.Activated:Connect(LobbyUI.Close)
	local credPill = new("Frame", { BackgroundColor3 = THEME.Panel2, Size = UDim2.new(0, 150, 0, 40), Position = UDim2.new(1, -236, 0, 16), Parent = panelFrame }, { corner(2) })
	Tac.brackets(credPill, Tac.C.line, 8)
	local credText = label({ Text = "", Font = THEME.Title, TextSize = 16, TextColor3 = THEME.Accent, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = credPill })
	RunService.Heartbeat:Connect(function()
		if data then credText.Text = priceText(data.Credits or 0) end
	end)
	panelBody = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -48, 1, -104), Position = UDim2.new(0, 24, 0, 84), Parent = panelFrame })
	panelTitle.ZIndex, panelSub.ZIndex = 3, 3
	panelTitle.TextSize = 38

	-- toasts (bottom centre)
	toastHost = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -230), Size = UDim2.new(0, 600, 0, 200), Parent = root }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	buildQueuePill()

	-- the KIT armory gets the same helpers so it looks like the rest of the UI
	Armory.Init({
		root = root, THEME = THEME, Config = Config, Icons = Icons,
		new = new, label = label, button = button, corner = corner, stroke = stroke, pad = pad, clear = clear,
		ask = ask, toast = toast, owns = owns, priceText = priceText, commas = commas,
		getData = function() return data end,
		setLobbyVisible = function(v)
			card.Visible = false -- (replaced by LobbyHudController's pill)
			dock.Visible = v
			if not v then LobbyUI.Close() end
		end,
		openRobux = function()
			LobbyUI.OpenShop("Scissors")
		end,
		scissorIcon = SCISSOR_ICON,
	})
end

-------------------------------------------------------------------------------
-- Start
-------------------------------------------------------------------------------
function LobbyUI.Start()
	local events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby")
	Request = events:WaitForChild("Request")
	QueueState = events:WaitForChild("QueueState")
	NotifyEvent = events:WaitForChild("Notify")

	Style.SetTokens(THEME)
	build()
	Style.Apply(gui)
	local transitionGui = player.PlayerGui:FindFirstChild("ArmoryTransition")
	if transitionGui then Style.Apply(transitionGui) end

	NotifyEvent.OnClientEvent:Connect(toast)
	QueueState.OnClientEvent:Connect(function(snap)
		queueSnap = snap
		updateQueuePill()
		if current == "Play" then LobbyUI.Refresh() end
	end)

	-- online search state (MatchmakingManager) and the live "searching" counts
	for _, attr in { "MM_Queue", "MM_Status" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			updateQueuePill()
			if current == "Play" then LobbyUI.Refresh() end
		end)
	end
	ReplicatedStorage:GetAttributeChangedSignal("MM_Counts"):Connect(function()
		if current == "Play" then LobbyUI.Refresh() end
	end)
	task.spawn(function() -- search timers
		while true do
			task.wait(0.5)
			if player:GetAttribute("MM_Status") == "Searching" then
				updateQueuePill()
				if current == "Play" and panelBody then
					local since = player:GetAttribute("MM_Since") or workspace:GetServerTimeNow()
					for _, d in panelBody:GetDescendants() do
						if d:GetAttribute("SearchTimer") then d.Text = "CANCEL  ·  " .. clockText(workspace:GetServerTimeNow() - since) end
					end
				end
			end
		end
	end)

	-- quest reset timers tick once a second
	task.spawn(function()
		while true do
			task.wait(1)
			if current == "Quests" and panelBody then
				for _, d in panelBody:GetDescendants() do
					local scope = d:GetAttribute("ResetScope")
					if scope then d.Text = "RESETS IN " .. duration(resetIn(scope)) end
				end
			end
		end
	end)

	-- Studio test hook (like CoverTestHook): Invoke("Open", panelId) / Invoke("Close") / Invoke("Dump")
	if RunService:IsStudio() then
		local hookFn = Instance.new("BindableFunction")
		hookFn.Name = "LobbyUITestHook"
		hookFn.OnInvoke = function(cmd, arg)
			if cmd == "Open" then LobbyUI.Open(arg) elseif cmd == "Close" then LobbyUI.Close() end
			task.wait(0.1)
			local texts = {}
			if panelBody then
				for _, d in panelBody:GetDescendants() do
					if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then table.insert(texts, d.Text) end
				end
			end
			return table.concat(texts, " | ")
		end
		hookFn.Parent = player:WaitForChild("PlayerScripts")
	end

	-- (live fix) whatever happens to the replica / prewarm, the menus stop waiting 15 s after join
	task.delay(15, function()
		if not menusReady then print("[MenuPrewarm] watchdog: menus ready after 15 s (replica / prewarm still busy)") end
		menusReady = true
	end)
	-- player data replica
	local PlayerData = require(script.Parent.Parent:WaitForChild("Registry"):WaitForChild("PlayerData"))
	task.spawn(function()
		print(string.format("[MenuPrewarm] waiting for the data replica (%.1fs)", os.clock() - prewarmStart))
		replica = PlayerData:GetMyReplica()
		print(string.format("[MenuPrewarm] replica arrived (%.1fs)", os.clock() - prewarmStart))
		data = replica.Data
		task.spawn(prewarmMenus) -- build + preload the menus in the background (loading dots until done)
		local ok, err = pcall(applySettings)
		if not ok then warn("[LobbyUI] applySettings: " .. tostring(err)) end
		replica:ListenToRaw(function(_, path)
			-- (2026-10-16) Settings changed on the server (a save, an admin ;wipe): put them into effect and let the open
			-- screen re-read them, instead of keeping stale binds until a rejoin
			if type(path) == "table" and (path[1] == "Settings" or #path == 0) then
				local ok, err = pcall(applySettings)
				if not ok then warn("[LobbyUI] applySettings: " .. tostring(err)) end
				if SettingsScreen.Reload then pcall(SettingsScreen.Reload) end
			end
			LobbyUI.Refresh()
		end)
		LobbyUI.Refresh()
	end)

	task.spawn(function()
		local ok, res = pcall(Request.InvokeServer, Request, "GetQueue")
		if ok and res and res.snapshot then
			queueSnap = res.snapshot
			updateQueuePill()
		end
	end)
end

-------------------------------------------------------------------------------
-- World prompts (holo pads, STUFF counter, armory table) open panels
-------------------------------------------------------------------------------
do
	local ProximityPromptService = game:GetService("ProximityPromptService")
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then return end
		local id = prompt:GetAttribute("OpenPanel")
		-- [NPC] dialogue-only (Edward 2026-10-16): a prompt with NPC_OpensPanel = false keeps its talk lines but opens no panel
		if id and id ~= "" and prompt:GetAttribute("NPC_OpensPanel") ~= false then
			LobbyUI.Open(id)
		elseif prompt:GetAttribute("Teleport") == "Range" then
			toast("The practice range isn't open yet.", "bad")
		end
	end)
	-- jumping onto the helicopter = exfil to the practice range (teleport wired later)
	local lastHeli = 0
	local function hookHeli(trig: BasePart)
		trig.Touched:Connect(function(hit)
			local char = player.Character
			if not char or not hit:IsDescendantOf(char) then return end
			if os.clock() - lastHeli < 4 then return end
			lastHeli = os.clock()
			toast("Exfil: the practice range isn't open yet.", "bad")
		end)
	end
	task.spawn(function()
		local map = workspace:WaitForChild("LobbyMap", 30)
		local heli = map and map:WaitForChild("Heli", 30)
		local trig = heli and heli:WaitForChild("HeliTrigger", 30)
		if trig then hookHeli(trig) end
	end)
end

return LobbyUI