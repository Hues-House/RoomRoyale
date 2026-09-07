-- ReplicatedStorage -> ItemDatabase
-- Shared item metadata and helper APIs.
-- Single source of truth: ItemCatalogData.
-- No runtime name-inference; all items are explicit catalog rows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemCatalogData"))

local RARITY_STYLE_VALUES = {
	Common = 0,
	Uncommon = 1,
	Rare = 2,
	Legendary = 4,
}

local function normalizeThemeId(themeId)
	if type(themeId) ~= "string" then
		return nil
	end
	return string.lower(themeId):gsub("%s+", "_")
end

local function csvToTags(csv, fallbackTheme)
	if type(csv) == "string" and csv ~= "" then
		local tags = {}
		for token in string.gmatch(csv, "[^,]+") do
			table.insert(tags, normalizeThemeId(token) or token)
		end
		if #tags > 0 then
			return tags
		end
	end
	return { normalizeThemeId(fallbackTheme) or "neutral" }
end

local function collectMatches(predicate)
	local results = {}
	for itemId, data in pairs(ItemDatabase) do
		if type(data) == "table" and data.Name and predicate(itemId, data) then
			results[itemId] = data
		end
	end
	return results
end


function ItemDatabase.Get(itemId)
	return ItemDatabase[itemId]
end

function ItemDatabase.GetByType(itemType)
	return collectMatches(function(_, data)
		return data.Type == itemType
	end)
end

function ItemDatabase.GetByCategory(category)
	return collectMatches(function(_, data)
		return data.Category == category
	end)
end

function ItemDatabase.GetByRarity(rarity)
	return collectMatches(function(_, data)
		return data.Rarity == rarity
	end)
end

function ItemDatabase.GetByDepartment(department)
	return collectMatches(function(_, data)
		return data.Department == department and data.ShowroomEligible ~= false
	end)
end

function ItemDatabase.GetShowroomItems()
	return collectMatches(function(_, data)
		return data.ShowroomEligible ~= false and data.Department ~= nil
	end)
end

function ItemDatabase.GetPlacementSurface(itemId)
	local data = ItemDatabase[itemId]
	return data and data.PlacementSurface or "Floor"
end

function ItemDatabase.GetSpawnChance(itemId)
	local data = ItemDatabase[itemId]
	return data and data.SpawnChance or 0
end

function ItemDatabase.GetThemeTags(itemId)
	local data = ItemDatabase[itemId]
	if not data then
		return {}
	end
	if data.ThemeTags then
		return data.ThemeTags
	end
	return csvToTags(data.ThemeTagsCsv, data.Theme)
end

function ItemDatabase.MatchesTheme(itemId, themeId)
	themeId = normalizeThemeId(themeId)
	if not themeId then
		return false
	end
	for _, tag in ipairs(ItemDatabase.GetThemeTags(itemId)) do
		if normalizeThemeId(tag) == themeId then
			return true
		end
	end
	return false
end

function ItemDatabase.GetRarityStyleValue(itemIdOrRarity)
	local rarity = itemIdOrRarity
	if type(itemIdOrRarity) == "string" and ItemDatabase[itemIdOrRarity] then
		rarity = ItemDatabase[itemIdOrRarity].Rarity
	end
	return RARITY_STYLE_VALUES[rarity] or 0
end

function ItemDatabase.IsWallMounted(itemId)
	return ItemDatabase.GetPlacementSurface(itemId) == "Wall"
end

function ItemDatabase.IsCeilingMounted(itemId)
	return ItemDatabase.GetPlacementSurface(itemId) == "Ceiling"
end

return ItemDatabase
