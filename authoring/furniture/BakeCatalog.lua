--!strict

local BakeCatalog = {}

function BakeCatalog.Build(gallery: Folder, parent: Instance): Folder
	assert(parent:FindFirstChild("RoomRoyaleFurnitureCandidates") == nil, "Candidate catalog already exists")
	local output = Instance.new("Folder")
	output.Name = "RoomRoyaleFurnitureCandidates"
	output:SetAttribute("AuthoringOnly", true)
	for _, source in ipairs(gallery:GetChildren()) do
		if not source:IsA("ProceduralModel") or not source:GetAttribute("CatalogId") then
			continue
		end
		assert(source:WaitForGenerationAsync(), source.GenerationError)
		local generated = source:FindFirstChildWhichIsA("GeneratedFolder")
		assert(generated, "Missing generated furniture")
		local model = Instance.new("Model")
		model.Name = source.Name
		model:SetAttribute("ItemId", source:GetAttribute("CatalogId"))
		model:SetAttribute("GeneratorVersion", 1)
		model:SetAttribute("RecipeVersion", source:GetAttribute("RecipeVersion"))
		model:SetAttribute("Family", source:GetAttribute("Family"))
		model:SetAttribute("DisplayName", source:GetAttribute("DisplayName"))
		model:SetAttribute("Category", source:GetAttribute("Category"))
		model:SetAttribute("AuthoringStatus", "Candidate")
		model:SetAttribute("PlacementSurface", source:GetAttribute("PlacementSurface"))
		for _, child in ipairs(generated:GetChildren()) do
			local clone = child:Clone()
			clone.Parent = model
			if clone:IsA("BasePart") then
				clone.CanCollide = clone.Name ~= "PlacementAnchor" and source:GetAttribute("PlacementSurface") == "Floor"
			end
		end
		local anchor = model:FindFirstChild("PlacementAnchor")
		assert(anchor and anchor:IsA("BasePart"), "Furniture needs a placement anchor")
		local contact = anchor:FindFirstChild("FloorContact")
		assert(contact and contact:IsA("Attachment"), "Furniture needs a floor contact")
		anchor.PivotOffset = contact.CFrame
		model.PrimaryPart = anchor
		model:PivotTo(CFrame.identity)
		model.Parent = output
	end
	output.Parent = parent
	return output
end

return BakeCatalog
