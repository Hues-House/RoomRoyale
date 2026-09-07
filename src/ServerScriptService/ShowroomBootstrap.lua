-- ServerScriptService > ShowroomBootstrap (v5 - department bays + spotlight core)
-- No staged rooms. Every display point is a generic fixture slot generated
-- from the BAYS / PEDESTALS / RUG_PLATFORMS / CEILING_SLOTS tables below.
-- Adding capacity = adding one entry to a table; geometry is computed.
-- Slot counts are sized to actual ItemCatalogData inventory per
-- Department/Subsection/Surface so the unique-pick spawner never starves.
-- Shell: 300x240 at Z=550, 36-stud ceiling. Entry pad + sign on the SOUTH
-- wall (toward the plaza). Pedestal slots carry a FloorY attribute that
-- StoreSetup uses to ground items on the pedestal top instead of the floor.

local SB = {}

local VERSION   = 9
local CENTER    = Vector3.new(4000, 0, 550)
local FY        = 0.3
local SX, SZ    = 380, 300
local CEIL_Y    = 36
local WT        = 1.5
local PLAT      = 0.12 -- thin platforms so carts roll flush (v4-tested)

local SMOOTH = Enum.Material.SmoothPlastic
local WOOD   = Enum.Material.WoodPlanks
local FABRIC = Enum.Material.Fabric
local NEON   = Enum.Material.Neon

local FLOOR_COLOR = Color3.fromRGB(199, 176, 148)
local CEIL_COLOR  = Color3.fromRGB(247, 245, 241)
local WALL_COLOR  = Color3.fromRGB(236, 230, 222)
local TRIM        = Color3.fromRGB(120, 96, 72)
local ACCENT      = Color3.fromRGB(214, 167, 82)
local GOLD        = Color3.fromRGB(255, 211, 116)
local CREAM       = Color3.fromRGB(250, 247, 240)

local DEPT_TINT = {
	LivingRoom  = Color3.fromRGB(232, 214, 196),
	Bedroom     = Color3.fromRGB(226, 206, 214),
	Storage     = Color3.fromRGB(208, 214, 206),
	Accessories = Color3.fromRGB(220, 212, 198),
}

