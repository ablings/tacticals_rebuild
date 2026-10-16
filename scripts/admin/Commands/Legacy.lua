-- AdminFramework/Commands/Legacy: the old ServerScriptService.AdminCommands chat commands, kept working on top of the new
-- framework (original in ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig). Typed with "/" (old) or ";".
--   /scissors 5000 | /scissors set 0   -> addcredits me 5000 | setcredits me 0
--   /give <name> 500                   -> ;give <name> 500 (Data.give: a number = scissors)
--   /wipeweapons                       -> ;wipe me inventory (asks for confirm like every wipe)
--   /unlockall                         -> alias of ;giveall (Data)
--   /admin                             -> ;cmds
return {
	{
		name = "scissors", level = "Tester", description = "Old form: /scissors 5000 adds, /scissors set 0 sets (yours).",
		args = { { name = "amount", type = "rest" } },
		run = function(ctx, a)
			local t = ctx.Core.Args.Tokenize(a.amount)
			local cmd
			if string.lower(t[1] or "") == "set" then cmd = "setcredits me " .. tostring(t[2] or "")
			else cmd = "addcredits me " .. tostring(t[1] or "") end
			local r = ctx.Core.Run(ctx.caller, cmd, (ctx.source or "") .. "/legacy")
			for _, l in r.lines do ctx.reply(l) end
			return r.ok
		end,
	},
	{
		name = "wipeweapons", level = "Admin", destructive = true,
		description = "Old form: lock every item again (back to the default kit). Same as ;wipe me inventory.",
		confirmText = function() return "lock every item you own again (default kit)" end,
		run = function(ctx)
			local D, p = ctx.Data, ctx.caller
			if not p or not D.Ready(p) then return false, "your data hasn't loaded yet" end
			local n = 0
			for _ in (D.Read(p, { "Owned" }) or {}) do n += 1 end
			D.Set(p, { "Owned" }, {}); D.Set(p, { "ItemXP" }, {}); D.Set(p, { "Loadout" }, D.DefaultLoadout())
			D.Refresh(p)
			return true, ("Wiped %d unlocked items. You're back to the default kit."):format(n)
		end,
	},
	{
		name = "admin", level = "Tester", description = "Old form of ;cmds.",
		run = function(ctx)
			local r = ctx.Core.Run(ctx.caller, "cmds", ctx.source)
			for _, l in r.lines do ctx.reply(l) end
			return r.ok
		end,
	},
}
