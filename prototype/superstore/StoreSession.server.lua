local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local start=ServerStorage:WaitForChild("StartCartLabRound")
local export=ServerStorage:WaitForChild("GetCartLabRoundCollection")
local world=workspace:WaitForChild("CartLab")
local request=Instance.new("RemoteEvent")
request.Name="HillsideSession"
request.Parent=ReplicatedStorage
local lastRequest={}

request.OnServerEvent:Connect(function(player,action)
	if action~="Start" and action~="Practice" and action~="Market" then return end
	local now=os.clock()
	if now-(lastRequest[player] or -math.huge)<2 then return end
	lastRequest[player]=now
	local phase=world:GetAttribute("ShoppingPhase")
	if action=="Practice" or action=="Market" then
		local free=ServerStorage:FindFirstChild("StartCartLabFreeShopping")
		if not free or not free:Invoke() then return end
		for _, shopper in game.Players:GetPlayers() do shopper:SetAttribute("HillsideSavedCount", 0) end
		local target=world:GetAttribute(action=="Practice" and "PracticeSpawn" or "MarketSpawn")
		local move=ServerStorage:FindFirstChild("MoveCartLabTo")
		if target and move then move:Invoke(player,target) end
		return
	end
	if phase and phase~="Style" then return end
	start:Invoke(150)
end)

game.Players.PlayerRemoving:Connect(function(player) lastRequest[player]=nil end)
world:GetAttributeChangedSignal("ShoppingPhase"):Connect(function()
	if world:GetAttribute("ShoppingPhase")~="Style" then return end
	for _,player in game.Players:GetPlayers() do
		player:SetAttribute("HillsideSavedCount",#export:Invoke(player))
	end
end)
