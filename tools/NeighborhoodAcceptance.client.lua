assert(game:GetService("RunService"):IsStudio())
assert(game.PlaceId==86511797738570)
local player=game.Players.LocalPlayer
while not player:GetAttribute("AcceptanceRemoteReady") do task.wait(.1) end
game.ReplicatedStorage.Events.HousePlaceSave:FireServer(player:GetAttribute("AcceptanceItem"),player:GetAttribute("AcceptancePlacement"),"client-recovery-fixture")