-- wall: shell wall the bay sits against. c: center along that wall
-- (X for N/S walls, Z for E/W walls). len: bay length along the wall.
-- Slots are spaced evenly; per-slot dept overrides def.dept.
local BAYS = {
	{ id="Seating", label="SEATING", dept="LivingRoom", wall="N", c=-120, len=120,
	  slots={ {sub="Seating",b="Showcase"},{sub="Seating",b="Flexible"},{sub="Seating",b="Flexible"},{sub="Seating",b="Accent"},
		{sub="Seating",b="Flexible"},{sub="Seating",b="Accent"},{sub="Seating",b="Flexible"},{sub="Seating",b="Showcase"} } },
	{ id="Tables", label="TABLES & DESKS", dept="LivingRoom", wall="N", c=10, len=100,
	  slots={ {sub="Tables",b="Showcase"},{sub="Tables",b="Flexible"},{sub="Tables",b="Accent"},
		{sub="Tables",b="Flexible"},{sub="Tables",b="Flexible"},{sub="Tables",b="Accent"} } },
	{ id="StorageBay", label="STORAGE", dept="Storage", wall="N", c=130, len=100,
	  slots={ {sub="Shelving",b="Showcase"},{sub="Shelving",b="Flexible"},{sub="Shelving",b="Flexible"},{sub="Shelving",b="Accent"},
		{sub="Shelving",b="Flexible"},{sub="Baskets",b="Flexible"},{sub="Baskets",b="Accent"},{sub="Baskets",b="Flexible"} } },
	{ id="Bedroom", label="BEDROOM", dept="Bedroom", wall="W", c=-55, len=140,
	  slots={ {sub="Beds",b="Showcase"},{sub="Beds",b="Flexible"},{sub="Beds",b="Accent"},
		{sub="Dressers",b="Showcase"},{sub="Dressers",b="Flexible"},{sub="Dressers",b="Flexible"},{sub="Dressers",b="Accent"},{sub="Dressers",b="Flexible"},
		{sub="Tables",b="Accent"},{sub="Seating",b="Accent"} } },
	{ id="Lighting", label="LIGHTING", wall="W", c=75, len=90,
	  slots={ {dept="Accessories",sub="Lighting",b="Showcase"},{dept="Accessories",sub="Lighting",b="Flexible"},{dept="Accessories",sub="Lighting",b="Accent"},
		{dept="LivingRoom",sub="Lighting",b="Flexible"},{dept="LivingRoom",sub="Lighting",b="Accent"} } },
	{ id="Gallery", label="WALL GALLERY", wall="E", c=-55, len=130, surface="Wall",
	  slots={ {dept="Accessories",sub="Art",b="RarePop"},{dept="Accessories",sub="Art",b="Showcase"},{dept="Accessories",sub="Art",b="Flexible"},{dept="Accessories",sub="Art",b="Accent"},
		{dept="Accessories",sub="Decor",b="Flexible"},{dept="Accessories",sub="Decor",b="Accent"},{dept="Accessories",sub="Decor",b="Flexible"},
		{dept="Bedroom",sub="Decor",b="Accent"},{dept="Accessories",sub="Plants",b="Accent"} } },
	{ id="DecorBay", label="DECOR", wall="E", c=70, len=100,
	  slots={ {dept="Accessories",sub="Decor",b="Showcase"},{dept="Accessories",sub="Decor",b="Flexible"},{dept="Accessories",sub="Decor",b="Accent"},
		{dept="LivingRoom",sub="Decor",b="Flexible"},{dept="LivingRoom",sub="Decor",b="Accent"},{dept="LivingRoom",sub="Decor",b="Flexible"},
		{dept="Bedroom",sub="Decor",b="Accent"} } },
	{ id="Plants", label="PLANTS", dept="Accessories", wall="S", c=-110, len=110,
	  slots={ {sub="Plants",b="Showcase"},{sub="Plants",b="Flexible"},{sub="Plants",b="Flexible"},{sub="Plants",b="Accent"},{sub="Plants",b="Flexible"} } },
	{ id="Electronics", label="ELECTRONICS", dept="Accessories", wall="S", c=110, len=90,
	  slots={ {sub="Electronics",b="Showcase"},{sub="Electronics",b="Flexible"},{sub="Electronics",b="Accent"},{sub="Electronics",b="Flexible"} } },
}

-- Spotlight Core pedestals: all RarePop, contested center loot.
-- Accessories entries omit sub = any Accessories floor item qualifies.
local PEDESTALS = {
	{ dept="LivingRoom", sub="Seating" },
	{ dept="LivingRoom", sub="Tables" },
	{ dept="Bedroom", sub="Beds" },
	{ dept="Bedroom", sub="Dressers" },
	{ dept="Storage", sub="Shelving" },
	{ dept="Accessories" }, { dept="Accessories" }, { dept="Accessories" },
}

local RUG_PLATFORMS = {
	{ x=-60, z=10, slots={ {dept="LivingRoom"},{dept="LivingRoom"},{dept="Bedroom"} } },
	{ x=60, z=10, slots={ {dept="LivingRoom"},{dept="Bedroom"},{dept="Storage"} } },
}

local CEILING_SLOTS = {
	{ x=-60, z=-50, dept="Accessories", sub="Lighting" },
	{ x=60, z=-50, dept="Accessories", sub="Lighting" },
	{ x=-60, z=70, dept="Accessories", sub="Plants" },
	{ x=60, z=70, dept="Accessories", sub="Decor" },
}

local function P(parent, name, size, cf, color, mat)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf
	p.Anchored = true; p.CanCollide = true; p.CastShadow = false
	p.Color = color or WALL_COLOR; p.Material = mat or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent; return p
end

local function addLight(parent, b, r, c)
	local l = Instance.new("PointLight"); l.Brightness = b; l.Range = r
	l.Color = c or Color3.fromRGB(255, 236, 200); l.Parent = parent
