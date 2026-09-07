-- StarterPlayerScripts > HousingClient  (detection-only)
-- Sets the InOwnHouse attribute when the local player is inside their own hub house
-- (StyleController's unified Decorate panel gates its entry button + Furniture source on
-- it), and relays the server's move-item (HouseEnterBuild) / force-exit (HouseExitBuild)
-- events to the placement pipeline. The furniture picker + "Decorate" button moved into
-- the unified StyleController panel (Furniture tab), so this no longer builds any UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlacementBridge = require(ReplicatedStorage:WaitForChild("PlacementBridge"))
local Events = ReplicatedStorage:WaitForChild("Events", 15)
local HouseEnterBuild = Events:WaitForChild("HouseEnterBuild", 15)
local HouseExitBuild  = Events:WaitForChild("HouseExitBuild",  15)

local currentPhase = player:GetAttribute("RoundPhase") or "Lobby"
local isInOwnHouse = false

local Layout=require(ReplicatedStorage:WaitForChild("NeighborhoodLayout"))
local function isPlayerInsideOwnHouse(): boolean
	if currentPhase ~= "Lobby" then return false end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local district = workspace:FindFirstChild("HousingDistrict")
	if not district then return false end
	local houseRoom = district:FindFirstChild("HouseRoom_" .. player.UserId)
	if not houseRoom then return false end
	local localPos = houseRoom:GetPivot():PointToObjectSpace(root.Position)
	return math.abs(localPos.X) <= Layout.House.Width/2-.4
		and localPos.Y >= Layout.House.FloorTop and localPos.Y <= Layout.House.FloorTop+Layout.House.WallHeight
		and math.abs(localPos.Z) <= Layout.House.Depth/2-.4
end

-- Poll every 0.5s (no need for per-frame).
local checkElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	checkElapsed += dt
	if checkElapsed < 0.5 then return end
	checkElapsed = 0
	local inside = isPlayerInsideOwnHouse()
	if inside ~= isInOwnHouse then
		isInOwnHouse = inside
		player:SetAttribute("InOwnHouse", inside)  -- StyleController gates its Decorate button/source on this
	end
end)

-- Server fires this when a player picks up (moves) a placed house item; re-enter build
-- mode with that item.
HouseEnterBuild.OnClientEvent:Connect(function(itemId: string)
	if typeof(itemId) == "string" and itemId ~= "" then
		PlacementBridge.SetItem:Fire(itemId)
	end
	PlacementBridge.Toggle:Fire("enter")
end)

-- Server fires this on non-Lobby phase transition to force-exit build mode.
HouseExitBuild.OnClientEvent:Connect(function()
	PlacementBridge.Toggle:Fire("cancel")
end)

player:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	currentPhase = player:GetAttribute("RoundPhase") or "Lobby"
	if currentPhase ~= "Lobby" then
		isInOwnHouse = false
		player:SetAttribute("InOwnHouse", false)
	end
end)

print("[HousingClient] Loaded (detection-only)")
