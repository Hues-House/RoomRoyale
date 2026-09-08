local G = require(script.Parent.Geometry)
local C = G.colors
local Park = {}

local TRACK_WIDTH = 24
local SURFACE_HEIGHT = 0.12
local PALETTE = {
	deck = Color3.fromRGB(224, 221, 207),
	track = Color3.fromRGB(119, 159, 143),
	trick = Color3.fromRGB(221, 167, 110),
	grass = Color3.fromRGB(160, 183, 147),
}

local function triangle(parent, a, b, c, color, route)
	-- Overlap neighboring faces so support rays cannot hit a vertical seam or the floor below.
	local center = (a + b + c) / 3
	a, b, c = center + (a - center) * 1.008, center + (b - center) * 1.008, center + (c - center) * 1.008
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
		c, a = a, c
	elseif ac:Dot(ac) > bc:Dot(bc) then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up, back = bc:Cross(right).Unit, bc.Unit
	local normal = if right.Y > 0 then right else -right
	local height = math.abs(ab:Dot(up))
	for _, shape in {
		{center = (a + b) / 2, right = right, back = back, length = math.abs(ab:Dot(back))},
		{center = (a + c) / 2, right = -right, back = -back, length = math.abs(ac:Dot(back))},
	} do
		if shape.length > 0.001 then
			local part = Instance.new("WedgePart")
			part.Name = route .. "Surface"
			part.Size = Vector3.new(0.2, height, shape.length)
			part.CFrame = CFrame.fromMatrix(shape.center - normal * 0.1, shape.right, up, shape.back)
			part.Color, part.Material = color, Enum.Material.Concrete
			part.Anchored, part.CanTouch, part.CastShadow = true, false, false
			part:SetAttribute("ParkRoute", route)
			part.Parent = parent
		end
	end
end

local function stripe(parent, a, b)
	local middle = (a + b) / 2 + Vector3.new(0, 0.035, 0)
	G.part(parent, "TrackEdge", Vector3.new(0.35, 0.035, (b - a).Magnitude + 0.1),
		CFrame.lookAt(middle, middle + b - a), C.cream, false)
end

local function surfacePoint(a, b, c, d, along, across)
	if across <= along then
		return a * (1 - along) + b * (along - across) + c * across
	end
	return a * (1 - across) + c * along + d * (across - along)
end

local function ribbon(parent, name, nodes, color, supportSamples)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	for i = 1, #nodes - 1 do
		local first, second = nodes[i], nodes[i + 1]
		local a, b, c, d = first.left, second.left, second.right, first.right
		triangle(model, a, b, c, color, name)
		triangle(model, a, c, d, color, name)
		stripe(model, a, b)
		stripe(model, d, c)
		for _, along in {0, 0.5, 1} do
			for _, across in {0.12, 0.5, 0.88} do
				table.insert(supportSamples, {
					position = surfacePoint(a, b, c, d, along, across),
					route = name,
					join = along ~= 0.5,
				})
			end
		end
	end
	return model
end