end

local function addSign(parent, pos, inward, text, twoSided)
	local w = #text * 1.35 + 4
	local sign = P(parent, "BaySign", Vector3.new(w, 3.2, 0.4), CFrame.lookAt(pos, pos + inward), Color3.fromRGB(255, 253, 248), SMOOTH)
	sign.CanCollide = false
	local function addFace(face)
		local g = Instance.new("SurfaceGui"); g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 50; g.Parent = sign
		local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1
		l.Text = text; l.TextColor3 = Color3.fromRGB(186, 132, 66)
		l.Font = Enum.Font.FredokaOne; l.TextScaled = true; l.Parent = g
	end
	addFace(Enum.NormalId.Front)
	if twoSided then addFace(Enum.NormalId.Back) end
end

local function makeSlot(parent, name, cf, surface, dept, sub, bias, floorY)
	local p = Instance.new("Part")
	p.Name = name; p.Size = Vector3.new(2.5, 0.2, 2.5); p.CFrame = cf
	p.Anchored = true; p.CanCollide = false; p.Transparency = 1; p.CastShadow = false
	p:SetAttribute("Department", dept)
	p:SetAttribute("PlacementSurface", surface)
	if sub then p:SetAttribute("StoreSubsection", sub) end
	p:SetAttribute("RarityBias", bias or "Flexible")
	local fy = floorY
	if not fy and surface == "Floor" then fy = cf.Position.Y end
	if fy then p:SetAttribute("FloorY", fy) end
	p.Parent = parent
	return p
end

local function slotFolder(sr, dept, group)
	local d = sr:FindFirstChild(dept)
	if not d then d = Instance.new("Folder"); d.Name = dept; d.Parent = sr end
	local g = d:FindFirstChild(group)
	if not g then g = Instance.new("Folder"); g.Name = group; g.Parent = d end
	return g
end

local function buildShell(sf)
	local cx, cz = CENTER.X, CENTER.Z
	P(sf, "Floor", Vector3.new(SX, 2, SZ), CFrame.new(cx, FY - 1, cz), FLOOR_COLOR, WOOD)
	P(sf, "Ceiling", Vector3.new(SX + WT * 2, 1, SZ + WT * 2), CFrame.new(cx, CEIL_Y, cz), CEIL_COLOR, SMOOTH)
	P(sf, "WallN", Vector3.new(SX + WT * 2, CEIL_Y, WT), CFrame.new(cx, CEIL_Y * 0.5, cz + SZ * 0.5 + WT * 0.5), WALL_COLOR)
	P(sf, "WallS", Vector3.new(SX + WT * 2, CEIL_Y, WT), CFrame.new(cx, CEIL_Y * 0.5, cz - SZ * 0.5 - WT * 0.5), WALL_COLOR)
	P(sf, "WallW", Vector3.new(WT, CEIL_Y, SZ), CFrame.new(cx - SX * 0.5 - WT * 0.5, CEIL_Y * 0.5, cz), WALL_COLOR)
	P(sf, "WallE", Vector3.new(WT, CEIL_Y, SZ), CFrame.new(cx + SX * 0.5 + WT * 0.5, CEIL_Y * 0.5, cz), WALL_COLOR)
	-- South-wall sign (faces the interior; entrance side, toward plaza)
	local sign = P(sf, "ShowroomSign", Vector3.new(80, 6, 0.4), CFrame.new(cx, CEIL_Y - 6, cz - SZ * 0.5 + 1), Color3.fromRGB(255, 253, 248), SMOOTH)
	sign.CanCollide = false
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; gui.CanvasSize = Vector2.new(1200, 90); gui.Parent = sign
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
	lbl.Text = "THE SHOWROOM"; lbl.TextColor3 = Color3.fromRGB(120, 90, 55)
	lbl.Font = Enum.Font.FredokaOne; lbl.TextSize = 64; lbl.Parent = gui
	local pad = P(sf, "ShopEntryPad", Vector3.new(60, 0.3, 12), CFrame.new(cx, FY + 0.15, cz - SZ * 0.5 + 10), Color3.fromRGB(228, 210, 180), SMOOTH)
	pad:SetAttribute("ShopEntryPad", true); pad.CanCollide = false
	for gx = -1, 1 do
		for gz = -1, 1 do
			local fix = P(sf, "CeilLight", Vector3.new(10, 0.5, 10), CFrame.new(cx + gx * 130, CEIL_Y - 1, cz + gz * 100), Color3.fromRGB(255, 248, 232), NEON)
			fix.CanCollide = false; addLight(fix, 0.85, 44, Color3.fromRGB(255, 240, 210))
		end
	end
