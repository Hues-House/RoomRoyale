-- ServerScriptService > StoreSetup
-- Spawns a curated showroom instead of the old test grid.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemAssets = ReplicatedStorage:WaitForChild("ItemAssets", 15)
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase", 15))
local ShowroomBootstrap = require(game.ServerScriptService:WaitForChild("ShowroomBootstrap", 15))
local ServerStorage = game:GetService("ServerStorage")

ShowroomBootstrap.EnsureAll()

-- ===== Per-lobby store isolation =====
-- Every active round shops in its OWN store instance so concurrent lobbies never share
-- the physical showroom. Slot 0 = the canonical workspace.TheShowroom at CENTER; slots 1+
-- = shell clones offset along +X. Each store is populated independently (a fresh random
-- roll) and its items live under <storeFolder>.StoreItems so clear/cleanup is store-scoped.
local STORE_SPACING      = 520   -- > showroom width (SX=380) so clones never overlap
local MAX_STORE_SLOTS    = 10
local STORE_ITEMS_FOLDER = "StoreItems"

local occupiedStoreSlots: {[number]: boolean} = {}
-- storeByRound[roundId] = { folder=Folder, slot=number, offset=Vector3, entryCF=CFrame? }
local storeByRound: {[string]: any} = {}

-- Pristine empty shell snapshot (taken before the canonical store is populated), used as
-- the clone source for slots 1+ so clones are cheap and never carry stale items.
local shellTemplate: Instance? = nil
local function ensureShellTemplate(): Instance?
	if shellTemplate and shellTemplate.Parent then return shellTemplate end
	local canonical = workspace:FindFirstChild("TheShowroom")
	if not canonical then
		ShowroomBootstrap.EnsureAll()
		canonical = workspace:FindFirstChild("TheShowroom")
	end
	if not canonical then return nil end
	local snap = canonical:Clone()
	snap.Name = "ShowroomShellTemplate"
	snap:SetAttribute("Version", nil)
	local oldItems = snap:FindFirstChild(STORE_ITEMS_FOLDER)
	if oldItems then oldItems:Destroy() end
	snap.Parent = ServerStorage
	shellTemplate = snap
	return snap
end

local RARITY_WEIGHT_MULTIPLIER = {
	Flexible = { Common = 1, Uncommon = 1, Rare = 1, Legendary = 1 },
	Accent = { Common = 1.2, Uncommon = 1, Rare = 0.8, Legendary = 0.45 },
	Showcase = { Common = 0.65, Uncommon = 1.1, Rare = 1.85, Legendary = 2.4 },
	RarePop = { Common = 0.4, Uncommon = 0.9, Rare = 2.1, Legendary = 3.1 },
}

local function getPromptBasePart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getBounds(instance)
	if instance:IsA("Model") then
		local root = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
		if root and not instance.PrimaryPart then
			instance.PrimaryPart = root
		end
		return instance:GetExtentsSize(), instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.Size, instance.CFrame
	end
	return Vector3.one, CFrame.new()
end

local function getItemsFolder(storeFolder: Instance): Folder
	local f = storeFolder:FindFirstChild(STORE_ITEMS_FOLDER)
	if not (f and f:IsA("Folder")) then
		if f then f:Destroy() end
		f = Instance.new("Folder")
		f.Name = STORE_ITEMS_FOLDER
		f.Parent = storeFolder
	end
	return f
end

-- Per-store clear: only destroys THIS store's items. Never a global StoreItem sweep,
-- which would wipe every other concurrent lobby's store.
local function clearStore(storeFolder: Instance)
	local f = storeFolder:FindFirstChild(STORE_ITEMS_FOLDER)
	if f then
		for _, item in ipairs(f:GetChildren()) do
			item:Destroy()
		end
	end
end

