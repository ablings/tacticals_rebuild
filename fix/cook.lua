-- fix/cook.lua [COOK] 2026-10-21, Edward (via the main PC): "if you hold it too long it can just explode on you, which RIVALS has ...
-- that's what I want, but I also want the throwing to feel like how the RIVALS grenade is thrown."
-- Frag cooking: the fuse starts when you PRESS (not on release). Let go in time and the grenade flies with what's left of the fuse;
-- hold it to the end and it blows up in your hand (a normal Frag blast at your position, credited to you). A tap still throws at once
-- with (nearly) the full fuse. Other gadgets keep the plain hold (up to MaxHoldTime) unless their config sets Cook = true.
--  * GadgetConfig.Frag.Cook = true
--  * GadgetManager: ThrowGadget mode "Cook" (sent by GadgetController on press) starts the fuse; the throw passes the remaining fuse to
--    throwGrenade; the fuse running out in hand explodes at the thrower and uses the charge; a throw that arrives after that is refused.
--  * Player attributes for the UI's cooking cue: CookStart = workspace:GetServerTimeNow() at the press, CookFuse = seconds; both nil when
--    the grenade leaves the hand or blows up.
-- Client side: ui/set/GadgetController.lua [COOK] (deployed by ui/deploy_ui.py). Both places. Idempotent; UNDO = true swaps back.
local UNDO = false --@UNDO
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")

