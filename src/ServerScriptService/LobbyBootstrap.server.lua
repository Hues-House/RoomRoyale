--!strict
-- ServerScriptService > LobbyBootstrap
-- Builds the PERSISTENT hub area: boutique display pedestals.
-- Built once at startup and kept live forever — hub is always on.
-- Queue/round logic lives in RoundManager.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local ProgressionService     = require(script.Parent:WaitForChild("ProgressionService"))
local PersistentStoreCatalog = require(ReplicatedStorage:WaitForChild("PersistentStoreCatalog"))
local ItemDatabase           = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local ShowroomBootstrap      = require(script.Parent:WaitForChild("ShowroomBootstrap"))
local UITheme                = require(ReplicatedStorage:WaitForChild("UITheme"))

local Events = ReplicatedStorage:WaitForChild("Events", 15)

local function ensureEvent(name: string, className: string)
	local existing = Events:FindFirstChild(name)
	if existing and existing.ClassName == className then return existing end
	if existing then existing:Destroy() end
	local e = Instance.new(className)
	e.Name = name; e.Parent = Events
	return e
end

local LobbyBoutiqueRefresh = ensureEvent("LobbyBoutiqueRefresh", "RemoteEvent")
local RequestLobbyPurchase = ensureEvent("RequestLobbyPurchase", "RemoteFunction")

-- =========================================================
--  CONFIG
-- =========================================================

local LOBBY_FLOOR_Y  = 0.5
local LOBBY_Z_CENTER = 240
local LOBBY_X_CENTER = 0

-- Two flanking pedestals (no dead-center one) so the spawn sightline toward the
-- boutique stays clear; the full catalog is in the Boutique panel anyway.
local PEDESTAL_DEFS = {
	{ offsetX = -40, offsetZ = 30 },
	{ offsetX =  40, offsetZ = 30 },
}

local PEDESTAL_BASE_H    = 1.0
local PEDESTAL_COLUMN_H  = 3.2
local PEDESTAL_TOP_H     = 0.55
local PEDESTAL_W         = 3.8
local ITEM_DISPLAY_Y_OFF = 0.6

local FLOOR_SIZE_X = 110
local FLOOR_SIZE_Z = 96

-- =========================================================
--  STATE
-- =========================================================

local lobbyFolder: Folder? = nil
local pedestalEntries: {[string]: string} = {}
local hubBuilt = false

-- =========================================================
--  GEOMETRY HELPERS
-- =========================================================

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame,
		color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cframe; p.Color = color
	p.Material = material; p.Transparency = transparency or 0
	p.Anchored = true; p.CanCollide = true; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function addPointLight(part: Part, brightness: number, range: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Brightness = brightness; light.Range = range; light.Color = color; light.Parent = part
end

local function stripForDisplay(instance: Instance)
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("Sound")
			or desc:IsA("ProximityPrompt") or desc:IsA("ClickDetector") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true; desc.CanCollide = false; desc.CastShadow = false
		end
	end
	if instance:IsA("BasePart") then
		(instance :: BasePart).Anchored = true
		(instance :: BasePart).CanCollide = false
	end
end

-- =========================================================
--  BILLBOARD GUI
-- =========================================================

local RARITY_COLORS = UITheme.RarityColors

local function makePedestalBillboard(adornee: BasePart, entry, isOwned: boolean): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "PedestalBillboard"; bb.Size = UDim2.fromOffset(220, 90)
	bb.StudsOffset = Vector3.new(0, 4.2, 0); bb.AlwaysOnTop = false
	bb.MaxDistance = 40; bb.LightInfluence = 0; bb.Adornee = adornee; bb.Parent = adornee

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.fromRGB(255, 253, 248)
	bg.BackgroundTransparency = 0.08; bg.BorderSizePixel = 0; bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14); corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = RARITY_COLORS[entry.Rarity or "Common"] or Color3.fromRGB(210,200,182)
	stroke.Thickness = 2; stroke.Transparency = isOwned and 0.4 or 0.12; stroke.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"; nameLabel.Size = UDim2.new(1, -16, 0, 28)
	nameLabel.Position = UDim2.fromOffset(8, 8); nameLabel.BackgroundTransparency = 1
	nameLabel.Text = entry.DisplayName or entry.ItemId
	nameLabel.TextColor3 = Color3.fromRGB(58, 48, 36); nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 20; nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd; nameLabel.Parent = bg

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"; rarityLabel.Size = UDim2.new(0.5, -8, 0, 18)
	rarityLabel.Position = UDim2.fromOffset(8, 38); rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = entry.Rarity or "Common"
	rarityLabel.TextColor3 = RARITY_COLORS[entry.Rarity or "Common"] or Color3.fromRGB(128,183,135)
	rarityLabel.Font = Enum.Font.GothamBold; rarityLabel.TextSize = 13
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left; rarityLabel.Parent = bg

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "Price"; priceLabel.Size = UDim2.new(1, -16, 0, 18)
	priceLabel.Position = UDim2.fromOffset(8, 58); priceLabel.BackgroundTransparency = 1
	local priceText
	if isOwned then
		priceText = "✓ In your collection"
	elseif entry.PurchaseType == "Coins" then
		priceText = string.format("✨ %d Style Bucks", entry.CurrencyPrice or 0)
	else
		priceText = string.format("💎 R$ %d", entry.RobuxPrice or 0)
	end
	priceLabel.Text = priceText
	priceLabel.TextColor3 = isOwned and Color3.fromRGB(88, 168, 118) or Color3.fromRGB(212, 167, 82)
	priceLabel.Font = Enum.Font.GothamBold; priceLabel.TextSize = 13
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left; priceLabel.Parent = bg

	return bb