local function addRareShowcaseEffects(item, rarity)
	if rarity ~= "Rare" and rarity ~= "Legendary" then
		return
	end
	local basePart = getPromptBasePart(item)
	if not basePart then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "RareShowcase"
	highlight.FillTransparency = rarity == "Legendary" and 0.72 or 0.86
	highlight.OutlineTransparency = 0.08
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.OutlineColor = rarity == "Legendary" and Color3.fromRGB(255, 204, 127) or Color3.fromRGB(255, 229, 170)
	highlight.Parent = item

	local light = Instance.new("PointLight")
	light.Range = rarity == "Legendary" and 13 or 9
	light.Brightness = rarity == "Legendary" and 1.2 or 0.8
	light.Color = highlight.OutlineColor
	light.Parent = basePart

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "RareShimmer"
	sparkle.Rate = rarity == "Legendary" and 7 or 4
	sparkle.Speed = NumberRange.new(0.4, 1.2)
	sparkle.Lifetime = NumberRange.new(0.5, 1.1)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkle.Color = ColorSequence.new(highlight.OutlineColor)
	sparkle.LightEmission = 1
	sparkle.Parent = basePart
end

local function gatherSlots(storeFolder: Instance)
	local slotsRoot = storeFolder:FindFirstChild("StoreSlots")
	local results = {}
	if not slotsRoot then
		return results
	end
	for _, departmentFolder in ipairs(slotsRoot:GetChildren()) do
		for _, surfaceFolder in ipairs(departmentFolder:GetChildren()) do
			for _, slot in ipairs(surfaceFolder:GetChildren()) do
				if slot:IsA("BasePart") then
					table.insert(results, slot)
				end
			end
		end
	end
	table.sort(results, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return results
end

local function chooseWeighted(candidates, slotBias)
	local weights = RARITY_WEIGHT_MULTIPLIER[slotBias] or RARITY_WEIGHT_MULTIPLIER.Flexible
	local totalWeight = 0
	for _, entry in ipairs(candidates) do
		local rarity = entry.data.Rarity or "Common"
		local weight = (entry.data.SpawnChance or 0.01) * (weights[rarity] or 1)
		entry.weight = math.max(weight, 0.01)
		totalWeight += entry.weight
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = Random.new():NextNumber(0, totalWeight)
	local cursor = 0
	for _, entry in ipairs(candidates) do
		cursor += entry.weight
		if roll <= cursor then
			return entry
		end
	end
	return candidates[#candidates]
end

local function getCandidatesForSlot(slot, usedItems)
	local department = slot:GetAttribute("Department")
	local surface = slot:GetAttribute("PlacementSurface") or "Floor"
	local subsection = slot:GetAttribute("StoreSubsection")
	local candidates = {}
	for itemId, data in pairs(ItemDatabase.GetShowroomItems()) do
		if usedItems[itemId] then
			continue
		end
		if data.Department ~= department then
			continue
		end
		if (data.PlacementSurface or "Floor") ~= surface then
			continue
		end
		if subsection and subsection ~= "" and data.StoreSubsection ~= subsection then
			continue
		end
		if not ItemAssets:FindFirstChild(itemId) then
			continue
		end
		table.insert(candidates, { itemId = itemId, data = data })
	end
	-- Fallback: relax subsection constraint but KEEP surface constraint.
	-- This prevents wall/ceiling items from landing on floor slots.
	if #candidates == 0 then
		for itemId, data in pairs(ItemDatabase.GetShowroomItems()) do
			if usedItems[itemId] then continue end
			if data.Department ~= department then continue end
			if (data.PlacementSurface or "Floor") ~= surface then continue end
			if not ItemAssets:FindFirstChild(itemId) then continue end
			table.insert(candidates, { itemId = itemId, data = data })
		end
	end
	return candidates
end

local FLOOR_Y = 0.3  -- showroom floor surface Y (must match ShowroomBootstrap FY)

local function getSlotPlacementCFrame(slot, item)
	local extents = item:IsA("Model") and item:GetExtentsSize() or item.Size
	local surface = slot:GetAttribute("PlacementSurface") or "Floor"

	if surface == "Wall" then
		return slot.CFrame * CFrame.new(0, 0, -(extents.Z * 0.5))
	elseif surface == "Ceiling" then
		return CFrame.new(slot.Position - Vector3.new(0, extents.Y * 0.5, 0))
			* (slot.CFrame - slot.CFrame.Position)
	end

	-- Floor: place at slot XZ, facing south (open aisle), grounded to floor surface.
	-- We put the item pivot at slot height + half-extents, then after spawn we'll
	-- ground-snap it. Facing south (-Z) so items face the shopping aisle.
	local facingSouth = CFrame.new(slot.Position.X, (slot:GetAttribute("FloorY") or FLOOR_Y) + extents.Y * 0.5, slot.Position.Z) * slot.CFrame.Rotation
		* CFrame.Angles(0, math.pi, 0)  -- rotate 180° so front faces south
	return facingSouth
end

local function spawnStoreItemAtSlot(slot, itemId, data, itemsParent)
	local template = ItemAssets:FindFirstChild(itemId)
	if not template then
		return nil
	end
	local item = template:Clone()
	item.Name = itemId .. "_Store"
	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		elseif part:IsA("Script") or part:IsA("LocalScript") or part:IsA("Sound") then
			part:Destroy()
		end
	end
	if item:IsA("Model") and not item.PrimaryPart then
		local primary = item:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			item.PrimaryPart = primary
		end
	end
	item:PivotTo(getSlotPlacementCFrame(slot, item))
	-- Ground-snap: correct any pivot-offset so item bottom sits on floor surface.
	if (data.PlacementSurface or "Floor") == "Floor" then
		-- (removed bogus 12-value destructure; GetBoundingBox returns 2 values)
		-- GetBoundingBox returns (cf, size); recalculate actual bottom
		local cf2, sz2 = item:GetBoundingBox()
		local bottomY = cf2.Position.Y - sz2.Y * 0.5
		local gap = (slot:GetAttribute("FloorY") or FLOOR_Y) - bottomY
		if math.abs(gap) > 0.01 then
			item:PivotTo(item:GetPivot() * CFrame.new(0, gap, 0))
		end
	end
	item:SetAttribute("ItemId", itemId)
	item:SetAttribute("ItemName", data.Name or itemId)
	item:SetAttribute("Claimed", false)
	item:SetAttribute("Department", data.Department or "Accessories")
	item:SetAttribute("PlacementSurface", data.PlacementSurface or "Floor")
	item:SetAttribute("StoreSubsection", data.StoreSubsection or "Decor")
	item:SetAttribute("Rarity", data.Rarity or "Common")
	item:SetAttribute("Theme", data.Theme or "Neutral")
	item:SetAttribute("SpawnChance", data.SpawnChance or 0)
	CollectionService:AddTag(item, "StoreItem")
	-- Tag every descendant part with a reference to the root store item name,
	-- so ShopTargeting.ResolveStoreItem can always climb back from a deep hit.
	for _, desc in ipairs(item:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc:SetAttribute("StoreItemRoot", item.Name)
		end
	end

	local primaryPart = getPromptBasePart(item)
	if primaryPart then
		local prompt = primaryPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.ActionText = "Grab"
		prompt.ObjectText = data.Name or itemId
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = primaryPart
		addRareShowcaseEffects(item, data.Rarity)
	end

	item.Parent = itemsParent
	return item
end

local function populateStore(storeFolder: Instance): number
	clearStore(storeFolder)
	local itemsParent = getItemsFolder(storeFolder)
	local usedItems = {}
	local count = 0
	for _, slot in ipairs(gatherSlots(storeFolder)) do
		local candidates = getCandidatesForSlot(slot, usedItems)
		local chosen = chooseWeighted(candidates, slot:GetAttribute("RarityBias") or "Flexible")
		if chosen then
			usedItems[chosen.itemId] = true
			if spawnStoreItemAtSlot(slot, chosen.itemId, chosen.data, itemsParent) then
				count += 1
			end
		end
	end
	print(string.format("[StoreSetup] Populated %s with %d items", storeFolder.Name, count))
	return count
end

-- ===== Store-slot allocator (keyed by roundId; mirrors RoomService's room allocator) =====
local function allocateStoreSlot(): number
	local slot = 0
	while occupiedStoreSlots[slot] do slot += 1 end
	occupiedStoreSlots[slot] = true
	return slot
end

local function offsetForSlot(slot: number): Vector3
	return Vector3.new(slot * STORE_SPACING, 0, 0)
end

-- Translate every BasePart of a freshly-cloned store (pure offset along +X).
local function shiftStore(storeFolder: Instance, offset: Vector3)
	for _, d in ipairs(storeFolder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + offset
		end
	end
end

local function entryCFrameOf(storeFolder: Instance): CFrame?
	local pad = storeFolder:FindFirstChild("ShopEntryPad")
	if pad and pad:IsA("BasePart") then return pad.CFrame end
	return nil
end

-- Acquire (or reuse) the dedicated store for a round. Returns its ShopEntryPad CFrame.
local function acquireStore(roundId: string): CFrame?
	if not roundId then return nil end
	local existing = storeByRound[roundId]
	if existing and existing.folder and existing.folder.Parent then
		return existing.entryCF
	end

	local slot = allocateStoreSlot()
	if slot >= MAX_STORE_SLOTS then
		-- Out of dedicated slots: share slot 0 rather than fail the round.
		occupiedStoreSlots[slot] = nil
		warn("[StoreSetup] Out of store slots; round " .. roundId .. " shares slot 0")
		slot = 0
	end

	local folder: Instance?
	local offset = offsetForSlot(slot)
	if slot == 0 then
		ShowroomBootstrap.EnsureAll()
		folder = workspace:FindFirstChild("TheShowroom")
	else
		local template = ensureShellTemplate()
		if not template then
			occupiedStoreSlots[slot] = nil
			warn("[StoreSetup] No shell template; cannot acquire store for " .. roundId)
			return nil
		end
		local clone = template:Clone()
		clone.Name = "TheShowroom_" .. roundId
		shiftStore(clone, offset)
		clone.Parent = workspace
		folder = clone
	end

	if not folder then
		occupiedStoreSlots[slot] = nil
		return nil
	end

	populateStore(folder)
	local entryCF = entryCFrameOf(folder)
	storeByRound[roundId] = { folder = folder, slot = slot, offset = offset, entryCF = entryCF }
	print(string.format("[StoreSetup] Round %s acquired store slot %d", roundId, slot))
	return entryCF
end

local function releaseStore(roundId: string)
	local rec = storeByRound[roundId]
	if not rec then return end
	storeByRound[roundId] = nil
	occupiedStoreSlots[rec.slot] = nil
	if rec.slot == 0 then
		-- Canonical store persists; just clear its items so nothing stale lingers.
		if rec.folder and rec.folder.Parent then clearStore(rec.folder) end
	else
		if rec.folder then rec.folder:Destroy() end
	end
	print(string.format("[StoreSetup] Round %s released store slot %d", roundId, rec.slot))
end

-- ===== Cross-script API (BindableFunctions, matching the project's RPC style) =====
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local function bindFn(name: string): BindableFunction
	local fn = Events:FindFirstChild(name)
	if not (fn and fn:IsA("BindableFunction")) then
		if fn then fn:Destroy() end
		fn = Instance.new("BindableFunction")
		fn.Name = name
		fn.Parent = Events
	end
	return fn
end

bindFn("AcquireStore").OnInvoke = function(roundId) return acquireStore(roundId) end
bindFn("ReleaseStore").OnInvoke = function(roundId) releaseStore(roundId); return true end

-- Snapshot the pristine empty shell before anything populates the canonical store.
task.defer(ensureShellTemplate)

print("[StoreSetup] Loaded (per-lobby store isolation)")
