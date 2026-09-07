local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local ProgressionConfig = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))
local PersistentStoreCatalog = require(ReplicatedStorage:WaitForChild("PersistentStoreCatalog"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local ProfileService = require(game:GetService("ServerStorage"):WaitForChild("ProfileService"))

local ProgressionService = {}

local Events = ReplicatedStorage:FindFirstChild("Events")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "Events"
	Events.Parent = ReplicatedStorage
end

local function ensureRemote(className: string, name: string)
	local existing = Events:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Events
	return created
end

local GetProgressionSnapshot = ensureRemote("RemoteFunction", "GetProgressionSnapshot")
local ProgressionUpdated = ensureRemote("RemoteEvent", "ProgressionUpdated")
local ProgressionToast = ensureRemote("RemoteEvent", "ProgressionToast")
local RequestPersistentPurchase = ensureRemote("RemoteFunction", "RequestPersistentPurchase")

local dataStore = DataStoreService:GetDataStore(ProgressionConfig.DataStoreName)
local profiles = {}
local profileObjects = {}  -- [userId] = ProfileService Profile object (held for :Release())
local initialized = false
local processedRoundRewards = {}
local datastoreWarningShown = false
local useInMemoryOnly = false

local function tableCloneDeep(value)
	if type(value) ~= "table" then
		return value
	end
	local clone = {}
	for key, nested in pairs(value) do
		clone[key] = tableCloneDeep(nested)
	end
	return clone
end

-- Retry a DataStore call with backoff. Bails immediately on the Studio
-- "API access disabled" error (won't change on retry). Step toward P0 data hardening;
-- the full fix is a session-locked store (ProfileService) -- see the handoff beta plan.
local function retry(fn, attempts: number?)
	local n = attempts or 3
	local lastErr
	for i = 1, n do
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		if RunService:IsStudio() and string.find(tostring(res), "Studio access to APIs is not allowed", 1, true) then
			return false, res
		end
		if i < n then task.wait(0.4 * i) end
	end
	return false, lastErr
end

local function hashString(text: string): number
	local hash = 7
	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index)) % 2147483647
	end
	return hash
end

local function getRotationKey(): string
	local now = os.date("!*t")
	return string.format("%04d-%02d-%02d", now.year, now.month, now.day)
end

local function makeDefaultProfile()
	return {
		version = 1,
		currency = ProgressionConfig.StartingCurrency,
		totalXP = 0,
		totalScore = 0,
		roundsFinished = 0,
		wins = 0,
		bestScore = 0,
		ownedItems = {},
		claimedReceipts = {},
		housePlacements = {},  -- { [id] = { itemId, cx,cy,cz, rx,ry,rz } }
		houseSurfaces = {},    -- { [surfaceKey] = { r,g,b, mat } } for wall/floor paint
	}
end

-- ============================================================
-- SESSION-LOCKED PERSISTENCE (ProfileService)
-- Replaces the legacy raw GetAsync/UpdateAsync store. Uses a NEW DataStore name
-- so ProfileService starts in its own wrapped format; the old raw store data is
-- intentionally NOT migrated (clean pre-beta start). ProfileService auto-saves
-- Profile.Data (~every AutoSaveSeconds) and on :Release(), and force-loads stale
-- session locks so players are never locked out.
-- ============================================================
local PROFILE_STORE_NAME = ProgressionConfig.DataStoreName .. "_PS"
local ProfileStore
do
	local ok, store = pcall(function()
		return ProfileService.GetProfileStore(PROFILE_STORE_NAME, makeDefaultProfile())
	end)
	if ok then
		ProfileStore = store
	else
		warn("[ProgressionService] ProfileService init failed; using in-session profiles only: " .. tostring(store))
	end
end

local function sanitizeProfile(raw)
	local profile = makeDefaultProfile()
	if type(raw) ~= "table" then
		return profile
	end
	profile.version = tonumber(raw.version) or profile.version
	profile.currency = math.max(0, math.floor(tonumber(raw.currency) or profile.currency))
	profile.totalXP = math.max(0, math.floor(tonumber(raw.totalXP) or profile.totalXP))
	profile.totalScore = math.max(0, math.floor(tonumber(raw.totalScore) or profile.totalScore))
	profile.roundsFinished = math.max(0, math.floor(tonumber(raw.roundsFinished) or profile.roundsFinished))
	profile.wins = math.max(0, math.floor(tonumber(raw.wins) or profile.wins))
	profile.bestScore = math.max(0, math.floor(tonumber(raw.bestScore) or profile.bestScore))
	if type(raw.ownedItems) == "table" then
		for itemId, info in pairs(raw.ownedItems) do
			if type(itemId) == "string" and itemId ~= "" then
				profile.ownedItems[itemId] = type(info) == "table" and tableCloneDeep(info) or { acquiredAt = os.time() }
			end
		end
	end
	if type(raw.claimedReceipts) == "table" then
		for receiptKey, value in pairs(raw.claimedReceipts) do
			if value then
				profile.claimedReceipts[tostring(receiptKey)] = true
			end
		end
	end
	if type(raw.housePlacements) == "table" then
		for id, entry in pairs(raw.housePlacements) do
			if type(id) == "string" and type(entry) == "table" and type(entry.itemId) == "string" then
				profile.housePlacements[id] = {
					itemId = entry.itemId,
					cx = tonumber(entry.cx) or 0,
					cy = tonumber(entry.cy) or 0,
					cz = tonumber(entry.cz) or 0,
					rx = tonumber(entry.rx) or 0,
					ry = tonumber(entry.ry) or 0,
					rz = tonumber(entry.rz) or 0,
				}
			end
		end
	end
	if type(raw.houseSurfaces) == "table" then
		for key, entry in pairs(raw.houseSurfaces) do
			if type(key) == "string" and type(entry) == "table" then
				profile.houseSurfaces[key] = {
					r = math.clamp(math.floor(tonumber(entry.r) or 255), 0, 255),
					g = math.clamp(math.floor(tonumber(entry.g) or 255), 0, 255),
					b = math.clamp(math.floor(tonumber(entry.b) or 255), 0, 255),
					mat = type(entry.mat) == "string" and entry.mat or nil,
				}
			end
		end
	end
	return profile
end

local function getStoreEntryByProductId(productId: number)
	for _, entry in ipairs(PersistentStoreCatalog.GetEntries()) do
		if tonumber(entry.RobuxProductId) == productId and productId > 0 then
			return entry
		end
	end
	return nil
end

local function getProfile(playerOrUserId)
	local userId = typeof(playerOrUserId) == "Instance" and playerOrUserId.UserId or playerOrUserId
	return profiles[userId]
end

local function getOwnedItemIds(profile)
	local owned = {}
	for itemId in pairs(profile.ownedItems) do
		table.insert(owned, itemId)
	end
	table.sort(owned, function(a, b)
		local aData = ItemDatabase.Get(a)
		local bData = ItemDatabase.Get(b)
		local aName = aData and aData.Name or a
		local bName = bData and bData.Name or b
		return aName < bName
	end)
	return owned
end

local function buildRotationEntries()
	local key = getRotationKey()
	local regular = {}
	local exclusive = {}
	for _, entry in ipairs(PersistentStoreCatalog.GetEntries()) do
		if entry.Exclusive then
			table.insert(exclusive, entry)
		else
			table.insert(regular, entry)
		end
	end

	local function selectEntries(pool, wanted, salt)
		local selected = {}
		local shuffled = tableCloneDeep(pool)
		local random = Random.new(hashString(key .. ":" .. salt))
		for index = #shuffled, 2, -1 do
			local swapIndex = random:NextInteger(1, index)
			shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
		end
		for _, entry in ipairs(shuffled) do
			if #selected >= wanted then
				break
			end
			table.insert(selected, entry)
		end
		return selected
	end

	local results = {}
	for _, entry in ipairs(selectEntries(regular, ProgressionConfig.StoreRotationSize, "regular")) do
		table.insert(results, entry)
	end
	for _, entry in ipairs(selectEntries(exclusive, ProgressionConfig.ExclusiveRotationSize, "exclusive")) do
		table.insert(results, entry)
	end
	return key, results
end

local function buildStoreEntryPayload(profile, entry)
	local itemData = ItemDatabase.Get(entry.ItemId)
	local owned = profile.ownedItems[entry.ItemId] ~= nil
	return {
		entryId = entry.Id,
		itemId = entry.ItemId,
		name = itemData and itemData.Name or entry.ItemId,
		description = entry.Tagline or (itemData and itemData.Description) or "",
		rarity = itemData and itemData.Rarity or "Common",
		theme = itemData and itemData.Theme or "Neutral",
		purchaseType = entry.PurchaseType,
		currencyPrice = entry.CurrencyPrice,
		robuxPrice = entry.RobuxPrice,
		levelRequired = entry.LevelRequired or 1,
		exclusive = entry.Exclusive == true,
		owned = owned,
		robuxProductId = tonumber(entry.RobuxProductId) or 0,
		robuxConfigured = (tonumber(entry.RobuxProductId) or 0) > 0,
	}
end

local function buildCollectionEntries(profile)
	local entries = {}
	for _, itemId in ipairs(getOwnedItemIds(profile)) do
		local itemData = ItemDatabase.Get(itemId)
		table.insert(entries, {
			itemId = itemId,
			name = itemData and itemData.Name or itemId,
			rarity = itemData and itemData.Rarity or "Common",
			theme = itemData and itemData.Theme or "Neutral",
			placementSurface = ItemDatabase.GetPlacementSurface and ItemDatabase.GetPlacementSurface(itemId) or (itemData and itemData.PlacementSurface) or "Floor",
		})
	end
	return entries
end

local function updateLeaderstats(player, snapshot)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local function setValue(name, className, value)
		local stat = leaderstats:FindFirstChild(name)
		if not stat or stat.ClassName ~= className then
			if stat then
				stat:Destroy()
			end
			stat = Instance.new(className)
			stat.Name = name
			stat.Parent = leaderstats
		end
		stat.Value = value
	end

	setValue("Style Bucks", "IntValue", snapshot.currency)
	setValue("Level", "IntValue", snapshot.level)
	setValue("Career Score", "IntValue", snapshot.totalScore)
end

local function buildSnapshot(player)
	local profile = getProfile(player)
	if not profile then
		return nil
	end
	local progress = ProgressionConfig.GetLevelProgress(profile.totalXP)
	local rotationKey, rotationEntries = buildRotationEntries()
	local rotationPayload = {}
	for _, entry in ipairs(rotationEntries) do
		table.insert(rotationPayload, buildStoreEntryPayload(profile, entry))
	end

	local snapshot = {
		currency = profile.currency,
		totalXP = profile.totalXP,
		level = progress.level,
		xpIntoLevel = progress.xpIntoLevel,
		xpForNextLevel = progress.xpForNextLevel,
		totalScore = profile.totalScore,
		roundsFinished = profile.roundsFinished,
		wins = profile.wins,
		bestScore = profile.bestScore,
		rotationKey = rotationKey,
		rotationEntries = rotationPayload,
		ownedItemIds = getOwnedItemIds(profile),
		collectionEntries = buildCollectionEntries(profile),
	}
	return snapshot
end

local function pushSnapshot(player)
	local snapshot = buildSnapshot(player)
	if not snapshot then
		return nil
	end
	updateLeaderstats(player, snapshot)
	player:SetAttribute("StyleCurrency", snapshot.currency)
	player:SetAttribute("StyleLevel", snapshot.level)
	player:SetAttribute("StyleXP", snapshot.totalXP)
	player:SetAttribute("StyleXPIntoLevel", snapshot.xpIntoLevel)
	player:SetAttribute("StyleXPForNextLevel", snapshot.xpForNextLevel)
	player:SetAttribute("StyleOwnedItems", #snapshot.ownedItemIds)
	ProgressionUpdated:FireClient(player, snapshot)
	return snapshot
end

-- ProfileService now owns persistence: it auto-saves Profile.Data periodically and
-- on :Release(). Kept as a no-op for any legacy caller.
local function saveProfileByUserId(_userId: number)
	return true
end

local function queueToast(player, payload)
	if player and player.Parent then
		ProgressionToast:FireClient(player, payload)
	end
end

local function awardCurrency(player, amount: number, reason: string, extras)
	local profile = getProfile(player)
	if not profile then
		return nil
	end
	local gained = math.max(0, math.floor(amount or 0))
	if gained <= 0 then
		return pushSnapshot(player)
	end
	profile.currency += gained
	local snapshot = pushSnapshot(player)
	queueToast(player, {
		kind = "currency",
		reason = reason,
		currency = gained,
		details = extras,
	})
	return snapshot
end

local function awardXP(player, amount: number)
	local profile = getProfile(player)
	if not profile then
		return nil
	end
	profile.totalXP += math.max(0, math.floor(amount or 0))
	return pushSnapshot(player)
end

local function grantOwnedItem(player, entry, acquisitionSource: string)
	local profile = getProfile(player)
	if not profile then
		return false, "Progression data is still loading."
	end
	if profile.ownedItems[entry.ItemId] then
		return false, "Already owned."
	end

	profile.ownedItems[entry.ItemId] = {
		acquiredAt = os.time(),
		source = acquisitionSource,
		entryId = entry.Id,
	}
	pushSnapshot(player)
	queueToast(player, {
		kind = "purchase",
		itemId = entry.ItemId,
		message = "Added to your collection",
	})
	return true, "Added to your collection."
end

function ProgressionService.GetRotationEntries(player)
	local _, entries = buildRotationEntries()
	if player then
		local profile = getProfile(player)
		if profile then
			for _, entry in ipairs(entries) do
				entry._owned = profile.ownedItems[entry.ItemId] ~= nil
			end
		end
	end
	return entries
end

function ProgressionService.GetOwnedItemIds(player)
	local profile = getProfile(player)
	if not profile then
		return {}
	end
	return getOwnedItemIds(profile)
end

function ProgressionService.GetSnapshot(player)
	return buildSnapshot(player)
end

function ProgressionService.AwardCurrencyPickup(player, amount: number, reason: string?)
	return awardCurrency(player, amount, reason or "pickup")
end

function ProgressionService.AwardRoundResults(roundNumber: number, scoreByUserId, leaderboard)
	if processedRoundRewards[roundNumber] then
		return
	end
	processedRoundRewards[roundNumber] = true
	local participantCount = type(leaderboard) == "table" and #leaderboard or 0
	for _, entry in ipairs(leaderboard or {}) do
		local player = Players:GetPlayerByUserId(entry.userId)
		local profile = player and getProfile(player)
		if player and profile then
			local scoreEntry = scoreByUserId and scoreByUserId[entry.userId] or entry
			local rewards = ProgressionConfig.BuildRoundRewards(scoreEntry, entry.rank or 999, participantCount)
			profile.currency += rewards.currency
			profile.totalXP += rewards.xp
			profile.totalScore += rewards.totalScore
			profile.roundsFinished += 1
			profile.bestScore = math.max(profile.bestScore, rewards.totalScore)
			if entry.rank == 1 then
				profile.wins += 1
			end
			pushSnapshot(player)
			queueToast(player, {
				kind = "roundRewards",
				currency = rewards.currency,
				xp = rewards.xp,
				rank = entry.rank,
				totalScore = rewards.totalScore,
			})
		end
	end
end

local function loadProfile(player)
	if not ProfileStore then
		-- ProfileService unavailable -> fresh in-session profile so the hub still works.
		profiles[player.UserId] = sanitizeProfile(nil)
		pushSnapshot(player)
		return
	end
	-- LoadProfileAsync throws on a DataStore outage, not just returns nil. Unhandled,
	-- the PlayerAdded thread dies and the player stays in the server with no profile:
	-- no leaderstats, no currency, every purchase refused, round rewards dropped.
	-- Retry a few times, then kick rather than leave them in that state.
	local profile
	for attempt = 1, 4 do
		local ok, result = pcall(function()
			return ProfileStore:LoadProfileAsync("p_" .. tostring(player.UserId))
		end)
		if ok then
			profile = result
			break
		end
		warn(string.format("[ProgressionService] LoadProfileAsync attempt %d failed for %s: %s",
			attempt, player.Name, tostring(result)))
		if not player:IsDescendantOf(Players) then return end
		task.wait(attempt)
	end
	if profile == nil then
		-- Session lock still held, or every load attempt errored.
		player:Kick("We couldn't load your saved data. Please rejoin in a moment.")
		return
	end
	profile:AddUserId(player.UserId)
	-- sanitizeProfile validates/clamps AND fills defaults (replaces :Reconcile).
	profile.Data = sanitizeProfile(profile.Data)
	profile:ListenToRelease(function()
		profileObjects[player.UserId] = nil
		profiles[player.UserId] = nil
		player:Kick("Your data was opened on another server.")
	end)
	if player:IsDescendantOf(Players) then
		profileObjects[player.UserId] = profile
		profiles[player.UserId] = profile.Data
		pushSnapshot(player)
	else
		-- Player left during load.
		profile:Release()
	end
end

local function handlePurchase(player, entryId: string, requestedMethod: string?)
	local profile = getProfile(player)
	if not profile then
		return { success = false, message = "Progression data is still loading." }
	end
	local entry = PersistentStoreCatalog.GetById(entryId)
	if not entry then
		return { success = false, message = "That boutique item is no longer available." }
	end
	local level = ProgressionConfig.GetLevelFromXP(profile.totalXP)
	if level < (entry.LevelRequired or 1) then
		return { success = false, message = string.format("Unlocks at level %d.", entry.LevelRequired or 1) }
	end
	if profile.ownedItems[entry.ItemId] then
		return { success = false, message = "You already own this item.", snapshot = pushSnapshot(player) }
	end

	local paymentMethod = requestedMethod or entry.PurchaseType
	if paymentMethod == "Coins" then
		local price = math.max(0, math.floor(tonumber(entry.CurrencyPrice) or 0))
		if price <= 0 then
			return { success = false, message = "This item is not available for coins right now." }
		end
		if profile.currency < price then
			return { success = false, message = string.format("You need %d more Style Bucks.", price - profile.currency) }
		end
		profile.currency -= price
		local granted, message = grantOwnedItem(player, entry, "Coins")
		if not granted then
			profile.currency += price
			return { success = false, message = message }
		end
		queueToast(player, {
			kind = "purchaseSpent",
			currency = price,
			message = "Boutique purchase",
		})
		return { success = true, message = message, snapshot = pushSnapshot(player) }
	end

	if paymentMethod == "Robux" then
		local productId = math.floor(tonumber(entry.RobuxProductId) or 0)
		if productId > 0 then
			MarketplaceService:PromptProductPurchase(player, productId)
			return { success = true, pending = true, message = "Complete the Robux purchase to unlock it." }
		end
		if ProgressionConfig.AllowStudioRobuxPreview then
			local granted, message = grantOwnedItem(player, entry, "StudioRobuxPreview")
			return { success = granted, message = granted and (message .. " (Studio preview)") or message, snapshot = pushSnapshot(player) }
		end
		return { success = false, message = "This exclusive item needs a live Robux product ID before it can be sold." }
	end

	return { success = false, message = "Unsupported purchase type." }
end

-- Public wrapper. NOTE: must stay defined AFTER the local handlePurchase above —
-- when it sat earlier in the file the closure captured a nil global and broke pedestal purchases.
function ProgressionService.HandlePurchase(player: Player, entryId: string, paymentMethod: string?)
	if typeof(entryId) ~= "string" then
		return { success = false, message = "Invalid item." }
	end
	return handlePurchase(player, entryId, paymentMethod)
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = getProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptKey = tostring(receiptInfo.PurchaseId)
	if profile.claimedReceipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local entry = getStoreEntryByProductId(receiptInfo.ProductId)
	if not entry then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local granted = select(1, grantOwnedItem(player, entry, "Robux"))
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.claimedReceipts[receiptKey] = true
	pushSnapshot(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Housing placement persistence
-- CFrame is serialized as 6 numbers: position XYZ + rotation XYZ (degrees)
local MAX_HOUSE_PLACEMENTS = 30

function ProgressionService.GetHousePlacements(player: Player)
	local profile = getProfile(player)
	if not profile then return {} end
	return tableCloneDeep(profile.housePlacements)
end

function ProgressionService.SaveHousePlacement(player: Player, id: string, itemId: string, cf: CFrame)
	local profile = getProfile(player)
	if not profile then return false, "Profile not loaded" end
	if not profile.ownedItems[itemId] then return false, "Item not owned" end
	if type(id) ~= "string" or id == "" then return false, "Invalid id" end
	if #itemId > 80 then return false, "ItemId too long" end
	-- Count existing placements excluding this id (allow update)
	local count = 0
	for existingId in pairs(profile.housePlacements) do
		if existingId ~= id then count += 1 end
	end
	if count >= MAX_HOUSE_PLACEMENTS then return false, "House is full" end
	-- One active placement per owned item: a persistent-inventory item is a single
	-- instance, not an unlimited stamp. Placing another copy of an itemId already in the
	-- home is rejected. (Moving removes the placement first, so moves still work.)
	local sameItem = 0
	for existingId, entry in pairs(profile.housePlacements) do
		if existingId ~= id and entry.itemId == itemId then sameItem += 1 end
	end
	if sameItem >= 1 then return false, "Already placed in your home" end
	local rx, ry, rz = cf:ToEulerAnglesXYZ()
	profile.housePlacements[id] = {
		itemId = itemId,
		cx = cf.Position.X, cy = cf.Position.Y, cz = cf.Position.Z,
		rx = math.deg(rx), ry = math.deg(ry), rz = math.deg(rz),
	}
	pushSnapshot(player)
	return true, "Saved"
end

function ProgressionService.RemoveHousePlacement(player: Player, id: string)
	local profile = getProfile(player)
	if not profile then return false end
	if profile.housePlacements[id] then
		profile.housePlacements[id] = nil
		pushSnapshot(player)
	end
	return true
end

-- House wall/floor paint persistence. Keys: "floor","wall_back","wall_left","wall_right".
-- "wall" (all) is expanded to the three individual walls so re-apply is order-free.
local HOUSE_SURFACE_KEYS = { floor = true, wall_back = true, wall_left = true, wall_right = true }

function ProgressionService.GetHouseSurfaces(player: Player)
	local profile = getProfile(player)
	if not profile then return {} end
	return tableCloneDeep(profile.houseSurfaces)
end

function ProgressionService.SaveHouseSurface(player: Player, surface: string, color: Color3, material: EnumItem?)
	local profile = getProfile(player)
	if not profile then return false end
	if typeof(color) ~= "Color3" then return false end
	local matName = typeof(material) == "EnumItem" and material.Name or nil
	local function store(key: string)
		profile.houseSurfaces[key] = {
			r = math.floor(color.R * 255 + 0.5),
			g = math.floor(color.G * 255 + 0.5),
			b = math.floor(color.B * 255 + 0.5),
			mat = matName,
		}
	end
	if surface == "wall" then
		store("wall_back"); store("wall_left"); store("wall_right")
	elseif HOUSE_SURFACE_KEYS[surface] then
		store(surface)
	else
		return false
	end
	return true
end

function ProgressionService.Init()
	if initialized then
		return
	end
	initialized = true

	GetProgressionSnapshot.OnServerInvoke = function(player)
		return pushSnapshot(player)
	end

	RequestPersistentPurchase.OnServerInvoke = function(player, entryId: string, paymentMethod: string?)
		if typeof(entryId) ~= "string" then
			return { success = false, message = "Invalid boutique item." }
		end
		return handlePurchase(player, entryId, paymentMethod)
	end

	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profileObjects[player.UserId]
		if profile then
			profile:Release()  -- final save + unlock; caches cleared by ListenToRelease
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfile, player)
	end

	-- ProfileService auto-saves Profile.Data and releases all profiles on game close,
	-- so no manual auto-save loop is needed. Release-all here is belt-and-suspenders.
	game:BindToClose(function()
		for _, profile in pairs(profileObjects) do
			profile:Release()
		end
	end)
end

return ProgressionService
