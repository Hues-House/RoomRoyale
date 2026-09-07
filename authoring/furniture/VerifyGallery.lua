--!strict

local recipes = require(script.Parent.CatalogRecipes)
local Verify = {}

local function bounds(model: Model): (Vector3, Vector3, number)
	local low, high, count = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge), 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "PlacementAnchor" then
			count += 1
			local cf = model:GetPivot():ToObjectSpace(part.CFrame)
			for _, x in ipairs({ -1, 1 }) do
				for _, y in ipairs({ -1, 1 }) do
					for _, z in ipairs({ -1, 1 }) do
						local p = cf * (part.Size * Vector3.new(x, y, z) / 2)
						low, high = low:Min(p), high:Max(p)
					end
				end
			end
		end
	end
	return low, high, count
end

local function signature(model: Model): string
	local rows = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf = model:GetPivot():ToObjectSpace(part.CFrame)
			table.insert(rows, string.format("%s %.3f %.3f %.3f %.3f %.3f %.3f %s", part.Name, part.Size.X, part.Size.Y, part.Size.Z, cf.X, cf.Y, cf.Z, tostring(part.Color)))
		end
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end

local function check(model: ProceduralModel)
	assert(model:WaitForGenerationAsync(), model.Name .. ": " .. model.GenerationError)
	local anchor = model:FindFirstChild("PlacementAnchor", true)
	assert(anchor and anchor:IsA("BasePart"), "Missing placement anchor")
	local contact = anchor:FindFirstChild("FloorContact")
	assert(contact and contact:IsA("Attachment"), "Missing floor contact")
	local low, high, count = bounds(model)
	local contactY = model:GetPivot():PointToObjectSpace(contact.WorldPosition).Y
	assert(count > 0 and count <= 40, model.Name .. ": unexpected part count " .. count)
	assert(math.abs(low.Y - contactY) < .02, model.Name .. ": floor contact differs from geometry")
	assert(math.abs(high.Y - low.Y - model.Size.Y) < .02, model.Name .. ": height differs from recipe " .. tostring(high - low))
	assert(high.X - low.X <= model.Size.X + .06 and high.Z - low.Z <= model.Size.Z + .06, model.Name .. ": geometry exceeds footprint " .. tostring(high - low))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			assert(part.Anchored and not part.CanCollide, "Authoring geometry must be anchored and non-colliding")
			assert(part:GetAttribute("AppearanceChannel") or part.Name == "PlacementAnchor", "Missing appearance channel")
		end
	end
	return { id = model.Name, family = model:GetAttribute("Family"), visualParts = count, measuredSize = { (high - low).X, (high - low).Y, (high - low).Z }, floorContactError = math.abs(low.Y - contactY) }
end

function Verify.Run(gallery: Folder)
	local results, seen = {}, {}
	for _, recipe in ipairs(recipes) do
		assert(not seen[recipe.id], "Duplicate catalog ID")
		seen[recipe.id] = true
		local model = gallery:FindFirstChild(recipe.id)
		assert(model and model:IsA("ProceduralModel"), "Missing recipe " .. recipe.id)
		assert(model.Size == recipe.size, recipe.id .. ": size differs from saved recipe")
		for key, value in pairs(recipe.attributes) do
			assert(model:GetAttribute(key) == value, recipe.id .. ": attribute differs from saved recipe: " .. key)
		end
		table.insert(results, check(model))
	end
	local tableModel = gallery:FindFirstChild("rr_pill_coffee_oak_v1") :: ProceduralModel
	local sofa = gallery:FindFirstChild("rr_track_loveseat_cream_v1") :: ProceduralModel
	local originalTable, originalSofa = signature(tableModel), signature(sofa)
	local originalColor, originalSize, sofaSize = tableModel:GetAttribute("TopColor"), tableModel.Size, sofa.Size
	local ok, message = pcall(function()
		tableModel:SetAttribute("TopColor", Color3.fromRGB(130, 158, 120))
		tableModel.Size = Vector3.new(5.8, originalSize.Y, originalSize.Z)
		check(tableModel)
		local center = tableModel:FindFirstChild("TopCenter", true) :: BasePart
		assert(math.abs(center.Size.X - 3.2) < .001 and center.Color == Color3.fromRGB(130, 158, 120), "Table color/width did not rebuild")
		sofa.Size = Vector3.new(8.2, sofaSize.Y, sofaSize.Z)
		sofa:SetAttribute("SeatCount", 3)
		check(sofa)
		assert(sofa:FindFirstChild("SeatCushion_3", true), "Third seat did not generate")
		sofa:SetAttribute("ArmStyle", "Roll")
		check(sofa)
		assert(sofa:FindFirstChild("ArmRoll_1", true), "Roll arms did not generate")
	end)
	tableModel:SetAttribute("TopColor", originalColor)
	tableModel.Size = originalSize
	sofa.Size = sofaSize
	sofa:SetAttribute("SeatCount", 2)
	sofa:SetAttribute("ArmStyle", "Track")
	check(tableModel)
	check(sofa)
	assert(ok, tostring(message))
	assert(signature(tableModel) == originalTable and signature(sofa) == originalSofa, "Restored recipes did not reproduce geometry")
	return { items = results, recipeCount = #results, tableColorAndWidth = true, sofaSeatCountAndArms = true, deterministicRestore = true }
end

function Verify.Baked(folder: Folder)
	local count = 0
	for _, recipe in ipairs(recipes) do
		local model = folder:FindFirstChild(recipe.id)
		assert(model and model:IsA("Model") and not model:IsA("ProceduralModel"), "Missing baked model")
		assert(model.PrimaryPart and model.PrimaryPart.Name == "PlacementAnchor", "Missing baked pivot")
		assert(model:GetPivot().Position.Magnitude < .001, "Baked pivot must be origin")
		local low, high = bounds(model)
		assert(math.abs(low.Y) < .02, "Baked model must rest on origin plane")
		assert(math.abs(high.Y - recipe.size.Y) < .02, "Baked height changed")
		for _, child in ipairs(model:GetDescendants()) do
			assert(not child:IsA("LuaSourceContainer") and not child:IsA("ProceduralModel"), "Baked model contains authoring code")
		end
		count += 1
	end
	return count
end

return Verify
