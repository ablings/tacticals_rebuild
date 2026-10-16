-- ServerScriptService/AdminFramework/Core (ModuleScript): command registry and dispatcher (notes/admin_framework.md).
--   Core.LoadCommands(folder)        require every ModuleScript in Commands/ (each returns a list of command defs)
--   Core.Run(caller, text, source)   -> { ok, lines = {...}, command }   caller = Player, or nil for the server console
--   Core.Visible(level)              -> command defs this level may run (help / admin panel)
-- A command def:
--   { name = "setlevel", aliases = { "level" }, group = "Data", level = "Tester", description = "...",
--     args = { { name = "player", type = "players", defaultToken = "me" }, { name = "level", type = "integer", min = 1 } },
--     destructive = true?,        -- needs "<same command> confirm" within Config.ConfirmWindow s; on several players Owner only
--     studioOnly = true?,         -- refused outside Studio
--     place = "lobby" | "match"?,  -- only registered in that place (Core.Place: "lobby" when Workspace.LobbyMap exists)
--     run = function(ctx, args) ... return true, "message" | false, "error" end }
--   ctx = { caller, level (number), levelName, source, targets (players parsed), reply(line), Core, Data (DataAdapter) }
-- Rules applied here, never by a command: level check, Testers may only target themselves, nobody targets a player
-- with a higher level, the confirm token, the audit log.
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Permissions = require(script.Parent.Permissions)
local Args = require(script.Parent.Args)
local Audit = require(script.Parent.Audit)
local DataAdapter = require(script.Parent.DataAdapter)

local IS_STUDIO = RunService:IsStudio()
local Core = { Commands = {}, ByName = {}, Groups = {} }
-- which place this server is: the lobby (Workspace.LobbyMap) or the match / tutorial place (notes/match_place_flow.md)
Core.Place = workspace:FindFirstChild("LobbyMap") and "lobby" or "match"
Core.Permissions, Core.Args, Core.Audit, Core.Data, Core.Config = Permissions, Args, Audit, DataAdapter, Config

-- Core.Notify(player, text, kind) shows a line in that player's chat; set by the AdminCommands script (kind: true/false/"info"/"announce")
Core.Notify = function(_player, text) print("[Admin] " .. tostring(text)) end

local pendingConfirm = {} -- [callerKey .. "|" .. normalised text] = os.clock()

function Core.Register(def)
	assert(type(def.name) == "string" and type(def.run) == "function", "admin command needs name + run")
	def.name = string.lower(def.name)
	def.level = def.level or "Admin"
	assert(Permissions.Values[def.level], "bad level for " .. def.name)
	def.args = def.args or {}
	def.group = def.group or "Misc"
	-- a command for the other place is left out here (help, the panel and chat never see it)
	if def.place and def.place ~= Core.Place then return end
	if Core.ByName[def.name] then warn("[Admin] duplicate command " .. def.name .. " (later one wins)") end
	table.insert(Core.Commands, def)
	Core.ByName[def.name] = def
	for _, a in def.aliases or {} do
		a = string.lower(a)
		if Core.ByName[a] and Core.ByName[a] ~= def then warn("[Admin] alias " .. a .. " of " .. def.name .. " shadows another command") end
		Core.ByName[a] = def
	end
	Core.Groups[def.group] = Core.Groups[def.group] or {}
	table.insert(Core.Groups[def.group], def)
end

function Core.LoadCommands(folder: Instance)
	local mods = folder:GetChildren()
	table.sort(mods, function(a, b) return a.Name < b.Name end)
	for _, m in mods do
		if m:IsA("ModuleScript") then
			local ok, list = pcall(require, m)
			if not ok then warn("[Admin] command module " .. m.Name .. " failed: " .. tostring(list)) continue end
			for _, def in list do
				def.group = def.group or m.Name
				local okR, err = pcall(Core.Register, def)
				if not okR then warn("[Admin] " .. m.Name .. ": " .. tostring(err)) end
			end
		end
	end
end

function Core.Visible(level: number)
	local out = {}
	for _, def in Core.Commands do
		if Permissions.Value(def.level) <= level and (not def.studioOnly or IS_STUDIO) then table.insert(out, def) end
	end
	table.sort(out, function(a, b) if a.group ~= b.group then return a.group < b.group end return a.name < b.name end)
	return out
end

function Core.Usage(def) return Args.Usage(def) end

local function playerNames(list)
	local t = {}
	for _, p in list do table.insert(t, p.Name) end
	return table.concat(t, ",")
end