end

local function buildBay(sf, sr, def)
	local cx, cz = CENTER.X, CENTER.Z
	local fold = Instance.new("Folder"); fold.Name = "Bay_" .. def.id; fold.Parent = sf
	local depth = 18
	local isWall = (def.surface == "Wall")
	local inward, platCF, platSize, bandCF, bandSize
	if def.wall == "N" then
		inward = Vector3.new(0, 0, -1)
		platCF = CFrame.new(cx + def.c, FY + PLAT * 0.5, cz + SZ * 0.5 - depth * 0.5)
		platSize = Vector3.new(def.len, PLAT, depth)
		bandCF = CFrame.new(cx + def.c, FY + 6, cz + SZ * 0.5 - 0.4)
		bandSize = Vector3.new(def.len, 12, 0.8)
	elseif def.wall == "S" then
		inward = Vector3.new(0, 0, 1)
		platCF = CFrame.new(cx + def.c, FY + PLAT * 0.5, cz - SZ * 0.5 + depth * 0.5)
		platSize = Vector3.new(def.len, PLAT, depth)
		bandCF = CFrame.new(cx + def.c, FY + 6, cz - SZ * 0.5 + 0.4)
		bandSize = Vector3.new(def.len, 12, 0.8)
	elseif def.wall == "W" then
		inward = Vector3.new(1, 0, 0)
		platCF = CFrame.new(cx - SX * 0.5 + depth * 0.5, FY + PLAT * 0.5, cz + def.c)
		platSize = Vector3.new(depth, PLAT, def.len)
		bandCF = CFrame.new(cx - SX * 0.5 + 0.4, FY + 6, cz + def.c)
		bandSize = Vector3.new(0.8, 12, def.len)
	else
		inward = Vector3.new(-1, 0, 0)
		platCF = CFrame.new(cx + SX * 0.5 - depth * 0.5, FY + PLAT * 0.5, cz + def.c)
		platSize = Vector3.new(depth, PLAT, def.len)
		bandCF = CFrame.new(cx + SX * 0.5 - 0.4, FY + 6, cz + def.c)
		bandSize = Vector3.new(0.8, 12, def.len)
	end
	local tint = DEPT_TINT[def.dept or def.slots[1].dept] or WALL_COLOR
	if not isWall then
		local plat = P(fold, "Platform", platSize, platCF, tint, FABRIC)
		plat.CanCollide = false
		local eSize = (def.wall == "N" or def.wall == "S") and Vector3.new(def.len, 0.06, 0.5) or Vector3.new(0.5, 0.06, def.len)
		local e = P(fold, "Edge", eSize, CFrame.new(platCF.Position + inward * (depth * 0.5) + Vector3.new(0, PLAT * 0.5 + 0.03, 0)), ACCENT, NEON)
		e.CanCollide = false
	end
	local band = P(fold, "Band", isWall and (bandSize + Vector3.new(0, 4, 0)) or bandSize, bandCF, tint, SMOOTH)
	band.CanCollide = false
	addSign(fold, bandCF.Position + inward * 1.2 + Vector3.new(0, isWall and 11 or 9.5, 0), inward, def.label)
	local n = #def.slots
	for i, sd in ipairs(def.slots) do
		local along = def.len * ((i - 0.5) / n - 0.5)
		local dept = sd.dept or def.dept
		local surface = def.surface or "Floor"
		local pos
		if isWall then
			local y = FY + 7
			if def.wall == "E" then pos = Vector3.new(cx + SX * 0.5 - 0.6, y, cz + def.c + along)
			elseif def.wall == "W" then pos = Vector3.new(cx - SX * 0.5 + 0.6, y, cz + def.c + along)
			elseif def.wall == "N" then pos = Vector3.new(cx + def.c + along, y, cz + SZ * 0.5 - 0.6)
			else pos = Vector3.new(cx + def.c + along, y, cz - SZ * 0.5 + 0.6) end
		else
			if def.wall == "N" or def.wall == "S" then
				pos = Vector3.new(cx + def.c + along, FY + PLAT, platCF.Position.Z)
			else
				pos = Vector3.new(platCF.Position.X, FY + PLAT, cz + def.c + along)
			end
		end
		local cf = CFrame.lookAt(pos, pos + inward)
		makeSlot(slotFolder(sr, dept, "Bay_" .. def.id), def.id .. "_slot" .. i, cf, surface, dept, sd.sub, sd.b, nil)
	end
