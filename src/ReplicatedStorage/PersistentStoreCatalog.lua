local entries = {
	{
		Id = "boutique_rounded_loveseat",
		ItemId = "RoundedNeutralLoveseat",
		CurrencyPrice = 760,
		PurchaseType = "Coins",
		LevelRequired = 2,
		RotationWeight = 9,
		Exclusive = false,
		Tagline = "Soft curves and premium showroom energy.",
	},
	{
		Id = "boutique_panel_bed",
		ItemId = "PanelBedSet",
		CurrencyPrice = 840,
		PurchaseType = "Coins",
		LevelRequired = 3,
		RotationWeight = 7,
		Exclusive = false,
		Tagline = "A full bedroom anchor with polished charm.",
	},
	{
		Id = "boutique_vanity_table",
		ItemId = "VanityTable",
		CurrencyPrice = 420,
		PurchaseType = "Coins",
		LevelRequired = 2,
		RotationWeight = 9,
		Exclusive = false,
		Tagline = "Pretty, compact, and easy to style fast.",
	},
	{
		Id = "boutique_cube_shelf",
		ItemId = "CubeShelf",
		CurrencyPrice = 360,
		PurchaseType = "Coins",
		LevelRequired = 1,
		RotationWeight = 10,
		Exclusive = false,
		Tagline = "Chunky cubbies for kid-friendly rooms.",
	},
	{
		Id = "boutique_toy_chest",
		ItemId = "ToyChestBench",
		CurrencyPrice = 410,
		PurchaseType = "Coins",
		LevelRequired = 2,
		RotationWeight = 8,
		Exclusive = false,
		Tagline = "Storage that still feels playful and cozy.",
	},
	{
		Id = "boutique_rainbow_gallery",
		ItemId = "RainbowGallerySet",
		CurrencyPrice = 340,
		PurchaseType = "Coins",
		LevelRequired = 1,
		RotationWeight = 10,
		Exclusive = false,
		Tagline = "Colorful wall art that reads at a glance.",
	},
	{
		Id = "boutique_leafy_planter",
		ItemId = "LeafyHangingPlanter",
		CurrencyPrice = 390,
		PurchaseType = "Coins",
		LevelRequired = 2,
		RotationWeight = 7,
		Exclusive = false,
		Tagline = "A ceiling vine moment for breezy rooms.",
	},
	{
		Id = "boutique_loft_lamp",
		ItemId = "LoftFloorLamp",
		CurrencyPrice = 300,
		PurchaseType = "Coins",
		LevelRequired = 1,
		RotationWeight = 10,
		Exclusive = false,
		Tagline = "A reliable lamp for elevated judge shots.",
	},
	{
		Id = "exclusive_bubble_chandelier",
		ItemId = "BubbleChandelier",
		PurchaseType = "Robux",
		RobuxProductId = 0,
		RobuxPrice = 149,
		LevelRequired = 5,
		RotationWeight = 5,
		Exclusive = true,
		Tagline = "A sparkling ceiling flex for standout rooms.",
	},
	{
		Id = "exclusive_tube_tv",
		ItemId = "TubeTV",
		PurchaseType = "Robux",
		RobuxProductId = 0,
		RobuxPrice = 99,
		LevelRequired = 4,
		RotationWeight = 6,
		Exclusive = true,
		Tagline = "Chunky throwback tech with instant retro personality.",
	},
	{
		Id = "exclusive_oak_study",
		ItemId = "OakWritingDesk",
		PurchaseType = "Robux",
		RobuxProductId = 0,
		RobuxPrice = 119,
		LevelRequired = 4,
		RotationWeight = 5,
		Exclusive = true,
		Tagline = "A writer's nook piece for styled corners.",
	},
	{
		Id = "exclusive_area_rug",
		ItemId = "AreaRug",
		PurchaseType = "Robux",
		RobuxProductId = 0,
		RobuxPrice = 79,
		LevelRequired = 3,
		RotationWeight = 7,
		Exclusive = true,
		Tagline = "A boutique-only rug to settle the whole layout.",
	},
}

local byId = {}
for _, entry in ipairs(entries) do
	byId[entry.Id] = entry
end

local Catalog = {}

function Catalog.GetEntries()
	return entries
end

function Catalog.GetById(entryId: string)
	return byId[entryId]
end

return Catalog
