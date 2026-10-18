-- Blurs / grades the world while a match is found, deploying or teleporting (menus do it via UITheme)
local Players=game:GetService("Players") local RS=game:GetService("ReplicatedStorage")
local UITheme=require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("UITheme"))
local plr=Players.LocalPlayer
local function update()
	local st=plr:GetAttribute("MM_Status")
	if plr:GetAttribute("Deploying") or st=="Teleporting" then UITheme.ShowBackdrop("MatchFlow",0.6)
	elseif st=="Found" then UITheme.ShowBackdrop("MatchFlow",0.4)
	else UITheme.HideBackdrop("MatchFlow") end
end
plr:GetAttributeChangedSignal("Deploying"):Connect(update)
plr:GetAttributeChangedSignal("MM_Status"):Connect(update)
update()
