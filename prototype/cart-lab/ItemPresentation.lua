--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Presentation = {}
Presentation.cargoScale = 0.86
Presentation.gap = 0.08

local function visualInstance(instance: Instance): boolean
	return instance:IsA("Model") or instance:IsA("Folder") or instance:IsA("BasePart")
		or instance:IsA("DataModelMesh") or instance:IsA("Decal") or instance:IsA("Texture")
		or instance:IsA("SurfaceAppearance") or instance:IsA("Bone")
end

function Presentation.bounds(model: Model): (Vector3, Vector3)
	local frame, size = model:GetBoundingBox()
	return model:GetPivot():PointToObjectSpace(frame.Position) - size * 0.5, size
end

function Presentation.capture(source: Instance, templateId: string, origin: CFrame): Model
	local templates = ReplicatedStorage:FindFirstChild("CartItemTemplates")
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "CartItemTemplates"
		templates.Parent = ReplicatedStorage
	end
	local previous = templates:FindFirstChild(templateId)
	if previous then previous:Destroy() end
	local clone = source:Clone()
	assert(clone, "Merchandise must be archivable")
	local model: Model
	if clone:IsA("Model") then
		model = clone
	else
		model = Instance.new("Model")
		clone.Parent = model
	end
	model.Name = templateId
	model.PrimaryPart = nil
	local partCount = 0
	for _, descendant in model:GetDescendants() do
		if not visualInstance(descendant) then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			partCount += 1
			descendant.CFrame = origin:ToObjectSpace(descendant.CFrame)
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	model.WorldPivot = CFrame.identity
	local _, size = Presentation.bounds(model)
	model:SetAttribute("TemplateId", templateId)
	model:SetAttribute("SourceSize", size)
	model:SetAttribute("PartCount", partCount)
	model:SetAttribute("Ready", true)
	model.Parent = templates
	return model
end

function Presentation.create(templateId: string, scale: number?): Model?
	local templates = ReplicatedStorage:FindFirstChild("CartItemTemplates")
	local template = templates and templates:FindFirstChild(templateId)
	if not (template and template:IsA("Model") and template:GetAttribute("Ready")) then return nil end
	local partCount = 0
	for _, descendant in template:GetDescendants() do if descendant:IsA("BasePart") then partCount += 1 end end
	if partCount ~= template:GetAttribute("PartCount") then return nil end
	local model = template:Clone()
	-- WorldPivot is not replicated. Template part positions are already in stock-local space.
	model.WorldPivot = CFrame.identity
	model:ScaleTo(model:GetScale() * (scale or Presentation.cargoScale))
	model:SetAttribute("PresentationScale", scale or Presentation.cargoScale)
	return model
end

function Presentation.stack(pieces, deckY: number, footprint: Vector2?)
	local ordered = table.clone(pieces)
	table.sort(ordered, function(a, b)
		local areaA, areaB = a.size.X * a.size.Z, b.size.X * b.size.Z
		if math.abs(areaA - areaB) > 0.01 then return areaA > areaB end
		return a.order < b.order
	end)
	local width, depth = if footprint then footprint.X else 5.2, if footprint then footprint.Y else 5.6
	for _, piece in ordered do width = math.max(width, piece.size.X); depth = math.max(depth, piece.size.Z) end
	local left = -width * 0.5
	local front = (if footprint then -3 else math.min(-0.4, 2.8 - depth * 0.5)) - depth * 0.5
	local placed = {}
	local height = deckY
	for _, piece in ordered do
		local size = piece.size
		local xs = {left + (width - size.X) * 0.5, left, left + width - size.X}
		local zs = {front + (depth - size.Z) * 0.5, front, front + depth - size.Z}
		for _, box in placed do
			table.insert(xs, box.x + box.size.X + Presentation.gap)
			table.insert(xs, box.x - size.X - Presentation.gap)
			table.insert(zs, box.z + box.size.Z + Presentation.gap)
			table.insert(zs, box.z - size.Z - Presentation.gap)
		end
		local best, bestScore = nil, math.huge
		for _, x in xs do
			if x < left - 0.001 or x + size.X > left + width + 0.001 then continue end
			for _, z in zs do
				if z < front - 0.001 or z + size.Z > front + depth + 0.001 then continue end
				local y = deckY
				for _, box in placed do
					if x < box.x + box.size.X + 0.02 and x + size.X + 0.02 > box.x
						and z < box.z + box.size.Z + 0.02 and z + size.Z + 0.02 > box.z then
						y = math.max(y, box.y + box.size.Y + Presentation.gap)
					end
				end
				local score = (y - deckY) * 100 + math.abs(x + size.X * 0.5) + math.abs(z + size.Z * 0.5 + 0.4) * 0.2
				if score < bestScore then bestScore, best = score, {x = x, y = y, z = z, size = size} end
			end
		end
		assert(best)
		piece.offset = CFrame.new(Vector3.new(best.x, best.y, best.z) - piece.minimum)
		piece.stackBase = best.y
		height = math.max(height, best.y + size.Y)
		table.insert(placed, best)
	end
	return height - deckY
end

return Presentation
