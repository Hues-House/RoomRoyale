--!strict

local Course = {}

export type Pickup = {
	itemId: string,
	name: string,
	space: number,
	weight: number,
	rarity: string?,
	color: Color3,
	part: Part,
	prompt: ProximityPrompt,
	label: BillboardGui,
	available: boolean,
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cf
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function label(parent: BasePart, text: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 64)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 100
	gui.AlwaysOnTop = false
	gui.Parent = parent
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundColor3 = Color3.fromRGB(33, 45, 53)
	caption.BackgroundTransparency = 0.15
	caption.TextColor3 = Color3.fromRGB(255, 250, 238)
	caption.TextSize = 18
	caption.Font = Enum.Font.GothamBold
	caption.Text = text
	caption.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = caption
	return gui
end

function Course.build()
	local existing = workspace:FindFirstChild("CartLab")
	if existing then existing:Destroy() end
	local world = Instance.new("Folder")
	world.Name = "CartLab"
	world:SetAttribute("CheckoutTarget", Vector3.new(-75, 15, 55))
	world.Parent = workspace
	part(world, "Floor", Vector3.new(320, 1, 720), CFrame.new(0, -0.5, -150), Color3.fromRGB(123, 151, 143))
	local crashWall = part(world, "CrashWall", Vector3.new(28, 12, 3), CFrame.new(-110, 6, -30), Color3.fromRGB(190, 119, 103))
	label(crashWall, "CRASH TEST\nHit hard. Keep your items.")
	part(world, "CrashPillar", Vector3.new(8, 14, 8), CFrame.new(116, 7, -30), Color3.fromRGB(190, 119, 103))

	local road = Color3.fromRGB(195, 175, 142)
	part(world, "Uphill", Vector3.new(36, 1, 64), CFrame.new(0, 8.5, -125) * CFrame.Angles(math.asin(18 / 64), 0, 0), road)
	part(world, "HighDeck", Vector3.new(36, 1, 46), CFrame.new(0, 17.5, -178), road)
	part(world, "Downhill", Vector3.new(36, 1, 52), CFrame.new(0, 8.5, -225) * CFrame.Angles(-math.asin(18 / 52), 0, 0), road)
	part(world, "TransferJump", Vector3.new(36, 1, 44), CFrame.new(0, 3.5, -274) * CFrame.Angles(math.asin(8 / 44), 0, 0), Color3.fromRGB(224, 186, 211))
	part(world, "BankLanding", Vector3.new(44, 1, 90), CFrame.new(0, 5, -351) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(180, 207, 232))
	part(world, "BankRunout", Vector3.new(58, 1, 70), CFrame.new(0, 2, -430) * CFrame.Angles(-math.asin(5 / 70), 0, 0), road)
	local routeSign = part(world, "RouteSign", Vector3.new(1, 1, 1), CFrame.new(-23, 3, -88), road)
	routeSign.Transparency = 1
	routeSign.CanCollide = false
	routeSign.CanQuery = false
	label(routeSign, "CENTER ROUTE\nClimb → downhill → jump → bank")
	part(world, "BankApproach", Vector3.new(32, 1, 60), CFrame.new(75, 2.5, -8) * CFrame.Angles(math.asin(6 / 60), 0, 0), Color3.fromRGB(180, 207, 232))
	part(world, "Bank", Vector3.new(32, 1, 100), CFrame.new(75, 5.5, -87) * CFrame.Angles(0, 0, math.rad(17)), Color3.fromRGB(180, 207, 232))
	part(world, "JumpRamp", Vector3.new(24, 1, 32), CFrame.new(-75, 3.5, -93) * CFrame.Angles(math.asin(8 / 32), 0, 0), Color3.fromRGB(224, 186, 211))
	part(world, "Landing", Vector3.new(32, 1, 68), CFrame.new(-75, 3.5, -169), Color3.fromRGB(224, 186, 211))
	local jumpSign = part(world, "JumpSign", Vector3.new(1, 1, 1), CFrame.new(-94, 3, -72), road)
	jumpSign.Transparency = 1
	jumpSign.CanCollide = false
	jumpSign.CanQuery = false
	label(jumpSign, "LEFT ROUTE\nPractice the jump on its own")

	for index, position in ipairs({Vector3.new(-75, 0, 55), Vector3.new(75, 0, -420)}) do
		local center = CFrame.new(position)
		local zone = part(world, "Checkout" .. index, Vector3.new(26, 12, 26), center * CFrame.new(0, 6, 0), Color3.fromRGB(103, 205, 178))
		zone.Transparency = 0.9
		zone.CanCollide = false
		zone.CanTouch = false
		zone.CanQuery = false
		zone:SetAttribute("CheckoutZone", true)
		label(zone, "TUBE CHECKOUT\nDrive through to unload")
		for _, offset in ipairs({Vector3.new(-13, 15, 0), Vector3.new(13, 15, 0)}) do
			part(world, "TubeSide", Vector3.new(1, 3, 26), center * CFrame.new(offset), Color3.fromRGB(95, 163, 160)).CanCollide = false
		end
		for _, offset in ipairs({Vector3.new(0, 15, -13), Vector3.new(0, 15, 13)}) do
			part(world, "TubeEdge", Vector3.new(26, 3, 1), center * CFrame.new(offset), Color3.fromRGB(95, 163, 160)).CanCollide = false
		end
	end

	local definitions = {
		{ "Sofa", "Cloud sofa", 40, 52, Color3.fromRGB(190, 166, 216), Vector3.new(-27, 2, 42), Vector3.new(7, 3, 3) },
		{ "Plant", "Potted plant", 18, 10, Color3.fromRGB(105, 169, 119), Vector3.new(0, 2, 20), Vector3.new(2, 4, 2) },
		{ "Lamp", "Mushroom lamp", 8, 3, Color3.fromRGB(241, 194, 112), Vector3.new(28, 2, 42), Vector3.new(2, 2, 2) },
		{ "Chair", "Lounge chair", 22, 21, Color3.fromRGB(115, 168, 203), Vector3.new(-32, 2, -15), Vector3.new(3, 3, 3) },
		{ "Rug", "Rolled rug", 12, 17, Color3.fromRGB(205, 130, 135), Vector3.new(28, 2, -20), Vector3.new(1.5, 1.5, 4) },
		{ "Books", "Book stack", 8, 6, Color3.fromRGB(138, 168, 161), Vector3.new(-27, 2, -62), Vector3.new(2, 1.5, 2) },
		{ "Table", "Dining table", 35, 46, Color3.fromRGB(183, 139, 97), Vector3.new(26, 2, -65), Vector3.new(5, 2, 4) },
	}
	local pickups: {Pickup} = {}
	for _, definition in ipairs(definitions) do
		local item = part(world, definition[1] :: string, definition[7] :: Vector3, CFrame.new(definition[6] :: Vector3), definition[5] :: Color3)
		item.CanCollide = false
		item.CanTouch = false
		item.CanQuery = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab"
		prompt.ObjectText = string.format("%s · %d space", definition[2] :: string, definition[3] :: number)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = item
		table.insert(pickups, {
			itemId = definition[1] :: string, name = definition[2] :: string,
			space = definition[3] :: number, weight = definition[4] :: number,
			rarity = if definition[1] == "Lamp" then "Rare" else "Common",
			color = definition[5] :: Color3, part = item, prompt = prompt,
			label = label(item, prompt.ObjectText), available = true,
		})
	end
	local checkoutZones: {BasePart} = {}
	for _, child in ipairs(world:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("CheckoutZone") then table.insert(checkoutZones, child) end
	end
	return { world = world, spawn = CFrame.new(0, 2.5, 88), pickups = pickups, checkoutZones = checkoutZones }
end

function Course.buildStyleRoom(index: number): CFrame
	local name = "LabStyleRoom" .. index
	local existing = workspace:FindFirstChild(name)
	if existing then existing:Destroy() end
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = workspace
	local cf = CFrame.new(400 + index * 65, 0, 80)
	part(model, "Floor", Vector3.new(48, 1, 40), cf * CFrame.new(0, -0.5, 0), Color3.fromRGB(220, 204, 181))
	part(model, "BackWall", Vector3.new(48, 16, 1), cf * CFrame.new(0, 8, -20), Color3.fromRGB(238, 231, 217))
	part(model, "LeftWall", Vector3.new(1, 16, 40), cf * CFrame.new(-24, 8, 0), Color3.fromRGB(202, 216, 210))
	part(model, "RightWall", Vector3.new(1, 16, 40), cf * CFrame.new(24, 8, 0), Color3.fromRGB(202, 216, 210))
	local ceiling = part(model, "CeilingDelivery", Vector3.new(46, 0.2, 38), cf * CFrame.new(0, 16, 0), Color3.fromRGB(249, 228, 176))
	ceiling.Transparency = 0.8
	ceiling.CanCollide = false
	label(model.BackWall, "STYLE DELIVERY TEST\nYour banked collection")
	return cf
end

return Course
