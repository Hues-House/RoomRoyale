--!strict
-- Review-only bridge. Durable geometry is stored in the adjacent Blender/GLB assets.
local AssetService = game:GetService("AssetService")
local Import = {}
local retained = {}
local materials = {}
local origin = Vector3.new(820, 0, 420)
local offsets = {
	rr_crescent_sofa_v2 = Vector3.new(-6, 0, 0),
	rr_loop_bentwood_chair_v2 = Vector3.new(5, 0, 0),
	rr_tide_lamp_v2 = Vector3.new(12, 3, 0),
}

function Import.Root()
	local root = workspace:FindFirstChild("RoomRoyaleMeshStudy")
	if not root then
		root = Instance.new("Folder")
		root.Name = "RoomRoyaleMeshStudy"
		root:SetAttribute("AuthoringOnly", true)
		root.Parent = workspace
	end
	return root
end

local function solidImage(color: Color3)
	local img = AssetService:CreateEditableImage({Size = Vector2.new(1, 1)})
	assert(img, "Editable image budget exhausted")
	img:DrawRectangle(Vector2.zero, Vector2.one, color, 0, Enum.ImageCombineType.Overwrite)
	table.insert(retained, img)
	return Content.fromObject(img)
end

function Import.Material(name: string, rgb, roughness: number, metallic: number)
	if materials[name] then return end
	materials[name] = AssetService:CreateSurfaceAppearanceAsync({
		ColorMap = solidImage(Color3.fromRGB(rgb[1], rgb[2], rgb[3])),
		RoughnessMap = solidImage(Color3.new(roughness, roughness, roughness)),
		MetalnessMap = solidImage(Color3.new(metallic, metallic, metallic)),
	})
end

function Import.Mesh(data)
	local root = Import.Root()
	local model = root:FindFirstChild(data.asset)
	if not model then
		model = Instance.new("Model")
		model.Name = data.asset
		model:SetAttribute("Source", "Blender mesh study")
		model.Parent = root
	end
	assert(not model:FindFirstChild(data.name), "Mesh already imported")
	local mesh = AssetService:CreateEditableMesh()
	assert(mesh, "Editable mesh budget exhausted")
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, v in ipairs(data.vertices) do
		local p = Vector3.new(v[1], v[2], v[3])
		low, high = low:Min(p), high:Max(p)
	end
	local center = (low + high) / 2
	local vertices, normals, uvs = {}, {}, {}
	for i, p in ipairs(data.vertices) do
		vertices[i] = mesh:AddVertex(Vector3.new(p[1], p[2], p[3]) - center)
		local n = data.normals[i]
		normals[i] = mesh:AddNormal(Vector3.new(n[1], n[2], n[3]))
		local uv = data.uvs[i]
		uvs[i] = mesh:AddUV(Vector2.new(uv[1], uv[2]))
	end
	for _, indices in ipairs(data.triangles) do
		local a, b, c = indices[1]+1, indices[2]+1, indices[3]+1
		local face = mesh:AddTriangle(vertices[a], vertices[b], vertices[c])
		mesh:SetFaceNormals(face, {normals[a], normals[b], normals[c]})
		mesh:SetFaceUVs(face, {uvs[a], uvs[b], uvs[c]})
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {CollisionFidelity = Enum.CollisionFidelity.Box})
	part.Name, part.Anchored, part.CanCollide = data.name, true, false
	part.Color = Color3.new(1, 1, 1)
	part.CFrame = CFrame.new(origin + offsets[data.asset] + center)
	Import.Material(data.material, data.rgb, data.roughness, data.metallic)
	materials[data.material]:Clone().Parent = part
	part:SetAttribute("TriangleCount", #data.triangles)
	part:SetAttribute("MaterialName", data.material)
	part.Parent = model
	table.insert(retained, mesh)
	return {name=part.Name,triangles=#data.triangles,size={part.Size.X,part.Size.Y,part.Size.Z}}
end

return Import
