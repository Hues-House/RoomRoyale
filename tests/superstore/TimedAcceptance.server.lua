local world=workspace:WaitForChild("CartLab")
local start=game.ServerStorage:WaitForChild("StartCartLabRound")
task.wait(1)
local times=start:Invoke(8)
assert(times,"A round is already active")
world:SetAttribute("AcceptanceShopEndsAt",times.shopEndsAt)
local phases={}
local previous
repeat
	local phase=world:GetAttribute("ShoppingPhase")
	if phase~=previous then
		previous=phase
		table.insert(phases,{phase=phase,at=workspace:GetServerTimeNow()})
	end
	task.wait(0.05)
until workspace:GetServerTimeNow()>times.styleStartsAt+1.5
local player=game.Players:GetPlayers()[1]
local collection=game.ServerStorage.GetCartLabRoundCollection:Invoke(player)
assert(#collection==2,"The two checked-out pieces were not exported")
assert(not workspace.LabCarts:FindFirstChild(tostring(player.UserId)),"Cart remained after Style")
world:SetAttribute("TimedAcceptanceServer",game:GetService("HttpService"):JSONEncode({phases=phases,collection=collection,position=tostring(player.Character:GetPivot().Position),health=player.Character.Humanoid.Health}))
