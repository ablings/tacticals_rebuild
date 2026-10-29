-- Match place only (deploy_ui --match): the old pass-38 HUD pieces that DuelHUD / MatchFlowUI replace.
-- Idempotent source patches; originals backed up to ServerStorage._RebuildRemoved.SET_<name>_Orig.
local bin = game.ServerStorage:FindFirstChild("_RebuildRemoved")
local function backup(s, name)
	if bin and not bin:FindFirstChild("SET_" .. name .. "_Orig") then
		local b = s:Clone(); b.Name = "SET_" .. name .. "_Orig"
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end
-- MatchResults: DuelHUD draws the results card; this script keeps only its teammate outlines
local mr = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("MatchResults")
if mr and not mr.Source:find("[SET]", 1, true) then
	backup(mr, "MatchResults")
	mr.Source = mr.Source:gsub("\n\tshow%(summary%)\nend%)", "\n\t-- [SET] DuelHUD draws the results card now (this one doubled it)\nend)", 1)
end
-- MatchHUD: quiet while DuelHUD / MatchFlowUI own the screen (keeps the free-practice / tutorial status line)
local mh = game.StarterPlayer.StarterPlayerScripts.Client.GUIs:FindFirstChild("MatchHUD")
if mh and not mh.Source:find("[SET]", 1, true) then
	backup(mh, "MatchHUD")
	local src = mh.Source
	src = src:gsub("local function update%(%)\n", [[
local function duelHudOwns() -- [SET] DuelHUD / MatchFlowUI own the match screen
	local ph = ReplicatedStorage:GetAttribute("MatchPhase")
	return localPlayer:GetAttribute("InMatch") == true or ReplicatedStorage:GetAttribute("LiveMatch") == true
		or ph == "Loading" or ph == "MapVote" or ph == "Loadout"
end

local function update()
	if duelHudOwns() then local i = getGui().MatchInfo; i.Score.Text, i.Timer.Text, i.Status.Text = "", "", ""; return end
]], 1)
	src = src:gsub("local function showAnnouncement%(title: string, subtitle: string%)\n", [[
local function showAnnouncement(title: string, subtitle: string)
	if duelHudOwns() then return end -- [SET] DuelHUD shows the banner
]], 1)
	mh.Source = src
end
-- the short intro (logo crumbles, waits for every player to load before the map vote)
local ls = game.ReplicatedFirst:FindFirstChild("LoadingScreen")
if ls then ls:SetAttribute("QuickIntro", true) end

-- (2026-10-29, UI survey fix 2) UIStyleController retired in the match places: it recoloured warm colours navy, remapped fonts and
-- added a 0.45 "_Shade" stroke to every code-built GUI not tagged NoStyle / KeepColors (LobbyHud, PlayerCards, PartyUI, Notify,
-- Hotbar, Vitals, MatchFlow, TouchControls...), and the lobby never had it, so the same component looked different per place.
-- The module stays (loaders require it) and its Start does nothing; the original is backed up (UNDO: copy its Source back).
local CC = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client")
CC = CC and CC:FindFirstChild("Controllers")
local usc = CC and CC:FindFirstChild("UIStyleController")
if usc and not usc.Source:find("[UISURVEY]", 1, true) then
	backup(usc, "UIStyleController")
	usc.Source = [[
-- [UISURVEY] (2026-10-29) retired: every screen styles itself from UIKit.Theme, the same in the lobby and the match places.
-- The old styler (warm -> navy, font remap, _Shade strokes) is in ServerStorage._RebuildRemoved.SET_UIStyleController_Orig.
local controller = {}
function controller.Start() end
function controller.Init() end
return controller
]]
end
-- (2026-10-29, UI survey fix 8) InterfaceController: the lobby's skip lines (LobbyUI / ShopUI / CutFX animate their own buttons),
-- so its Scale-only press tween never shrinks an Offset-sized LobbyUI button to 0 x 0 in the match places
local ic = CC and CC:FindFirstChild("InterfaceController")
if ic and not ic.Source:find("LobbyUI animates its own buttons", 1, true) then
	backup(ic, "InterfaceController")
	local src, n = ic.Source:gsub('if desc:HasTag%("Nonapplicable"%) then continue end',
		'if desc:HasTag("Nonapplicable") or desc:FindFirstAncestor("LobbyUI") or desc:FindFirstAncestor("ShopUI") or desc:FindFirstAncestor("CutFX") then continue end -- LobbyUI animates its own buttons')
	local NL, TAB = string.char(10), string.char(9)
	local src2, m = src:gsub("playerGUI%.ChildAdded:Connect%(function%(UI: ScreenGui%)" .. NL,
		"playerGUI.ChildAdded:Connect(function(UI: ScreenGui)" .. NL .. TAB .. TAB .. 'if UI.Name == "LobbyUI" then return end' .. NL, 1)
	if n == 2 and m == 1 then ic.Source = src2 else warn("[deploy] InterfaceController skip lines not matched (" .. n .. ", " .. m .. ")") end
end
