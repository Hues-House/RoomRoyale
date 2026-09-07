-- ServerScriptService > HousingService
-- Manages persistent player houses in the lobby world.
-- Reuses RoomService's RoomTemplate and PlaceItemEvent infrastructure.
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

local CFG = {
	PlotSpacingZ     = -90,
	PlotStartZ       = 130,
	PlotCountPerSide = 4,
	LeftX            = -90,
	RightX           = 90,
	FloorY           = 0,
	MaxPlacements    = 30,
	MaxPlaceDistance = 35,
}

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

local function getDistrict(): Folder
	local d = workspace:FindFirstChild("HousingDistrict")
	if not d then
		d = Instance.new("Folder")
		d.Name = "HousingDistrict"
		d.Parent = workspace
	end
	return d :: Folder
end

local function getPlotPosition(index: number): Vector3
	local side = index <= CFG.PlotCountPerSide and CFG.LeftX or CFG.RightX
	local row  = (index - 1) % CFG.PlotCountPerSide
	local z    = CFG.PlotStartZ + row * CFG.PlotSpacingZ
	return Vector3.new(side, CFG.FloorY, z)
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

-- Build a thin paintable liner just inside a wall's interior face. The player paints
-- the liner; the structural wall keeps its fixed cottage-exterior colour, so interior
-- colours never bleed to the outside of the house.
local function addInteriorLiner(room: Model, wall: BasePart, centerPos: Vector3)
	local cf, sz = wall.CFrame, wall.Size
	local thinX = sz.X <= sz.Z
	local halfThin = thinX and sz.X / 2 or sz.Z / 2
	local normalDir = thinX and cf.RightVector or cf.LookVector
	if normalDir:Dot(centerPos - cf.Position) < 0 then normalDir = -normalDir end
	local liner = Instance.new("Part")
	liner.Name = wall.Name .. "Liner"
	-- Full-bleed across the wall face (no side trim reveal); tiny top/bottom inset only,
	-- to avoid z-fighting the floor/ceiling.
	liner.Size = thinX and Vector3.new(0.12, sz.Y - 0.3, sz.Z)
		or Vector3.new(sz.X, sz.Y - 0.3, 0.12)
	liner.CFrame = (cf - cf.Position) + (cf.Position + normalDir * (halfThin + 0.08))
	liner.Anchored = true
	liner.CanCollide = false
	liner.CastShadow = false
	liner.Color = Color3.fromRGB(252, 250, 247)
	liner.Material = Enum.Material.SmoothPlastic
	liner:SetAttribute("SurfaceType", "Wall")
	liner.Parent = room
	return liner
end

