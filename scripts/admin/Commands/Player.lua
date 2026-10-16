-- AdminFramework/Commands/Player: kick, tp, heal, kill, respawn, god, speed.
-- Players in a lobby duel (attribute DuelMatch) are not teleported / respawned: that would break the match (;endmatch first).
local Players = game:GetService("Players")

local P = { name = "player", type = "players", defaultToken = "me" }

local function humanoidOf(p: Player)
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function each(ctx, list, fn)
	local done, skipped = {}, {}
	for _, p in list do
		local ok, why = fn(p)
		if ok == false then table.insert(skipped, p.Name .. " (" .. tostring(why) .. ")") else table.insert(done, p.Name) end
	end
	if #skipped > 0 then ctx.reply("skipped " .. table.concat(skipped, ", ")) end
	if #done == 0 then table.insert(done, "nobody") end
	return done
end

-- god mode: an invisible ForceField (every damage path uses Humanoid:TakeDamage, which a ForceField blocks) plus a heal-back
local god = {}
local function applyGod(p: Player)
	local hum = humanoidOf(p)
	if not hum then return end
	local c = p.Character
	if not c:FindFirstChild("AdminGodField") then
		local ff = Instance.new("ForceField"); ff.Name = "AdminGodField"; ff.Visible = false; ff.Parent = c
	end
	if not hum:GetAttribute("AdminGodHooked") then
		hum:SetAttribute("AdminGodHooked", true)
		hum.HealthChanged:Connect(function(h)
			if god[p] and h > 0 and h < hum.MaxHealth then hum.Health = hum.MaxHealth end
		end)
	end
	hum.Health = hum.MaxHealth
end
local function removeGod(p: Player)
	local c = p.Character
	local ff = c and c:FindFirstChild("AdminGodField")
	if ff then ff:Destroy() end
end
local hooked = {}
local function hookPlayer(p: Player)
	if hooked[p] then return end
	hooked[p] = true
	p.CharacterAdded:Connect(function()
		task.wait() -- let the Humanoid exist
		if god[p] then applyGod(p) end
		local speed = p:GetAttribute("AdminSpeed")
		local hum = humanoidOf(p)
		if speed and hum then hum.WalkSpeed = speed end
	end)
end
Players.PlayerRemoving:Connect(function(p) god[p] = nil; hooked[p] = nil end)

