--!strict

local roundedBox = require(script.Parent.RoundedBox)
local BuildParts = {}

function BuildParts.new(parameters, target: GeneratedFolder)
	local floor = -parameters.Size.Y / 2
	local build = {}
	function build.finish(part: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, channel: string): BasePart
		part.Name, part.Size, part.CFrame = name, size, CFrame.new(0, floor, 0) * cf
		part.Anchored, part.CanCollide, part.CanTouch = true, false, false
		part.Color, part.Material = color, material
		part:SetAttribute("AppearanceChannel", channel)
		if part:IsA("PartOperation") then part.UsePartColor = true end
		part.Parent = target
		return part
	end
	function build.block(name, size, position, color, material, channel)
		return build.finish(Instance.new("Part"), name, size, CFrame.new(position), color, material, channel)
	end
	function build.round(name, size, position, color, material, channel, radius)
		parameters:Pause()
		return build.finish(roundedBox(size, radius), name, size, CFrame.new(position), color, material, channel)
	end
	function build.ball(name, size, position, color, material, channel)
		local part = Instance.new("Part")
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, part
		return build.finish(part, name, size, CFrame.new(position), color, material, channel)
	end
	function build.cylinder(name, diameter, height, position, color, material, channel)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		return build.finish(part, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, channel)
	end
	function build.anchor(supportHeight: number?)
		local anchor = build.block("PlacementAnchor", Vector3.new(.1, .1, .1), Vector3.new(0, .05, 0), Color3.new(), Enum.Material.SmoothPlastic, "Anchor")
		anchor.Transparency, anchor.CanQuery = 1, false
		local contact = Instance.new("Attachment")
		contact.Name, contact.Position, contact.Parent = "FloorContact", Vector3.new(0, -.05, 0), anchor
		if supportHeight then
			local support = Instance.new("Attachment")
			support.Name, support.Position = "TopSupport", Vector3.new(0, supportHeight - .05, 0)
			support:SetAttribute("Width", parameters.Size.X)
			support:SetAttribute("Depth", parameters.Size.Z)
			support.Parent = anchor
		end
	end
	return build
end

return BuildParts
