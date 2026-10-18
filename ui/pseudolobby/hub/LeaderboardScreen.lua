-- LeaderboardScreen: draws ReplicatedStorage.LobbyTopWins on the hub leaderboard screen.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TEAL = Color3.fromRGB(138, 156, 74)
local GOLD_FREE = Color3.fromRGB(235, 238, 242) -- no yellow/orange in this game: rank 1 uses white + teal
local FONT = "rbxasset://fonts/families/GothamSSm.json"
local player = Players.LocalPlayer
local part = workspace:WaitForChild("LobbyMap", 60):WaitForChild("Signs", 30):WaitForChild("Screen_Leaderboard", 30)
local value = game.ReplicatedStorage:WaitForChild("LobbyTopWins", 30)
if not (part and value) then return end

local function new(c, p, parent) local o = Instance.new(c) for k, v in p do o[k] = v end o.Parent = parent return o end
local gui = new("SurfaceGui", { Name = "LeaderboardGui", Adornee = part, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
	CanvasSize = Vector2.new(940, 580), LightInfluence = 0, Brightness = 1.5, MaxDistance = 120, ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 30, 38), Color3.fromRGB(9, 10, 13)) }, root)
local head = new("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = Color3.fromRGB(12, 14, 18), BorderSizePixel = 0 }, root)
new("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = TEAL, BorderSizePixel = 0 }, head)
new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 14), Size = UDim2.new(0.7, 0, 0, 56), Text = "TOP OPERATORS",
	FontFace = Font.new(FONT, Enum.FontWeight.Heavy), TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left }, head)
new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 26), Size = UDim2.new(0.25, 0, 0, 32), Text = "BY WINS",
	FontFace = Font.new(FONT, Enum.FontWeight.Bold), TextScaled = true, TextColor3 = TEAL, TextXAlignment = Enum.TextXAlignment.Right }, head)
new("Frame", { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = TEAL, BorderSizePixel = 0 }, root)
local rows = {}
for i = 1, 10 do
	local col = (i - 1) // 5
	local r = (i - 1) % 5
	local row = new("Frame", { Position = UDim2.fromOffset(24 + col * 458, 108 + r * 92), Size = UDim2.fromOffset(434, 80),
		BackgroundColor3 = Color3.fromRGB(22, 25, 31), BackgroundTransparency = i <= 3 and 0 or 0.2 }, root)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, row)
	local st = new("UIStroke", { Color = TEAL, Thickness = 2, Transparency = i == 1 and 0 or (i <= 3 and 0.5 or 0.85) }, row)
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(52, 52), Text = "#" .. i,
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy), TextScaled = true, TextColor3 = i == 1 and TEAL or Color3.fromRGB(150, 158, 170) }, row)
	local img = new("ImageLabel", { Position = UDim2.fromOffset(72, 8), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(34, 38, 46), Image = "" }, row)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, img)
	local nm = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(148, 14), Size = UDim2.fromOffset(190, 32), Text = "—",
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy), TextScaled = true, TextColor3 = GOLD_FREE, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local wins = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(148, 48), Size = UDim2.fromOffset(190, 20), Text = "",
		FontFace = Font.new(FONT, Enum.FontWeight.Bold), TextScaled = true, TextColor3 = TEAL, TextXAlignment = Enum.TextXAlignment.Left }, row)
	rows[i] = { img = img, nm = nm, wins = wins, user = nil }
end
local shots = {}
local function render()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok then return end
	for i, r in rows do
		local e = list[i]
		if e then
			r.nm.Text = string.upper(e.n or "OPERATOR")
			r.wins.Text = tostring(e.w or 0) .. " WINS"
			if r.user ~= e.u then
				r.user = e.u
				r.img.Image = shots[e.u] or ""
				task.spawn(function()
					local okT, url = pcall(Players.GetUserThumbnailAsync, Players, math.max(1, e.u), Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					if okT then shots[e.u] = url if r.user == e.u then r.img.Image = url end end
				end)
			end
		else
			r.nm.Text = "—" r.wins.Text = "" r.img.Image = "" r.user = nil
		end
	end
end
value.Changed:Connect(render)
render()
