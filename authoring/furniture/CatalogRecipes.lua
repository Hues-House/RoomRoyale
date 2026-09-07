--!strict

local finishes = require(script.Parent.Finishes)
local recipes = {}

local function add(id, name, family, category, surface, size, attributes)
	table.insert(recipes, { id = id, name = name, family = family, category = category, surface = surface, size = size, attributes = attributes })
end

for _, r in ipairs(require(script.Parent.TableRecipes)) do
	add(r.id, r.name, "Table", "Tables", "Floor", r.size, { TopShape = r.shape, BaseStyle = r.base, TopColor = r.top, BaseColor = r.legs })
end
for _, r in ipairs(require(script.Parent.SofaRecipes)) do
	add(r.id, r.name, "Sofa", "Seating", "Floor", r.size, { SeatCount = r.seats, ArmStyle = r.arm, UpholsteryColor = r.color })
end

local function color(name) return finishes[name].color end
local function storage(id, name, size, layout, divisions, accent)
	add("rr_" .. id .. "_v1", name, "Storage", "Storage", "Floor", size, { Layout = layout, Divisions = divisions, BodyColor = color("Oak"), AccentColor = color(accent) })
end
storage("low_shelf_oak", "Open low shelf", Vector3.new(5.2, 3, 1.5), "Open", 2, "Cream")
storage("bookcase_sage", "Sage back bookcase", Vector3.new(3.4, 6.5, 1.5), "Open", 4, "Sage")
storage("sideboard_clay", "Clay door sideboard", Vector3.new(6.2, 3.1, 1.8), "Doors", 3, "Clay")
storage("nightstand_cream", "Cream bedside cabinet", Vector3.new(2, 2.2, 1.5), "Drawers", 2, "Cream")
storage("dresser_lake", "Lake blue dresser", Vector3.new(4.6, 3.8, 1.8), "Drawers", 3, "Lake")
storage("wardrobe_sage", "Sage wardrobe", Vector3.new(4.2, 7, 2.2), "Doors", 2, "Sage")

local function rug(id, name, width, depth, pattern, accent, repeats)
	add("rr_" .. id .. "_v1", name, "Rug", "Rugs", "Rug", Vector3.new(width, .12, depth), { Pattern = pattern, Repeats = repeats or 6, GroundColor = color("Cream"), PatternColor = color(accent) })
end
rug("border_rug_sage", "Sage border rug", 8, 6, "Border", "Sage")
rug("stripe_runner_clay", "Clay stripe runner", 3, 8, "Stripe", "Clay", 8)
rug("check_rug_lake", "Lake checker rug", 6, 6, "Check", "Lake", 6)
rug("round_rug_ochre", "Ochre round rug", 5, 5, "Round", "Ochre")
rug("stripe_rug_rose", "Rose stripe rug", 8, 6, "Stripe", "Rose", 5)
rug("border_mat_charcoal", "Charcoal border mat", 3, 2, "Border", "Charcoal")

local function lamp(id, name, width, height, shade, finish)
	add("rr_" .. id .. "_v1", name, "Lamp", "Lighting", if height > 3 then "Floor" else "Surface", Vector3.new(width, height, width), { ShadeStyle = shade, ShadeColor = color(finish), StemColor = color("Brass"), Lit = true })
end
lamp("drum_floor_lamp", "Linen drum floor lamp", 2.2, 5.8, "Drum", "Cream")
lamp("drum_table_lamp", "Linen bedside lamp", 1.3, 2.3, "Drum", "Cream")
lamp("mushroom_lamp_clay", "Clay mushroom lamp", 1.8, 2, "Mushroom", "Clay")
lamp("mushroom_floor_sage", "Sage mushroom floor lamp", 2.6, 5.4, "Mushroom", "Sage")

local function decor(id, name, size, object, body, accent, count)
	add("rr_" .. id .. "_v1", name, "Decor", "Objects", "Surface", size, { Object = object, Count = count or 3, BodyColor = color(body), AccentColor = color(accent) })
