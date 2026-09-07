local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))

local Events = ReplicatedStorage:WaitForChild("Events", 15)

local PICKUP_FOLDER_NAME = "ShopCurrencyPickups"
local PICKUP_HEIGHT = 1.2
local COIN_SIZE = Vector3.new(1.35, 0.26, 1.35)
local RIM_SIZE = Vector3.new(1.42, 0.1, 1.42)
local STAMP_SIZE = Vector3.new(0.36, 0.04, 0.22)
local TRIGGER_SIZE = Vector3.new(3.5, 2.6, 3.5)
local SPIN_SPEED = math.rad(135)
local BOB_HEIGHT = 0.08
local BOB_SPEED = 2.8
local PICKUP_OFFSETS = {
	Vector3.new(-88, PICKUP_HEIGHT, -136),
	Vector3.new(-52, PICKUP_HEIGHT, -126),
	Vector3.new(-10, PICKUP_HEIGHT, -114),
	Vector3.new(28, PICKUP_HEIGHT, -126),
	Vector3.new(76, PICKUP_HEIGHT, -96),
	Vector3.new(-82, PICKUP_HEIGHT, -34),
	Vector3.new(-46, PICKUP_HEIGHT, -26),
	Vector3.new(-4, PICKUP_HEIGHT, -18),
	Vector3.new(38, PICKUP_HEIGHT, -24),
	Vector3.new(86, PICKUP_HEIGHT, -36),
	Vector3.new(-94, PICKUP_HEIGHT, 24),
	Vector3.new(-66, PICKUP_HEIGHT, 18),
	Vector3.new(-28, PICKUP_HEIGHT, 36),
	Vector3.new(8, PICKUP_HEIGHT, 24),
	Vector3.new(48, PICKUP_HEIGHT, 22),
	Vector3.new(88, PICKUP_HEIGHT, 16),
	Vector3.new(-84, PICKUP_HEIGHT, 86),
	Vector3.new(-48, PICKUP_HEIGHT, 72),
	Vector3.new(-8, PICKUP_HEIGHT, 58),
	Vector3.new(36, PICKUP_HEIGHT, 78),
	Vector3.new(72, PICKUP_HEIGHT, 104),
	Vector3.new(-80, PICKUP_HEIGHT, 142),
	Vector3.new(-36, PICKUP_HEIGHT, 148),
	Vector3.new(6, PICKUP_HEIGHT, 146),
	Vector3.new(46, PICKUP_HEIGHT, 142),
	Vector3.new(80, PICKUP_HEIGHT, 128),
	Vector3.new(20, PICKUP_HEIGHT, 102),
	Vector3.new(18, PICKUP_HEIGHT, -74),
}

local activeFolder: Folder? = nil
local activeCoins = {}

local function hashSeed(text: string): number
	local hash = 19
	for index = 1, #text do
		hash = (hash * 37 + string.byte(text, index)) % 2147483647
	end
	return hash
end

local function getShowroomFloor(): BasePart?
	local showroom = Workspace:FindFirstChild("TheShowroom")
	if not showroom then
		return nil
	end
	local floor = showroom:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		return floor
	end
	return nil
end

