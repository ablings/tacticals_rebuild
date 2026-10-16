-- ServerScriptService/AdminFramework/Args (ModuleScript): typed argument parsing for admin commands.
-- A command declares args = { { name = "player", type = "players" }, { name = "n", type = "integer", min = 1, optional = true, default = 1 } }.
-- Types:
--   players   one or more players: me, all, others, @userid, a name / display-name prefix, or a comma list ("me,bob")
--   player    exactly one player (same selectors)
--   number, integer (min / max), boolean (on/off, true/false, yes/no, 1/0), string, rest (the rest of the line)
--   choice    one of `choices` (case-insensitive)
--   item      an item id or name from the catalogue (LobbyConfig.Items), validated
--   stat      a stat setstat can change (DataAdapter.StatList), validated
--   level     None / Tester / Admin / Owner
-- Errors are plain sentences the caller sees in chat.
local Players = game:GetService("Players")
local DataAdapter = require(script.Parent.DataAdapter)
local Permissions = require(script.Parent.Permissions)

local Args = {}

-- split on spaces, keep "quoted strings" together
function Args.Tokenize(text: string): { string }
	local out = {}
	local i, n = 1, #text
	while i <= n do
		local c = string.sub(text, i, i)
		if c == " " or c == "\t" then
			i += 1
		elseif c == '"' then
			local j = string.find(text, '"', i + 1, true) or (n + 1)
			table.insert(out, string.sub(text, i + 1, j - 1))
			i = j + 1
		else
			local j = string.find(text, "[ \t]", i) or (n + 1)
			table.insert(out, string.sub(text, i, j - 1))
			i = j
		end
	end
	return out
end

local function names(list)
	local t = {}
	for _, p in list do table.insert(t, p.Name) end
	return table.concat(t, ", ")
end

