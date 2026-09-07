-- ServerScriptService > RoomService
-- Manages style phase rooms:
--   - Builds a RoomTemplate in ServerStorage
--   - On Style phase: clones one room per player, teleports them in
--   - Handles PlaceItem, SetRoomSurface, SetItemAppearance RemoteEvents
--   - On Lobby phase: destroys all rooms

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService       = game:GetService("HttpService")
local ItemAssets        = ReplicatedStorage:WaitForChild("ItemAssets", 10)
local ItemDatabase      = require(ReplicatedStorage:WaitForChild("ItemDatabase", 15))

-- =========================================================
--  CONFIG
-- =========================================================

-- Room geometry
local ROOM_W            = 52    -- width (X)
local ROOM_D            = 44    -- depth (Z)
local ROOM_H            = 18    -- ceiling height
local WALL_T            = 1     -- wall thickness
local LOFT_HEIGHT       = 10    -- mezzanine floor height above main floor
local LOFT_DEPTH        = 15    -- back-half loft depth
local BATH_SIZE         = 12    -- bathroom footprint
local BATH_HEIGHT       = 10    -- bathroom wall height
local FRONT_DOOR_WIDTH  = 6
local FRONT_DOOR_HEIGHT = 10
local BATH_DOOR_WIDTH   = 4
local BATH_DOOR_HEIGHT  = 7
local STAIR_COUNT       = 8

-- Room layout: rooms arranged in a row along X, spaced apart
-- Rooms start far from store (store is at Z=20, rooms at Z=600+)
local ROOM_ROW_Z    = 850
local ROOM_SPACING  = 64

-- Default surface appearance
local DEFAULT_WALL_COLOR  = Color3.fromRGB(252, 250, 247)
local DEFAULT_FLOOR_COLOR = Color3.fromRGB(216, 202, 183)
local DEFAULT_FLOOR_MAT   = Enum.Material.WoodPlanks
local DEFAULT_WALL_MAT    = Enum.Material.SmoothPlastic

-- Max items a player can place
local MAX_PLACE_DISTANCE = 30  -- studs, must match PlacementController

-- =========================================================
--  REMOTE EVENTS
-- =========================================================

local Events = ReplicatedStorage:WaitForChild("Events", 10)
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "Events"
	Events.Parent = ReplicatedStorage
end

local function getOrCreate(className, name)
	local e = Events:FindFirstChild(name)
	if e then return e end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = Events
	return r
end

local PlaceItemEvent       = getOrCreate("RemoteEvent",    "PlaceItem")
local ItemPlaced           = getOrCreate("RemoteEvent",    "ItemPlaced")
local SetRoomSurface       = getOrCreate("RemoteEvent",    "SetRoomSurface")
local SetItemAppearance    = getOrCreate("RemoteEvent",    "SetItemAppearance")
local ResetItemAppearance  = getOrCreate("RemoteEvent",    "ResetItemAppearance")
local PickupPlacedItem     = getOrCreate("RemoteEvent",    "PickupPlacedItem")
local GetRoomInfo          = getOrCreate("RemoteFunction", "GetRoomInfo")
local OpenSurfacePicker    = getOrCreate("RemoteEvent",    "OpenSurfacePicker")
local OpenItemAppearance   = getOrCreate("RemoteEvent",    "OpenItemAppearance")
local SetRoomLighting      = getOrCreate("RemoteEvent",    "SetRoomLighting")

-- =========================================================
--  ROOM TEMPLATE
--  Built once in ServerStorage, cloned per player each round.
--  Structure:
--    RoomTemplate (Model)
--      Floor   (Part) — tagged "RoomFloor"
--      WallBack (Part)
--      WallLeft (Part)
--      WallRight (Part)
--      SpawnPart (Part, invisible) — player spawns here
--      PlotBoundary (Part, invisible) — used by PlacementController
--      PlacedItems (Folder) — placed furniture goes here
-- =========================================================

