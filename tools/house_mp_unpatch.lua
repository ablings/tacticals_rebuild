-- revert the test-only two-player patch ([[HOUSE2P TEST]]) in every script of the build copy; returns what it restored
local A = 'if IS_STUDIO and (id == "bot" or (n and n <= 0)) then bots[side] += 1'
local out = {}
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		local ok, src = pcall(function() return d.Source end)
		if ok and src and src:find("HOUSE2P TEST", 1, true) then
			d.Source = src:gsub('if IS_STUDIO and %(id == "bot" or %(n and n <= 0[^\n]-%-%-%[%[HOUSE2P TEST%]%]', function() return A end)
			table.insert(out, d:GetFullName() .. (d.Source:find("HOUSE2P", 1, true) and " STILL PATCHED" or " restored"))
		end
	end
end
return #out .. " restored: " .. table.concat(out, "; ")
