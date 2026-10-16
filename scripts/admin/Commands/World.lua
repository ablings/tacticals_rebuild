-- AdminFramework/Commands/World: server-wide things.
local Players = game:GetService("Players")

return {
	{
		name = "announce", aliases = { "m", "say" }, level = "Admin", description = "A system message (and toast in the lobby) to everyone here.",
		args = { { name = "text", type = "rest" } },
		run = function(ctx, a)
			local text = string.sub(a.text, 1, 160)
			for _, p in Players:GetPlayers() do ctx.Core.Notify(p, text, "announce") end
			return true, "Announced to " .. #Players:GetPlayers() .. " player(s)."
		end,
	},
	{
		name = "pads", level = "Tester", description = "Duel pads: mode, state, NoMap, who is on them.",
		run = function(ctx)
			local map = workspace:FindFirstChild("LobbyMap")
			local duels = map and map:FindFirstChild("Duels")
			if not duels then return false, "this place has no LobbyMap.Duels pads" end
			local n = 0
			for _, pad in duels:GetChildren() do
				if pad:IsA("Model") and pad:GetAttribute("QueueName") then
					n += 1
					ctx.reply(("%s  %s  bay %s  %s%s"):format(pad.Name, tostring(pad:GetAttribute("QueueName")), tostring(pad:GetAttribute("BayId")),
						(function() local h = pad:FindFirstChild("Holo"); local v = h and h:GetAttribute("BayStatus"); return type(v) == "string" and v or "" end)(),
						pad:GetAttribute("NoMap") and ("  NoMap: " .. tostring(pad:GetAttribute("NoMapText"))) or ""))
				end
			end
			return true, n .. " pad(s). tp to one with ;tp me 1v1a"
		end,
	},
}