local function buildRoomTemplate()
	local existing = ServerStorage:FindFirstChild("RoomTemplate")
	if existing then existing:Destroy() end

	local RW = 52; local RD = 44; local RH = 18; local WT = 0.8
	local halfW = RW/2; local halfD = RD/2

	local WALL_COLOR  = Color3.fromRGB(252,250,247)
	local FLOOR_COLOR = Color3.fromRGB(210,196,178)
	local TRIM_COLOR  = Color3.fromRGB(62,55,48)
	local FRAME_COLOR = Color3.fromRGB(45,42,40)
	local GLASS_COLOR = Color3.fromRGB(196,214,226)
	local CEIL_COLOR  = Color3.fromRGB(250,249,247)
	local LIGHT_COLOR = Color3.fromRGB(255,240,208)
	local SMOOTH=Enum.Material.SmoothPlastic; local WOOD=Enum.Material.WoodPlanks
	local METAL=Enum.Material.Metal; local GLASS=Enum.Material.Glass; local NEON=Enum.Material.Neon

	local template=Instance.new("Model"); template.Name="RoomTemplate"
	local exterior=Instance.new("Folder"); exterior.Name="Exterior"; exterior.Parent=template
	local shell=Instance.new("Folder"); shell.Name="VisualShell"; shell.Parent=template
	local folder=Instance.new("Folder"); folder.Name="PlacedItems"; folder.Parent=template

	local function P(parent,name,size,cf,color,mat,trans,cc,st)
		local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=cf
		p.Anchored=true; p.CanCollide=if cc==nil then true else cc
		p.Color=color; p.Material=mat or SMOOTH; p.Transparency=trans or 0; p.CastShadow=false
		p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
		if st then p:SetAttribute("SurfaceType",st) end; p.Parent=parent; return p
	end

	-- Floor
	local floor=P(exterior,"Floor",Vector3.new(RW,WT,RD),CFrame.new(0,-WT/2,0),FLOOR_COLOR,WOOD,0,true,"Floor")
	CollectionService:AddTag(floor,"RoomFloor")
	P(template,"PlotBoundary",Vector3.new(RW-1,0.5,RD-1),CFrame.new(0,0.25,0),FLOOR_COLOR,WOOD,1,false,"Floor")
	P(template,"SpawnPart",Vector3.new(4,0.5,4),CFrame.new(0,0.25,halfD-4),FLOOR_COLOR,WOOD,1,false)

	-- Ceiling
	P(exterior,"Ceiling",Vector3.new(RW+WT*2,WT,RD+WT),CFrame.new(0,RH,-WT/2),CEIL_COLOR,SMOOTH,0,true,"Ceiling")

	-- Three walls (open front)
	local backZ=-halfD-WT/2; local leftX=-halfW-WT/2; local rightX=halfW+WT/2
	P(exterior,"WallBack",Vector3.new(RW,RH,WT),CFrame.new(0,RH/2,backZ),WALL_COLOR,SMOOTH,0,true,"Wall")
	P(exterior,"WallLeft",Vector3.new(WT,RH,RD+WT*2),CFrame.new(leftX,RH/2,-WT/2),WALL_COLOR,SMOOTH,0,true,"Wall")
	P(exterior,"WallRight",Vector3.new(WT,RH,RD+WT*2),CFrame.new(rightX,RH/2,-WT/2),WALL_COLOR,SMOOTH,0,true,"Wall")

	-- Back windows (3 tall glass panels)
	-- Glass is placed slightly BEHIND the WallBack face so paint changes are visible.
	local winH=RH-3; local winY=winH/2+0.8; local winZ=backZ-WT/2-0.06; local winW=13
	for i,wx in ipairs({-RW/2+9, 0, RW/2-9}) do
		P(shell,"WinGlass"..i,Vector3.new(winW,winH,0.12),CFrame.new(wx,winY,winZ),GLASS_COLOR,GLASS,0.55,false)
		P(shell,"WinFrameT"..i,Vector3.new(winW+0.5,0.32,0.22),CFrame.new(wx,0.8+winH+0.16,winZ),FRAME_COLOR,METAL,0,false)
		P(shell,"WinFrameB"..i,Vector3.new(winW+0.5,0.32,0.22),CFrame.new(wx,0.64,winZ),FRAME_COLOR,METAL,0,false)
		P(shell,"WinDiv"..i,Vector3.new(0.22,winH,0.22),CFrame.new(wx,winY,winZ),FRAME_COLOR,METAL,0,false)
		-- Sky backdrop moved with glass to maintain depth
	end
	for _,fx in ipairs({-halfW+2,-RW/2+9+winW/2+0.25,winW/2+0.25,halfW-2}) do
		P(shell,"WinPost"..math.floor(fx*10),Vector3.new(0.3,winH+0.4,0.3),CFrame.new(fx,winY,winZ),FRAME_COLOR,METAL,0,false)
	end

	-- Sky backdrop + window glow
	P(shell,"SkyBackdrop",Vector3.new(RW+10,RH+4,0.4),CFrame.new(0,RH/2,backZ-4),Color3.fromRGB(188,213,232),SMOOTH,0,false)
	local wg=P(shell,"WinGlow",Vector3.new(RW-4,RH-6,0.1),CFrame.new(0,RH/2,backZ-0.6),Color3.fromRGB(210,228,242),NEON,0.9,false)
	local wl=Instance.new("PointLight"); wl.Brightness=0.4; wl.Range=20; wl.Color=Color3.fromRGB(205,225,240); wl.Parent=wg

	-- Ceiling light strips
	for _,lx in ipairs({-RW/4,RW/4}) do
		local ls=P(shell,"CeilLight",Vector3.new(RW*0.38,0.18,1.4),CFrame.new(lx,RH-0.3,-halfD/2),Color3.fromRGB(255,246,222),NEON,0,false)
		local pl=Instance.new("PointLight"); pl.Brightness=0.9; pl.Range=24; pl.Color=LIGHT_COLOR; pl.Parent=ls
	end

	-- Baseboards + cornice
	P(shell,"TrimBackF",Vector3.new(RW,0.5,0.22),CFrame.new(0,0.25,backZ+WT/2+0.11),TRIM_COLOR,WOOD,0,false)
	P(shell,"TrimLeftF",Vector3.new(0.22,0.5,RD),CFrame.new(leftX+WT/2+0.11,0.25,-WT/2),TRIM_COLOR,WOOD,0,false)
	P(shell,"TrimRightF",Vector3.new(0.22,0.5,RD),CFrame.new(rightX-WT/2-0.11,0.25,-WT/2),TRIM_COLOR,WOOD,0,false)
	P(shell,"CorBack",Vector3.new(RW,0.3,0.22),CFrame.new(0,RH-0.15,backZ+WT/2+0.11),TRIM_COLOR,WOOD,0,false)
	P(shell,"CorLeft",Vector3.new(0.22,0.3,RD),CFrame.new(leftX+WT/2+0.11,RH-0.15,-WT/2),TRIM_COLOR,WOOD,0,false)
	P(shell,"CorRight",Vector3.new(0.22,0.3,RD),CFrame.new(rightX-WT/2-0.11,RH-0.15,-WT/2),TRIM_COLOR,WOOD,0,false)

	-- Surface paint billboards (floating "🎨 Paint" labels on each surface)
	local function makeSurfaceAnchor(name,pos,label,surfaceKey)
		local anchor=P(shell,name.."Anchor",Vector3.new(1,1,1),CFrame.new(pos),WALL_COLOR,SMOOTH,1,false)
		local pp=Instance.new("ProximityPrompt"); pp.Name="PaintPrompt"
		-- Custom style: rendered by PromptController (project-wide prompt UI convention).
		pp.Style=Enum.ProximityPromptStyle.Custom; pp.ActionText="Paint "..label; pp.ObjectText=""
		pp.KeyboardKeyCode=Enum.KeyCode.E; pp.HoldDuration=0; pp.MaxActivationDistance=14
		pp.RequiresLineOfSight=false; pp.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
		pp:SetAttribute("SurfaceKey",surfaceKey); pp.Parent=anchor
		pp.Triggered:Connect(function(trigPlayer)
			OpenSurfacePicker:FireClient(trigPlayer, surfaceKey)
		end)
		return anchor
	end
	makeSurfaceAnchor("BackWall",Vector3.new(0,RH/2,backZ+WT+3),"Back Wall","wall_back")
	makeSurfaceAnchor("LeftWall",Vector3.new(leftX+WT+3,RH/2,-halfD/4),"Left Wall","wall_left")
	makeSurfaceAnchor("RightWall",Vector3.new(rightX-WT-3,RH/2,-halfD/4),"Right Wall","wall_right")
	makeSurfaceAnchor("FloorSurf",Vector3.new(0,1.2,halfD-8),"Floor","floor")

	-- ===== Safety seal (prevents falling into the void) =====
	-- Big invisible floor under the whole footprint, plus an invisible front wall
	-- across the open (+Z) side. CanCollide on, CanQuery off so placement raycasts ignore them.
	local frontZ = halfD + WT/2
	local safetyFloor = P(exterior,"SafetyFloor",Vector3.new(RW+40,2,RD+40),CFrame.new(0,-WT-1,0),FLOOR_COLOR,SMOOTH,1,true)
	safetyFloor.CanQuery = false
	local safetyFront = P(exterior,"SafetyFrontWall",Vector3.new(RW+8,RH+24,WT),CFrame.new(0,RH/2,frontZ),WALL_COLOR,SMOOTH,1,true)
	safetyFront.CanQuery = false

	template.PrimaryPart=floor; template.Parent=ServerStorage
	return template
