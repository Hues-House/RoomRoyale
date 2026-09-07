-- ServerScriptService > NeighborhoodBootstrap
-- Persistent plaza + boulevard decor: fountain hangout, benches (sittable),
-- lamps, planters, picnic umbrellas, boutique facade, boulevard path with
-- walkways to each house plot, welcome arch. Pure geometry; no game logic.
-- Plaza floor/pedestals come from LobbyBootstrap. House plots: X=+/-90,
-- Z rows 130, 40, -50, -140 (HousingService). Queue ring (0,212). Spawn (0,258).

local NB = {}
local VERSION = 7

local PLAZA = Vector3.new(0, 0, 240)
local STONE  = Color3.fromRGB(210, 203, 192)
local CREAM  = Color3.fromRGB(250, 246, 238)
local GOLD   = Color3.fromRGB(214, 167, 82)
local PINK   = Color3.fromRGB(238, 158, 178)
local WATER  = Color3.fromRGB(140, 205, 235)
local GREEN  = Color3.fromRGB(118, 168, 108)
local WOODC  = Color3.fromRGB(168, 132, 96)
local PATHC  = Color3.fromRGB(226, 216, 200)

local function P(parent, name, size, cf, color, mat, collide)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf
	p.Anchored = true; p.CanCollide = (collide ~= false); p.CastShadow = false
	p.Color = color or CREAM; p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent; return p
end

local function cyl(parent, name, dia, h, pos, color, mat, collide)
	local p = P(parent, name, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat, collide)
	p.Shape = Enum.PartType.Cylinder; return p
end

local function ball(parent, name, dia, pos, color, mat)
	local p = P(parent, name, Vector3.new(dia, dia, dia), CFrame.new(pos), color, mat, false)
	p.Shape = Enum.PartType.Ball; return p
end

local function light(part, b, r, c)
	local l = Instance.new("PointLight"); l.Brightness = b; l.Range = r
	l.Color = c or Color3.fromRGB(255, 236, 200); l.Parent = part
end

local function bench(parent, pos, faceTowards)
	local f = Instance.new("Folder"); f.Name = "Bench"; f.Parent = parent
	local cf = CFrame.lookAt(pos, Vector3.new(faceTowards.X, pos.Y, faceTowards.Z))
	local seat = Instance.new("Seat")
	seat.Size = Vector3.new(5, 0.5, 1.8); seat.CFrame = cf * CFrame.new(0, 1.5, 0)
	seat.Anchored = true; seat.Color = WOODC; seat.Material = Enum.Material.WoodPlanks
	seat.TopSurface = Enum.SurfaceType.Smooth; seat.Parent = f
	P(f, "Back", Vector3.new(5, 1.6, 0.35), cf * CFrame.new(0, 2.4, 0.85), WOODC, Enum.Material.WoodPlanks)
	P(f, "LegL", Vector3.new(0.4, 1.3, 1.6), cf * CFrame.new(-2.1, 0.65, 0), STONE)
	P(f, "LegR", Vector3.new(0.4, 1.3, 1.6), cf * CFrame.new(2.1, 0.65, 0), STONE)
end