local function ensurePickupFolder(): Folder
	local existing = Workspace:FindFirstChild(PICKUP_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = PICKUP_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function clearPickups()
	local existing = Workspace:FindFirstChild(PICKUP_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	activeFolder = nil
	activeCoins = {}
end

local function resolvePlayerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if character then
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			return player
		end
		if CollectionService:HasTag(character, "PlayerCart") then
			local ownerUserId = tonumber(character:GetAttribute("OwnerUserId"))
			if ownerUserId then
				return Players:GetPlayerByUserId(ownerUserId)
			end
		end
	end

	local cursor = hit.Parent
	while cursor do
		if cursor:IsA("Model") and CollectionService:HasTag(cursor, "PlayerCart") then
			local ownerUserId = tonumber(cursor:GetAttribute("OwnerUserId"))
			if ownerUserId then
				return Players:GetPlayerByUserId(ownerUserId)
			end
		end
		cursor = cursor.Parent
	end
	return nil
end

local function makePickupVisual(parent: Instance, value: number)
	local pickup = Instance.new("Model")
	pickup.Name = string.format("Currency_%d", value)
	pickup.Parent = parent

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = COIN_SIZE
	coin.Color = Color3.fromRGB(245, 201, 73)
	coin.Material = Enum.Material.Metal
	coin.Reflectance = 0.08
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanTouch = false
	coin.CanQuery = true
	coin.CastShadow = true
	coin.TopSurface = Enum.SurfaceType.Smooth
	coin.BottomSurface = Enum.SurfaceType.Smooth
	coin.Parent = pickup

	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = RIM_SIZE
	rim.Color = Color3.fromRGB(193, 144, 41)
	rim.Material = Enum.Material.Metal
	rim.Reflectance = 0.04
	rim.Anchored = true
	rim.CanCollide = false
	rim.CanTouch = false
	rim.CanQuery = false
	rim.CastShadow = false
	rim.TopSurface = Enum.SurfaceType.Smooth
	rim.BottomSurface = Enum.SurfaceType.Smooth
	rim.Parent = pickup

	local stamp = Instance.new("Part")
	stamp.Name = "Stamp"
	stamp.Shape = Enum.PartType.Block
	stamp.Size = STAMP_SIZE
	stamp.Color = Color3.fromRGB(255, 236, 163)
	stamp.Material = Enum.Material.Metal
	stamp.Reflectance = 0.12
	stamp.Anchored = true
	stamp.CanCollide = false
	stamp.CanTouch = false
	stamp.CanQuery = false
	stamp.CastShadow = false
	stamp.TopSurface = Enum.SurfaceType.Smooth
	stamp.BottomSurface = Enum.SurfaceType.Smooth
	stamp.Parent = pickup

	local trigger = Instance.new("Part")
	trigger.Name = "PickupTrigger"
	trigger.Size = TRIGGER_SIZE
	trigger.Transparency = 1
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger.CanQuery = false
	trigger.CastShadow = false
	trigger.Parent = pickup

	pickup.PrimaryPart = trigger
	return pickup, trigger, coin, rim, stamp
end

local function spawnPickups()
	clearPickups()
	local floor = getShowroomFloor()
	if not floor then
		warn("[CurrencyPickupService] Showroom floor not found")
		return
	end

	activeFolder = ensurePickupFolder()
	local count = ProgressionConfig.GetPickupCount(#Players:GetPlayers())
	local offsets = table.clone(PICKUP_OFFSETS)
	local random = Random.new(hashSeed(os.date("!%Y-%m-%d") .. ":" .. tostring(#Players:GetPlayers())))
	for index = #offsets, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		offsets[index], offsets[swapIndex] = offsets[swapIndex], offsets[index]
	end

	for index = 1, math.min(count, #offsets) do
		local value = ProgressionConfig.PickupValues[random:NextInteger(1, #ProgressionConfig.PickupValues)]
		local pickup, trigger, coin, rim, stamp = makePickupVisual(activeFolder, value)
		local yaw = math.rad(random:NextInteger(0, 359))
		local baseCF = floor.CFrame * CFrame.new(offsets[index].X, offsets[index].Y, offsets[index].Z) * CFrame.Angles(0, yaw, math.rad(90))
		coin.CFrame = baseCF
		rim.CFrame = baseCF * CFrame.new(0, -(COIN_SIZE.Y * 0.46), 0)
		stamp.CFrame = baseCF * CFrame.new(0, (COIN_SIZE.Y * 0.56), 0)
		trigger.CFrame = CFrame.new(baseCF.Position + Vector3.new(0, 0.38, 0))
		table.insert(activeCoins, {
			model = pickup,
			coin = coin,
			rim = rim,
			stamp = stamp,
			trigger = trigger,
			position = baseCF.Position,
			yaw = yaw,
			bobOffset = random:NextNumber(0, math.pi * 2),
		})
		pickup:SetAttribute("PickupValue", value)
		pickup:SetAttribute("Collected", false)
		trigger.Touched:Connect(function(hit)
			if pickup:GetAttribute("Collected") then
				return
			end
			if not hit or not hit:IsA("BasePart") then
				return
			end
			local player = resolvePlayerFromHit(hit)
			if not player then
				return
			end
			if player:GetAttribute("RoundPhase") ~= "Shop" then
				return
			end
			pickup:SetAttribute("Collected", true)
			ProgressionService.AwardCurrencyPickup(player, value, "showroom_pickup")
			pickup:Destroy()
		end)
	end
end

RunService.Heartbeat:Connect(function()
	if #activeCoins == 0 then
		return
	end
	local now = os.clock()
	for index = #activeCoins, 1, -1 do
		local entry = activeCoins[index]
		if not (entry.model and entry.model.Parent and entry.coin and entry.coin.Parent) then
			table.remove(activeCoins, index)
			continue
		end
		local bob = math.sin((now * BOB_SPEED) + entry.bobOffset) * BOB_HEIGHT
		local spin = entry.yaw + (now * SPIN_SPEED)
		local coinCF = CFrame.new(entry.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, math.rad(90))
		entry.coin.CFrame = coinCF
		entry.rim.CFrame = coinCF * CFrame.new(0, -(COIN_SIZE.Y * 0.46), 0)
		entry.stamp.CFrame = coinCF * CFrame.new(0, (COIN_SIZE.Y * 0.58), 0)
		entry.trigger.CFrame = CFrame.new(entry.position + Vector3.new(0, 0.38 + bob, 0))
	end
end)

local function onRoundPhaseChanged(roundId: string?, phase: string?, cohort: {Player}?)
	if phase == "Shop" then
		task.delay(0.75, spawnPickups)
	else
		clearPickups()
	end
end

local RoundPhaseServer = Events:WaitForChild("RoundPhaseServer", 15)
if RoundPhaseServer and RoundPhaseServer:IsA("BindableEvent") then
	RoundPhaseServer.Event:Connect(onRoundPhaseChanged)
end