end

buildRoomTemplate()
print("[RoomService] RoomTemplate built")

-- =========================================================
--  STATE
-- =========================================================

-- playerRooms[userId] = { model=Model, ownerId=number }
local playerRooms: {[number]: Model} = {}
local nextPlacedId = 0

-- roundInventory[userId][itemId] = how many of that piece the player may still place.
-- Built once per Style phase from the two things a player can legitimately own:
-- the cart they filled during Shop, and their persistent boutique collection.
-- PlaceItem decrements, picking an item back up increments. Without this the
-- server accepted any ItemAssets name, unlimited times, making Shop optional.
local roundInventory: {[number]: {[string]: number}} = {}

-- Global style-room slot allocator. Rooms must occupy GLOBALLY-unique positions:
-- concurrent rounds previously both used cohort index 1 -> same X=0 spot, so a late
-- joiner's room overlapped (and they spawned into) another player's room.
local occupiedSlots: {[number]: boolean} = {}
local roomSlotByUser: {[number]: number} = {}
local function allocateRoomSlot(): number
	local slot = 1
	while occupiedSlots[slot] do slot += 1 end
	occupiedSlots[slot] = true
	return slot
end
local function freeRoomSlot(userId: number)
	local slot = roomSlotByUser[userId]
	if slot then occupiedSlots[slot] = nil; roomSlotByUser[userId] = nil end