end

local function buildSpotlightCore(sf, sr)
	local cx, cz = CENTER.X, CENTER.Z + 10
	local fold = Instance.new("Folder"); fold.Name = "SpotlightCore"; fold.Parent = sf
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local base = P(fold, "DaisBase", Vector3.new(1.7, 62, 62), CFrame.new(cx, FY + 0.85, cz) * upright, GOLD, SMOOTH)
	base.Shape = Enum.PartType.Cylinder
	local top = P(fold, "DaisTop", Vector3.new(0.5, 60, 60), CFrame.new(cx, FY + 1.95, cz) * upright, CREAM, SMOOTH)
	top.Shape = Enum.PartType.Cylinder
	local rim = P(fold, "DaisRim", Vector3.new(0.25, 61.5, 61.5), CFrame.new(cx, FY + 2.05, cz) * upright, GOLD, NEON)
	rim.Shape = Enum.PartType.Cylinder; rim.CanCollide = false
	local daisTopY = FY + 2.2
	for _, d in ipairs({ Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }) do
		local pos = Vector3.new(cx + d.X * 36, FY + 1.1, cz + d.Z * 36)
		local w = Instance.new("WedgePart")
		w.Size = Vector3.new(12, 2.2, 12); w.Anchored = true; w.CanCollide = true
		w.Material = SMOOTH; w.Color = CREAM; w.CastShadow = false
		w.CFrame = CFrame.lookAt(pos, pos + d * 10) -- high side toward dais
		w.Parent = fold
	end
	for i, pd in ipairs(PEDESTALS) do
		local ang = (i - 1) * math.pi * 2 / #PEDESTALS
		local px = cx + math.sin(ang) * 20
		local pz = cz + math.cos(ang) * 20
		P(fold, "Pedestal" .. i, Vector3.new(3.5, 2.6, 3.5), CFrame.new(px, daisTopY + 1.3, pz), Color3.fromRGB(255, 253, 248), SMOOTH)
		local trim = P(fold, "PedTrim" .. i, Vector3.new(3.7, 0.18, 3.7), CFrame.new(px, daisTopY + 2.6, pz), GOLD, NEON)
		trim.CanCollide = false
		local topY = daisTopY + 2.6
		local pos = Vector3.new(px, topY + 0.1, pz)
		local outward = Vector3.new(math.sin(ang), 0, math.cos(ang))
		makeSlot(slotFolder(sr, pd.dept, "SpotlightCore"), "Spotlight_slot" .. i, CFrame.lookAt(pos, pos + outward), "Floor", pd.dept, pd.sub, "RarePop", topY)
	end
	local beacon = P(fold, "Beacon", Vector3.new(0.4, 6, 6), CFrame.new(cx, CEIL_Y - 1.2, cz) * upright, GOLD, NEON)
	beacon.Shape = Enum.PartType.Cylinder; beacon.CanCollide = false
	addLight(beacon, 0.7, 30, Color3.fromRGB(255, 232, 180))
	addSign(fold, Vector3.new(cx, FY + 13, cz), Vector3.new(0, 0, -1), "SPOTLIGHT FINDS", true)
