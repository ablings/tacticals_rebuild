-- AdminFramework/Commands/NetDebug [HITDEBUG] 2026-10-18 (Edward: dying "fully behind a pillar"; testing peeks with a friend).
--   ;hitdebug [on|off] [player]   every claimed hit on a character in this server is drawn on that player's screen for a few
--                                 seconds (StarterPlayerScripts.HitDebugView): where the server rewound the target to (green =
--                                 accepted, red = rejected), where it is now (blue), the claimed point (yellow), the shot line,
--                                 and a label: who shot whom, the part, accepted / why not, how far back the server looked (ms),
--                                 the lag window and the shooter's ping. Off by default.
return {
	{
		name = "hitdebug", aliases = { "hd" }, level = "Admin",
		description = "[on|off] [player]: show every hit check (where the server had the target, accepted / rejected and why).",
		args = {
			{ name = "on", type = "boolean", optional = true },
			{ name = "player", type = "players", defaultToken = "me" },
		},
		run = function(ctx, a)
			local names = {}
			for _, p in a.player do
				local on = a.on
				if on == nil then on = not p:GetAttribute("HitDebug") end
				p:SetAttribute("HitDebug", on or nil)
				table.insert(names, p.Name .. (on and " ON" or " off"))
			end
			return true, "Hit debug: " .. table.concat(names, ", ")
		end,
	},
}