end

local function refreshPedestalBillboard(topPart: BasePart, entry, isOwned: boolean)
	local existing = topPart:FindFirstChild("PedestalBillboard")
	if existing then existing:Destroy() end
	makePedestalBillboard(topPart, entry, isOwned)
end

-- =========================================================
--  PEDESTAL BUILDER
-- =========================================================

local function buildPedestal(parent: Folder, index: number, entry, worldX: number, worldZ: number)
	local pFolder = Instance.new("Folder")
	pFolder.Name = "Pedestal_" .. index; pFolder.Parent = parent

	local baseY = LOBBY_FLOOR_Y + PEDESTAL_BASE_H * 0.5
	local colY  = LOBBY_FLOOR_Y + PEDESTAL_BASE_H + PEDESTAL_COLUMN_H * 0.5
	local topY  = LOBBY_FLOOR_Y + PEDESTAL_BASE_H + PEDESTAL_COLUMN_H + PEDESTAL_TOP_H * 0.5

	local creamWhite = Color3.fromRGB(242, 238, 230)
	local colColor   = Color3.fromRGB(220, 215, 205)
	local topColor   = Color3.fromRGB(250, 248, 244)

	makePart(pFolder, "Base", Vector3.new(PEDESTAL_W, PEDESTAL_BASE_H, PEDESTAL_W),
		CFrame.new(worldX, baseY, worldZ), creamWhite, Enum.Material.SmoothPlastic)
	makePart(pFolder, "Column",
		Vector3.new(PEDESTAL_W * 0.55, PEDESTAL_COLUMN_H, PEDESTAL_W * 0.55),
		CFrame.new(worldX, colY, worldZ), colColor, Enum.Material.SmoothPlastic)

	local topPart = makePart(pFolder, "Top",
		Vector3.new(PEDESTAL_W * 0.82, PEDESTAL_TOP_H, PEDESTAL_W * 0.82),
		CFrame.new(worldX, topY, worldZ), topColor, Enum.Material.SmoothPlastic)
	topPart.CanCollide = true

	local rarityColor = RARITY_COLORS[entry.Rarity or "Common"] or Color3.fromRGB(212, 167, 82)
	addPointLight(topPart, 1.4, 14, rarityColor)

	local ringY = LOBBY_FLOOR_Y + PEDESTAL_BASE_H + PEDESTAL_COLUMN_H + PEDESTAL_TOP_H + 0.06
	local ring = makePart(pFolder, "RarityRing",
		Vector3.new(PEDESTAL_W * 0.82 + 0.3, 0.14, PEDESTAL_W * 0.82 + 0.3),
		CFrame.new(worldX, ringY, worldZ), rarityColor, Enum.Material.Neon)
	ring.CanCollide = false; ring.CastShadow = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BoutiquePrompt"; prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = entry.PurchaseType == "Coins"
		and string.format("Buy for %d Bucks", entry.CurrencyPrice or 0)
		or string.format("Buy for R$ %d", entry.RobuxPrice or 0)
	prompt.ObjectText = entry.DisplayName or entry.ItemId
	prompt.KeyboardKeyCode = Enum.KeyCode.E; prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16; prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = topPart
	CollectionService:AddTag(topPart, "LobbyBoutiqueItem")
	topPart:SetAttribute("BoutiqueEntryId", entry.Id)
	topPart:SetAttribute("BoutiqueItemId", entry.ItemId)

	local itemY = topY + PEDESTAL_TOP_H * 0.5 + ITEM_DISPLAY_Y_OFF
	local ItemAssets = ReplicatedStorage:FindFirstChild("ItemAssets")
	local template = ItemAssets and ItemAssets:FindFirstChild(entry.ItemId)
	if template then
		local clone = template:Clone()
		stripForDisplay(clone)
		if clone:IsA("Model") then
			local bbCF, bbSize = clone:GetBoundingBox()
			local currentBottom = bbCF.Position.Y - bbSize.Y * 0.5
			local offset = Vector3.new(
				worldX - bbCF.Position.X,
				itemY - currentBottom,
				worldZ - bbCF.Position.Z)
			clone:PivotTo(clone:GetPivot() + offset)
		elseif clone:IsA("BasePart") then
			local bp = clone :: BasePart
			bp.CFrame = CFrame.new(worldX, itemY + bp.Size.Y * 0.5, worldZ)
		end
		clone.Name = "DisplayItem"; clone.Parent = pFolder
	end

	local isOwned = entry._owned == true
	refreshPedestalBillboard(topPart, entry, isOwned)
	if isOwned then prompt.Enabled = false end

	return topPart