end

local function buildRoundInventory(player: Player)
	local counts: {[string]: number} = {}

	local getCart = Events:FindFirstChild("GetCartContentsServer")
	if getCart and getCart:IsA("BindableFunction") then
		local ok, contents = pcall(function() return getCart:Invoke(player) end)
		if ok and type(contents) == "table" then
			for _, entry in ipairs(contents) do
				local itemId = type(entry) == "table" and entry.itemId
				if type(itemId) == "string" and itemId ~= "" then
					counts[itemId] = (counts[itemId] or 0) + 1
				end
			end
		end
	end

	-- Persistent boutique pieces are placeable once each, matching the one-active-
	-- placement-per-owned-item rule the house system already uses.
	local ok, Progression = pcall(function()
		return require(game.ServerScriptService:WaitForChild("ProgressionService", 5))
	end)
	if ok and type(Progression) == "table" and Progression.GetOwnedItemIds then
		local gotOwned, owned = pcall(function() return Progression.GetOwnedItemIds(player) end)
		if gotOwned and type(owned) == "table" then
			for _, itemId in ipairs(owned) do
				if type(itemId) == "string" and itemId ~= "" then
					counts[itemId] = (counts[itemId] or 0) + 1
				end
			end
		end
	end

	roundInventory[player.UserId] = counts
end

local function takeFromInventory(player: Player, itemId: string): boolean
	local counts = roundInventory[player.UserId]
	if not counts then return false end
	local remaining = counts[itemId]
	if not remaining or remaining <= 0 then return false end
	counts[itemId] = remaining - 1
	return true
end

local function returnToInventory(player: Player, itemId: string)
	local counts = roundInventory[player.UserId]
	if not counts then return end
	counts[itemId] = (counts[itemId] or 0) + 1
end

-- =========================================================
--  ROOM CREATION & TELEPORT
-- =========================================================

local function getRoomPosition(index: number): Vector3
	-- Lay rooms out in a row along X, centered around X=0
	local totalWidth = 0  -- calculated dynamically, not needed for position
	local x = (index - 1) * ROOM_SPACING
	return Vector3.new(x, 0, ROOM_ROW_Z)
end

