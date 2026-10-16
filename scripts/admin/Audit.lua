-- ServerScriptService/AdminFramework/Audit (ModuleScript): every command run (or refused) is logged.
--   Audit.Log(entry)   entry = { admin, adminId, level, command, args (text), targets (text), ok, result }
--   Audit.Recent(n)    newest first, from memory (this server)
-- Memory: the last Config.AuditMemory entries. DataStore: Config.AuditStore key "log" keeps the last AuditStoreCap entries
-- across servers, flushed every AuditFlushEvery seconds. If the DataStore can't be used (Studio without API access, outages)
-- the store is switched off for this server with one warning, and the memory log keeps working.
local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

local Audit = {}
local memory = {}
local pending = {}
local storeState = "unused" -- unused | ok | off: <reason>
local store

function Audit.Log(e)
	e.time = os.time()
	e.place = game.PlaceId
	table.insert(memory, e)
	while #memory > (Config.AuditMemory or 200) do table.remove(memory, 1) end
	if not string.find(storeState, "^off") then table.insert(pending, e) end
	print(("[Admin] %s (%s) %s %s -> %s %s"):format(tostring(e.admin), tostring(e.level), tostring(e.command), tostring(e.args or ""),
		e.ok and "ok" or "refused", tostring(e.result or "")))
end

function Audit.Recent(n: number?)
	local out = {}
	for i = #memory, math.max(1, #memory - (n or 10) + 1), -1 do table.insert(out, memory[i]) end
	return out
end

function Audit.StoreState(): string return storeState end

local function flush()
	if #pending == 0 or string.find(storeState, "^off") then return end
	if not store then
		local ok, s = pcall(DataStoreService.GetDataStore, DataStoreService, Config.AuditStore)
		if not ok then storeState = "off: " .. tostring(s); warn("[Admin] audit DataStore off: " .. tostring(s)); pending = {} return end
		store = s
	end
	local batch = pending
	pending = {}
	local ok, err = pcall(store.UpdateAsync, store, "log", function(old)
		local list = type(old) == "table" and old or {}
		for _, e in batch do
			table.insert(list, { t = e.time, a = e.adminId, n = e.admin, l = e.level, c = e.command, x = e.args, g = e.targets,
				ok = e.ok, r = e.result and string.sub(tostring(e.result), 1, 120), p = e.place })
		end
		while #list > (Config.AuditStoreCap or 100) do table.remove(list, 1) end
		return list
	end)
	if ok then storeState = "ok" else storeState = "off: " .. tostring(err); warn("[Admin] audit DataStore off: " .. tostring(err)) end
end

task.spawn(function()
	while true do
		task.wait(Config.AuditFlushEvery or 30)
		flush()
	end
end)
game:BindToClose(function() pcall(flush) end)

return Audit
