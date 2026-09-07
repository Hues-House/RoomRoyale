-- ReplicatedStorage > ThemeDatabase
-- Shared round themes for style prompts and Judge scoring.

local ThemeDatabase = {}

ThemeDatabase.MechanicalThemes = {
	farmhouse = {
		id = "farmhouse",
		label = "Farmhouse",
		hint = "Warm wood, simple pieces, homey charm.",
		prompt = "Make it feel like a homey country makeover.",
		required = {"SlatDiningTable"},
		bonus = {"BentwoodDiningChair", "WoodenChair", "OakWritingDesk", "OakNightstand", "OpenBookshelf", "LinenFloorLamp", "WovenAreaRug", "BathroomVanity"},
	},
	coastal = {
		id = "coastal",
		label = "Coastal",
		hint = "Airy, beachy, light, and relaxed.",
		prompt = "Build a breezy beach-house vibe.",
		required = {"WovenAreaRug"},
		bonus = {"TrackLoveseat", "PebbleLoungeChair", "SlimSideTable", "TallPottedPlant", "ArchedMirror", "StripedRunnerRug", "LinenFloorLamp"},
	},
	boho = {
		id = "boho",
		label = "Boho",
		hint = "Relaxed, artsy, layered, and a little planty.",
		prompt = "Create a chill artsy space with layered personality.",
		required = {"TallPottedPlant"},
		bonus = {"PebbleLoungeChair", "FloatingWallShelf", "FramedAbstractArt", "WovenAreaRug", "MushroomTableLamp", "OakWritingDesk", "SlimSideTable"},
	},
	retro = {
		id = "retro",
		label = "Retro",
		hint = "Old-school cool with fun shapes and throwback energy.",
		prompt = "Make it feel like a fun throwback hangout.",
		required = {"MushroomTableLamp"},
		bonus = {"BentwoodDiningChair", "RoundCoffeeTable", "FramedAbstractArt", "ArcFloorLamp", "PebbleLoungeChair", "LiftTopCoffeeTable"},
	},
	preppy = {
		id = "preppy",
		label = "Preppy",
		hint = "Clean, polished, bright, and a little fancy.",
		prompt = "Build a polished room that feels neat and expensive.",
		required = {"TrackLoveseat"},
		bonus = {"CloudSofa", "SlimSideTable", "ArchedMirror", "LinenFloorLamp", "SlatDiningTable", "FramedAbstractArt"},
	},
	cozy_cabin = {
		id = "cozy_cabin",
		label = "Cozy Cabin",
		hint = "Woodsy, snug, warm-lit, and tucked in.",
		prompt = "Turn the room into a warm weekend hideaway.",
		required = {"LinenFloorLamp"},
		bonus = {"WoodenChair", "OpenBookshelf", "OakNightstand", "WovenAreaRug", "TallPottedPlant", "PlatformBed", "MushroomTableLamp"},
	},
	gothic = {
		id = "gothic",
		label = "Gothic",
		hint = "Dark, moody, elegant, and a little dramatic.",
		prompt = "Make it dark, elegant, and dramatic.",
		required = {"ArchedMirror"},
		bonus = {"FramedAbstractArt", "ArcFloorLamp", "OpenBookshelf", "MushroomTableLamp", "TallPottedPlant", "TrackLoveseat"},
	},
	old_west = {
		id = "old_west",
		label = "Old West",
		hint = "Rugged wood, frontier charm, and saloon energy.",
		prompt = "Build a space that feels frontier, rustic, and bold.",
		required = {"WoodenChair"},
		bonus = {"SlatDiningTable", "OpenBookshelf", "OakWritingDesk", "LinenFloorLamp", "BathroomVanity", "BentwoodDiningChair"},
	},
}

ThemeDatabase.MechanicalOrder = {
	"farmhouse",
	"coastal",
	"boho",
	"retro",
	"preppy",
	"cozy_cabin",
	"gothic",
	"old_west",
}

ThemeDatabase.AestheticThemes = {
	overall_style = {
		id = "overall_style",
		label = "Overall Style",
		hint = "Judge the room on the whole vibe, not a second prompt.",
	},
}

ThemeDatabase.AestheticOrder = {
	"overall_style",
}

local function cloneList(list)
	local copy = {}
	for index, value in ipairs(list or {}) do
		copy[index] = value
	end
	return copy
end

local function cloneTheme(theme)
	if not theme then
		return nil
	end

	local copy = {}
	for key, value in pairs(theme) do
		if type(value) == "table" then
			copy[key] = cloneList(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function getRandomSource(seedOrRandom)
	if typeof(seedOrRandom) == "Random" then
		return seedOrRandom
	end
	if type(seedOrRandom) == "number" then
		return Random.new(seedOrRandom)
	end
	return Random.new()
end

local function chooseTheme(order, pool, seedOrRandom)
	local randomSource = getRandomSource(seedOrRandom)
	local index = randomSource:NextInteger(1, #order)
	local themeId = order[index]
	return cloneTheme(pool[themeId])
end

function ThemeDatabase.GetMechanicalTheme(themeId)
	return cloneTheme(ThemeDatabase.MechanicalThemes[themeId])
end

function ThemeDatabase.GetAestheticTheme(themeId)
	return cloneTheme(ThemeDatabase.AestheticThemes[themeId])
end

function ThemeDatabase.RollThemePair(seedOrRandom)
	local randomSource = getRandomSource(seedOrRandom)
	return {
		mechanical = chooseTheme(ThemeDatabase.MechanicalOrder, ThemeDatabase.MechanicalThemes, randomSource),
		aesthetic = chooseTheme(ThemeDatabase.AestheticOrder, ThemeDatabase.AestheticThemes, randomSource),
	}
end

return ThemeDatabase
