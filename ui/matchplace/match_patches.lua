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