local function getPromptBasePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function findRoomPart(room: Instance, name: string): BasePart?
	local found = room:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function setRoomInteractionEnabled(cohort: {Player}, enabled: boolean)
	for _, player in ipairs(cohort) do
		local room = playerRooms[player.UserId]
		if room then
			for _, descendant in ipairs(room:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					descendant.Enabled = enabled
				end
			end
		end
	end
end

local function attachMovePrompt(item: Model, itemId: string)
	local promptPart = getPromptBasePart(item)
	if not promptPart then
		return
	end

	local prompt = promptPart:FindFirstChild("MovePrompt")
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MovePrompt"
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0.04
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = promptPart
	end
	local movePrompt = prompt :: ProximityPrompt
	movePrompt.ActionText = "Move"
	movePrompt.ObjectText = itemId
	movePrompt.Enabled = true
end

local function attachEditPrompt(item: Model, itemId: string)
	local promptPart = getPromptBasePart(item)
	if not promptPart then
		return
	end

	local prompt = promptPart:FindFirstChild("EditPrompt")
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EditPrompt"
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.KeyboardKeyCode = Enum.KeyCode.G
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = promptPart
	end
	local editPrompt = prompt :: ProximityPrompt
	editPrompt.ActionText = "Tint"
	editPrompt.ObjectText = itemId
	editPrompt.Enabled = true
end

local function createRoomForPlayer(player: Player, index: number): Model?
	local template = ServerStorage:FindFirstChild("RoomTemplate")
	if not template then
		warn("[RoomService] RoomTemplate missing")
		return nil
	end

	local room = template:Clone()
	room.Name = "StyleRoom_" .. player.UserId

	-- Position room
	local pos = getRoomPosition(index)
	room:PivotTo(CFrame.new(pos))

	-- Tag all wall parts with OwnerUserId for PlacementController lookup
	room:SetAttribute("OwnerUserId", player.UserId)
	room:SetAttribute("RoomIndex",   index)

	-- Tag walls/floor for PlacementController wall-surface detection
	for _, part in ipairs(room:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("OwnerUserId", player.UserId)
		end
	end

	-- Name the PlotBoundary so PlacementController can find it
	local plot = room:FindFirstChild("PlotBoundary", true)
	if plot then
		plot.Name = "StyleRoom_" .. player.UserId .. "_Plot"
	end

	-- Wire PaintPrompt billboards on each surface anchor.
	-- Each prompt has a SurfaceKey attribute: "wall_back","wall_left","wall_right","floor"
	for _, desc in ipairs(room:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.Name == "PaintPrompt" then
			local key = desc:GetAttribute("SurfaceKey")
			if key then
				desc.Triggered:Connect(function(triggeringPlayer: Player)
					if triggeringPlayer:GetAttribute("RoundPhase") ~= "Style" then return end
					if triggeringPlayer.UserId ~= player.UserId then return end
					-- Map SurfaceKey to the surface picker identifier
					OpenSurfacePicker:FireClient(player, key)
				end)
			end
		end
	end

	room.Parent = workspace
	CollectionService:AddTag(room, "StyleRoom")
	return room
end

local function wakeCharacterForTeleport(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
	character:SetAttribute("InCart", false)
	for _, cart in ipairs(CollectionService:GetTagged("PlayerCart")) do
		if cart:GetAttribute("OwnerUserId") == player.UserId then
			cart:Destroy()
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BallSocketConstraint") and descendant.Name == "RagdollBSC" then
			descendant:Destroy()
		elseif descendant:IsA("Attachment") and (descendant.Name == "RagdollAtt0" or descendant.Name == "RagdollAtt1") then
			descendant:Destroy()
		elseif descendant:IsA("Motor6D") and not descendant.Enabled then
			descendant.Enabled = true
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			pcall(function()
				descendant:SetNetworkOwner(player)
			end)
		end
	end
	root.Anchored = false
	humanoid.RequiresNeck = true
	humanoid.Sit = false
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	if humanoid.WalkSpeed < 16 then
		humanoid.WalkSpeed = 16
	end
	if humanoid.UseJumpPower then
		if humanoid.JumpPower <= 0 then
			humanoid.JumpPower = 50
		end
	else
		if humanoid.JumpHeight <= 0 then
			humanoid.JumpHeight = 7.2
		end
	end
	for _, state in ipairs({
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Freefall,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.GettingUp,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
	}) do
		humanoid:SetStateEnabled(state, true)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	task.defer(function()
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function teleportToRoom(player: Player, room: Model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and root and root:IsA("BasePart")) then return end
	wakeCharacterForTeleport(player, character, humanoid, root)

	local spawn = room:FindFirstChild("SpawnPart")
	local floor = room:FindFirstChild("Floor")
	local targetBase = room:GetPivot().Position + Vector3.new(0, 2, ROOM_D/2 - 4)
	if spawn and spawn:IsA("BasePart") then
		targetBase = spawn.Position
	elseif floor and floor:IsA("BasePart") then
		targetBase = floor.Position + Vector3.new(0, floor.Size.Y * 0.5 + 2, ROOM_D/2 - 4)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = {room}
	local floorHit = workspace:Raycast(targetBase + Vector3.new(0, 1, 0), Vector3.new(0, -10, 0), rayParams)
	local standHeight = math.max(4, humanoid.HipHeight + (root.Size.Y * 0.5) + 2)
	if floorHit then
		targetBase = Vector3.new(targetBase.X, floorHit.Position.Y + standHeight, targetBase.Z)
	else
		targetBase = targetBase + Vector3.new(0, standHeight, 0)
	end

	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	character:PivotTo(CFrame.lookAt(targetBase, targetBase + Vector3.new(0, 0, -1)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	task.delay(0.12, function()
		if not character.Parent or not root.Parent then
			return
		end
		local correction = workspace:Raycast(targetBase + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rayParams)
		if correction and root.Position.Y < correction.Position.Y + 2 then
			character:PivotTo(CFrame.lookAt(Vector3.new(targetBase.X, correction.Position.Y + standHeight, targetBase.Z), targetBase + Vector3.new(0, 0, -1)))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

local function destroyRoomsForCohort(cohort: {Player})
	for _, player in ipairs(cohort) do
		local room = playerRooms[player.UserId]
		if room then
			room:Destroy()
			playerRooms[player.UserId] = nil
		end
		roundInventory[player.UserId] = nil
		freeRoomSlot(player.UserId)
	end
end

local function spawnStyleRooms(playerList: {Player})
	destroyRoomsForCohort(playerList)

	-- Per-player fault isolation. A bare loop meant one player failing to get a room
	-- aborted the loop, so every player after them was never teleported and never had
	-- wakeCharacterForTeleport restore their movement. Solo testing cannot surface this.
	local built = 0
	for _, player in ipairs(playerList) do
		local ok, err = pcall(function()
			buildRoundInventory(player)
			local slot = allocateRoomSlot()
			roomSlotByUser[player.UserId] = slot
			local room = createRoomForPlayer(player, slot)
			if not room then
				error("createRoomForPlayer returned nil", 0)
			end
			playerRooms[player.UserId] = room
			built += 1
			task.delay(0.3, function()  -- short delay for room to settle
				local tok, terr = pcall(teleportToRoom, player, room)
				if not tok then
					warn(string.format("[RoomService] teleportToRoom failed for %s: %s",
						player.Name, tostring(terr)))
				end
			end)
		end)
		if not ok then
			warn(string.format("[RoomService] style room failed for %s: %s",
				player.Name, tostring(err)))
		end
	end
	if built < #playerList then
		warn(string.format("[RoomService] only %d/%d style rooms built", built, #playerList))
	end
	print(string.format("[RoomService] Spawned %d/%d style rooms", built, #playerList))
end

local function destroyAllRooms()
	for _, room in ipairs(CollectionService:GetTagged("StyleRoom")) do
		room:Destroy()
	end
	playerRooms = {}
	print("[RoomService] All style rooms destroyed")
end

-- =========================================================
--  PLACEMENT HANDLER
-- =========================================================

local function pickupPlacedItemForPlayer(player: Player, itemName: string)
	local room = playerRooms[player.UserId]
	if not room then return end
	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end
	local item = folder:FindFirstChild(itemName)
	if not item then return end
	if item:GetAttribute("PlacedBy") ~= player.UserId then return end

	local itemId = item:GetAttribute("ItemId") or itemName:gsub("_placed", "")
	item:Destroy()
	returnToInventory(player, tostring(itemId))
	PickupPlacedItem:FireClient(player, itemId)
end

local function validatePlacementSurface(room: Model, placementSurface: string, placeCFrame: CFrame, source: Instance): boolean
	local extents = if source:IsA("Model") then source:GetExtentsSize() else (source :: BasePart).Size
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { room }

	if placementSurface == "Wall" then
		local reach = math.max(3, extents.Z + 1.5)
		local hit = workspace:Raycast(placeCFrame.Position, -placeCFrame.LookVector * reach, params)
		if not hit then
			hit = workspace:Raycast(placeCFrame.Position, placeCFrame.LookVector * reach, params)
		end
		return hit ~= nil and hit.Instance ~= nil and hit.Instance:GetAttribute("SurfaceType") == "Wall"
	elseif placementSurface == "Ceiling" then
		local hit = workspace:Raycast(placeCFrame.Position, Vector3.new(0, math.max(3, extents.Y + 2), 0), params)
		return hit ~= nil and hit.Instance ~= nil and hit.Instance:GetAttribute("SurfaceType") == "Ceiling"
	end

	local hit = workspace:Raycast(placeCFrame.Position + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), params)
	if not hit or not hit.Instance then
		return false
	end
	local surfaceType = hit.Instance:GetAttribute("SurfaceType")
	return surfaceType == "Floor" or surfaceType == nil
end

PlaceItemEvent.OnServerEvent:Connect(function(player: Player, itemId: string, placeCFrame: CFrame)
	if player:GetAttribute("RoundPhase") ~= "Style" then return end

	local room = playerRooms[player.UserId]
	if not room then return end

	-- Validate itemId
	if typeof(itemId) ~= "string" or itemId == "" then return end
	if typeof(placeCFrame) ~= "CFrame" then return end
	local source = ItemAssets and ItemAssets:FindFirstChild(itemId)
	if not source then return end

	-- Validate CFrame is inside the room (basic sanity check)
	local roomPos = room:GetPivot().Position
	local dist = (placeCFrame.Position - roomPos).Magnitude
	if dist > MAX_PLACE_DISTANCE + ROOM_W then return end  -- generous bound

	local itemData = ItemDatabase.Get(itemId)
	local placementSurface = itemData and itemData.PlacementSurface or "Floor"
	if not validatePlacementSurface(room, placementSurface, placeCFrame, source) then return end

	-- Last gate, and the only one that consumes: the player must actually hold this piece.
	if not takeFromInventory(player, itemId) then return end

	-- Clone and place
	local placed = source:Clone()
	nextPlacedId += 1
	placed.Name = string.format("%s_placed_%s", itemId, HttpService:GenerateGUID(false):sub(1, 8) .. tostring(nextPlacedId))
	placed:SetAttribute("ItemId", itemId)
	placed:SetAttribute("PlacedBy", player.UserId)
	placed:SetAttribute("PlacementSurface", placementSurface)
	placed:SetAttribute("Theme", itemData and itemData.Theme or "Neutral")
	placed:SetAttribute("Rarity", itemData and itemData.Rarity or "Common")
	if placementSurface == "Wall" then
		placed:SetAttribute("PlacementCategory", "WallMounted")
	end

	-- Store original appearance on each part before anchoring
	for _, part in ipairs(placed:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("OrigColor", tostring(part.Color))
			part:SetAttribute("OrigMaterial", tostring(part.Material))
			part.Anchored = true
			part.CanCollide = placementSurface == "Floor"
		end
	end

	placed:PivotTo(placeCFrame)

	local folder = room:FindFirstChild("PlacedItems")
	placed.Parent = folder or room
	attachMovePrompt(placed, itemId)
	attachEditPrompt(placed, itemId)
	for _, descendant in ipairs(placed:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "MovePrompt" then
			descendant.Triggered:Connect(function(triggeringPlayer: Player)
				if triggeringPlayer:GetAttribute("RoundPhase") ~= "Style" then return end
				if triggeringPlayer.UserId ~= player.UserId then return end
				pickupPlacedItemForPlayer(triggeringPlayer, placed.Name)
			end)
		elseif descendant:IsA("ProximityPrompt") and descendant.Name == "EditPrompt" then
			descendant.Triggered:Connect(function(triggeringPlayer: Player)
				if triggeringPlayer:GetAttribute("RoundPhase") ~= "Style" then return end
				if triggeringPlayer.UserId ~= player.UserId then return end
				OpenItemAppearance:FireClient(triggeringPlayer, placed.Name)
			end)
		end
	end

	-- Tell client item was placed (itemId, placed instance name)
	ItemPlaced:FireClient(player, itemId, placed.Name)
end)

-- =========================================================
--  SURFACE CUSTOMIZATION (wall color / floor material+color)
-- =========================================================

-- surface = "wall" | "floor"
-- color = Color3
-- material = Enum.Material (optional, floor only)
local WALL_MAP = {
	wall       = { "WallBack", "WallLeft", "WallRight" },
	wall_all   = { "WallBack", "WallLeft", "WallRight" },
	wall_back  = { "WallBack" },
	wall_left  = { "WallLeft" },
	wall_right = { "WallRight" },
}

local FLOOR_PART_NAMES = { "Floor" }

SetRoomSurface.OnServerEvent:Connect(function(player: Player, surface: string, color: Color3, material: EnumItem?)
	if typeof(color) ~= "Color3" then return end
	local canon = string.gsub(string.lower(tostring(surface)), "[^%a]", "")
	if canon == "wallback" then surface = "wall_back"
	elseif canon == "wallleft" then surface = "wall_left"
	elseif canon == "wallright" then surface = "wall_right"
	elseif canon == "back" then surface = "wall_back"
	elseif canon == "left" then surface = "wall_left"
	elseif canon == "right" then surface = "wall_right"
	elseif canon == "all" then surface = "wall"
	elseif string.find(canon, "floor", 1, true) then surface = "floor"
	elseif string.find(canon, "wall", 1, true) then surface = "wall"
	end
	local room = playerRooms[player.UserId]
	if not room then return end

	if surface == "floor" then
		for _, name in ipairs(FLOOR_PART_NAMES) do
			local floorPart = findRoomPart(room, name)
			if floorPart then
				floorPart.Color = color
				if material then
					floorPart.Material = material
				end
			end
		end
	else
		local wallNames = WALL_MAP[surface]
		print("[RoomService] paint surface=" .. tostring(surface) .. " walls=" .. tostring(wallNames and #wallNames or "nil"))
		if not wallNames then return end
		for _, name in ipairs(wallNames) do
			local wallPart = findRoomPart(room, name)
			if wallPart then
				wallPart.Color = color
				if material then
					wallPart.Material = material
				end
			end
		end
	end
end)

-- =========================================================
--  ITEM APPEARANCE CUSTOMIZATION
-- =========================================================

-- itemName = placed item name in PlacedItems folder
-- color = Color3, material = Enum.Material
SetItemAppearance.OnServerEvent:Connect(function(player: Player, itemName: string, color: Color3, material: EnumItem?)
	local room = playerRooms[player.UserId]
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

-- =========================================================
--  RESET ITEM APPEARANCE
-- =========================================================

ResetItemAppearance.OnServerEvent:Connect(function(player: Player, itemName: string)
	local room = playerRooms[player.UserId]
	if not room then return end
	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end
	local item = folder:FindFirstChild(itemName)
	if not item then return end
	if item:GetAttribute("PlacedBy") ~= player.UserId then return end

	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			local origColor    = part:GetAttribute("OrigColor")
			local origMaterial = part:GetAttribute("OrigMaterial")
			if origColor then
				-- Parse stored color string back to Color3
				local r,g,b = origColor:match("([%d%.]+), ([%d%.]+), ([%d%.]+)")
				if r then part.Color = Color3.new(tonumber(r), tonumber(g), tonumber(b)) end
			end
			if origMaterial then
				local ok, mat = pcall(function() return Enum.Material[origMaterial:match("%.(%w+)$") or origMaterial] end)
				if ok and mat then part.Material = mat end
			end
		end
	end
end)

-- =========================================================
--  PICKUP PLACED ITEM (lift back to placement mode)
-- =========================================================

PickupPlacedItem.OnServerEvent:Connect(function(player: Player, itemName: string)
	if player:GetAttribute("RoundPhase") ~= "Style" then return end
	pickupPlacedItemForPlayer(player, itemName)
end)

-- =========================================================
--  ROOM INFO (client asks for its room position)
-- =========================================================

GetRoomInfo.OnServerInvoke = function(player: Player)
	local room = playerRooms[player.UserId]
	if not room then return nil end
	local pivot = room:GetPivot()
	return {
		position   = pivot.Position,
		roomWidth  = ROOM_W,
		roomDepth  = ROOM_D,
		roomHeight = ROOM_H,
	}
end

-- =========================================================
--  PHASE LISTENER
--  Use PhaseChanged RemoteEvent fired by RoundManager.
--  game:GetAttributeChangedSignal fires client-side only in some contexts,
--  so we hook the server BindableEvent instead.
-- =========================================================

local function onRoundPhaseChanged(roundId: string, phase: string, cohort: {Player})
	if phase == "Style" then
		task.wait(0.3)
		spawnStyleRooms(cohort)
		setRoomInteractionEnabled(cohort, true)
	elseif phase == "Judge" then
		setRoomInteractionEnabled(cohort, false)
	elseif phase == "Results" or phase == "Shop" or phase == "" then
		setRoomInteractionEnabled(cohort, false)
		destroyRoomsForCohort(cohort)
	end
end

local RoundPhaseServer = Events:WaitForChild("RoundPhaseServer", 15)
if RoundPhaseServer and RoundPhaseServer:IsA("BindableEvent") then
	print("[RoomService] Connected to RoundPhaseServer")
	RoundPhaseServer.Event:Connect(onRoundPhaseChanged)
end
print("[RoomService] Round Phase listener ready")

-- Clean up if player leaves during style phase
Players.PlayerRemoving:Connect(function(player: Player)
	local room = playerRooms[player.UserId]
	if room then
		room:Destroy()
		playerRooms[player.UserId] = nil
	end
	roundInventory[player.UserId] = nil
	freeRoomSlot(player.UserId)
end)

-- =========================================================
--  LIGHTING CUSTOMIZATION
--  Client fires SetRoomLighting(ambientColor, pointColor, brightness)
--  Server finds the room's CeilLight PointLights and WinGlow PointLight,
--  updates their Color and Brightness, and sets room ambient via an
--  AmbientLight attribute so judges can see the same view.
-- =========================================================

SetRoomLighting.OnServerEvent:Connect(function(player: Player, ambientColor: Color3, pointColor: Color3, brightness: number)
	if typeof(ambientColor) ~= "Color3" or typeof(pointColor) ~= "Color3" then return end
	if typeof(brightness) ~= "number" then brightness = 1 end
	brightness = math.clamp(brightness, 0.1, 3)

	local room = playerRooms[player.UserId]
	if not room then return end

	for _, desc in ipairs(room:GetDescendants()) do
		if desc:IsA("PointLight") then
			desc.Color = pointColor
			desc.Brightness = brightness
		end
	end
	-- Store on room so judge view can read it
	room:SetAttribute("AmbientColor", ambientColor)
	room:SetAttribute("LightColor", pointColor)
	room:SetAttribute("LightBrightness", brightness)
end)

print("[RoomService] Loaded")
