--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage:WaitForChild("CartItemPresentation"))
local Acceptance = {}

local function parts(model: Instance)
	local result = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then table.insert(result, descendant) end
	end
	return result
end

local function assertSameVisual(source: Model, target: Model, ratio: number)
	local expected, actual = parts(source), parts(target)
	assert(#expected == #actual, "Furniture part count changed")
	local remaining = table.clone(actual)
	local sourceFrame = source:GetBoundingBox()
	local targetFrame = target:GetBoundingBox()
	for _, before in expected do
		local beforeFrame = sourceFrame:ToObjectSpace(before.CFrame)
		local matched
		for index, candidate in remaining do
			local afterFrame = targetFrame:ToObjectSpace(candidate.CFrame)
			if (beforeFrame.Position * ratio - afterFrame.Position).Magnitude < 0.01
				and (beforeFrame.LookVector - afterFrame.LookVector).Magnitude < 0.01
				and (beforeFrame.UpVector - afterFrame.UpVector).Magnitude < 0.01 and before.Name == candidate.Name and before.ClassName == candidate.ClassName
				and (before.Size * ratio - candidate.Size).Magnitude < 0.01
				and before.Color == candidate.Color and before.Material == candidate.Material
				and before.Transparency == candidate.Transparency
				and (not before:IsA("MeshPart") or (candidate:IsA("MeshPart") and before.MeshId == candidate.MeshId and before.TextureID == candidate.TextureID)) then
				matched = index
				break
			end
		end
		assert(matched, "Furniture part identity, size or appearance changed: " .. before.Name)
		local after = table.remove(remaining, matched)
		assert((before.Size * ratio - after.Size).Magnitude < 0.01, "Furniture scale changed")
		assert(before.Color == after.Color and before.Material == after.Material, "Furniture finish changed")
		assert(before.Transparency == after.Transparency, "Furniture transparency changed")
		if before:IsA("MeshPart") then
			assert(after:IsA("MeshPart") and before.MeshId == after.MeshId and before.TextureID == after.TextureID, "Designer mesh changed")
		end
		assert(after.Anchored and not after.CanCollide and not after.CanTouch and not after.CanQuery, "Cargo gained physics interaction")
	end
	for _, descendant in target:GetDescendants() do
		assert(not descendant:IsA("LuaSourceContainer") and not descendant:IsA("ProximityPrompt")
			and not descendant:IsA("LayerCollector") and not descendant:IsA("Constraint") and not descendant:IsA("JointInstance"), "Template carries gameplay objects")
	end
	return #actual
end

local function boxes(model: Model, frame: CFrame)
	local minimum, maximum = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, part in parts(model) do
		local cf = frame:ToObjectSpace(part.CFrame)
		for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
			local corner = cf:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
			minimum = minimum:Min(corner)
			maximum = maximum:Max(corner)
		end end end
	end
	return {minimum = minimum, maximum = maximum}
end

local function assertSeparated(models, frame: CFrame)
	local measured = {}
	for _, model in models do table.insert(measured, boxes(model, frame)) end
	for a = 1, #measured do for b = a + 1, #measured do
		local first, second = measured[a], measured[b]
		local overlap = first.maximum:Min(second.maximum) - first.minimum:Max(second.minimum)
		assert(overlap.X < 0.02 or overlap.Y < 0.02 or overlap.Z < 0.02, "Furniture bounding boxes overlap")
	end end
	return measured
end

function Acceptance.runTemplates()
	local templates = ReplicatedStorage:WaitForChild("CartItemTemplates")
	local world = workspace:WaitForChild("CartLab")
	local result = {}
	for _, template in templates:GetChildren() do
		if not template:IsA("Model") then continue end
		local source = world:FindFirstChild("Merchandise_" .. template.Name, true)
		assert(source, "Shelf furniture missing: " .. template.Name)
		local model = assert(Presentation.create(template.Name))
		local count = assertSameVisual(source, model, Presentation.cargoScale)
		table.insert(result, {templateId = template.Name, parts = count, scale = Presentation.cargoScale, variantId = template:GetAttribute("VariantId")})
		model:Destroy()
	end
	assert(#result > 0, "No exact shelf templates checked")
	return result
end

function Acceptance.runClient(Cargo, player: Player)
	local templates = ReplicatedStorage:WaitForChild("CartItemTemplates"):GetChildren()
	table.sort(templates, function(a, b)
		local aSize, bSize = a:GetAttribute("SourceSize"), b:GetAttribute("SourceSize")
		return aSize.X * aSize.Z > bSize.X * bSize.Z
	end)
	local items, used = {}, 0
	for _, template in templates do
		local cost = template:GetAttribute("Space")
		if not cost or cost + used > 100 then continue end
		table.insert(items, {id = "Acceptance_" .. #items, templateId = template.Name, variantId = template:GetAttribute("VariantId"),
			itemId = template:GetAttribute("ItemId"), space = cost, rarity = template:GetAttribute("Rarity"), order = #items + 1})
		used += cost
	end
	assert(#items >= 2, "Need at least two fitting stock pieces")
	local fixture = Instance.new("Folder")
	fixture.Name = "CargoAcceptanceCarts"
	fixture.Parent = workspace
	local cart = Instance.new("Model")
	cart.Name = "AcceptanceCart"
	cart:SetAttribute("OwnerUserId", player.UserId)
	cart:SetAttribute("CargoDeckY", -0.7)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.CFrame = CFrame.new(12000, 50, 12000)
	body.Anchored = true
	body.CanCollide = false
	body.Parent = cart
	cart.PrimaryPart = body
	local records = Instance.new("Folder")
	records.Name = "Cargo"
	records.Parent = cart
	for _, item in items do
		local record = Instance.new("Folder")
		record.Name = item.id
		record:SetAttribute("ItemId", item.itemId)
		record:SetAttribute("TemplateId", item.templateId)
		record:SetAttribute("VariantId", item.variantId)
		record:SetAttribute("Order", item.order)
		record.Parent = records
	end
	cart.Parent = fixture
	local renderer = Cargo.new(fixture, player)
	renderer.folder.Name = "CargoAcceptanceVisuals"
	local ok, result = pcall(function()
		task.wait()
		renderer:step(2, body.Position)
		local entry = assert(renderer.carts[cart])
		local models, original = {}, {}
		for _, item in items do
			local model = assert(entry.pieces[item.id]).model
			assertSameVisual(assert(ReplicatedStorage.CartItemTemplates:FindFirstChild(item.templateId)), model, 0.86)
			assert(model:GetAttribute("VariantId") == item.variantId)
			table.insert(models, model)
			original[item.id] = model
		end
		local measured = assertSeparated(models, body.CFrame)
		local highest, lowest = -math.huge, math.huge
		for _, box in measured do highest = math.max(highest, box.maximum.Y); lowest = math.min(lowest, box.minimum.Y) end
		assert(lowest >= -0.71, "Cargo sunk through flatbed")
		assert(highest - lowest > 3, "Full load is still miniature")
		-- Exercise both network orderings with the real renderer and replicated record signals.
		local first = table.remove(items, 1)
		renderer:deposit({cart = cart, items = {first}, position = body.Position + Vector3.new(0, 16, 0)})
		records:FindFirstChild(first.id):Destroy()
		task.wait()
		assert(renderer.flights[1].model == original[first.id], "Suction replaced carried model")
		records:ClearAllChildren()
		task.wait()
		renderer:deposit({cart = cart, items = items, position = body.Position + Vector3.new(0, 16, 0)})
		table.insert(items, 1, first)
		assert(#renderer.flights == #items, "Deposit lost or duplicated furniture")
		for _, flight in renderer.flights do assert(flight.model == original[flight.model.Name], "Deposit lost object identity") end
		renderer:step(0.4, body.Position)
		for _, flight in renderer.flights do
			local template = ReplicatedStorage.CartItemTemplates:FindFirstChild(flight.model:GetAttribute("TemplateId"))
			assertSameVisual(assert(template), flight.model, 0.86)
		end
		renderer:step(3, body.Position)
		assert(#renderer.flights == 0, "Suction failed to finish")
		renderer:deliver({ownerUserId = player.UserId, items = items, room = body.CFrame})
		renderer:step(3, body.Position)
		local delivered = renderer.deliveries[player.UserId]
		assert(#delivered == #items, "Room delivery lost furniture")
		for index, model in delivered do
			assertSameVisual(assert(ReplicatedStorage.CartItemTemplates:FindFirstChild(items[index].templateId)), model, 1)
		end
		assertSeparated(delivered, body.CFrame)
		return {items = #items, space = used, stackHeight = highest - lowest, cargoScale = 0.86, deliveryScale = 1,
			exactShelfParts = true, nonOverlapping = true, sameSuctionInstances = true, bothReplicationOrders = true}
	end)
	renderer:destroy()
	fixture:Destroy()
	assert(ok, result)
	return result
end

return Acceptance
