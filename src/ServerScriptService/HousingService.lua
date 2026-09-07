-- ServerScriptService > HousingService
-- Manages persistent player houses in the lobby world.
-- Houses have a dedicated template and session lots; competition rooms remain separate.
-- Houses live in Workspace.HousingDistrict and persist across rounds.
-- Only the owning player can place/move items; all players can walk through.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local ItemAssets   = ReplicatedStorage:WaitForChild("ItemAssets", 10)
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase", 15))

local ProgressionService = nil

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local function getOrCreate(className, name)
	local e = Events:FindFirstChild(name)
	if e and e.ClassName == className then return e end
	if e then e:Destroy() end
	local r = Instance.new(className)
	r.Name  = name
	r.Parent = Events
	return r
end

local SetRoomSurface      = getOrCreate("RemoteEvent",    "SetRoomSurface")
local SetItemAppearance   = getOrCreate("RemoteEvent",    "SetItemAppearance")
local ResetItemAppearance = getOrCreate("RemoteEvent",    "ResetItemAppearance")
local HousePlaceSave      = getOrCreate("RemoteEvent",    "HousePlaceSave")
local HousePlaceRemove    = getOrCreate("RemoteEvent",    "HousePlaceRemove")
local HouseEnterBuild     = getOrCreate("RemoteEvent",    "HouseEnterBuild")
local HouseExitBuild      = getOrCreate("RemoteEvent",    "HouseExitBuild")
local GetHouseInfo        = getOrCreate("RemoteFunction", "GetHouseInfo")
local OpenSurfacePicker   = getOrCreate("RemoteEvent",    "OpenSurfacePicker")
local PickupPlacedItem    = getOrCreate("RemoteEvent",    "PickupPlacedItem")

local PhaseChangedServer = Events:WaitForChild("PhaseChangedServer", 15)

local Layout = require(ReplicatedStorage.NeighborhoodLayout)
local HouseBuilder = require(script.Parent.HouseTemplateBuilder)
local Lots = require(script.Parent.HouseLotService)
local Geometry = require(script.Parent.HousePlacementGeometry)
local loading = {}
local initialized = false

local houseRooms: {[number]: Model} = {}
local HousingService = {}

-- Per-round migration: phase is per-player (RoundPhase attribute), not global.
-- A player is free to decorate whenever they are in the hub, i.e. they have no
-- active round phase (RoundPhase is nil/""/"Lobby"). Players physically in a
-- round are teleported away from the housing district, so per-player action
-- guards below are sufficient; house prompts stay enabled for everyone.
local function playerCanDecorate(player: Player): boolean
	local rp = player:GetAttribute("RoundPhase")
	return rp == nil or rp == "" or rp == "Lobby"
end

local function getPromptBasePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then return instance :: BasePart end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then return d :: BasePart end
	end
	return nil
end

-- ---- House surface painting (walls / floor) --------------------------------
-- Canonicalize the client's surface token to: "floor" | "wall_back" |
-- "wall_left" | "wall_right" | "wall" (all walls).
local function canonSurface(surface: string): string
	local canon = string.gsub(string.lower(tostring(surface)), "[^%a]", "")
	if canon == "wallback" or canon == "back" then return "wall_back"
	elseif canon == "wallleft" or canon == "left" then return "wall_left"
	elseif canon == "wallright" or canon == "right" then return "wall_right"
	elseif canon == "all" then return "wall"
	elseif string.find(canon, "floor", 1, true) then return "floor"
	elseif string.find(canon, "wall", 1, true) then return "wall"
	end
	return tostring(surface)
end

local HOUSE_FLOOR_NAMES = { "Floor", "BathFloor", "LoftFloor",
	"StairStep01","StairStep02","StairStep03","StairStep04",
	"StairStep05","StairStep06","StairStep07","StairStep08" }
-- Paint targets the interior LINERS, not the structural walls, so the cottage
-- exterior is never recoloured when the player paints the interior.
local HOUSE_WALL_NAMES = { "WallBackLiner", "WallLeftLiner", "WallRightLiner" }
local HOUSE_PER_WALL = {
	wall_back = { "WallBackLiner" },
	wall_left = { "WallLeftLiner" },
	wall_right = { "WallRightLiner" },
}

local function applyHouseSurface(room: Model, surface: string, color: Color3, material: EnumItem?): boolean
	local targets
	if surface == "floor" then
		targets = HOUSE_FLOOR_NAMES
	else
		targets = HOUSE_PER_WALL[surface] or (surface == "wall" and HOUSE_WALL_NAMES or nil)
	end
	if not targets then return false end
	for _, name in ipairs(targets) do
		local part = room:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			part.Color = color
			if material then part.Material = material end
		end
	end
	return true
