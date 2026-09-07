--!strict

local Generator = {}

Generator.Attributes = {
	TopShape = "Pill",
	BaseStyle = "TwinPedestal",
	TopThickness = 0.22,
	LegWidth = 0.35,
	TopColor = Color3.fromRGB(192, 155, 109),
	BaseColor = Color3.fromRGB(161, 119, 77),
}

type Parameters = {
	Size: Vector3,
	Attributes: typeof(Generator.Attributes),
	Pause: (self: any) -> (),
}

local function inRange(value: number, low: number, high: number): boolean
	return value == value and value >= low and value <= high
end

function Generator.OnGenerate(parameters: Parameters, target: GeneratedFolder)
	local size = parameters.Size
	local a = parameters.Attributes
	assert(inRange(size.X, 1.5, 8) and inRange(size.Y, 1.2, 3.6) and inRange(size.Z, 1.2, 5), "Table dimensions outside authoring range")
	assert(inRange(a.TopThickness, 0.12, 0.5), "TopThickness must be 0.12 to 0.5 studs")
	assert(inRange(a.LegWidth, 0.18, 0.6), "LegWidth must be 0.18 to 0.6 studs")
	assert(a.TopShape == "Rectangle" or a.TopShape == "Pill" or a.TopShape == "Round", "Unknown TopShape")
	assert(a.BaseStyle == "FourLeg" or a.BaseStyle == "Pedestal" or a.BaseStyle == "TwinPedestal", "Unknown BaseStyle")
	assert(a.TopShape ~= "Pill" or size.X > size.Z, "Pill top must be wider than it is deep")
	assert(a.TopShape ~= "Round" or math.abs(size.X - size.Z) < 0.001, "Round top needs equal X/Z dimensions")
	assert(a.BaseStyle ~= "TwinPedestal" or size.X >= size.Z * 1.3, "TwinPedestal needs an elongated top")
	assert(typeof(a.TopColor) == "Color3" and typeof(a.BaseColor) == "Color3", "Table colors must be Color3")

	local floorY = -size.Y / 2
	local topY = size.Y / 2 - a.TopThickness / 2
	local baseHeight = size.Y - a.TopThickness
	local baseY = floorY + baseHeight / 2
	local function part(name: string, dimensions: Vector3, cf: CFrame, color: Color3, channel: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = dimensions
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.Wood
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("AppearanceChannel", channel)
		p.Parent = target
		return p
	end
	local function cylinder(name: string, diameter: number, height: number, x: number, y: number, z: number, color: Color3, channel: string): Part
		local p = part(name, Vector3.new(height, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), color, channel)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	if a.TopShape == "Round" then
		cylinder("Top", size.X, a.TopThickness, 0, topY, 0, a.TopColor, "Top")
	elseif a.TopShape == "Pill" then
		local straight = size.X - size.Z
		part("TopCenter", Vector3.new(straight, a.TopThickness, size.Z), CFrame.new(0, topY, 0), a.TopColor, "Top")
		cylinder("TopEndLeft", size.Z, a.TopThickness, -straight / 2, topY, 0, a.TopColor, "Top")
		cylinder("TopEndRight", size.Z, a.TopThickness, straight / 2, topY, 0, a.TopColor, "Top")
	else
		part("Top", Vector3.new(size.X, a.TopThickness, size.Z), CFrame.new(0, topY, 0), a.TopColor, "Top")
	end

	if a.BaseStyle == "FourLeg" then
		for index, signs in ipairs({ Vector2.new(-1, -1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(1, 1) }) do
			parameters:Pause()
			local x = signs.X * (size.X * 0.28)
			local z = signs.Y * (size.Z * 0.28)
			part("Leg" .. index, Vector3.new(a.LegWidth, baseHeight, a.LegWidth), CFrame.new(x, baseY, z), a.BaseColor, "Base")
		end
	else
		local positions = if a.BaseStyle == "TwinPedestal" then { -size.X * 0.24, size.X * 0.24 } else { 0 }
		local diameter = math.min(size.Z * 0.45, 1.3)
		for index, x in ipairs(positions) do
			parameters:Pause()
			cylinder("Pedestal" .. index, diameter, baseHeight, x, baseY, 0, a.BaseColor, "Base")
			cylinder("Foot" .. index, size.Z * 0.68, 0.12, x, floorY + 0.06, 0, a.BaseColor, "Base")
		end
	end

	local anchor = part("PlacementAnchor", Vector3.new(0.1, 0.1, 0.1), CFrame.new(0, floorY + 0.05, 0), a.BaseColor, "Helper")
	anchor.Transparency = 1
	anchor.CanQuery = false
	local contact = Instance.new("Attachment")
	contact.Name = "FloorContact"
	contact.Position = Vector3.new(0, -0.05, 0)
	contact.Parent = anchor
	local support = Instance.new("Attachment")
	support.Name = "TopSupport"
	support.Position = Vector3.new(0, size.Y - 0.05, 0)
	support:SetAttribute("Shape", a.TopShape)
	support:SetAttribute("Width", size.X)
	support:SetAttribute("Depth", size.Z)
	support.Parent = anchor
end

return Generator
