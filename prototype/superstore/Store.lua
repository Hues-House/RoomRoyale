local G = require(script.Parent.Geometry)
local Props = require(script.Parent.Props)
local PracticePark = require(script.Parent.PracticePark)
local C = G.colors
local Store = {}

local function tree(parent, x, z)
    local cf = CFrame.new(x, 0, z)
    G.part(parent, "TreePlanter", Vector3.new(7, 1.2, 7), cf * CFrame.new(0, 0.6, 0), C.cream, true)
    G.part(parent, "Trunk", Vector3.new(0.9, 9, 0.9), cf * CFrame.new(0, 5, 0), C.wood, false)
    G.part(parent, "Canopy", Vector3.new(10, 9, 10), cf * CFrame.new(0, 12, 0), C.mint, false, Enum.PartType.Ball)
end

local function checkout(parent)
    local center = Vector3.new(0, 0, -96)
    G.part(parent, "CheckoutInlay", Vector3.new(66, 0.08, 36), CFrame.new(center + Vector3.new(0, 0.12, 0)), C.mint, false)
    local zone = G.part(parent, "GardenCheckout", Vector3.new(66, 12, 36), CFrame.new(center + Vector3.new(0, 6, 0)), C.mint, false)
    zone.Transparency = 1
    zone:SetAttribute("CheckoutZone", true)
    zone:SetAttribute("ZoneId", "garden-checkout")
    zone:SetAttribute("TubeDestination", center + Vector3.new(0, 26, 0))
    for _, x in {-32, 32} do
        G.part(parent, "TubeSupport", Vector3.new(1.8, 30, 1.8), CFrame.new(x, 15, -96), C.wood, true)
    end
    for i = 1, 24 do
        local a = i * math.pi * 2 / 24
        local cf = CFrame.new(center + Vector3.new(math.cos(a) * 13, 26, math.sin(a) * 13)) * CFrame.Angles(0, -a, 0)
        G.part(parent, "TubeRim", Vector3.new(1.8, 2.6, 3.5), cf, C.mint, false)
        G.part(parent, "TubeTopRim", Vector3.new(1.8, 1.2, 3.5), cf * CFrame.new(0, 19, 0), C.mint, false)
        local glass = G.part(parent, "TubeGlass", Vector3.new(0.35, 18, 3.5), cf * CFrame.new(0, 9.5, 0), C.blue, false)
        glass.Material, glass.Transparency = Enum.Material.Glass, 0.82
    end
    G.floatingSign(parent, "CheckoutBeacon", "CHECKOUT\nDrive through to save", center + Vector3.new(0, 20, 28), C.mint, 250, 340)
    return zone
end

local function department(parent, name, x, z, color)
    G.part(parent, name .. "DisplayMat", Vector3.new(28, 0.04, 44), CFrame.new(x, 0.08, z), color, false)
    G.floatingSign(parent, name .. "Sign", name:upper(), Vector3.new(x, 14, z), color, 160, 92)
    -- Low shelves keep the checkout and both exits visible from every display.
    G.part(parent, "DisplayBench", Vector3.new(22, 1.5, 2), CFrame.new(x, 0.75, z - 22), C.cream, true)
end

local function course(parent, name, x, tint, mirrored)
    local direction = mirrored and -1 or 1
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = name, parent
    local x0 = x - direction * 24
    G.road(folder, name .. "Entry", Vector3.new(x0, 0.03, 68), Vector3.new(x, 2.8, 38), 20, tint)
    G.part(folder, name .. "LaunchOne", Vector3.new(22, 1, 28), CFrame.new(x, 2.3, 24), tint, true)
    G.part(folder, name .. "LandingOne", Vector3.new(23, 1, 28), CFrame.new(x, 5.1, -14), tint, true)
    G.part(folder, name .. "PrizeDeck", Vector3.new(27, 1, 34), CFrame.new(x, 7.9, -57), tint, true)
    G.road(folder, name .. "Exit", Vector3.new(x, 8.4, -74), Vector3.new(x0, 0.08, -120), 23, tint)
    G.floatingSign(folder, name .. "EntrySign", "JUMP TRAIL\nHold + release JUMP", Vector3.new(x0, 12, 65), tint, 198, 68)
    G.floatingSign(folder, name .. "PrizeSign", "SPECIAL FIND\n1 per round", Vector3.new(x, 20, -57), C.yellow, 170, 115)
    for _, z in {31, -7} do
        G.arrow(folder, Vector3.new(x, z == 31 and 2.86 or 5.66, z), 0, C.cream, 1.7)
    end
    return CFrame.new(x, 8.4, -57)
end