local function onePart(part: string, ctx): ({ Player }?, string?)
	local t = string.lower(part)
	local caller = ctx.caller
	if t == "me" then
		if not caller then return nil, "\"me\" needs a player (the server console has none)" end
		return { caller }
	elseif t == "all" or t == "everyone" then
		return Players:GetPlayers()
	elseif t == "others" then
		local list = {}
		for _, p in Players:GetPlayers() do if p ~= caller then table.insert(list, p) end end
		if #list == 0 then return nil, "\"others\" matches nobody: you're the only player here" end
		return list
	elseif string.sub(t, 1, 1) == "@" then
		local id = tonumber(string.sub(t, 2))
		if not id then return nil, ("\"%s\" isn't a user id (use @12345)"):format(part) end
		local p = Players:GetPlayerByUserId(id)
		if not p then return nil, ("no player with user id %d in this server"):format(id) end
		return { p }
	end
	local exact, partial = {}, {}
	for _, p in Players:GetPlayers() do
		local n, d = string.lower(p.Name), string.lower(p.DisplayName)
		if n == t or d == t then table.insert(exact, p)
		elseif string.sub(n, 1, #t) == t or string.sub(d, 1, #t) == t then table.insert(partial, p) end
	end
	local list = #exact > 0 and exact or partial
	if #list == 0 then return nil, ("no player here matches \"%s\""):format(part) end
	if #list > 1 then return nil, ("\"%s\" matches %s: type more of the name"):format(part, names(list)) end
	return list
end

-- returns players, multi (true when the selector can mean several: all / others / a list)
function Args.Players(token: string, ctx): ({ Player }?, string?, boolean?)
	local out, seen, multi = {}, {}, false
	for part in string.gmatch(token, "[^,]+") do
		local t = string.lower(part)
		if t == "all" or t == "everyone" or t == "others" then multi = true end
		local list, err = onePart(part, ctx)
		if not list then return nil, err end
		for _, p in list do if not seen[p] then seen[p] = true; table.insert(out, p) end end
	end
	if #out == 0 then return nil, "nobody matches \"" .. token .. "\"" end
	if #out > 1 then multi = true end
	return out, nil, multi
end

local TRUE = { on = true, ["true"] = true, yes = true, ["1"] = true, enable = true, enabled = true }
local FALSE = { off = true, ["false"] = true, no = true, ["0"] = true, disable = true, disabled = true }

Args.Types = {}
Args.Types.players = function(tok, spec, ctx)
	local list, err, multi = Args.Players(tok, ctx)
	if not list then return nil, err end
	ctx.multiTarget = ctx.multiTarget or multi
	return list
end
Args.Types.player = function(tok, spec, ctx)
	local list, err = Args.Players(tok, ctx)
	if not list then return nil, err end
	if #list ~= 1 then return nil, ("%s needs exactly one player, \"%s\" is %d"):format(spec.name, tok, #list) end
	return list[1]
end
Args.Types.number = function(tok, spec)
	local n = tonumber(tok)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil, ("%s must be a number, not \"%s\""):format(spec.name, tok) end
	if spec.min and n < spec.min then return nil, ("%s must be at least %s"):format(spec.name, spec.min) end
	if spec.max and n > spec.max then return nil, ("%s must be at most %s"):format(spec.name, spec.max) end
	return n
end
Args.Types.integer = function(tok, spec)
	local n, err = Args.Types.number(tok, spec)
	if not n then return nil, err end
	if n ~= math.floor(n) then return nil, ("%s must be a whole number, not \"%s\""):format(spec.name, tok) end
	return n
end
Args.Types.boolean = function(tok, spec)
	local t = string.lower(tok)
	if TRUE[t] then return true end
	if FALSE[t] then return false end
	return nil, ("%s must be on or off, not \"%s\""):format(spec.name, tok)
end
Args.Types.string = function(tok) return tok end
Args.Types.rest = function(tok) return tok end -- Parse already joined the rest of the line
Args.Types.choice = function(tok, spec)
	local t = string.lower(tok)
	for _, c in spec.choices do if string.lower(c) == t then return c end end
	return nil, ("%s must be one of %s, not \"%s\""):format(spec.name, table.concat(spec.choices, " | "), tok)
end
Args.Types.item = function(tok)
	local id, err = DataAdapter.FindItem(tok)
	if not id then return nil, err end
	return id
end
Args.Types.stat = function(tok)
	local s = DataAdapter.FindStat(tok)
	if not s then return nil, ("no stat \"%s\". Stats: %s"):format(tok, table.concat(DataAdapter.StatList(), ", ")) end
	return s
end
Args.Types.level = function(tok, spec)
	local name = Permissions.Parse(tok)
	if not name then return nil, ("%s must be None, Tester, Admin or Owner"):format(spec.name) end
	return name
end

function Args.Usage(def): string
	local bits = { (def.prefix or ";") .. def.name }
	for _, a in def.args or {} do
		local label = a.name
		if a.type == "choice" then label = table.concat(a.choices, "|") end
		table.insert(bits, a.optional and ("[" .. label .. "]") or ("<" .. label .. ">"))
	end
	return table.concat(bits, " ")
end

-- tokens (without the command name) -> values (by name and by index) or nil, error
function Args.Parse(def, tokens: { string }, ctx)
	local values, specs = {}, def.args or {}
	local i = 1
	for idx, spec in specs do
		local tok = tokens[i]
		if spec.type == "rest" then
			if i <= #tokens then
				tok = table.concat(tokens, " ", i)
				i = #tokens + 1
			end
		else
			i += 1
		end
		local v
		if (tok == nil or tok == "") and spec.defaultToken then tok = spec.defaultToken end -- e.g. "me"
		if tok == nil or tok == "" then
			if not spec.optional then return nil, ("missing %s. Usage: %s"):format(spec.name, Args.Usage(def)) end
			v = spec.default
			if type(v) == "function" then v = v(ctx) end
		else
			local parser = Args.Types[spec.type]
			if not parser then return nil, "bad arg type " .. tostring(spec.type) end
			local err
			v, err = parser(tok, spec, ctx)
			if v == nil then return nil, err .. ". Usage: " .. Args.Usage(def) end
		end
		values[spec.name] = v
		values[idx] = v
	end
	if i <= #tokens then
		return nil, ("too many arguments (\"%s\"). Usage: %s"):format(table.concat(tokens, " ", i), Args.Usage(def))
	end
	return values
end

return Args