end

local function buildDividers(sf)
	local fold = Instance.new("Folder"); fold.Name = "AisleDividers"; fold.Parent = sf
	local cx, cz = CENTER.X, CENTER.Z
	local defs = {
		{ x = 0, z = -70, sx = 80, sz = 2.5 },
		{ x = 0, z = 90, sx = 80, sz = 2.5 },
		{ x = -100, z = 10, sx = 2.5, sz = 80 },
		{ x = 100, z = 10, sx = 2.5, sz = 80 },
	}
	for i, d in ipairs(defs) do
		P(fold, "Divider" .. i, Vector3.new(d.sx, 7, d.sz), CFrame.new(cx + d.x, FY + 3.5, cz + d.z), CREAM, SMOOTH)
		local strip = P(fold, "DividerTrim" .. i, Vector3.new(d.sx, 0.3, d.sz), CFrame.new(cx + d.x, FY + 7.15, cz + d.z), ACCENT, NEON)
		strip.CanCollide = false
	end
end

local function buildRugPlatforms(sf, sr)
	for pi, rp in ipairs(RUG_PLATFORMS) do
		local cx, cz = CENTER.X + rp.x, CENTER.Z + rp.z
		local fold = Instance.new("Folder"); fold.Name = "RugPlatform" .. pi; fold.Parent = sf
		local plat = P(fold, "Platform", Vector3.new(30, PLAT, 46), CFrame.new(cx, FY + PLAT * 0.5, cz), Color3.fromRGB(214, 204, 188), FABRIC)
		plat.CanCollide = false
		for i, sd in ipairs(rp.slots) do
			local pos = Vector3.new(cx, FY + PLAT, cz + (i - 2) * 15)
			makeSlot(slotFolder(sr, sd.dept, "RugPlatform" .. pi), "Rug" .. pi .. "_slot" .. i, CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)), "Floor", sd.dept, "Rug", i == 1 and "Accent" or "Flexible", nil)
		end
	end
end

local function buildCeilingSlots(sr)
	for i, cs in ipairs(CEILING_SLOTS) do
		local pos = Vector3.new(CENTER.X + cs.x, CEIL_Y - 1.5, CENTER.Z + cs.z)
		local cf = CFrame.new(pos) * CFrame.Angles(math.pi, 0, 0)
		makeSlot(slotFolder(sr, cs.dept, "CeilingAisle"), "Ceiling_slot" .. i, cf, "Ceiling", cs.dept, cs.sub, "RarePop", nil)
	end
end

function SB.EnsureAll()
	local ex = workspace:FindFirstChild("TheShowroom")
	if ex then
		local sl = ex:FindFirstChild("StoreSlots")
		if sl and ex:GetAttribute("Version") == VERSION then return sl end
		ex:Destroy()
	end
	local sf = Instance.new("Folder"); sf.Name = "TheShowroom"; sf:SetAttribute("Version", VERSION); sf.Parent = workspace
	local sr = Instance.new("Folder"); sr.Name = "StoreSlots"; sr.Parent = sf
	buildShell(sf)
	for _, def in ipairs(BAYS) do buildBay(sf, sr, def) end
	buildSpotlightCore(sf, sr)
	buildRugPlatforms(sf, sr)
	buildDividers(sf)
	buildCeilingSlots(sr)
	local n = 0
	for _, d in ipairs(sr:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	print(("[ShowroomBootstrap] v8 department bays + spotlight core | Z=%d | %d slots | %d bays"):format(CENTER.Z, n, #BAYS))
	return sr
end
SB.EnsureStoreSlots = SB.EnsureAll

function SB.GetShopEntryPad()
	local sr = workspace:FindFirstChild("TheShowroom"); if not sr then return nil end
	local pad = sr:FindFirstChild("ShopEntryPad"); return pad and pad.CFrame or nil
end

return SB
