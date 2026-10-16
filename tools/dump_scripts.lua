-- Dump every script's path, length and a cheap hash (read-only). Used to diff the copy against the main game.
local HS = game:GetService("HttpService")
local function h(s)
	local a, b = 1, 0
	for i = 1, #s, 3 do
		a = (a + s:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end
local out = {}
local roots = {"Workspace","ReplicatedFirst","ReplicatedStorage","ServerScriptService","ServerStorage","StarterGui","StarterPack","StarterPlayer","Lighting"}
for _, r in ipairs(roots) do
	local svc = game:GetService(r)
	for _, d in ipairs(svc:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			local full = d:GetFullName()
			if not full:find("_RebuildRemoved", 1, true) and not full:find("_Pre", 1, true) and not full:find("_MainGame", 1, true) then
				local ok, src = pcall(function() return d.Source end)
				if ok then out[full .. "|" .. d.ClassName] = {#src, h(src)} end
			end
		end
	end
	task.wait()
end
return HS:JSONEncode(out)
