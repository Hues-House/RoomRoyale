--!strict

local roundedBox = require(script.Parent.RoundedBox)
local Generator = {}

Generator.Attributes = {
	SeatCount = 2,
	ArmStyle = "Track",
	UpholsteryColor = Color3.fromRGB(183, 186, 155),
	FrameColor = Color3.fromRGB(135, 101, 72),
	CushionRadius = 0.18,
}

type Parameters = {
	Size: Vector3,
	Attributes: typeof(Generator.Attributes),
	Pause: (self: any) -> (),
}

function Generator.OnGenerate(parameters: Parameters, target: GeneratedFolder)
	local size, a = parameters.Size, parameters.Attributes
	assert(size.X >= 3.4 and size.X <= 9 and size.Y >= 3.2 and size.Y <= 4 and size.Z >= 3.1 and size.Z <= 4.2, "Sofa dimensions outside authoring range")
	assert(a.SeatCount % 1 == 0 and a.SeatCount >= 1 and a.SeatCount <= 3, "SeatCount must be 1, 2 or 3")
	assert(a.ArmStyle == "Track" or a.ArmStyle == "Roll", "Unknown ArmStyle")
	assert(a.CushionRadius >= 0.08 and a.CushionRadius <= 0.28, "CushionRadius outside supported range")
	assert(typeof(a.UpholsteryColor) == "Color3" and typeof(a.FrameColor) == "Color3", "Invalid sofa color")
	local armWidth = if a.ArmStyle == "Roll" then 0.65 else 0.48
	local inner = size.X - armWidth * 2
	local seatWidth = inner / a.SeatCount
	assert(seatWidth >= 1.9 and seatWidth <= 3.1, "Seat count does not fit this width")
	local floorY = -size.Y / 2
	local function finish(p: BasePart, name: string, cf: CFrame, channel: string)
		p.Name, p.CFrame = name, cf
		p.Anchored, p.CanCollide, p.CanTouch = true, false, false
		p.Material = if channel == "Frame" then Enum.Material.Wood else Enum.Material.Fabric
		p.Color = if channel == "Frame" then a.FrameColor else a.UpholsteryColor
		p.CastShadow = true
		if p:IsA("PartOperation") then p.UsePartColor = true end
		p:SetAttribute("AppearanceChannel", channel)
		p.Parent = target
	end
	local function box(name: string, s: Vector3, pos: Vector3, radius: number, channel: string)
		parameters:Pause()
		local p = roundedBox(s, radius)
		finish(p, name, CFrame.new(pos + Vector3.new(0, floorY, 0)), channel)
	end
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			box("Foot_" .. x .. "_" .. z, Vector3.new(0.32, 0.3, 0.32), Vector3.new(x * (size.X / 2 - 0.48), 0.15, z * (size.Z / 2 - 0.45)), 0.04, "Frame")
		end
	end
	box("Base", Vector3.new(size.X - 0.14, 0.75, size.Z - 0.12), Vector3.new(0, 0.675, 0), 0.12, "Upholstery")
	box("BackFrame", Vector3.new(inner, size.Y - 1.15, 0.5), Vector3.new(0, 0.3 + (size.Y - 1.15) / 2, -size.Z / 2 + 0.25), 0.12, "Upholstery")
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (size.X - armWidth) / 2
		box("Arm_" .. side, Vector3.new(armWidth, 2.1, size.Z - 0.06), Vector3.new(x, 1.35, 0), 0.15, "Upholstery")
		if a.ArmStyle == "Roll" then
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Z - 0.06, armWidth, armWidth)
			finish(p, "ArmRoll_" .. side, CFrame.new(x, floorY + 2.38, 0) * CFrame.Angles(0, math.pi / 2, 0), "Upholstery")
		end
	end
	for index = 1, a.SeatCount do
		local x = -inner / 2 + seatWidth * (index - 0.5)
		box("SeatCushion_" .. index, Vector3.new(seatWidth - 0.06, 0.75, size.Z - 0.7), Vector3.new(x, 1.425, 0.28), a.CushionRadius, "Upholstery")
		local backHeight = size.Y - 1.55
		box("BackCushion_" .. index, Vector3.new(seatWidth - 0.06, backHeight, 0.62), Vector3.new(x, 1.55 + backHeight / 2, -size.Z / 2 + 0.66), a.CushionRadius, "Upholstery")
	end
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size = "PlacementAnchor", Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(0, floorY + 0.05, 0)
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Parent = target
	local contact = Instance.new("Attachment")
	contact.Name, contact.Position = "FloorContact", Vector3.new(0, -0.05, 0)
	contact.Parent = anchor
end

return Generator
