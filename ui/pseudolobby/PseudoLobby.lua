-- UIKit/PseudoLobby (ModuleScript): the after-match lobby in the Matchmaking / Ranked places (2026-10-18, Edward: "a pseudo
-- lobby ... all the aspects of the main lobby, the duel pads barricaded, To Hub / Play Again / Rematch").
-- The lead session's server copies Workspace.LobbyMap in after a match; the lobby's own client scripts run on top of it.
-- Contract (lead session):
--   ReplicatedStorage attribute PseudoLobbyMap: nil in the hub; false in a match place until the map is out; true once it is
--     in Workspace (it then stays there for the server's life).
--   Player attribute InPseudoLobby: true while you're in the lobby part (the lobby UI shows); false / nil in a match.
-- In the hub every call here is a no-op: MatchPlace() is false, WaitMap() returns at once, Active() is true.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PseudoLobby = {}

-- a Matchmaking / Ranked server (the saved match places carry PseudoLobbyMap = false; PlaceKind is the fallback)
function PseudoLobby.MatchPlace(): boolean
	return ReplicatedStorage:GetAttribute("PseudoLobbyMap") ~= nil or ReplicatedStorage:FindFirstChild("PlaceKind") ~= nil
end

-- the lobby map is in Workspace (always, in the hub)
function PseudoLobby.MapReady(): boolean
	return not PseudoLobby.MatchPlace() or ReplicatedStorage:GetAttribute("PseudoLobbyMap") == true
end

-- yield until the lobby map is in Workspace (hub: returns at once)
function PseudoLobby.WaitMap()
	while not PseudoLobby.MapReady() do
		ReplicatedStorage:GetAttributeChangedSignal("PseudoLobbyMap"):Wait()
	end
end

-- the lobby UI should show (hub: always; match place: while InPseudoLobby)
function PseudoLobby.Active(): boolean
	if not PseudoLobby.MatchPlace() then return true end
	local p = Players.LocalPlayer
	return p ~= nil and p:GetAttribute("InPseudoLobby") == true
end

-- fn(active) now and whenever it changes (match places only fire on change)
function PseudoLobby.Watch(fn: (boolean) -> ())
	local p = Players.LocalPlayer
	local last = PseudoLobby.Active()
	fn(last)
	if not PseudoLobby.MatchPlace() then return end
	p:GetAttributeChangedSignal("InPseudoLobby"):Connect(function()
		local now = PseudoLobby.Active()
		if now ~= last then last = now; fn(now) end
	end)
end

-- the lobby's ScreenGuis: forced off while the pseudo lobby isn't active (a rematch game runs on the same server). Bound
-- after every other render step, so a controller that re-enables its gui each frame never shows it during a match.
PseudoLobby.GUIS = { "LobbyHud", "LobbyUI", "PlayRowUI", "ArmoryUI", "ArmoryTransition", "SettingsUI", "ShopUI", "ShopUI2", "CodesUI",
	"RankedUI", "MissionsUI", "PlayUI", "PlayerCards", "PartyUI", "Tooltips" } -- (not UIBackdrop: the match screens use it too)
local guarding = false
function PseudoLobby.Guard()
	if guarding or not PseudoLobby.MatchPlace() then return end
	guarding = true
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService:BindToRenderStep("PseudoLobbyGuard", Enum.RenderPriority.Last.Value + 5, function()
		if PseudoLobby.Active() then return end
		for _, name in PseudoLobby.GUIS do
			local g = pg:FindFirstChild(name)
			if g and g:IsA("ScreenGui") and g.Enabled then g.Enabled = false end
		end
	end)
	-- leaving the lobby part (rematch starting): close whatever menu was open so it doesn't come back on the next visit
	PseudoLobby.Watch(function(on)
		if on then return end
		local get = shared.Get
		local LobbyUI = get and get("LobbyUIController")
		if LobbyUI then
			if LobbyUI.CloseScreens then pcall(LobbyUI.CloseScreens) end
			if LobbyUI.Close then pcall(LobbyUI.Close) end
		end
		for _, n in { "PlayerCards", "PartyScreen" } do
			local ok, m = pcall(require, script.Parent:WaitForChild(n, 1))
			if ok and type(m) == "table" then
				if m.CloseProfile then pcall(m.CloseProfile) end
				if m.CloseMenu then pcall(m.CloseMenu) end
				if m.Close then pcall(m.Close) end
			end
		end
	end)
end

-- PLAY in the pseudo lobby = Play Again (the lead's MatchFlow "PlayAgain": back to the hub and straight into the queue)
function PseudoLobby.PlayAgain()
	local ev = ReplicatedStorage:FindFirstChild("MatchFlow")
	if ev then ev:FireServer("PlayAgain") end
end

return PseudoLobby