end

local function buildHouseRoom(player: Player, index: number): Model
	local room=HouseBuilder.Build(index,player)
	for _,name in {"Floor","WallBackLiner","WallLeftLiner","WallRightLiner"} do
		local p=room:FindFirstChild(name,true)
		local prompt=Instance.new("ProximityPrompt")
		prompt.Name="PaintPrompt" prompt.ActionText="Paint" prompt.ObjectText=name=="Floor" and "Floor" or "Wall"
		prompt.MaxActivationDistance=8 prompt.HoldDuration=.2 prompt.Parent=p
		local key=name=="Floor" and "floor" or p:GetAttribute("SurfaceKey")
		prompt.Triggered:Connect(function(actor)
			if actor==player and playerCanDecorate(actor) then OpenSurfacePicker:FireClient(actor,key) end
		end)
	end
	return room
end

local function attachMovePrompt(placed: Model, itemId: string, placementId: string, player: Player)
	local promptPart = getPromptBasePart(placed)
	if not promptPart then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HouseMovePrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Move"
	prompt.ObjectText = itemId
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0.04
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = promptPart
	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if not playerCanDecorate(triggeringPlayer) then return end
		if triggeringPlayer.UserId ~= player.UserId then return end
		placed:Destroy()
		if ProgressionService then
			ProgressionService.RemoveHousePlacement(player, placementId)
		end
		HouseEnterBuild:FireClient(triggeringPlayer, itemId)
	end)
end

-- Pick up a placed HOUSE item by name (fired by the unified Decorate panel's "✓ Room" card
-- tap). Mirrors the Move prompt. RoomService also listens to PickupPlacedItem (Style rooms);
-- this safely no-ops unless the named item is in THIS player's house, so the two coexist.
PickupPlacedItem.OnServerEvent:Connect(function(player: Player, placedName)
	if typeof(placedName) ~= "string" then return end
	local district = workspace:FindFirstChild("HousingDistrict")
	local room = district and district:FindFirstChild("HouseRoom_" .. player.UserId)
	local folder = room and room:FindFirstChild("PlacedItems")
	local placed = folder and folder:FindFirstChild(placedName)
	if not (placed and placed:IsA("Model")) then return end
	if not playerCanDecorate(player) then return end
	local itemId = placed:GetAttribute("ItemId") or placedName:match("^(.-)_house_") or placedName
	local placementId = placed:GetAttribute("HousePlacementId")
	placed:Destroy()
	if ProgressionService and placementId then
		ProgressionService.RemoveHousePlacement(player, placementId)
	end
	HouseEnterBuild:FireClient(player, itemId)
end)

local function populateHouseFromSaved(player: Player, room: Model)
	if not ProgressionService then return end
	-- Re-apply saved wall/floor paint so the home keeps its look across rejoins.
	if ProgressionService.GetHouseSurfaces then
		for key, s in pairs(ProgressionService.GetHouseSurfaces(player)) do
			if type(s) == "table" then
				local color = Color3.fromRGB(s.r or 255, s.g or 255, s.b or 255)
				local material = nil
				if type(s.mat) == "string" then
					local ok, m = pcall(function() return (Enum.Material :: any)[s.mat] end)
					if ok then material = m end
				end
				applyHouseSurface(room, key, color, material)
			end
		end
	end
	local placements = ProgressionService.GetHousePlacements(player)
	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end

	for id, entry in pairs(placements) do
		local source = ItemAssets and ItemAssets:FindFirstChild(entry.itemId)
		if not source then
			room:SetAttribute("MissingAssetCount",(room:GetAttribute("MissingAssetCount") or 0)+1)
			room:SetAttribute("RecoveredPlacementCount",(room:GetAttribute("RecoveredPlacementCount") or 0)+1)
			continue
		end

		local cf=Geometry.Read(entry,room:GetPivot())
		if not cf then room:SetAttribute("RecoveredPlacementCount",(room:GetAttribute("RecoveredPlacementCount") or 0)+1) continue end

		local placed = source:Clone()
		placed.Name = entry.itemId .. "_house_" .. id
		placed:SetAttribute("HousePlacementId", id)
		placed:SetAttribute("ItemId", entry.itemId)
		placed:SetAttribute("PlacedBy", player.UserId)
		placed:SetAttribute("IsHousePlacement", true)

		local itemData = ItemDatabase.Get(entry.itemId)
		local surface = itemData and itemData.PlacementSurface or "Floor"
		placed:SetAttribute("PlacementSurface", surface)

		for _, part in ipairs(placed:GetDescendants()) do
			if part:IsA("BasePart") then
				part:SetAttribute("OrigColor", tostring(part.Color))
				part:SetAttribute("OrigMaterial", tostring(part.Material))
				part.Anchored = true
				part.CanCollide = surface == "Floor"
			end
		end

		placed:PivotTo(cf)
		if not Geometry.Fits(room,placed) or not Geometry.HasSupport(room,placed,surface) then
			room:SetAttribute("RecoveredPlacementCount",(room:GetAttribute("RecoveredPlacementCount") or 0)+1)
			placed:Destroy()
			continue
		end
		placed.Parent = folder
		attachMovePrompt(placed, entry.itemId, id, player)
	end
