--!strict

local recipes = require(script.Parent.CatalogRecipes)
local finishes = require(script.Parent.Finishes)
local Gallery = {}

local function label(parent: Instance, name: string, position: CFrame, text: string, width: number)
	local sign = Instance.new("Part")
	sign.Name, sign.Size, sign.CFrame = name, Vector3.new(width, .1, 1.2), position
	sign.Anchored, sign.CanCollide = true, false
	sign.Color, sign.Parent = Color3.fromRGB(236, 230, 214), parent
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Top, Enum.SurfaceGuiSizingMode.PixelsPerStud, 60
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size, title.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	title.Text, title.TextScaled, title.Font = text, true, Enum.Font.GothamMedium
	title.TextColor3, title.Parent = Color3.fromRGB(55, 65, 57), gui
end

function Gallery.Build(parent: Instance, origin: CFrame, name: string?): Folder
	local folderName = name or "RoomRoyaleFurniturePilot"
	assert(parent:FindFirstChild(folderName) == nil, "Gallery already exists; retain a backup before rebuilding")
	local root = Instance.new("Folder")
	root.Name = folderName
	root:SetAttribute("AuthoringOnly", true)
	root:SetAttribute("GeneratorVersion", 1)
	root:SetAttribute("RecipeCount", #recipes)
	root.Parent = parent
	local stage = Instance.new("Part")
	stage.Name, stage.Size = "ReviewStage", Vector3.new(106, .5, 151)
	stage.CFrame = origin * CFrame.new(38, -.25, 62)
	stage.Anchored, stage.Color = true, Color3.fromRGB(214, 214, 202)
	stage.Material, stage.Parent = Enum.Material.SmoothPlastic, root
	local row, column, previousFamily = -1, 0, ""
	for _, recipe in ipairs(recipes) do
		if recipe.family ~= previousFamily then
			row, column, previousFamily = row + 1, 0, recipe.family
			label(root, recipe.family .. "Heading", origin * CFrame.new(-9, .08, row * 14), recipe.category, 8)
		end
		local model = Instance.new("ProceduralModel")
		model.Name, model.Size = recipe.id, recipe.size
		for key, value in pairs(recipe.attributes) do model:SetAttribute(key, value) end
		model:SetAttribute("CatalogId", recipe.id)
		model:SetAttribute("DisplayName", recipe.name)
		model:SetAttribute("Family", recipe.family)
		model:SetAttribute("Category", recipe.category)
		model:SetAttribute("PlacementSurface", recipe.surface)
		model:SetAttribute("RecipeVersion", 1)
		model:SetAttribute("AuthoringStatus", "Candidate")
		model:PivotTo(origin * CFrame.new(column * 12, recipe.size.Y / 2, row * 14))
		model.Generator = script.Parent:FindFirstChild(recipe.family .. "Generator") :: ModuleScript
		model.Parent = root
		label(root, recipe.id .. "Label", origin * CFrame.new(column * 12, .08, row * 14 + 5.2), recipe.name, 8)
		column += 1
	end
	local names = {}
	for finishName in pairs(finishes) do table.insert(names, finishName) end
	table.sort(names)
	for index, finishName in ipairs(names) do
		local finish = finishes[finishName]
		local swatch = Instance.new("Part")
		swatch.Name, swatch.Size = finishName .. "Swatch", Vector3.new(3.2, .2, 3.2)
		swatch.CFrame = origin * CFrame.new((index - 1) * 6 - 2, .1, -9)
		swatch.Anchored, swatch.Color, swatch.Material = true, finish.color, finish.material
		swatch.Parent = root
		label(root, finishName .. "Label", origin * CFrame.new((index - 1) * 6 - 2, .08, -6.5), finishName, 4.8)
	end
	return root
end

return Gallery
