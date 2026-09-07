--!strict

local Showcase = {}

function Showcase.Build(parent: Instance, catalog: Folder, origin: CFrame): Folder
	assert(not parent:FindFirstChild("RoomRoyaleFurnitureShowcase"), "Showcase already exists; retain it before rebuilding")
	local root = Instance.new("Folder")
	root.Name = "RoomRoyaleFurnitureShowcase"
	root:SetAttribute("AuthoringOnly", true)
	root.Parent = parent
	local function room(name: string, cf: CFrame, accent: Color3)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = name, root
		local function part(label: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material)
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame = label, size, cf * CFrame.new(pos)
			p.Color, p.Material, p.Anchored = color, material, true
			p.Parent = folder
			return p
		end
		for i = 1, 12 do
			part("Floorboard_" .. i, Vector3.new(1.975, .3, 20), Vector3.new(-13 + i * 2, -.15, 0), Color3.fromRGB(187 + i % 3 * 3, 156 + i % 3 * 3, 117 + i % 3 * 3), Enum.Material.Wood)
		end
		part("BackWall", Vector3.new(24, 11.5, .25), Vector3.new(0, 5.75, -10), Color3.fromRGB(233, 227, 208), Enum.Material.SmoothPlastic)
		part("LeftWall", Vector3.new(.25, 11.5, 20), Vector3.new(-12, 5.75, 0), accent, Enum.Material.SmoothPlastic)
		part("BackSkirting", Vector3.new(24, .3, .12), Vector3.new(0, .15, -9.8), Color3.fromRGB(241, 235, 218), Enum.Material.Wood)
		part("LeftSkirting", Vector3.new(.12, .3, 20), Vector3.new(-11.8, .15, 0), Color3.fromRGB(241, 235, 218), Enum.Material.Wood)
		local fill = part("RoomFill", Vector3.new(.1, .1, .1), Vector3.new(0, 8, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		fill.Transparency, fill.CanCollide, fill.CanQuery = 1, false, false
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(255, 238, 209), 1.2, 28, false
		light.Parent = fill
		local index = 0
		local function place(id: string, x: number, y: number, z: number, degrees: number?)
			local source = catalog:FindFirstChild("rr_" .. id .. "_v1")
			assert(source and source:IsA("Model"), "Missing showcase recipe " .. id)
			local model = source:Clone()
			index += 1
			model.Name = id .. "_" .. index
			model:PivotTo(cf * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(degrees or 0), 0))
			model.Parent = folder
			return model
		end
		return place
	end
	local living = room("ClayAndSageLivingRoom", origin, Color3.fromRGB(179, 193, 164))
	living("border_rug_sage", -2, 0, -1)
	living("track_sofa_clay", -3, 0, -5.8)
	living("track_armchair_sage", 4.3, 0, -1.6, -65)
	living("pill_coffee_oak", -2, .12, -1)
	living("books_sage", -2.9, 1.82, -1)
	living("bud_vase_clay", -1, 1.82, -1.1)
	living("round_side_clay", -8.8, 0, -5.6)
	living("drum_table_lamp", -8.8, 2.1, -5.6)
	living("sideboard_clay", 5.5, 0, -8.6)
	living("vase_cream", 4, 3.1, -8.6)
	living("books_clay", 6.4, 3.1, -8.6)
	living("wide_sunset_print", -3, 5.1, -9.64)
	living("colorblock_print", 5.5, 5.1, -9.64)
	living("tall_plant", -10, 0, -1)
	living("drum_floor_lamp", 1.9, 0, -6.7)
	living("low_shelf_oak", -9.2, 0, 5.5, 90)
	living("desk_plant", -9.2, 3, 4.5)
	living("tray_oak", -9.2, 3, 6.5, 90)

	local bedroom = room("LakeAndOakBedroom", origin * CFrame.new(30, 0, 0), Color3.fromRGB(172, 188, 198))
	bedroom("stripe_rug_rose", -2, 0, -1.5, 90)
	bedroom("double_bed_sage", -2, .12, -1.5)
	bedroom("nightstand_cream", -6.6, 0, -4.7)
	bedroom("mushroom_lamp_clay", -6.6, 2.2, -4.7)
	bedroom("nightstand_cream", 2.6, 0, -4.7)
	bedroom("books_sage", 2.6, 2.2, -4.7)
	bedroom("candle_rose", 2.6, 2.85, -4.7)
	bedroom("dresser_lake", 7.7, 0, -7.8)
	bedroom("vase_lake", 8.7, 3.8, -7.8)
	bedroom("oak_mirror", 7.7, 4.6, -9.64)
	bedroom("sunset_print", -2, 5, -9.64)
	bedroom("bench_cream", -2, 0, 5.9)
	bedroom("leaf_plant", -10.1, 0, -6.4)
	bedroom("wardrobe_sage", -10, 0, .5, 90)
	bedroom("round_rug_ochre", 7, 0, 4.5)
	bedroom("panel_chair_clay", 7.2, .12, 4.5, -30)
	return root
end

return Showcase
