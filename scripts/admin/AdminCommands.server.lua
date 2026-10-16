-- [ADMIN] ServerScriptService/AdminCommands (Script): entry points of the admin framework (notes/admin_framework.md, 2026-10-16).
-- Replaces the old chat-command script (original: ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig); its commands still
-- work (Commands/Legacy). The framework itself is ServerScriptService.AdminFramework (Config, Permissions, Args, DataAdapter,
-- Audit, Core, Commands/*). Same files in the lobby and the match place.
-- Entry points (all end in Core.Run on the server, which checks the caller's level; the client never decides):
--   1. Chat: ";cmd args" (and the old "/scissors" etc.). TextChatService.AdminCommands holds one TextChatCommand per name /
--      alias, so the text never shows as a chat message; StarterPlayerScripts.AdminFeedback forwards it via AdminRequest.
--   2. Admin panel (UI session, notes/admin_ui_requests.md): ReplicatedStorage.AdminRemote (RemoteFunction)
--      InvokeServer("commands") / ("run", text) / ("whoami") / ("audit", n).
--   3. Studio command bar / MCP: ServerStorage.AdminBindable (BindableFunction, server only)
--      Invoke("run", text, userId)      as that player (their real level), feedback in their chat
--      Invoke("console", text, userId?) as the server console (Owner); "me" = that player
--      Invoke("simlevel", userId, "None"|"Tester"|"Admin"|nil)   Studio only
--      Invoke("audit", n) / Invoke("list")
-- Feedback: ReplicatedStorage.AdminFeedback:FireClient(player, line, kind) -> a system line in chat (AdminFeedback LocalScript).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Framework = ServerScriptService:WaitForChild("AdminFramework")
local Core = require(Framework.Core)
local Config = require(Framework.Config)
Core.LoadCommands(Framework.Commands)

local function remote(class: string, name: string)
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and not r:IsA(class) then r:Destroy(); r = nil end
	if not r then r = Instance.new(class); r.Name = name; r.Parent = ReplicatedStorage end
	return r
end
local feedback = remote("RemoteEvent", "AdminFeedback")
local request = remote("RemoteEvent", "AdminRequest")
local panel = remote("RemoteFunction", "AdminRemote")

local MAX_LINES = 24
Core.Notify = function(player: Player?, text: string, kind)
	if not player then print("[Admin] " .. tostring(text)) return end
	if not player.Parent then return end
	feedback:FireClient(player, string.sub(tostring(text), 1, 400), kind)
	if kind == "announce" then
		local lobby = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Lobby")
		local toast = lobby and lobby:FindFirstChild("Notify")
		if toast and toast:IsA("RemoteEvent") then toast:FireClient(player, text, "info") end
	end
end

local function send(player: Player?, result)
	local kind = result.ok and true or false
	if result.needsConfirm then kind = "info" end
	for i, line in result.lines do
		if i > MAX_LINES then Core.Notify(player, ("(%d more lines)"):format(#result.lines - MAX_LINES), "info") break end
		-- the last line carries ok / error colour, the lines before it are plain output
		local k = "info"
		if i == #result.lines then k = kind end -- (not `cond and kind or "info"`: kind can be false)
		Core.Notify(player, line, k)
	end
end

-- 1. Chat ---------------------------------------------------------------------------------------------------------------------
local LEGACY = { scissors = true, give = true, wipeweapons = true, unlockall = true, admin = true }
local folder = TextChatService:FindFirstChild("AdminCommands") or Instance.new("Folder")
folder.Name = "AdminCommands"
folder:ClearAllChildren()
local made = {}
local function chatCommand(word: string)
	if made[word] or not string.match(word, "^[%w_%?]+$") then return end
	made[word] = true
	local c = Instance.new("TextChatCommand")
	c.Name = "Admin_" .. word
	c.PrimaryAlias = Config.Prefix .. word
	c.SecondaryAlias = LEGACY[word] and (Config.LegacyPrefix .. word) or ""
	c.AutocompleteVisible = false
	c.Parent = folder
end
for _, def in Core.Commands do
	chatCommand(def.name)
	for _, a in def.aliases or {} do chatCommand(string.lower(a)) end
end
folder.Parent = TextChatService

local last = {}
local function limited(player: Player): boolean
	local t = os.clock()
	if last[player] and t - last[player] < Config.RateLimit then return true end
	last[player] = t
	return false
end
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

request.OnServerEvent:Connect(function(player: Player, text: any)
	if typeof(text) ~= "string" or #text > Config.MaxTextLength or limited(player) then return end
	local result = Core.Run(player, text, "chat")
	-- non-admins typing something that isn't a command hear nothing
	if result.unknown and Core.Permissions.LevelOf(player) == 0 then return end
	send(player, result)
end)

-- A mistyped ";command" from an admin matches no TextChatCommand and would be posted as a chat message: hold it back
-- (ShouldDeliverCallback, server) and answer "unknown command" instead. Anyone else's ";..." is normal chat.
local seenMsg = {}
local function guardChannel(channel: Instance)
	if not channel:IsA("TextChannel") then return end
	channel.ShouldDeliverCallback = function(message: TextChatMessage, _target: TextSource)
		local src = message.TextSource
		local text = message.Text
		if not src or type(text) ~= "string" or not string.match(text, "^%" .. Config.Prefix .. "%a") then return true end
		local sender = Players:GetPlayerByUserId(src.UserId)
		if not sender or Core.Permissions.LevelOf(sender) == 0 then return true end
		if not seenMsg[message.MessageId] then
			seenMsg[message.MessageId] = os.clock()
			task.spawn(function() send(sender, Core.Run(sender, text, "chat")) end)
		end
		return false
	end
end
task.spawn(function()
	-- the default channels are created a moment after the server starts
	local channels = TextChatService:WaitForChild("TextChannels", 30)
	if not channels then return end
	for _, c in channels:GetChildren() do guardChannel(c) end
	channels.ChildAdded:Connect(guardChannel)
end)
task.spawn(function()
	while true do
		task.wait(60)
		for id, t in seenMsg do if os.clock() - t > 60 then seenMsg[id] = nil end end
	end
end)

-- 2. Admin panel ------------------------------------------------------------------------------------------------------------
local function describe(def)
	local args = {}
	for _, a in def.args do
		table.insert(args, { name = a.name, type = a.type, optional = a.optional == true, choices = a.choices, min = a.min, max = a.max,
			default = a.defaultToken or (type(a.default) ~= "function" and a.default or nil) })
	end
	return { name = def.name, aliases = def.aliases or {}, group = def.group, level = def.level, description = def.description or "",
		usage = Core.Usage(def), destructive = def.destructive == true, args = args }
end
panel.OnServerInvoke = function(player: Player, action: any, payload: any)
	-- only "run" is rate-limited (the panel reads whoami + commands together when it opens)
	if action == "run" and limited(player) then return { ok = false, lines = { "slow down" } } end
	local level = Core.Permissions.LevelOf(player)
	if action == "whoami" then
		return { ok = true, level = level, levelName = Core.Permissions.Name(level), prefix = Config.Prefix }
	end
	if level == 0 then return { ok = false, lines = { "You're not allowed to use admin commands." } } end
	if action == "commands" then
		local list = {}
		for _, def in Core.Visible(level) do table.insert(list, describe(def)) end
		return { ok = true, commands = list, level = level, levelName = Core.Permissions.Name(level) }
	elseif action == "run" then
		if typeof(payload) ~= "string" or #payload > Config.MaxTextLength then return { ok = false, lines = { "bad command text" } } end
		local r = Core.Run(player, payload, "panel")
		return { ok = r.ok, lines = r.lines, needsConfirm = r.needsConfirm, command = r.command }
	elseif action == "audit" then
		if level < Core.Permissions.Values.Admin then return { ok = false, lines = { "audit needs Admin" } } end
		return { ok = true, entries = Core.Audit.Recent(math.clamp(tonumber(payload) or 20, 1, 50)) }
	end
	return { ok = false, lines = { "unknown action" } }
end

-- 3. Studio command bar / MCP ------------------------------------------------------------------------------------------------
local bindable = ServerStorage:FindFirstChild("AdminBindable") or Instance.new("BindableFunction")
bindable.Name = "AdminBindable"
bindable.OnInvoke = function(action: string, a, b, c)
	if action == "run" then
		local p = Players:GetPlayerByUserId(tonumber(b) or 0) or (b == nil and Players:GetPlayers()[1])
		if not p then return { ok = false, lines = { "no such player" } } end
		local r = Core.Run(p, a, "bindable")
		if not (r.unknown and Core.Permissions.LevelOf(p) == 0) then send(p, r) end
		return r
	elseif action == "console" then
		local me = b and Players:GetPlayerByUserId(tonumber(b) or 0) or nil
		local r = Core.Run(nil, a, "console", { forceLevel = Core.Permissions.Values.Owner, me = me })
		for _, l in r.lines do print("[Admin console] " .. l) end
		return r
	elseif action == "simlevel" then
		return Core.Permissions.SetSimulated(tonumber(a) or 0, b)
	elseif action == "audit" then
		return Core.Audit.Recent(tonumber(a) or 20)
	elseif action == "list" then
		local t = {}
		for _, def in Core.Commands do table.insert(t, def.name) end
		return t
	end
	return "unknown action " .. tostring(action)
end
bindable.Parent = ServerStorage

print(("[Admin] ready: %d commands, prefix %s, group %d, data layer %s"):format(#Core.Commands, Config.Prefix,
	Core.Permissions.GroupId(), Core.Data.HasPlayerStore and "PlayerStore" or "DataManager replicas"))
