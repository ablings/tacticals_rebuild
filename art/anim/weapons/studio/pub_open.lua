-- pub_open.lua (prepend `local NAME = "<Clip>"`): select the KeyframeSequence and open Studio's upload dialog for it
local ks = game.ReplicatedStorage.Repository.AnimationSources:FindFirstChild(NAME)
if not ks then return "missing " .. NAME end
game:GetService("Selection"):Set({ ks })
local ok, err = pcall(function() plugin:SaveSelectedToRoblox() end)
return ("%s selected; SaveSelectedToRoblox %s %s"):format(NAME, tostring(ok), tostring(err))