-- tp destinations that aren't players: duel pads, the spawn, the hangar, or "x,y,z"
local function placeTarget(token: string): (CFrame?, string?)
	local t = string.lower(token)
	local map = workspace:FindFirstChild("LobbyMap")
	if t == "spawn" or t == "hub" then
		local sp = map and map:FindFirstChild("LobbySpawn")
		if sp then return sp.CFrame + Vector3.new(0, 4, 0), "the spawn" end
		local any = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if any then return any.CFrame + Vector3.new(0, 4, 0), "the spawn" end
		return CFrame.new(0, 10, 0), "the origin"
	elseif t == "hangar" or t == "exfil" then
		return CFrame.new(112, 3.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), "the hangar" -- LobbyFallCatch's HANGAR
	end
	local x, y, z = string.match(t, "^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
	if x then return CFrame.new(tonumber(x), tonumber(y), tonumber(z)), ("%s,%s,%s"):format(x, y, z) end
	-- pads: Pad_1v1_A, "1v1a", "pad_2v2_b" ...
	local duels = map and map:FindFirstChild("Duels")
	local key = string.gsub(string.gsub(t, "^pad_?", ""), "_", "")
	for _, pad in (duels and duels:GetChildren() or {}) do
		if pad:IsA("Model") and pad:GetAttribute("QueueName") then
			local n = string.lower(string.gsub(string.gsub(pad.Name, "^Pad_", ""), "_", ""))
			if n == key then
				local zone = pad:FindFirstChild("Team1") or pad.PrimaryPart
				local pos = zone and zone:IsA("BasePart") and (zone.Position - Vector3.new(0, zone.Size.Y / 2 - 3, 0)) or pad:GetPivot().Position
				return CFrame.new(pos), pad.Name
			end
		end
	end
	return nil
end

return {
	{
		name = "kick", level = "Admin", description = "Kick a player from this server.",
		args = { { name = "player", type = "players" }, { name = "reason", type = "rest", optional = true, default = "Kicked by an admin" } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				if p == ctx.caller then return false, "not yourself" end
				p:Kick(a.reason)
			end)
			return done[1] ~= "nobody", "Kicked " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "tp", aliases = { "teleport", "goto" }, level = "Tester",
		description = "Teleport players to a player, a duel pad (1v1a, pad_2v2_b), spawn, hangar, or x,y,z.",
		args = { P, { name = "target", type = "string" } },
		run = function(ctx, a)
			local cf, label = placeTarget(a.target)
			if not cf then
				local list, err = ctx.Core.Args.Players(a.target, ctx)
				if not list then return false, "no place or player \"" .. a.target .. "\" (" .. tostring(err) .. ")" end
				if #list ~= 1 then return false, "tp to exactly one player" end
				local _, root = humanoidOf(list[1])
				if not root then return false, list[1].Name .. " has no character" end
				cf, label = root.CFrame * CFrame.new(0, 0, 4), list[1].Name
			end
			local done = each(ctx, a.player, function(p)
				if p:GetAttribute("DuelMatch") then return false, "in a duel" end
				local _, root = humanoidOf(p)
				if not root then return false, "no character" end
				p.Character:PivotTo(cf)
			end)
			return done[1] ~= "nobody", ("Teleported %s to %s."):format(table.concat(done, ", "), label)
		end,
	},
	{
		name = "heal", level = "Tester", description = "Full health.",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local hum = humanoidOf(p)
				if not hum or hum.Health <= 0 then return false, "no living character" end
				hum.Health = hum.MaxHealth
			end)
			return done[1] ~= "nobody", "Healed " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "kill", level = "Tester", description = "Kill (in a duel this counts as a death in the round).",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local hum = humanoidOf(p)
				if not hum then return false, "no character" end
				if god[p] then god[p] = nil; removeGod(p); p:SetAttribute("AdminGod", nil) end
				hum.Health = 0
			end)
			return done[1] ~= "nobody", "Killed " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "respawn", aliases = { "re", "refresh" }, level = "Tester", description = "Load a new character at the spawn.",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				if p:GetAttribute("DuelMatch") then return false, "in a duel" end
				task.spawn(function() p:LoadCharacter() end)
			end)
			return done[1] ~= "nobody", "Respawned " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "god", level = "Tester", description = "God mode on/off (invisible ForceField + heal-back; lasts through respawns).",
		args = { P, { name = "on", type = "boolean", optional = true, default = true } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				hookPlayer(p)
				god[p] = a.on or nil
				p:SetAttribute("AdminGod", a.on or nil)
				if a.on then applyGod(p) else removeGod(p) end
			end)
			return done[1] ~= "nobody", ("God %s: %s."):format(a.on and "on" or "off", table.concat(done, ", "))
		end,
	},
	{
		name = "speed", aliases = { "walkspeed", "ws" }, level = "Tester",
		description = "WalkSpeed (16 = normal; 'reset' or 0 = normal). Sets player attribute AdminSpeed.",
		args = { P, { name = "speed", type = "string", optional = true, default = "reset" } },
		run = function(ctx, a)
			local n = tonumber(a.speed)
			if a.speed ~= "reset" and (not n or n < 0 or n > 500) then return false, "speed must be 0-500 or reset" end
			if n == 0 or a.speed == "reset" then n = nil end
			local done = each(ctx, a.player, function(p)
				hookPlayer(p)
				p:SetAttribute("AdminSpeed", n)
				local hum = humanoidOf(p)
				if hum then hum.WalkSpeed = n or 16 end
			end)
			return done[1] ~= "nobody", ("Speed %s for %s."):format(n and tostring(n) or "normal", table.concat(done, ", "))
		end,
	},
}