end

-- =========================================================
--  LOBBY FLOOR PAD
-- =========================================================

local function buildLobbyFloor(parent: Folder)
	local floorY = LOBBY_FLOOR_Y - 0.1
	local floor = makePart(parent, "LobbyFloor",
		Vector3.new(FLOOR_SIZE_X, 0.2, FLOOR_SIZE_Z),
		CFrame.new(LOBBY_X_CENTER, floorY, LOBBY_Z_CENTER),
		Color3.fromRGB(238, 216, 190), Enum.Material.Brick)
	floor.CanCollide = true

	for _, xSide in ipairs({-FLOOR_SIZE_X * 0.5 + 0.4, FLOOR_SIZE_X * 0.5 - 0.4}) do
		local border = makePart(parent, "FloorBorder",
			Vector3.new(0.6, 0.22, FLOOR_SIZE_Z),
			CFrame.new(LOBBY_X_CENTER + xSide, floorY + 0.01, LOBBY_Z_CENTER),
			Color3.fromRGB(212, 167, 82), Enum.Material.SmoothPlastic)
		border.CanCollide = false
	end
	for _, zSide in ipairs({-FLOOR_SIZE_Z * 0.5 + 0.4, FLOOR_SIZE_Z * 0.5 - 0.4}) do
		local border = makePart(parent, "FloorBorder",
			Vector3.new(FLOOR_SIZE_X, 0.22, 0.6),
			CFrame.new(LOBBY_X_CENTER, floorY + 0.01, LOBBY_Z_CENTER + zSide),
			Color3.fromRGB(212, 167, 82), Enum.Material.SmoothPlastic)
		border.CanCollide = false
	end

	local signPart = makePart(parent, "BoutiqueSign",
		Vector3.new(26, 4, 0.4),
		CFrame.new(LOBBY_X_CENTER, LOBBY_FLOOR_Y + 15, LOBBY_Z_CENTER + FLOOR_SIZE_Z * 0.5 - 6)
			* CFrame.Angles(0, math.rad(180), 0),
		Color3.fromRGB(255, 253, 248), Enum.Material.SmoothPlastic)
	signPart.CanCollide = false

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front; signGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	signGui.CanvasSize = Vector2.new(880, 140); signGui.AlwaysOnTop = false; signGui.Parent = signPart

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1); signLabel.BackgroundTransparency = 1
	signLabel.Text = "Today's Boutique"
	signLabel.TextColor3 = Color3.fromRGB(58, 48, 36); signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextSize = 72; signLabel.TextXAlignment = Enum.TextXAlignment.Center
	signLabel.Parent = signGui
