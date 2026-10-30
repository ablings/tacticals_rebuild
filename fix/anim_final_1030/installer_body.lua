
local RS = game:GetService("ReplicatedStorage")
local res = {}

local function resolve(path: string): Instance?
	local node: Instance? = game
	for seg in path:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end
-- paths with a "[Server] Init" segment hold a dot-free name; resolve the managers' folder by walking names
local function resolvePath(path: string): Instance?
	local node = resolve(path)
	if node then return node end
	local a, b = path:find("ServerScriptService.ServerScripts.[Server] Init.", 1, true)
	if a == 1 then
		local base = game:GetService("ServerScriptService"):FindFirstChild("ServerScripts")
		base = base and base:FindFirstChild("[Server] Init")
		node = base
		for seg in path:sub(b + 1):gmatch("[^%.]+") do node = node and node:FindFirstChild(seg) end
		return node
	end
	return nil
end

local IDENT = "[%w_]"
local function boundaryOk(s: string, a: number, b: number): boolean
	if a > 1 and s:sub(a, a):match(IDENT) and s:sub(a - 1, a - 1):match(IDENT) then return false end
	if b < #s and s:sub(b, b):match(IDENT) and s:sub(b + 1, b + 1):match(IDENT) then return false end
	return true
end

local STAMP_ON = RS.Modules.Shared.Config.WeaponConfig
local stamp = STAMP_ON:GetAttribute("AnimFinal1030Round")
assert(stamp == nil or stamp == ROUND, "ANIMFINAL round " .. tostring(stamp) .. " is installed: UNDO it with that round's installer first")
if not UNDO then
	assert(stamp == ROUND or not STAMP_ON.Source:find("[ANIMFINAL]", 1, true), "an unstamped ANIMFINAL install is in WeaponConfig: UNDO it first")
end

-- pass 1: work out every new source (nothing written yet)
local plan = {}
for _, t in TARGETS do
	local inst = resolvePath(t.path)
	local short = t.path:match("[^%.]+$")
	if not inst then
		assert(t.optional, "missing script " .. t.path)
		table.insert(res, short .. " n/a")
		continue
	end
	local s = inst.Source:gsub("\r\n", "\n")
	local marks = {}
	local list = t.edits
	if UNDO then -- reverse order: a later edit's text can sit next to an earlier one's
		list = {}
		for i = #t.edits, 1, -1 do table.insert(list, { t.edits[i], i }) end
	else
		local l2 = {}
		for i, e in t.edits do table.insert(l2, { e, i }) end
		list = l2
	end
	for _, pair in list do
		local e, i = pair[1], pair[2]
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
	if inst.Source:find("\r\n", 1, true) then s = s:gsub("\n", "\r\n") end
	table.insert(plan, { inst = inst, src = s, line = short .. " " .. table.concat(marks, " ") })
end
for _, m in MODULES do
	local f, err = loadstring(m.src)
	assert(f, m.name .. " would not parse: " .. tostring(err))
	local parent = resolve(m.parent)
	assert(parent or UNDO, "missing parent " .. m.parent)
	local cur = parent and parent:FindFirstChild(m.name)
	assert(not cur or cur:GetAttribute("AnimFinal1030"), "a " .. m.name .. " that isn't ours is in the place")
end

-- pass 2: stamp, then write
if not UNDO then STAMP_ON:SetAttribute("AnimFinal1030Round", ROUND) end
for _, p in plan do
	if p.inst.Source ~= p.src then p.inst.Source = p.src end
	table.insert(res, p.line)
end
for _, m in MODULES do
	local parent = resolve(m.parent)
	local cur = parent and parent:FindFirstChild(m.name)
	if UNDO then
		if cur then cur:Destroy() table.insert(res, m.name .. " -") end
	elseif not cur then
		local ms = Instance.new("ModuleScript")
		ms.Name = m.name
		ms:SetAttribute("AnimFinal1030", true)
		ms.Source = m.src
		ms.Parent = parent
		table.insert(res, m.name .. " +")
	elseif cur.Source ~= m.src then
		cur.Source = m.src
		table.insert(res, m.name .. " ~")
	else
		table.insert(res, m.name .. " =")
	end
end
if UNDO then STAMP_ON:SetAttribute("AnimFinal1030Round", nil) end

local h = 0
for _, t in TARGETS do
	local inst = resolvePath(t.path)
	if inst then
		local s = inst.Source
		for i = 1, #s, 7 do h = (h * 31 + s:byte(i)) % 4294967291 end
	end
end
table.insert(res, ("hash %08x"):format(h))
return (UNDO and "UNDO " or "") .. "ANIMFINAL round " .. ROUND .. ": " .. table.concat(res, " | ")
