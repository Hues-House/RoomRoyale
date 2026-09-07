--!strict

local GeometryService = game:GetService("GeometryService")

return function(dimensions: Vector3, radius: number): BasePart
	local r = math.min(radius, math.min(dimensions.X, dimensions.Y, dimensions.Z) / 2 - 0.01)
	assert(r > 0, "Rounded box radius must be positive")
	local pieces: { BasePart } = {}
	local function make(shape: Enum.PartType, size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Shape, p.Size, p.CFrame = shape, size, cf
		p.Anchored = true
		table.insert(pieces, p)
	end
	local d = r * 2
	make(Enum.PartType.Block, Vector3.new(dimensions.X, dimensions.Y - d, dimensions.Z - d), CFrame.identity)
	make(Enum.PartType.Block, Vector3.new(dimensions.X - d, dimensions.Y, dimensions.Z - d), CFrame.identity)
	make(Enum.PartType.Block, Vector3.new(dimensions.X - d, dimensions.Y - d, dimensions.Z), CFrame.identity)
	local half = dimensions / 2 - Vector3.new(r, r, r)
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			make(Enum.PartType.Cylinder, Vector3.new(dimensions.X - d, d, d), CFrame.new(0, a * half.Y, b * half.Z))
			make(Enum.PartType.Cylinder, Vector3.new(dimensions.Y - d, d, d), CFrame.new(a * half.X, 0, b * half.Z) * CFrame.Angles(0, 0, math.pi / 2))
			make(Enum.PartType.Cylinder, Vector3.new(dimensions.Z - d, d, d), CFrame.new(a * half.X, b * half.Y, 0) * CFrame.Angles(0, math.pi / 2, 0))
			for _, c in ipairs({ -1, 1 }) do
				make(Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(a * half.X, b * half.Y, c * half.Z))
			end
		end
	end
	local first = table.remove(pieces, 1)
	assert(first)
	local ok, result = pcall(function()
		return GeometryService:UnionAsync(first, pieces, { SplitApart = false, CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	first:Destroy()
	for _, p in ipairs(pieces) do p:Destroy() end
	assert(ok, tostring(result))
	assert(#result == 1, "Rounded box must produce one solid")
	return result[1]
end