local function buildHouseRoom(player: Player, index: number): Model?
	local template = ServerStorage:FindFirstChild("RoomTemplate")
	if not template then
		warn("[HousingService] RoomTemplate not found in ServerStorage")
		return nil
	end

	local room = template:Clone()
	room.Name = "HouseRoom_" .. player.UserId

	local pos = getPlotPosition(index)
	local facingCF
	if pos.X < 0 then
		facingCF = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
	else
		facingCF = CFrame.new(pos) * CFrame.Angles(0, math.rad(-90), 0)
	end
	room:PivotTo(facingCF)
	-- Houses get a walkable front + cottage exterior (round rooms keep the diorama)
	-- Strip the RoomTemplate's built-in exterior so HouseShellBuilder's cottage is the only one (no double roof).
	local STRIP_EXTERIOR = {"RoofBack","RoofFront","Chimney","ChimneyCap","PorchStep","PorchAwning","PorchPostL","PorchPostR","FenceL","FenceR","MailPost","MailBox","MailFlag","FrontDoorOpen","FlowerBoxLeft","FlowerBoxRight","FlowersLeft","FlowersRight","FacadeLeft","FacadeRight","FacadeHeader","WindowTrim","SkyBackdrop"}
	for _, sn in ipairs(STRIP_EXTERIOR) do
		for _, sp in ipairs(room:GetDescendants()) do
			if sp.Name == sn then sp:Destroy() end
		end
	end
	local sfw = room:FindFirstChild("SafetyFrontWall", true)
	if sfw then sfw:Destroy() end
	local okShell, shellErr = pcall(function()
		local builder = require(script.Parent:WaitForChild("HouseShellBuilder"))
		local shell = builder.GetShell():Clone()
		shell:PivotTo(room:GetPivot())
		shell.Parent = room
	end)
	if not okShell then warn("[HousingService] shell graft failed: " .. tostring(shellErr)) end

	-- Strip the style-room template's showroom dressing (back-window glass wall, neon
	-- glow panel, neon ceiling track strips) so the house reads as a cozy cottage. Scoped
	-- to the template's VisualShell so the cottage shell's own windows (HouseShellDecor)
	-- and the paint-prompt anchors/trim are preserved.
	local visualShell = room:FindFirstChild("VisualShell")
	if visualShell then
		local stripPrefixes = {"WinGlass","WinFrame","WinDiv","WinPost","WinGlow","CeilLight"}
		local toStrip = {}
		for _, sp in ipairs(visualShell:GetDescendants()) do
			if sp:IsA("BasePart") then
				for _, pre in ipairs(stripPrefixes) do
					if sp.Name:sub(1, #pre) == pre then table.insert(toStrip, sp); break end
				end
			end
		end
		for _, sp in ipairs(toStrip) do sp:Destroy() end
	end

	-- Warm cottage ceiling light (replaces the removed showroom track lights). Kept
	-- modest: a near-opaque Neon panel + a strong PointLight blew out the interior
	-- (Bloom amplifies emissive surfaces). A small dim fixture reads as a light without
	-- washing the room. NOTE: the room is still flooded by sky ambient
	-- (Lighting.EnvironmentDiffuseScale=1), so placed lamps/mood barely register yet --
	-- see the "enclosed rooms + interior lighting" plan in the handoff doc.
	local ceilingLight = Instance.new("Part")
	ceilingLight.Name = "CottageCeilingLight"
	ceilingLight.Size = Vector3.new(2.6, 0.3, 2.6)
	ceilingLight.Anchored = true
	ceilingLight.CanCollide = false
	ceilingLight.CastShadow = false
	ceilingLight.Color = Color3.fromRGB(255, 244, 222)
	ceilingLight.Material = Enum.Material.Neon
	ceilingLight.Transparency = 0.5
	ceilingLight.CFrame = room:GetPivot() * CFrame.new(0, 17.4, 0)
	ceilingLight.Parent = room
	local warmLight = Instance.new("PointLight")
	warmLight.Brightness = 0.8
	warmLight.Range = 22
	warmLight.Color = Color3.fromRGB(255, 236, 205)
	warmLight.Parent = ceilingLight

	-- Interior wall liners (paintable). Keep the cottage exterior independent of the
	-- interior wall colours the player picks in the Decorate panel.
	local centerPos = room:GetPivot().Position
	for _, wn in ipairs({ "WallBack", "WallLeft", "WallRight" }) do
		local wall = room:FindFirstChild(wn, true)
		if wall and wall:IsA("BasePart") then
			wall.Color = Color3.fromRGB(252, 250, 247)  -- exterior stays the fixed cottage colour
			addInteriorLiner(room, wall, centerPos)
		end
	end

	room:SetAttribute("OwnerUserId", player.UserId)
	room:SetAttribute("HouseIndex",  index)
	room:SetAttribute("IsHouseRoom", true)

	for _, part in ipairs(room:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("OwnerUserId", player.UserId)
			part:SetAttribute("IsHouseRoom", true)
		end
	end

	local plot = room:FindFirstChild("PlotBoundary", true)
	if plot then
		plot.Name = "HouseRoom_" .. player.UserId .. "_Plot"
	end

	-- Owner nameplate
	local namePart = Instance.new("Part")
	namePart.Name = "OwnerSign"
	namePart.Size = Vector3.new(10, 2.5, 0.3)
	namePart.Anchored = true
	namePart.CanCollide = false
	namePart.CastShadow = false
	namePart.Transparency = 1
	namePart.Parent = room

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true  -- render over the roof so the nameplate is never occluded
	bb.MaxDistance = 80
	bb.Adornee = namePart
	bb.Parent = namePart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundColor3 = Color3.fromRGB(255, 253, 248)
	nameLabel.BackgroundTransparency = 0.1
	nameLabel.Text = player.DisplayName .. "'s Place"
	nameLabel.TextColor3 = Color3.fromRGB(58, 48, 36)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 18
	nameLabel.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bb

	-- Float the nameplate above the cottage centre (ridge ≈ y35) so it clears the roof.
	local frontWorld = room:GetPivot() * CFrame.new(0, 28, 0)
	namePart.CFrame = frontWorld

	-- Wire the surface paint prompts ([E] Paint on each wall/floor). RoomService wires
	-- these for style rooms; the house must wire its own, with a hub-only owner guard.
	for _, desc in ipairs(room:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.Name == "PaintPrompt" then
			local key = desc:GetAttribute("SurfaceKey")
			if key then
				desc.Triggered:Connect(function(trigPlayer: Player)
					if not playerCanDecorate(trigPlayer) then return end
					if trigPlayer.UserId ~= player.UserId then return end
					OpenSurfacePicker:FireClient(player, key)
				end)
			end
		end
	end

	room.Parent = getDistrict()
	CollectionService:AddTag(room, "HouseRoom")
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
		if not source then continue end

		local cf = CFrame.new(entry.cx, entry.cy, entry.cz)
			* CFrame.fromEulerAnglesXYZ(
				math.rad(entry.rx), math.rad(entry.ry), math.rad(entry.rz)
			)

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

	local ok, msg = ProgressionService.SaveHousePlacement(player, placementId, itemId, placeCFrame)
	if not ok then
		warn("[HousingService] SavePlacement rejected:", msg)
		return
	end

	local source = ItemAssets and ItemAssets:FindFirstChild(itemId)
	if not source then return end

	local roomPos = room:GetPivot().Position
	if (placeCFrame.Position - roomPos).Magnitude > CFG.MaxPlaceDistance + 25 then return end

	local folder = room:FindFirstChild("PlacedItems")
	if not folder then return end

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
	return { position = pivot.Position, roomWidth = 40, roomDepth = 30, roomHeight = 18 }
end

local function lockHousePrompts(enabled: boolean)
	for _, room in ipairs(CollectionService:GetTagged("HouseRoom")) do
		for _, desc in ipairs(room:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.Name == "HouseMovePrompt" then
				desc.Enabled = enabled
			end
		end
	end
end

-- (Removed) onPhaseChanged: housing no longer keys off a global phase signal.
-- House prompts stay enabled; per-player decorate guards (playerCanDecorate)
-- handle who may act. lockHousePrompts retained for potential manual use.

local function onPlayerAdded(player: Player)
	task.spawn(function()
		for _ = 1, 40 do
			if ProgressionService and ProgressionService.GetSnapshot(player) then break end
			task.wait(0.5)
		end
		local index = 1
		local used: {[number]: boolean} = {}
		for _, room in ipairs(CollectionService:GetTagged("HouseRoom")) do
			local idx = room:GetAttribute("HouseIndex")
			if typeof(idx) == "number" then used[idx] = true end
		end
		while used[index] and index <= 8 do index += 1 end
		if index > 8 then
			warn("[HousingService] No plot available for", player.Name)
			return
		end
		local room = buildHouseRoom(player, index)
		if not room then return end
		houseRooms[player.UserId] = room
		populateHouseFromSaved(player, room)
		print(string.format("[HousingService] House built for %s (plot %d)", player.Name, index))
	end)
end

local function onPlayerRemoving(player: Player)
	local room = houseRooms[player.UserId]
	if room then
		room:Destroy()
		houseRooms[player.UserId] = nil
	end
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
	ProgressionService = progressionServiceRef
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	print("[HousingService] Initialized")
end

return HousingService