end

-- =========================================================
--  QUEUE RING  —  physical "step in to join the round" pad.
--  Geometry + a tagged touch sensor only; LobbyClient turns a
--  local step-in into RequestJoinQueue (the SAME queue as the
--  Join Round button). Sits on the central plaza lane, clear
--  of the fountain and boutique pedestals.
-- =========================================================

local QUEUE_RING_CENTER = Vector3.new(LOBBY_X_CENTER, LOBBY_FLOOR_Y, 208)
local QUEUE_RING_RADIUS = 5.2

local function buildQueueRing(parent: Folder)
	local ring = Instance.new("Folder")
	ring.Name = "QueueRing"
	ring.Parent = parent

	local cx, cy, cz = QUEUE_RING_CENTER.X, QUEUE_RING_CENTER.Y, QUEUE_RING_CENTER.Z
	local gold     = Color3.fromRGB(212, 167, 82)
	local goldGlow = Color3.fromRGB(245, 214, 140)

	-- Translucent glow disc on the floor.
	local pad = Instance.new("Part")
	pad.Name = "GlowPad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.2, QUEUE_RING_RADIUS * 2, QUEUE_RING_RADIUS * 2)
	pad.CFrame = CFrame.new(cx, cy + 0.07, cz) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = goldGlow
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.6
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = false
	pad.CastShadow = false
	pad.Parent = ring

	-- Raised gold rim of tangent segments.
	local segCount = 32
	local chord = 2 * QUEUE_RING_RADIUS * math.sin(math.pi / segCount) + 0.2
	for i = 0, segCount - 1 do
		local ang = (i / segCount) * math.pi * 2
		local sx = cx + math.cos(ang) * QUEUE_RING_RADIUS
		local sz = cz + math.sin(ang) * QUEUE_RING_RADIUS
		local seg = Instance.new("Part")
		seg.Name = "RimSeg"
		seg.Size = Vector3.new(chord, 0.55, 0.7)
		seg.CFrame = CFrame.lookAt(Vector3.new(sx, cy + 0.35, sz), Vector3.new(cx, cy + 0.35, cz))
		seg.Color = gold
		seg.Material = Enum.Material.Neon
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanTouch = false
		seg.CastShadow = false
		seg.Parent = ring
	end

	-- Soft warm glow.
	local lightAnchor = Instance.new("Part")
	lightAnchor.Name = "RingLight"
	lightAnchor.Size = Vector3.new(0.4, 0.4, 0.4)
	lightAnchor.CFrame = CFrame.new(cx, cy + 1.4, cz)
	lightAnchor.Transparency = 1
	lightAnchor.Anchored = true
	lightAnchor.CanCollide = false
	lightAnchor.CanTouch = false
	lightAnchor.CastShadow = false
	lightAnchor.Parent = ring
	addPointLight(lightAnchor, 1.7, 20, goldGlow)

	-- Invisible touch sensor filling the ring.
	local sensor = Instance.new("Part")
	sensor.Name = "Sensor"
	sensor.Shape = Enum.PartType.Cylinder
	sensor.Size = Vector3.new(7, QUEUE_RING_RADIUS * 2 - 0.8, QUEUE_RING_RADIUS * 2 - 0.8)
	sensor.CFrame = CFrame.new(cx, cy + 3, cz) * CFrame.Angles(0, 0, math.rad(90))
	sensor.Transparency = 1
	sensor.Anchored = true
	sensor.CanCollide = false
	sensor.CanTouch = true
	sensor.CastShadow = false
	sensor.Parent = ring
	CollectionService:AddTag(sensor, "QueueRingTrigger")

	-- Floating call-to-action.
	local labelAnchor = Instance.new("Part")
	labelAnchor.Name = "LabelAnchor"
	labelAnchor.Size = Vector3.new(0.4, 0.4, 0.4)
	labelAnchor.CFrame = CFrame.new(cx, cy + 4.4, cz)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.CanTouch = false
	labelAnchor.CastShadow = false
	labelAnchor.Parent = ring

	local bb = Instance.new("BillboardGui")
	bb.Name = "RingLabel"
	bb.Size = UDim2.fromOffset(220, 70)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Adornee = labelAnchor
	bb.Parent = labelAnchor

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 253, 248)
	bg.BackgroundTransparency = 0.08
	bg.BorderSizePixel = 0
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = gold
	stroke.Thickness = 2.5
	stroke.Transparency = 0.1
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -14, 0.56, 0)
	title.Position = UDim2.fromOffset(7, 5)
	title.BackgroundTransparency = 1
	title.Text = "Join the Round"
	title.TextColor3 = Color3.fromRGB(58, 48, 36)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Parent = bg

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -14, 0.36, 0)
	sub.Position = UDim2.new(0, 7, 0.58, 0)
	sub.BackgroundTransparency = 1
	sub.Text = "Step inside to queue up"
	sub.TextColor3 = Color3.fromRGB(118, 100, 78)
	sub.Font = Enum.Font.GothamMedium
	sub.TextScaled = true
	sub.Parent = bg
