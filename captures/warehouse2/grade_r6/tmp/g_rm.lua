local hits = {}
for _, d in game:GetDescendants() do
  local ok, isScript = pcall(function() return d:IsA("LuaSourceContainer") end)
  if ok and isScript then
    local ok2, src = pcall(function() return d.Source end)
    if ok2 and src and (src:find("applyMapEnv",1,true) or src:find("Exterior",1,true) or src:find("Dynamic",1,true) or src:find("Warehouse2Door",1,true) or src:find("CloseAll",1,true)) then
      local lines = {}
      local i = 0
      for line in (src.."\n"):gmatch("(.-)\n") do
        i += 1
        if line:find("applyMapEnv",1,true) or line:find("Exterior",1,true) or line:find("%.Dynamic") or line:find("Warehouse2Door",1,true) or line:find("CloseAll",1,true) then
          table.insert(lines, i .. ": " .. line:sub(1,160))
        end
      end
      table.insert(hits, d:GetFullName() .. "\n  " .. table.concat(lines, "\n  "))
    end
  end
end
return table.concat(hits, "\n")
