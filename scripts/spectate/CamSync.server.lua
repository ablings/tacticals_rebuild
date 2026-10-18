-- ServerScriptService.CamSync (Script, hub + match places) [CAMSYNC] 2026-10-18, Edward (via the UI session): "spectating
-- captures the player's camera and pov ... scoped in with the sniper ... 1:1 as what the player sees, without lag".
-- ReplicatedStorage.CamSync (UnreliableRemoteEvent): a WATCHED player's CameraController sends, at most 15/s,
--   (off: Vector3 = camera position in their HumanoidRootPart's space, look: Vector3 = camera look in root space,
--    fov: number, scope: number 0..1)
-- Server: validated (off.Magnitude <= 20, look ~unit, fov 5..120, scope 0..1, faster than ~20 Hz dropped), then written to
--   player.Character attributes CamOff, CamLook, CamFOV, CamScope, CamT = workspace:GetServerTimeNow(). Spectators ride
--   those (UI session); CamT older than 0.6 s = fall back to the over-the-shoulder cam (bots never send).
-- Player attribute Watched (only the server sets it, every 0.25 s): an alive player in a match / lobby duel while anyone in
--   that same match is dead or spectating (SpectateTarget / DuelSpectate), or whom anyone is spectating directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("CamSync")
if not (remote and remote:IsA("UnreliableRemoteEvent")) then
	if remote then remote:Destroy() end
	remote = Instance.new("UnreliableRemoteEvent")
	remote.Name = "CamSync"
	remote.Parent = ReplicatedStorage
end

local MIN_GAP = 1 / 20
local last = {} -- [Player] = os.clock()

local function finiteVec(v): boolean
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e4 and math.abs(v.Y) < 1e4 and math.abs(v.Z) < 1e4
end

remote.OnServerEvent:Connect(function(player, off, look, fov, scope)
	if player:GetAttribute("Watched") ~= true then return end
	local now = os.clock()
	if now - (last[player] or 0) < MIN_GAP then return end
	last[player] = now
	if not (finiteVec(off) and finiteVec(look)) then return end
	if off.Magnitude > 20 then return end
	local len = look.Magnitude
	if len < 0.8 or len > 1.2 then return end
	if type(fov) ~= "number" or fov ~= fov then return end
	if type(scope) ~= "number" or scope ~= scope then scope = 0 end
	local character = player.Character
	if not character or not character.Parent then return end
	character:SetAttribute("CamOff", off)
	character:SetAttribute("CamLook", look.Unit)
	character:SetAttribute("CamFOV", math.clamp(fov, 5, 120))
	character:SetAttribute("CamScope", math.clamp(scope, 0, 1))
	character:SetAttribute("CamT", workspace:GetServerTimeNow())
end)

Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

-- which match / duel a player belongs to (players or spectators); nil = not in one
local function groupOf(p: Player)
	local duel = p:GetAttribute("DuelMatch") or p:GetAttribute("DuelSpectate")
	if duel ~= nil then return "duel:" .. tostring(duel) end
	if p:GetAttribute("InMatch") == true then return "match" end
	return nil
end

local function alive(p: Player): boolean
	if p:GetAttribute("Alive") == false then return false end
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

while true do
	local down, direct = {}, {}
	for _, p in Players:GetPlayers() do
		local g = groupOf(p)
		local spect = p:GetAttribute("SpectateTarget")
		if spect ~= nil then direct[spect] = true end
		if g and (p:GetAttribute("DuelSpectate") ~= nil or spect ~= nil or not alive(p)) then down[g] = true end
	end
	for _, p in Players:GetPlayers() do
		local g = groupOf(p)
		local watched = alive(p) and ((g ~= nil and down[g] == true) or direct[p.UserId] == true)
		if (p:GetAttribute("Watched") == true) ~= watched then p:SetAttribute("Watched", watched or nil) end
	end
	task.wait(0.25)
end