end

HousePlaceSave.OnServerEvent:Connect(function(player: Player, itemId: string, placeCFrame: CFrame, placementId: string)
	if not playerCanDecorate(player) then return end
	local room = houseRooms[player.UserId]
	if not room then return end
	if typeof(itemId) ~= "string" or itemId == "" then return end
	if typeof(placementId) ~= "string" or placementId == "" then return end
	if not ProgressionService then return end

	if typeof(placeCFrame)~="CFrame" then return end
	for _,n in {placeCFrame:GetComponents()} do if n~=n or math.abs(n)==math.huge then return end end
	local source=ItemAssets and ItemAssets:FindFirstChild(itemId)
	if not source then return end
	local characterRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not characterRoot or (characterRoot.Position-placeCFrame.Position).Magnitude>40 then return end
	local candidate=source:Clone()
	candidate:PivotTo(placeCFrame)
	local itemData=ItemDatabase.Get(itemId)
	local surface=itemData and itemData.PlacementSurface or "Floor"
	local fits=Geometry.Fits(room,candidate) and Geometry.HasSupport(room,candidate,surface)
	candidate:Destroy()
	if not fits then
		local toast=Events:FindFirstChild("ProgressionToast")
		if toast then toast:FireClient(player,{kind="placementRejected",message="Place the piece on its surface, inside your home and clear of the door."}) end
		return
	end
	local folder=room:FindFirstChild("PlacedItems")
	if not folder then return end
	-- Reuse an unmaterialized saved record only after the player chooses a valid location.
	-- Until then the original placement and ownership remain untouched.
	for savedId,entry in ProgressionService.GetHousePlacements(player) do
		if entry.itemId==itemId then
			local visible=false
			for _,model in folder:GetChildren() do
				if model:GetAttribute("HousePlacementId")==savedId then visible=true break end
			end
			if not visible then placementId=savedId break end
		end
	end
	local ok,msg=ProgressionService.SaveHousePlacement(player,placementId,itemId,room:GetPivot():ToObjectSpace(placeCFrame),"house-local-v2")
	if not ok then
		local toast=Events:FindFirstChild("ProgressionToast")
		if toast then toast:FireClient(player,{kind="placementRejected",message=msg}) end
		return
	end

	for _, existing in ipairs(folder:GetChildren()) do
		if existing:GetAttribute("HousePlacementId") == placementId then
			existing:Destroy()
		end
	end

	local placed = source:Clone()
	placed.Name = itemId .. "_house_" .. placementId
	placed:SetAttribute("HousePlacementId", placementId)
	placed:SetAttribute("ItemId", itemId)
	placed:SetAttribute("PlacedBy", player.UserId)
	placed:SetAttribute("IsHousePlacement", true)

	local itemData = ItemDatabase.Get(itemId)
	local surface = itemData and itemData.PlacementSurface or "Floor"
	placed:SetAttribute("PlacementSurface", surface)

	for _, part in ipairs(placed:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("OrigColor", tostring(part.Color))
			part:SetAttribute("OrigMaterial", tostring(part.Material))
			part.Anchored = true
			part.CanCollide = surface == "Floor"
		end
	end

	placed:PivotTo(placeCFrame)
	placed.Parent = folder
	attachMovePrompt(placed, itemId, placementId, player)
	local event=Events:FindFirstChild("ItemPlaced")
	if event then event:FireClient(player,itemId,placed.Name) end
end)

HousePlaceRemove.OnServerEvent:Connect(function(player: Player, placementId: string)
	if not playerCanDecorate(player) then return end
	local room = houseRooms[player.UserId]
	if not room then return end
	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end
	for _, item in ipairs(folder:GetChildren()) do
		if item:GetAttribute("HousePlacementId") == placementId then
			item:Destroy()
		end
	end
	if ProgressionService then
		ProgressionService.RemoveHousePlacement(player, placementId)
	end
end)

SetRoomSurface.OnServerEvent:Connect(function(player: Player, surface: string, color: Color3, material: EnumItem?)
	-- Only paint the persistent house while the player is in the hub. During a
	-- round the SAME SetRoomSurface remote drives the Style room (RoomService);
	-- without this guard, round paint bled onto the home.
	if not playerCanDecorate(player) then return end
	if typeof(color) ~= "Color3" then return end
	surface = canonSurface(surface)
	local room = houseRooms[player.UserId]
	if not room then return end
	if not applyHouseSurface(room, surface, color, material) then
		warn("[HousingService] Unknown paint surface: " .. tostring(surface))
		return
	end
	-- Persist so the home keeps its look across rounds and rejoins.
	if ProgressionService and ProgressionService.SaveHouseSurface then
		ProgressionService.SaveHouseSurface(player, surface, color, material)
	end
end)

SetItemAppearance.OnServerEvent:Connect(function(player: Player, itemName: string, color: Color3, material: EnumItem?)
	if not playerCanDecorate(player) then return end
	local room = houseRooms[player.UserId]
	if not room then return end
	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end
	local item = folder:FindFirstChild(itemName)
	if not item then return end
	if item:GetAttribute("PlacedBy") ~= player.UserId then return end
	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = color
			if material then part.Material = material end
		end
	end
end)

ResetItemAppearance.OnServerEvent:Connect(function(player: Player, itemName: string)
	if not playerCanDecorate(player) then return end
	local room = houseRooms[player.UserId]
	if not room then return end
	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end
	local item = folder:FindFirstChild(itemName)
	if not item then return end
	if item:GetAttribute("PlacedBy") ~= player.UserId then return end
	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			local origColor = part:GetAttribute("OrigColor")
			local origMat   = part:GetAttribute("OrigMaterial")
			if origColor then
				local r,g,b = origColor:match("([%d%.]+), ([%d%.]+), ([%d%.]+)")
				if r then part.Color = Color3.new(tonumber(r),tonumber(g),tonumber(b)) end
			end
			if origMat then
				local ok, mat = pcall(function()
					return Enum.Material[origMat:match("%.(%w+)$") or origMat]
				end)
				if ok and mat then part.Material = mat end
			end
		end
	end
end)

GetHouseInfo.OnServerInvoke = function(player: Player)
	local room = houseRooms[player.UserId]
	if not room then return nil end
	local pivot = room:GetPivot()
	return { position=pivot.Position, cframe=pivot, roomWidth=Layout.House.Width, roomDepth=Layout.House.Depth, roomHeight=Layout.House.WallHeight, recoveredPlacements=room:GetAttribute("RecoveredPlacementCount") or 0 }
end

local function onPlayerAdded(player: Player)
	if loading[player.UserId] or houseRooms[player.UserId] then return end
	local token={}
	loading[player.UserId]=token
	task.spawn(function()
		while player.Parent==Players and loading[player.UserId]==token do
			if ProgressionService and ProgressionService.GetSnapshot(player) then break end
			task.wait(.25)
		end
		if player.Parent~=Players or loading[player.UserId]~=token then return end
		local index=Lots.Reserve(player.UserId)
		if not index then loading[player.UserId]=nil warn("[HousingService] No vacant lot for",player.Name) return end
		local room
		local ok,err=pcall(function()
			room=buildHouseRoom(player,index)
			populateHouseFromSaved(player,room)
		end)
		if not ok or player.Parent~=Players or loading[player.UserId]~=token then
			if room then room:Destroy() end
			Lots.Release(player.UserId) loading[player.UserId]=nil
			if not ok then warn("[HousingService] House load failed:",err) end
			return
		end
		if Lots.Occupy(index,player.UserId,room) then
			houseRooms[player.UserId]=room
			CollectionService:AddTag(room,"HouseRoom")
			player:SetAttribute("HouseLotIndex",index)
		end
		loading[player.UserId]=nil
	end)
end

local function onPlayerRemoving(player: Player)
	loading[player.UserId]=nil
	houseRooms[player.UserId]=nil
	Lots.Release(player.UserId)
	-- A full server may have had a player waiting for a free lot.
	for _,waiting in Players:GetPlayers() do if waiting~=player then onPlayerAdded(waiting) end end
end

function HousingService.GetHouseRoom(player: Player): Model?
	return houseRooms[player.UserId]
end

function HousingService.IsHousingPhase(player: Player?): boolean
	-- Per-player: a player can decorate whenever they are in the hub.
	if player then return playerCanDecorate(player) end
	return true
end

function HousingService.Init(progressionServiceRef)
	if initialized then return end
	initialized=true
	require(script.Parent.NeighborhoodBootstrap).EnsureAll()
	Lots.Ensure()
	ProgressionService = progressionServiceRef
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	print("[HousingService] Initialized")
end

return HousingService