end
decor("bud_vase_clay", "Clay bud vase", Vector3.new(.8, 1.2, .8), "Vase", "Clay", "Cream")
decor("vase_cream", "Cream round vase", Vector3.new(1.2, 1.8, 1.2), "Vase", "Cream", "Ochre")
decor("vase_lake", "Lake tall vase", Vector3.new(1, 2.2, 1), "Vase", "Lake", "Cream")
decor("books_sage", "Sage book stack", Vector3.new(1.3, .65, .9), "Books", "Sage", "Cream", 3)
decor("books_clay", "Clay coffee table books", Vector3.new(1.8, .48, 1.2), "Books", "Clay", "Lake", 2)
decor("tray_oak", "Oak catchall tray", Vector3.new(1.8, .22, 1.2), "Tray", "Oak", "Walnut")
decor("candle_rose", "Rose saucer candle", Vector3.new(.6, .8, .6), "Candle", "Rose", "Cream")
decor("candle_ochre", "Ochre pillar candle", Vector3.new(.7, 1.2, .7), "Candle", "Ochre", "Cream")

for _, r in ipairs({
	{ "desk_plant", "Little desk plant", 1.2, 1.5, 5, "Cream" },
	{ "leaf_plant", "Leafy clay planter", 2.2, 3.8, 7, "Clay" },
	{ "tall_plant", "Tall sage planter", 3.2, 5.8, 10, "Sage" },
}) do
	add("rr_" .. r[1] .. "_v1", r[2], "Plant", "Plants", if r[4] < 2 then "Surface" else "Floor", Vector3.new(r[3], r[4], r[3]), { LeafCount = r[5], PotColor = color(r[6]), LeafColor = color("Leaf") })
end

for _, r in ipairs({
	{ "sunset_print", "Clay sunset print", 2.4, 3.2, "Sunset", "Clay" },
	{ "wide_sunset_print", "Ochre horizon print", 4, 2.5, "Sunset", "Ochre" },
	{ "colorblock_print", "Lake colorblock print", 2.5, 3.4, "Colorblock", "Lake" },
	{ "oak_mirror", "Oak framed mirror", 2.4, 4, "Mirror", "Cream" },
}) do
	add("rr_" .. r[1] .. "_v1", r[2], "Wall", "Wall decor", "Wall", Vector3.new(r[3], r[4], .2), { Design = r[5], FrameColor = color("Oak"), GroundColor = color("Cream"), AccentColor = color(r[6]) })
end

for _, r in ipairs({
	{ "slat_chair_sage", "Sage slat dining chair", 2, 3.5, 2.1, "Slats", "Sage" },
	{ "panel_chair_clay", "Clay panel dining chair", 2.1, 3.4, 2.1, "Panel", "Clay" },
	{ "stool_ochre", "Ochre padded stool", 1.8, 1.9, 1.8, "None", "Ochre" },
	{ "bench_cream", "Cream entry bench", 4.6, 1.9, 1.9, "None", "Cream" },
}) do
	add("rr_" .. r[1] .. "_v1", r[2], "Chair", "Seating", "Floor", Vector3.new(r[3], r[4], r[5]), { Back = r[6], FrameColor = color("Oak"), SeatColor = color(r[7]) })
end

add("rr_double_bed_sage_v1", "Sage throw double bed", "Bed", "Beds", "Floor", Vector3.new(6.2, 3.6, 8.2), { PillowCount = 2, FrameColor = color("Oak"), LinenColor = color("Cream"), ThrowColor = color("Sage") })
add("rr_single_bed_lake_v1", "Lake throw single bed", "Bed", "Beds", "Floor", Vector3.new(4, 3.4, 7.8), { PillowCount = 1, FrameColor = color("Oak"), LinenColor = color("Cream"), ThrowColor = color("Lake") })

return recipes