function Store.build()
    local existing = workspace:FindFirstChild("CartLab")
    if existing then existing:Destroy() end
    local world = Instance.new("Folder")
    world.Name = "CartLab"
    world:SetAttribute("EnvironmentId", "hillside-market-v4")
    world:SetAttribute("StoreTitle", "Hillside Market")
    world:SetAttribute("CheckoutTarget", Vector3.new(0, 26, -96))
    world:SetAttribute("CheckoutCenter", Vector3.new(0, 0, -96))
    world.Parent = workspace
    local structure, routes, stock, scenery = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
    structure.Name, routes.Name, stock.Name, scenery.Name = "Architecture", "Routes", "Stock", "Garden"
    for _, folder in {structure, routes, stock, scenery} do folder.Parent = world end
    G.part(structure, "MarketFloor", Vector3.new(320, 4, 320), CFrame.new(0, -2, 0), Color3.fromRGB(235, 224, 202), true)
    G.part(scenery, "GardenGround", Vector3.new(860, 4, 450), CFrame.new(120, -4.1, 0), Color3.fromRGB(164, 188, 150), true)
    -- The center aisle has no collision geometry between the entrance and checkout.
    G.part(routes, "CheckoutSpine", Vector3.new(34, 0.035, 200), CFrame.new(0, 0.04, 5), Color3.fromRGB(190, 217, 188), false)
    for _, x in {-72, 72} do
        G.part(routes, "EasyLoopSide", Vector3.new(30, 0.03, 214), CFrame.new(x, 0.04, 0), Color3.fromRGB(218, 211, 188), false)
    end
    for _, z in {-125, 100} do
        G.part(routes, "EasyLoopEnd", Vector3.new(170, 0.03, 28), CFrame.new(0, 0.04, z), Color3.fromRGB(218, 211, 188), false)
    end
    for z = 82, -64, -28 do G.arrow(routes, Vector3.new(0, 0.085, z), 0, C.cream, 1.7) end
    for _, x in {-72, 72} do
        for z = 66, -78, -36 do G.arrow(routes, Vector3.new(x, 0.085, z), x < 0 and 0 or math.pi, C.mint, 1.4) end
    end
    for _, x in {-43, 43} do G.arrow(routes, Vector3.new(x, 0.09, -125), x < 0 and -math.pi/2 or math.pi/2, C.mint, 1.6) end
    local zone = checkout(structure)
    G.sign(structure, "HILLSIDE MARKET", CFrame.new(0, 25, 128), 64, 9, C.cream)
    for _, x in {-36, 36} do G.part(structure, "EntrancePost", Vector3.new(1.5, 28, 1.5), CFrame.new(x, 14, 128), C.wood, true) end
    G.floatingSign(structure, "FirstTripSign", "GRAB A FEW FINDS\nThen follow green to checkout", Vector3.new(0, 11, 82), C.cream, 234, 55)
    department(structure, "Living", -42, 50, C.lilac)
    department(structure, "Dining", 42, 50, C.peach)
    department(structure, "Bedroom", -42, -5, C.blue)
    department(structure, "Plants + lights", 42, -5, C.yellow)
    for _, x in {-72, 72} do
        G.floatingSign(structure, "LoopCheckout" .. x, "CHECKOUT  >\nKeep shopping after", Vector3.new(x, 12, -62), C.mint, 172, 68)
    end
    local leftPrize = course(routes, "CushionJumpTrail", -116, C.lilac, true)
    local rightPrize = course(routes, "SunshineJumpTrail", 116, C.peach, false)
    -- A rolling outskirts path is an easy alternative to the jump trails.
    local gardenPath = {Vector3.new(-72,0.03,100), Vector3.new(-104,1.5,115), Vector3.new(-132,3.5,92), Vector3.new(-132,2,57), Vector3.new(-144,0.04,20)}
    for i = 1, #gardenPath - 1 do G.road(routes, "GardenShortcut" .. i, gardenPath[i], gardenPath[i+1], 18, C.mint) end
    G.floatingSign(routes, "GardenPathSign", "GARDEN PATH\nA few extra finds", Vector3.new(-93, 12, 107), C.mint, 175, 72)
    for _, x in {-149,149} do for _, z in {-136, -92, -22, 48, 136} do tree(scenery, x, z) end end
    for _, x in {-205,515} do
        for _, z in {-100,50,160} do G.part(scenery,"Hillside",Vector3.new(95,48,105),CFrame.new(x,1,z),Color3.fromRGB(158,181,144),false,Enum.PartType.Ball) end
    end
    -- A low boundary catches ordinary driving, while all jump failures land on solid floor.
    G.part(structure,"MarketEdge",Vector3.new(1,3,320),CFrame.new(-160,1.5,0),C.cream,true)
    G.part(structure,"MarketEdge",Vector3.new(1,3,228),CFrame.new(160,1.5,-46),C.cream,true)
    G.part(structure,"MarketEdge",Vector3.new(1,3,48),CFrame.new(160,1.5,136),C.cream,true)
    local park = PracticePark.build(world)
    world:SetAttribute("PracticeSpawn", park.spawn)
    world:SetAttribute("MarketSpawn", CFrame.new(0,2.5,112))
    for _, z in {-160,160} do G.part(structure,"MarketEdge",Vector3.new(320,3,1),CFrame.new(0,1.5,z),C.cream,true) end
    local definitions = {
        {key="living-sofa",itemId="Sofa",name="Crescent sofa",department="Living",route="main",space=40,weight=52,color=C.lilac,cf=CFrame.new(-42,0.12,59)},
        {key="living-chair",itemId="Chair",name="Loop bentwood chair",department="Living",route="main",space=22,weight=21,color=C.blue,cf=CFrame.new(-42,0.12,39)},
        {key="dining-table",itemId="Table",name="Oak dining table",department="Dining",route="main",space=35,weight=46,color=C.wood,cf=CFrame.new(42,0.12,59)},
        {key="dining-chair",itemId="Chair",name="Bentwood dining chair",department="Dining",route="main",space=22,weight=21,color=C.peach,cf=CFrame.new(42,0.12,39)},
        {key="bedroom-bed",itemId="Bed",name="Linen double bed",department="Bedroom",route="main",space=44,weight=55,color=C.blue,cf=CFrame.new(-42,0.12,4)},
        {key="bedroom-lamp",itemId="Lamp",name="Tide bedside lamp",department="Bedroom",route="main",space=8,weight=3,color=C.yellow,cf=CFrame.new(-42,0.12,-16)},
        {key="garden-plant",itemId="Plant",name="Garden plant",department="Plants",route="main",space=18,weight=10,color=C.mint,cf=CFrame.new(42,0.12,4)},
        {key="lighting-lamp",itemId="Lamp",name="Tide table lamp",department="Lighting",route="main",space=8,weight=3,color=C.yellow,cf=CFrame.new(42,0.12,-16)},
        {key="checkout-rug",itemId="Rug",name="Peach woven rug",department="Finishing touches",route="checkout",space=12,weight=17,color=C.peach,cf=CFrame.new(-43,0.12,-62)},
        {key="checkout-books",itemId="Books",name="Colour study books",department="Finishing touches",route="checkout",space=8,weight=6,color=C.blue,cf=CFrame.new(43,0.12,-62)},
        {key="garden-books",itemId="Books",name="Botanical books",department="Garden path",route="garden",space=8,weight=6,color=C.mint,rarity="Rare",cf=CFrame.new(-132,2.12,57)},
        {key="trail-chair",itemId="Chair",name="Lilac bentwood chair",department="Special finds",route="jump",space=22,weight=21,color=C.lilac,specialTint=C.lilac,rarity="Limited",finiteStock=1,requireLanding=true,cf=leftPrize},
        {key="trail-lamp",itemId="OrbitLamp",name="Orbit halo lamp",department="Special finds",route="jump",space=8,weight=3,color=C.yellow,rarity="Limited",finiteStock=1,requireLanding=true,cf=rightPrize},
    }
    local pickups = {}
    for _, definition in definitions do table.insert(pickups, Props.pickup(stock, definition)) end
    local lighting = game:GetService("Lighting")
    lighting.ClockTime, lighting.Brightness, lighting.ExposureCompensation = 14, 1.5, -0.3
    lighting.Ambient, lighting.OutdoorAmbient = Color3.fromRGB(130,139,143), Color3.fromRGB(170,181,175)
    return {world=world,spawn=CFrame.new(0,2.5,112),pickups=pickups,checkoutZones={zone},stockLocations=definitions,routes={main="EasyLoop",optional="JumpTrails",returnLane="EasyLoopSide"},tubeDestinations={["garden-checkout"]=Vector3.new(0,26,-96)}}
end

function Store.buildStyleRoom(index)
	local name="HillsideCollection"..index
	local old=workspace:FindFirstChild(name)
	if old then old:Destroy() end
	local room=Instance.new("Model")
	room.Name=name
	room.Parent=workspace
	local cf=CFrame.new(450+index*70,0,80)
	G.part(room,"OakFloor",Vector3.new(52,1,44),cf*CFrame.new(0,-0.5,0),C.wood,true).Material=Enum.Material.WoodPlanks
	G.part(room,"BackWall",Vector3.new(52,20,1),cf*CFrame.new(0,10,-22),C.cream,true)
	for _,x in {-26,26} do G.part(room,"SideWall",Vector3.new(1,20,44),cf*CFrame.new(x,10,0),Color3.fromRGB(206,217,198),true) end
	G.part(room,"FrontRail",Vector3.new(52,3,0.8),cf*CFrame.new(0,1.5,22),C.cream,true)
	G.sign(room,"YOUR HILLSIDE FINDS",cf*CFrame.new(0,13,-21.3),35,4,C.cream)
	G.sign(room,"Collection preview / Ready for another shopping trip?",cf*CFrame.new(0,8,-21.3),42,3,C.cream)
	return cf
end

return Store
