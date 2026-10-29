--@lib
-- args via globals edited by sed: GUN, LIST
local rig = workspace._AnimStage.StageRig
local SRC = game.ReplicatedStorage.Repository.AnimationSources
local list = {}
for _, it in LIST do table.insert(list, { SRC[it[1]], it[2] }) end
L.pose(rig, list)
L.puppet(rig, GUN, ROOT and (rig.HumanoidRootPart.CFrame * ROOT) or nil)
return "posed"