end

-- =========================================================
--  FULL HUB BUILD
-- =========================================================

local function buildLobbyArea()
	if hubBuilt then return end
	hubBuilt = true
	local existing = workspace:FindFirstChild("LobbyArea")
	if existing then existing:Destroy() end
	table.clear(pedestalEntries)

	local folder = Instance.new("Folder")
	folder.Name = "LobbyArea"; folder.Parent = workspace
	lobbyFolder = folder

	buildLobbyFloor(folder)
	buildQueueRing(folder)

	local entries = ProgressionService.GetRotationEntries(nil)
	local displayCount = math.min(#PEDESTAL_DEFS, #entries)

	for i = 1, displayCount do
		local entry = entries[i]
		local def = PEDESTAL_DEFS[i]
		local worldX = LOBBY_X_CENTER + def.offsetX
		local worldZ = LOBBY_Z_CENTER + def.offsetZ

		local itemData = ItemDatabase.Get(entry.ItemId)
		entry.DisplayName = itemData and itemData.Name or entry.ItemId
		entry.Rarity = itemData and itemData.Rarity or "Common"

		local topPart = buildPedestal(folder, i, entry, worldX, worldZ)
		pedestalEntries[topPart.Name] = entry.Id
	end
end

-- =========================================================
--  PURCHASE HANDLER
-- =========================================================

RequestLobbyPurchase.OnServerInvoke = function(player: Player, entryId: string)
	if typeof(entryId) ~= "string" then
		return { success = false, message = "Invalid item." }
	end
	local result = ProgressionService.HandlePurchase(player, entryId, nil)
	if type(result) == "table" and result.success then
		LobbyBoutiqueRefresh:FireAllClients(entryId, player.UserId)
		task.spawn(function()
			local lobbyArea = workspace:FindFirstChild("LobbyArea")
			if not lobbyArea then return end
			for _, desc in ipairs(lobbyArea:GetDescendants()) do
				if desc:IsA("BasePart")
					and CollectionService:HasTag(desc, "LobbyBoutiqueItem")
					and desc:GetAttribute("BoutiqueEntryId") == entryId then
					local prompt = desc:FindFirstChildOfClass("ProximityPrompt")
					if prompt then prompt.Enabled = false end
				end
			end
		end)
	end
	return result
end

-- =========================================================
--  STARTUP: build hub once, keep it up forever
-- =========================================================

task.spawn(function()
	task.wait(0.4)
	print("[LobbyBootstrap] Building hub area...")
	buildLobbyArea()
	print("[LobbyBootstrap] Hub area ready (persistent)")
end)

print("[LobbyBootstrap] Loaded")--!strict

-- Neighborhood decor (plaza hangouts, boulevard) - appended
task.spawn(function()
	local nbm = script.Parent:WaitForChild("NeighborhoodBootstrap", 10)
	if nbm then
		local ok, err = pcall(function() require(nbm).EnsureAll() end)
		if not ok then warn("[LobbyBootstrap] Neighborhood build failed: " .. tostring(err)) end
	end
end)