local function lamp(parent, x, z)
	local f = Instance.new("Folder"); f.Name = "Lamp"; f.Parent = parent
	cyl(f, "Base", 1.6, 0.5, Vector3.new(x, 0.25, z), STONE)
	P(f, "Post", Vector3.new(0.5, 9, 0.5), CFrame.new(x, 4.9, z), Color3.fromRGB(92, 86, 80))
	local head = ball(f, "Head", 1.7, Vector3.new(x, 9.8, z), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	light(head, 1.1, 26)
end

local function planter(parent, x, z)
	local f = Instance.new("Folder"); f.Name = "Planter"; f.Parent = parent
	P(f, "Box", Vector3.new(4, 1.3, 4), CFrame.new(x, 0.65, z), Color3.fromRGB(196, 124, 94), Enum.Material.Concrete)
	ball(f, "Bush", 3.6, Vector3.new(x, 2.6, z), GREEN, Enum.Material.Grass)
	ball(f, "Flower1", 0.7, Vector3.new(x - 1, 3.4, z + 0.6), PINK, Enum.Material.Neon)
	ball(f, "Flower2", 0.7, Vector3.new(x + 0.9, 3.6, z - 0.5), Color3.fromRGB(255, 214, 120), Enum.Material.Neon)
end

local function picnic(parent, x, z)
	local f = Instance.new("Folder"); f.Name = "Picnic"; f.Parent = parent
	cyl(f, "TableTop", 5, 0.35, Vector3.new(x, 2.8, z), CREAM)
	P(f, "TableLeg", Vector3.new(0.6, 2.7, 0.6), CFrame.new(x, 1.35, z), STONE)
	P(f, "Pole", Vector3.new(0.35, 7.6, 0.35), CFrame.new(x, 6.4, z), CREAM)
	cyl(f, "Umbrella", 9, 0.5, Vector3.new(x, 9.4, z), PINK, Enum.Material.SmoothPlastic, false)
	for _, off in ipairs({ Vector3.new(3.4, 0, 0), Vector3.new(-3.4, 0, 0), Vector3.new(0, 0, 3.4), Vector3.new(0, 0, -3.4) }) do
		local seat = Instance.new("Seat")
		seat.Size = Vector3.new(2, 0.45, 2)
		seat.CFrame = CFrame.lookAt(Vector3.new(x, 1.6, z) + off, Vector3.new(x, 1.6, z))
		seat.Anchored = true; seat.Color = WOODC; seat.Material = Enum.Material.WoodPlanks
		seat.Parent = f
	end
end

local function buildFountain(parent)
	local f = Instance.new("Folder"); f.Name = "Fountain"; f.Parent = parent
	local cx, cz = PLAZA.X, PLAZA.Z
	cyl(f, "Basin", 18, 1.6, Vector3.new(cx, 0.8, cz), STONE, Enum.Material.Concrete)
	local w = cyl(f, "Water", 15.6, 0.9, Vector3.new(cx, 1.35, cz), WATER, Enum.Material.Neon, false)
	light(w, 0.6, 20, WATER)
	P(f, "Pillar", Vector3.new(1.8, 3.6, 1.8), CFrame.new(cx, 3.2, cz), STONE, Enum.Material.Concrete)
	cyl(f, "Bowl", 7, 0.8, Vector3.new(cx, 5.2, cz), STONE, Enum.Material.Concrete)
	cyl(f, "WaterTop", 5.8, 0.5, Vector3.new(cx, 5.7, cz), WATER, Enum.Material.Neon, false)
	local orb = ball(f, "Orb", 1.6, Vector3.new(cx, 6.9, cz), Color3.fromRGB(255, 244, 214), Enum.Material.Neon)
	light(orb, 1.2, 30)
	for i = 0, 3 do
		local ang = math.rad(45 + i * 90)
		local bx = cx + math.sin(ang) * 15
		local bz = cz + math.cos(ang) * 15
		bench(f, Vector3.new(bx, 0, bz), Vector3.new(cx, 0, cz))
	end
end

local function buildFacade(parent)
	local f = Instance.new("Folder"); f.Name = "BoutiqueFacade"; f.Parent = parent
	local z = PLAZA.Z + 52.5
	P(f, "Wall", Vector3.new(114, 14, 1.2), CFrame.new(0, 7, z), CREAM)
	P(f, "Awning", Vector3.new(114, 0.5, 5), CFrame.new(0, 10.6, z - 2.6), PINK)
	for i = -2, 2 do
		if i ~= 0 then
			local win = P(f, "Window", Vector3.new(9, 5.5, 0.4), CFrame.new(i * 22, 6.2, z - 0.5), Color3.fromRGB(176, 216, 232), Enum.Material.Glass, false)
			win.Transparency = 0.35
		end
	end
	P(f, "Door", Vector3.new(8, 9, 0.4), CFrame.new(0, 4.5, z - 0.5), WOODC, Enum.Material.WoodPlanks, false)
	local sign = P(f, "FacadeSign", Vector3.new(60, 4.5, 0.4), CFrame.new(0, 12.2, z - 0.9), Color3.fromRGB(255, 253, 248))
	sign.CanCollide = false
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; gui.CanvasSize = Vector2.new(1200, 100); gui.Parent = sign
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
	lbl.Text = "THE BOUTIQUE"; lbl.TextColor3 = Color3.fromRGB(120, 90, 55)
	lbl.Font = Enum.Font.FredokaOne; lbl.TextScaled = true; lbl.Parent = gui
end

local function buildBoulevard(parent)
	local f = Instance.new("Folder"); f.Name = "Boulevard"; f.Parent = parent
	P(f, "Path", Vector3.new(16, 0.2, 350), CFrame.new(0, 0.1, 15), PATHC, Enum.Material.Concrete)
	P(f, "EdgeW", Vector3.new(0.6, 0.24, 350), CFrame.new(-7.7, 0.11, 15), GOLD, Enum.Material.SmoothPlastic, false)
	P(f, "EdgeE", Vector3.new(0.6, 0.24, 350), CFrame.new(7.7, 0.11, 15), GOLD, Enum.Material.SmoothPlastic, false)
	for _, rowZ in ipairs({ 130, 40, -50, -140 }) do
		P(f, "WalkwayW", Vector3.new(62, 0.2, 8), CFrame.new(-39, 0.1, rowZ), PATHC, Enum.Material.Concrete)
		P(f, "WalkwayE", Vector3.new(62, 0.2, 8), CFrame.new(39, 0.1, rowZ), PATHC, Enum.Material.Concrete)
	end
	for _, z in ipairs({ 85, -5, -95 }) do
		lamp(f, -11, z); lamp(f, 11, z)
	end
	-- Welcome arch at the plaza junction
	local az = 190
	P(f, "ArchPillarW", Vector3.new(1.6, 11, 1.6), CFrame.new(-9, 5.5, az), CREAM)
	P(f, "ArchPillarE", Vector3.new(1.6, 11, 1.6), CFrame.new(9, 5.5, az), CREAM)
	local beam = P(f, "ArchBeam", Vector3.new(21, 2.2, 1.8), CFrame.new(0, 11.6, az), PINK)
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; gui.CanvasSize = Vector2.new(900, 90); gui.Parent = beam
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
	lbl.Text = "ROYALE ROW"; lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Font = Enum.Font.FredokaOne; lbl.TextScaled = true; lbl.Parent = gui
	local gui2 = gui:Clone(); gui2.Face = Enum.NormalId.Front; gui2.Parent = beam
end

local function buildPlazaDecor(parent)
	local f = Instance.new("Folder"); f.Name = "PlazaDecor"; f.Parent = parent
	lamp(f, -48, PLAZA.Z - 42); lamp(f, 48, PLAZA.Z - 42)
	lamp(f, -48, PLAZA.Z + 42); lamp(f, 48, PLAZA.Z + 42)
	planter(f, -48, PLAZA.Z); planter(f, 48, PLAZA.Z)
	picnic(f, -40, 210); picnic(f, 40, 210)
	-- Spawn pad marker (SpawnLocation itself is a separate instance)
	local pad = cyl(f, "SpawnPad", 10, 0.3, Vector3.new(0, 0.55, 258), Color3.fromRGB(255, 232, 170), Enum.Material.SmoothPlastic, false)
	local ring = cyl(f, "SpawnRing", 11, 0.2, Vector3.new(0, 0.58, 258), GOLD, Enum.Material.Neon, false)
end

local function tree(parent, x, z, s)
	s = s or 1
	local f = Instance.new("Folder"); f.Name = "Tree"; f.Parent = parent
	P(f, "Trunk", Vector3.new(1.9*s, 10*s, 1.9*s), CFrame.new(x, 5*s, z), Color3.fromRGB(120, 88, 60), Enum.Material.Wood)
	ball(f, "Leaf1", 11*s, Vector3.new(x, 11.5*s, z), Color3.fromRGB(108,164,96), Enum.Material.Grass)
	ball(f, "Leaf2", 8.5*s, Vector3.new(x - 3*s, 14*s, z + 2*s), Color3.fromRGB(128,184,114), Enum.Material.Grass)
	ball(f, "Leaf3", 8*s, Vector3.new(x + 3.2*s, 13.5*s, z - 1.5*s), Color3.fromRGB(96,150,86), Enum.Material.Grass)
	ball(f, "Leaf4", 6.5*s, Vector3.new(x + 0.4*s, 16.5*s, z + 0.4*s), Color3.fromRGB(136,192,122), Enum.Material.Grass)
end

local function bush(parent, x, z, s)
	s = s or 1
	local f = Instance.new("Folder"); f.Name = "Bush"; f.Parent = parent
	ball(f, "B1", 5*s, Vector3.new(x, 1.9*s, z), Color3.fromRGB(112,168,100), Enum.Material.Grass)
	ball(f, "B2", 4*s, Vector3.new(x+2.2*s, 1.5*s, z+1*s), Color3.fromRGB(126,182,112), Enum.Material.Grass)
	ball(f, "B3", 3.6*s, Vector3.new(x-2*s, 1.4*s, z-1*s), Color3.fromRGB(100,154,90), Enum.Material.Grass)
end

local function flowers(parent, x, z)
	local f = Instance.new("Folder"); f.Name = "Flowers"; f.Parent = parent
	local cols = { PINK, Color3.fromRGB(255,214,120), Color3.fromRGB(220,180,235), Color3.fromRGB(255,255,255) }
	for i=1,8 do
		local ox, oz = (math.random()-0.5)*8, (math.random()-0.5)*8
		P(f, "Stem", Vector3.new(0.25,1.5,0.25), CFrame.new(x+ox,0.95,z+oz), Color3.fromRGB(96,150,86), Enum.Material.Grass, false)
		ball(f, "Bloom", 1.1, Vector3.new(x+ox,1.8,z+oz), cols[(i%#cols)+1], Enum.Material.Neon)
	end
end

local function buildGroundAndTrees(parent)
	-- Calm sea extending past the horizon so the world reads as an island sitting in
	-- water, not a grass slab floating in the void. (Parts cap at 2048 studs/axis; this
	-- one covers the plaza, all house plots, and the round-room island.) CanCollide acts
	-- as a safety floor so walking off the island lands on water instead of falling.
	local sea = P(parent, "Sea", Vector3.new(2048, 10, 2048), CFrame.new(0, -6, 300), WATER, Enum.Material.SmoothPlastic)
	sea.Reflectance = 0.15
	-- Plaza landmass: grass top + deep tapered earth/rock so it reads as solid ground, not a floating slab
	P(parent, "GrassEdge", Vector3.new(348, 1.4, 600), CFrame.new(0, -1.9, 50), Color3.fromRGB(150, 192, 132), Enum.Material.Grass)
	P(parent, "Ground", Vector3.new(332, 2, 582), CFrame.new(0, -1, 50), Color3.fromRGB(120, 174, 104), Enum.Material.Grass)
	P(parent, "EarthMass", Vector3.new(326, 44, 576), CFrame.new(0, -24, 50), Color3.fromRGB(140, 110, 82), Enum.Material.Ground)
	P(parent, "Rock", Vector3.new(300, 70, 540), CFrame.new(0, -70, 50), Color3.fromRGB(122, 112, 106), Enum.Material.Slate)
	P(parent, "RockDeep", Vector3.new(232, 110, 452), CFrame.new(0, -150, 50), Color3.fromRGB(98, 92, 88), Enum.Material.Slate)
	-- round-space island (showroom + style rooms): same grounded treatment
	P(parent, "RoundIslandGrass", Vector3.new(680, 2, 640), CFrame.new(0, -1, 680), Color3.fromRGB(120,174,104), Enum.Material.Grass)
	P(parent, "RoundIslandEarth", Vector3.new(672, 44, 632), CFrame.new(0, -24, 680), Color3.fromRGB(140,110,82), Enum.Material.Ground)
	P(parent, "RoundIslandRock", Vector3.new(620, 100, 560), CFrame.new(0, -92, 680), Color3.fromRGB(112,104,100), Enum.Material.Slate)
	-- lush perimeter planting framing the plaza & boulevard
	math.randomseed(7)
	local treeSpots = { {-26,108,1.1},{26,108,1.0},{-26,12,1.05},{26,12,0.95},{-26,-86,1.05},{26,-86,1.0},
		{-44,205,1.2},{44,205,1.15},{-44,285,1.0},{44,285,1.05},{-48,250,1.25},{48,250,1.2},
		{-40,160,1.1},{40,160,1.1},{-40,60,1.05},{40,60,1.05},{-40,-40,1.1},{40,-40,1.05},
		{-30,300,0.95},{30,300,0.95} }
	for _, t in ipairs(treeSpots) do tree(parent, t[1], t[2], t[3]) end
	for bx = -50, 50, 12 do tree(parent, bx, 322, 0.9 + (bx%7)*0.03) end
	local bushSpots = { {-44,200},{44,200},{-50,150},{50,150},{-46,232},{46,232},{-40,270},{40,270},{-48,182},{48,182},{-34,300},{34,300} }
	for _, b in ipairs(bushSpots) do bush(parent, b[1], b[2], 1) end
	local flowerSpots = { {-40,222},{40,222},{-48,255},{48,255},{-30,182},{30,182},{-44,210},{44,210} }
	for _, fl in ipairs(flowerSpots) do flowers(parent, fl[1], fl[2]) end
end

function NB.EnsureAll()
	local ex = workspace:FindFirstChild("Neighborhood")
	if ex then
		if ex:GetAttribute("Version") == VERSION then return ex end
		ex:Destroy()
	end
	local f = Instance.new("Folder"); f.Name = "Neighborhood"
	f:SetAttribute("Version", VERSION); f.Parent = workspace
	buildFountain(f)
	buildFacade(f)
	buildBoulevard(f)
	buildPlazaDecor(f)
	buildGroundAndTrees(f)
	print("[NeighborhoodBootstrap] v" .. VERSION .. " plaza + boulevard built")
	return f
end

return NB