local function patch(inst, edits)
	if not inst then return "missing" end
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		if UNDO then old, new = new, old end
		if s:find(new, 1, true) then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			assert(a, inst.Name .. " edit " .. i .. ": anchor not found")
			assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. ": anchor not unique")
			s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
			table.insert(out, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return inst.Name .. " " .. table.concat(out, " ")
end

local res = {}
table.insert(res, patch(RS.Modules.Shared.Config.GadgetConfig, {
	{ "\t\tFuseTime = 2,          -- [THROWNOW] Edward: 2 s from the throw (was 1.7)\n",
	  "\t\tFuseTime = 2,          -- [THROWNOW] Edward: 2 s from the throw (was 1.7)\n"
	  .. "\t\tCook = true,           -- [COOK] the fuse starts on the press; held to 0 it blows up in your hand\n" },
}))

local GM = SSS:FindFirstChild("GadgetManager", true)
table.insert(res, patch(GM, {
	-- throwGrenade takes the fuse left (cooked frags)
	{ "local function throwGrenade(gadget: string, character: Model?, direction: Vector3, power: number, mode: string, side: number?)\n\tlocal cfg = GadgetConfig[gadget]\n",
	  "local function throwGrenade(gadget: string, character: Model?, direction: Vector3, power: number, mode: string, side: number?, fuseLeft: number?)\n"
	  .. "\tlocal cfg = GadgetConfig[gadget]\n\tlocal fuse = fuseLeft or cfg.FuseTime -- [COOK] what's left of a cooked fuse\n" },
	{ "\t\ttask.delay(math.max(cfg.FuseTime - 0.6, 0), function()\n", "\t\ttask.delay(math.max(fuse - 0.6, 0), function() -- [COOK] fuse\n" },
	{ "\ttask.delay(cfg.FuseTime, function()\n\t\tif not grenade.Parent then return end\n",
	  "\ttask.delay(fuse, function() -- [COOK] fuse\n\t\tif not grenade.Parent then return end\n" },
	-- onThrow: remember a "Cook" press before the mode is normalised
	{ "\tif mode ~= \"Roll\" then mode = \"Throw\" end\n",
	  "\tlocal cookPress = mode == \"Cook\" -- [COOK]\n\tif mode ~= \"Roll\" then mode = \"Throw\" end\n" },
	{ "\tlocal cfg = GadgetConfig[gadget]\n\tlocal now = os.clock()\n\tif now - (lastThrow[player] or 0) < cfg.Cooldown then return end\n",
	  "\tlocal cfg = GadgetConfig[gadget]\n"
	  .. "\t-- [COOK] the press starts the fuse (fix/cook.lua); held to the end it blows up in the thrower's hand\n"
	  .. "\tif cookPress then\n"
	  .. "\t\tif not cfg.Cook or os.clock() - (lastThrow[player] or 0) < cfg.Cooldown or (player:GetAttribute(cfg.ChargesAttribute) or 0) <= 0 then return end\n"
	  .. "\t\tlocal token = {}\n"
	  .. "\t\tcooks[player] = { start = os.clock(), gadget = gadget, token = token }\n"
	  .. "\t\tplayer:SetAttribute(\"CookStart\", workspace:GetServerTimeNow())\n"
	  .. "\t\tplayer:SetAttribute(\"CookFuse\", cfg.FuseTime)\n"
	  .. "\t\ttask.delay(cfg.FuseTime, function()\n"
	  .. "\t\t\tlocal c = cooks[player]\n"
	  .. "\t\t\tif not c or c.token ~= token then return end\n"
	  .. "\t\t\tcooks[player], cookedOut[player] = nil, os.clock()\n"
	  .. "\t\t\tplayer:SetAttribute(\"CookStart\", nil)\n"
	  .. "\t\t\tplayer:SetAttribute(\"CookFuse\", nil)\n"
	  .. "\t\t\tlocal ch = player.Character\n"
	  .. "\t\t\tlocal at = ch and (ch:FindFirstChild(\"RightHand\") or ch:FindFirstChild(\"HumanoidRootPart\"))\n"
	  .. "\t\t\tlocal hum = ch and ch:FindFirstChildOfClass(\"Humanoid\")\n"
	  .. "\t\t\tif not at or not hum or hum.Health <= 0 then return end\n"
	  .. "\t\t\tlastThrow[player] = os.clock()\n"
	  .. "\t\t\tlocal left = player:GetAttribute(cfg.ChargesAttribute) or 0\n"
	  .. "\t\t\tif not GadgetConfig.InfiniteCharges or ReplicatedStorage:GetAttribute(\"LiveMatch\") then player:SetAttribute(cfg.ChargesAttribute, math.max(left - 1, 0)) end\n"
	  .. "\t\t\tlocal shootables = Get(\"ShootableManager\")\n"
	  .. "\t\t\tif shootables then shootables.Explode(at.Position, \"Frag\", player) end\n"
	  .. "\t\tend)\n"
	  .. "\t\treturn\n"
	  .. "\tend\n"
	  .. "\tlocal fuseLeft = nil\n"
	  .. "\tif cfg.Cook then\n"
	  .. "\t\tlocal c = cooks[player]\n"
	  .. "\t\tif c and c.gadget == gadget then\n"
	  .. "\t\t\tfuseLeft = math.max(cfg.FuseTime - (os.clock() - c.start), 0.05)\n"
	  .. "\t\telseif os.clock() - (cookedOut[player] or 0) < 1.5 then\n"
	  .. "\t\t\treturn -- it already went off in the hand: the late release throws nothing\n"
	  .. "\t\tend\n"
	  .. "\t\tcooks[player] = nil\n"
	  .. "\t\tplayer:SetAttribute(\"CookStart\", nil)\n"
	  .. "\t\tplayer:SetAttribute(\"CookFuse\", nil)\n"
	  .. "\tend\n"
	  .. "\tlocal now = os.clock()\n\tif now - (lastThrow[player] or 0) < cfg.Cooldown then return end\n" },
	{ "\tthrowGrenade(gadget, player.Character, direction, power, mode, side)\n",
	  "\tthrowGrenade(gadget, player.Character, direction, power, mode, side, fuseLeft) -- [COOK] fuseLeft\n" },
	{ "local function onThrow(player: Player, gadget: any, direction: any, power: any, mode: any, side: any)\n",
	  "local cooks = setmetatable({}, { __mode = \"k\" }) -- [COOK] [Player] = { start, gadget, token }\n"
	  .. "local cookedOut = setmetatable({}, { __mode = \"k\" }) -- [COOK] [Player] = os.clock() of a blow-up in hand\n"
	  .. "local function onThrow(player: Player, gadget: any, direction: any, power: any, mode: any, side: any)\n" },
}))
return (UNDO and "UNDO " or "COOK ") .. table.concat(res, " | ")
