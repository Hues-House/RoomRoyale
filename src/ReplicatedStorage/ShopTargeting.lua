--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ShopTargeting = {}

ShopTargeting.DEFAULT_DISTANCE = 16

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanizeItemName(rawName: string): string
	local sanitized = rawName:gsub("_Store$", ""):gsub("_Loose$", "")
	return sanitized:gsub("(%l)(%u)", "%1 %2"):gsub("^%l", string.upper)
end

local function isTaggedStoreItem(instance: Instance): boolean
	return CollectionService:HasTag(instance, "StoreItem")
end

local function hasStoreIdentity(instance: Instance): boolean
	if CollectionService:HasTag(instance, "StoreItem") then
		return true
	end
	if type(instance:GetAttribute("ItemId")) == "string" then
		return true
	end
	if instance.Name:match("_Store$") or instance.Name:match("_Loose$") then
		return true
	end
	-- NOTE: deliberately does NOT do a recursive descendant search for a
	-- ClickDetector here. That caused inner wrapper Models to be mistaken
	-- for the store item, so resolution stopped on the wrong (inner) model.
	return false
end

-- Walks up from the hit instance and returns the OUTERMOST store item.
-- Priority: the topmost CollectionService-tagged "StoreItem" ancestor (the
-- authoritative marker the server validates against). If none is tagged in
-- the chain, fall back to the topmost ancestor with any store identity.
-- This guarantees we never stop on an inner wrapper Model.
function ShopTargeting.ResolveStoreItem(instance: Instance?): Instance?
	-- Fast path: if this part was tagged with the root store item name, climb to the
	-- ANCESTOR with that name (store-scoped). We must not do workspace:FindFirstChild here:
	-- with per-lobby store clones, many stores hold identically-named items, so a global
	-- name lookup could resolve to another lobby's far-away item and fail the distance check.
	if instance and instance:IsA("BasePart") then
		local rootName = instance:GetAttribute("StoreItemRoot")
		if rootName then
			local current: Instance? = instance
			while current and current ~= Workspace do
				if current.Name == rootName and CollectionService:HasTag(current, "StoreItem") then
					return current
				end
				current = current.Parent
			end
		end
	end
	local current = instance
	local bestTagged: Instance? = nil
	local bestAny: Instance? = nil
	while current and current ~= Workspace do
		if isTaggedStoreItem(current) then
			bestTagged = current  -- keep climbing; remember the highest tagged one
		end
		if hasStoreIdentity(current) then
			bestAny = current
		end
		current = current.Parent
	end
	return bestTagged or bestAny
end

function ShopTargeting.GetStoreItemPosition(item: Instance): Vector3?
	if item:IsA("Model") then
		return item:GetPivot().Position
	elseif item:IsA("BasePart") then
		return item.Position
	end
	return nil
end

function ShopTargeting.IsStoreItemAvailable(item: Instance?): boolean
	return item ~= nil and item.Parent ~= nil and hasStoreIdentity(item) and item:GetAttribute("Claimed") ~= true
end

function ShopTargeting.GetAllStoreItems(): {Instance}
	local results = {}
	local seen: {[Instance]: true} = {}

	for _, item in ipairs(CollectionService:GetTagged("StoreItem")) do
		if ShopTargeting.IsStoreItemAvailable(item) and not seen[item] then
			seen[item] = true
			table.insert(results, item)
		end
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		if ShopTargeting.IsStoreItemAvailable(child) and not seen[child] then
			seen[child] = true
			table.insert(results, child)
		end
	end

	return results
end

function ShopTargeting.GetDistanceToPlayer(player: Player, item: Instance): number?
	local root = getCharacterRoot(player)
	local itemPosition = ShopTargeting.GetStoreItemPosition(item)
	if not (root and itemPosition) then
		return nil
	end
	return (root.Position - itemPosition).Magnitude
end

function ShopTargeting.IsInRange(player: Player, item: Instance, maxDistance: number?): boolean
	local distance = ShopTargeting.GetDistanceToPlayer(player, item)
	return distance ~= nil and distance <= (maxDistance or ShopTargeting.DEFAULT_DISTANCE)
end

function ShopTargeting.GetDisplayName(item: Instance): string
	local itemName = item:GetAttribute("ItemName") or item:GetAttribute("ItemId") or item.Name
	if typeof(itemName) == "string" then
		return humanizeItemName(itemName)
	end
	return humanizeItemName(item.Name)
end

function ShopTargeting.GetPointedStoreItem(target: Instance?): Instance?
	local item = ShopTargeting.ResolveStoreItem(target)
	if item and ShopTargeting.IsStoreItemAvailable(item) then
		return item
	end
	return nil
end

function ShopTargeting.FindNearestStoreItem(player: Player, maxDistance: number?): Instance?
	local nearest: Instance? = nil
	local nearestDistance = maxDistance or ShopTargeting.DEFAULT_DISTANCE
	for _, item in ipairs(ShopTargeting.GetAllStoreItems()) do
		local distance = ShopTargeting.GetDistanceToPlayer(player, item)
		if distance and distance < nearestDistance then
			nearest = item
			nearestDistance = distance
		end
	end
	return nearest
end

function ShopTargeting.GetShopFocusTarget(player: Player, pointedTarget: Instance?, maxDistance: number?, allowNearestFallback: boolean?): (Instance?, boolean)
	local pointedItem = ShopTargeting.GetPointedStoreItem(pointedTarget)
	if pointedItem then
		return pointedItem, ShopTargeting.IsInRange(player, pointedItem, maxDistance)
	end
	if allowNearestFallback then
		local nearest = ShopTargeting.FindNearestStoreItem(player, maxDistance)
		if nearest then
			return nearest, true
		end
	end
	return nil, false
end

return ShopTargeting