-- caller: Player or nil (console). opts.forceLevel (console bindable), opts.me (who "me" is for the console)
function Core.Run(caller: Player?, text: string, source: string?, opts)
	opts = opts or {}
	local lines = {}
	local result = { ok = false, lines = lines }
	if type(text) ~= "string" then table.insert(lines, "bad command text") return result end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local prefix = string.sub(text, 1, 1)
	if prefix == Config.Prefix or prefix == Config.LegacyPrefix then text = string.sub(text, 2) end
	local tokens = Args.Tokenize(text)
	local name = string.lower(table.remove(tokens, 1) or "")
	local def = Core.ByName[name]
	local level, why = Permissions.LevelOf(caller)
	if opts.forceLevel then level, why = opts.forceLevel, "server console" end
	local levelName = Permissions.Name(level)
	local adminName = caller and caller.Name or "console"
	local function audit(ok, msg, targets)
		Audit.Log({ admin = adminName, adminId = caller and caller.UserId or 0, level = levelName, command = def and def.name or name,
			args = table.concat(tokens, " "), targets = targets, ok = ok, result = msg, source = source })
	end
	if name == "" then table.insert(lines, "type " .. Config.Prefix .. "cmds for the command list") return result end
	if not def then
		result.unknown = true
		table.insert(lines, ("unknown command \"%s\". Type %scmds for the list."):format(name, Config.Prefix))
		return result
	end
	result.command = def.name
	if level < Permissions.Value(def.level) then
		local msg = level == 0 and "You're not allowed to use admin commands." or
			("%s%s needs %s (you are %s)."):format(Config.Prefix, def.name, def.level, levelName)
		table.insert(lines, msg)
		audit(false, "denied: " .. levelName)
		return result
	end
	if def.studioOnly and not IS_STUDIO then
		table.insert(lines, Config.Prefix .. def.name .. " only works in Studio.")
		return result
	end
	-- trailing "confirm"
	local confirming = false
	if def.destructive and #tokens > 0 and string.lower(tokens[#tokens]) == "confirm" then
		confirming = true
		table.remove(tokens)
	end
	local ctx = { caller = caller, me = caller or opts.me, level = level, levelName = levelName, source = source, Core = Core,
		Data = DataAdapter, lines = lines, why = why }
	ctx.caller = caller or opts.me -- "me" for the console is opts.me
	function ctx.reply(line) table.insert(lines, tostring(line)) end
	local values, err = Args.Parse(def, tokens, ctx)
	if not values then
		table.insert(lines, err)
		audit(false, err)
		return result
	end
	-- who is targeted
	local targets = {}
	for _, spec in def.args do
		local v = values[spec.name]
		if spec.type == "players" and type(v) == "table" then for _, p in v do table.insert(targets, p) end
		elseif spec.type == "player" and v then table.insert(targets, v) end
	end
	ctx.targets = targets
	local targetText = #targets > 0 and playerNames(targets) or nil
	for _, p in targets do
		if p ~= caller then
			if caller and level < Permissions.Values.Admin and not def.anyTarget then
				local msg = ("Testers can only use %s%s on themselves."):format(Config.Prefix, def.name)
				table.insert(lines, msg); audit(false, msg, targetText); return result
			end
			local theirs = Permissions.LevelOf(p)
			if caller and theirs > level and not def.anyTarget then
				local msg = ("%s is %s, above you (%s)."):format(p.Name, Permissions.Name(theirs), levelName)
				table.insert(lines, msg); audit(false, msg, targetText); return result
			end
		end
	end
	if def.destructive then
		local several = ctx.multiTarget or #targets > 1
		if several and level < Permissions.Values.Owner then
			local msg = ("%s%s on several players is Owner only."):format(Config.Prefix, def.name)
			table.insert(lines, msg); audit(false, msg, targetText); return result
		end
		local key = (caller and caller.UserId or 0) .. "|" .. def.name .. " " .. string.lower(table.concat(tokens, " "))
		if not confirming then
			pendingConfirm[key] = os.clock()
			local what = def.confirmText and def.confirmText(ctx, values) or (def.name .. " " .. table.concat(tokens, " "))
			local again = Config.Prefix .. name .. (#tokens > 0 and (" " .. table.concat(tokens, " ")) or "") .. " confirm"
			table.insert(lines, ("This will %s. To go ahead type: %s   (within %d s)"):format(what, again, Config.ConfirmWindow))
			result.ok = true
			result.needsConfirm = true
			audit(true, "awaiting confirm", targetText)
			return result
		end
		local t = pendingConfirm[key]
		pendingConfirm[key] = nil
		if not t or os.clock() - t > Config.ConfirmWindow then
			local msg = t and "That confirm came too late (over " .. Config.ConfirmWindow .. " s). Run it again without confirm first."
				or "Nothing to confirm: run the command without confirm first."
			table.insert(lines, msg); audit(false, msg, targetText); return result
		end
	end
	local ok, a, b = pcall(def.run, ctx, values)
	if not ok then
		warn("[Admin] " .. def.name .. " failed: " .. tostring(a))
		table.insert(lines, "That command failed: " .. tostring(a))
		audit(false, "error: " .. tostring(a), targetText)
		return result
	end
	local good = a ~= false
	if type(b) == "string" then table.insert(lines, b) elseif type(a) == "string" then table.insert(lines, a) end
	result.ok = good
	audit(good, lines[#lines], targetText)
	return result
end

-- clean up stale confirm tokens now and then
task.spawn(function()
	while true do
		task.wait(30)
		for k, t in pendingConfirm do if os.clock() - t > Config.ConfirmWindow then pendingConfirm[k] = nil end end
	end
end)

return Core
