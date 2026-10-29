
local RS = game:GetService("ReplicatedStorage")
local res = {}

local function resolve(path: string): Instance?
	local node: Instance? = game
	for seg in path:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

local IDENT = "[%w_]"
local function boundaryOk(s: string, a: number, b: number): boolean
	if a > 1 and s:sub(a, a):match(IDENT) and s:sub(a - 1, a - 1):match(IDENT) then return false end
	if b < #s and s:sub(b, b):match(IDENT) and s:sub(b + 1, b + 1):match(IDENT) then return false end
	return true
end

-- the round stamp: refuse any other round, and an unstamped install
local STAMP_ON = RS.Modules.Shared.Config.CoverConfig
local stamp = STAMP_ON:GetAttribute("MoveRework1029Round")
if not UNDO then
	assert(stamp == nil or stamp == ROUND, "MOVE1029 round " .. tostring(stamp) .. " is installed: UNDO it with that round's installer first")
	assert(stamp == ROUND or not STAMP_ON.Source:find("[MOVE1029]", 1, true), "an unstamped MOVE1029 install is in CoverConfig: UNDO it first")
else
	assert(stamp == nil or stamp == ROUND, "MOVE1029 round " .. tostring(stamp) .. " is installed: UNDO it with that round's installer")
end

-- pass 1: work out every new source (nothing written yet)
local plan = {}
for _, t in TARGETS do
	local inst = resolve(t.path)
	local short = t.path:match("[^%.]+$")
	if not inst then
		assert(t.optional, "missing script " .. t.path)
		table.insert(res, short .. " n/a")
		continue
	end
	local s = inst.Source:gsub("\r\n", "\n")
	local marks = {}
	for i, e in t.edits do
		local source, target = e[1], e[2]
		if UNDO then source, target = e[2], e[1] end
		local done
		if UNDO then done = s:find(source, 1, true) == nil else done = s:find(target, 1, true) ~= nil end
		if done then
			table.insert(marks, i .. "=")
		else
			local a, b = s:find(source, 1, true)
			assert(a, short .. " edit " .. i .. " anchor not found")
			assert(not s:find(source, b + 1, true), short .. " edit " .. i .. " anchor not unique")
			assert(boundaryOk(s, a, b), short .. " edit " .. i .. " anchor not at a token boundary")
			s = s:sub(1, a - 1) .. target .. s:sub(b + 1)
			table.insert(marks, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, short .. " would not parse: " .. tostring(err))
	-- keep the script's own line endings (some lobby scripts are CRLF): UNDO then gives back the exact bytes
	if inst.Source:find("\r\n", 1, true) then s = s:gsub("\n", "\r\n") end
	table.insert(plan, { inst = inst, src = s, line = short .. " " .. table.concat(marks, " ") })
end

-- pass 2: stamp, then write
if not UNDO then STAMP_ON:SetAttribute("MoveRework1029Round", ROUND) end
for _, p in plan do
	if p.inst.Source ~= p.src then p.inst.Source = p.src end
	table.insert(res, p.line)
end

-- the shared rules module and the MoveAction remote
local shared1029 = RS.Modules.Shared
local mr = shared1029:FindFirstChild("MoveRules")
if UNDO then
	if mr and mr:GetAttribute("MoveRework1029") then mr:Destroy() table.insert(res, "MoveRules -") end
else
	if not mr then
		mr = Instance.new("ModuleScript")
		mr.Name = "MoveRules"
		mr:SetAttribute("MoveRework1029", true)
		mr.Source = MOVERULES_SRC
		mr.Parent = shared1029
		table.insert(res, "MoveRules +")
	else
		assert(mr:GetAttribute("MoveRework1029"), "a MoveRules module that isn't ours is in the place")
		if mr.Source ~= MOVERULES_SRC then mr.Source = MOVERULES_SRC table.insert(res, "MoveRules ~") else table.insert(res, "MoveRules =") end
	end
end
local movementEvents = RS.Events.Movement
local ma = movementEvents:FindFirstChild("MoveAction")
if UNDO then
	if ma and ma:GetAttribute("MoveRework1029") then ma:Destroy() table.insert(res, "MoveAction -") end
else
	if not ma then
		ma = Instance.new("RemoteEvent")
		ma.Name = "MoveAction"
		ma:SetAttribute("MoveRework1029", true)
		ma.Parent = movementEvents
		table.insert(res, "MoveAction +")
	else
		table.insert(res, "MoveAction =")
	end
end
if UNDO then STAMP_ON:SetAttribute("MoveRework1029Round", nil) end

-- a hash of everything this touches, to prove UNDO -> before
local h = 0
for _, t in TARGETS do
	local inst = resolve(t.path)
	if inst then
		local s = inst.Source
		for i = 1, #s, 7 do h = (h * 31 + s:byte(i)) % 4294967291 end
	end
end
table.insert(res, ("hash %08x"):format(h))
return (UNDO and "UNDO " or "") .. "MOVE1029 round " .. ROUND .. ": " .. table.concat(res, " | ")
