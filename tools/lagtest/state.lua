local RS = game.ReplicatedStorage
return tostring(RS:GetAttribute("MatchState")) .. " round " .. tostring(RS:GetAttribute("Round")) .. " combat " .. tostring(RS:GetAttribute("CombatEnabled"))