function Park.build(world, origin)
	local frame = origin or CFrame.new(310, 0, 0)
	local existing = world:FindFirstChild("PracticePark")
	if existing then existing:Destroy() end
	local root = Instance.new("Model")
	root.Name, root.Parent = "PracticePark", world
	root:SetAttribute("EnvironmentId", "neighborhood-practice-park-v1")
	local function position(x, y, z)
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local function pose(x, y, z, yaw)
		return frame * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	local deck = G.part(root, "ParkLandingFloor", Vector3.new(270, 4, 250),
		pose(5, -2, 5), PALETTE.deck, true)
	deck.Material = Enum.Material.Concrete
	deck:SetAttribute("ParkLandingSupport", true)
	local connector = G.part(root, "MarketParkConnection", Vector3.new(75, 4, 44),
		pose(-127.5, -2.02, 90), PALETTE.deck, true)
	connector:SetAttribute("ParkLandingSupport", true)
	G.part(root, "EntryPath", Vector3.new(84, 0.03, 24), pose(-118, 0.025, 90), C.mint, false)
	G.part(root, "SouthApron", Vector3.new(96, 0.025, 29), pose(-37, 0.025, 86), C.mint, false)

	local samples, loop = {}, {}
	local halfWidth = TRACK_WIDTH / 2
	local function loopNode(x, z, direction, height, bank)
		local outside = direction:Cross(Vector3.yAxis)
		local lift = math.sin(bank) * halfWidth
		local center = Vector3.new(x, height + lift, z)
		local side = outside * math.cos(bank) * halfWidth + Vector3.yAxis * lift
		table.insert(loop, {
			position = frame:PointToWorldSpace(center),
			left = frame:PointToWorldSpace(center - side),
			right = frame:PointToWorldSpace(center + side),
			forward = frame:VectorToWorldSpace(direction),
		})
	end
	local straightSteps, bendSteps = 28, 44
	for i = 0, straightSteps - 1 do
		local t = i / straightSteps
		loopNode(-50 + 108 * t, 59, Vector3.xAxis,
			SURFACE_HEIGHT + 2.3 * math.sin(t * math.pi * 3) ^ 2, 0)
	end
	for i = 0, bendSteps - 1 do
		local t = i / bendSteps
		local angle = math.pi / 2 - t * math.pi
		loopNode(58 + 54 * math.cos(angle), 5 + 54 * math.sin(angle),
			Vector3.new(math.sin(angle), 0, -math.cos(angle)), SURFACE_HEIGHT,
			math.rad(14) * math.sin(t * math.pi) ^ 2)
	end
	for i = 0, straightSteps - 1 do
		local t = i / straightSteps
		loopNode(58 - 108 * t, -49, -Vector3.xAxis,
			SURFACE_HEIGHT + 3.2 * math.sin(t * math.pi * 2) ^ 2, 0)
	end
	for i = 0, bendSteps - 1 do
		local t = i / bendSteps
		local angle = -math.pi / 2 - t * math.pi
		loopNode(-50 + 54 * math.cos(angle), 5 + 54 * math.sin(angle),
			Vector3.new(math.sin(angle), 0, -math.cos(angle)), SURFACE_HEIGHT,
			math.rad(14) * math.sin(t * math.pi) ^ 2)
	end
	table.insert(loop, loop[1])
	ribbon(root, "PumpLoop", loop, PALETTE.track, samples)
	for i = 1, #loop - 1, 12 do
		local node = loop[i]
		local yaw = math.atan2(-node.forward.X, -node.forward.Z)
		G.arrow(root, node.position + Vector3.new(0, 0.045, 0), yaw, C.cream, 1.2)
	end

	local function lineNodes(points, width)
		local nodes = {}
		for i, point in points do
			local direction = if i == #points then point - points[i - 1] else points[i + 1] - point
			local outside = Vector3.new(direction.X, 0, direction.Z).Unit:Cross(Vector3.yAxis)
			table.insert(nodes, {
				position = frame:PointToWorldSpace(point),
				left = frame:PointToWorldSpace(point - outside * width / 2),
				right = frame:PointToWorldSpace(point + outside * width / 2),
			})
		end
		return nodes
	end
	local launch = lineNodes({Vector3.new(-77, SURFACE_HEIGHT, 5), Vector3.new(-60, SURFACE_HEIGHT, 5),
		Vector3.new(-32, 4, 5)}, 24)
	local landing = lineNodes({Vector3.new(-6, 1, 5), Vector3.new(14, 1, 5),
		Vector3.new(46, SURFACE_HEIGHT, 5), Vector3.new(70, SURFACE_HEIGHT, 5)}, 32)
	ribbon(root, "TrickLaunch", launch, PALETTE.trick, samples)
	ribbon(root, "TrickLanding", landing, PALETTE.trick, samples)
	for _, x in {-71, -44, 12, 49} do
		local y = if x < -60 then SURFACE_HEIGHT else if x < -32 then SURFACE_HEIGHT + (x + 60) / 28 * (4 - SURFACE_HEIGHT) else if x <= 14 then 1 else SURFACE_HEIGHT
		G.arrow(root, position(x, y + 0.05, 5), -math.pi / 2 + math.atan2(-frame.LookVector.X, -frame.LookVector.Z), C.cream, 1.5)
	end

	G.sign(root, "PUMP PARK\nRide the rollers", pose(-89, 9, 110), 33, 8, C.cream)
	for _, x in {-106, -72} do
		G.part(root, "ParkSignPost", Vector3.new(0.8, 11, 0.8), pose(x, 5.5, 110), C.wood, false)
	end
	G.sign(root, "TRICK LINE\nJump. Dive. Keep rolling.", pose(-70, 7, -18), 30, 6, C.yellow)
	G.sign(root, "MARKET\nCHECKOUT", pose(-121, 7, 70, math.pi / 2), 18, 6, C.mint)
	G.arrow(root, position(-135, 0.065, 90), math.pi / 2 + math.atan2(-frame.LookVector.X, -frame.LookVector.Z), C.cream, 1.8)
	for _, x in {-22, 47, 110} do
		G.part(root, "ParkBench", Vector3.new(15, 1, 3.5), pose(x, 2, 114), C.wood, false)
		G.part(root, "ParkBenchBack", Vector3.new(15, 2, 0.7), pose(x, 3.1, 115.4), C.wood, false)
	end
	for _, x in {-42, 80, 125} do
		G.part(root, "ParkPlanter", Vector3.new(8, 1.2, 8), pose(x, 0.6, -106), C.cream, false)
		G.part(root, "ParkTreeTrunk", Vector3.new(0.9, 8, 0.9), pose(x, 4.5, -106), C.wood, false)
		G.part(root, "ParkTreeCanopy", Vector3.new(11, 10, 11), pose(x, 12, -106), PALETTE.grass, false, Enum.PartType.Ball)
	end
	local spawn = pose(-105, 2.5, 90, -math.pi / 2)
	root:SetAttribute("PracticeSpawn", spawn)
	root:SetAttribute("MarketReturn", pose(-166, 2.5, 90, math.pi / 2))
	return {
		root = root,
		spawn = spawn,
		marketReturn = pose(-166, 2.5, 90, math.pi / 2),
		origin = frame,
		bounds = {min = position(-165, -4.02, -120), max = position(140, 24, 130)},
		loop = loop,
		routes = {launch = launch, landing = landing},
		supportSamples = samples,
		trackWidth = TRACK_WIDTH,
		insideBendRadius = 42,
		rollerHeights = {2.3, 3.2},
	}
end

return Park
