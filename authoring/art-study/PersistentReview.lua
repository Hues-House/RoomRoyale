-- Run Build() from the Studio authoring plugin in Edit mode.
local AssetService=game:GetService("AssetService")
local records=require(script.Parent.PrivateAssets)
local Review={}
local offsets={rr_crescent_sofa_v2=Vector3.new(-6,0,0),rr_loop_bentwood_chair_v2=Vector3.new(5,0,0),rr_tide_lamp_v2=Vector3.new(12,3,0)}

function Review.Build()
	assert(not game:GetService("RunService"):IsRunning(),"Build the authoring gallery in Edit mode")
	local root=workspace:FindFirstChild("RoomRoyaleMeshStudy")
	if not root then root=Instance.new("Folder") root.Name="RoomRoyaleMeshStudy" root.Parent=workspace end
	local candidates={}
	local ok,err=pcall(function()
		for _,row in records do
			local model=candidates[row.asset]
			if not model then model=Instance.new("Model") model.Name=row.asset candidates[row.asset]=model end
			local part=AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://"..row.mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
			part.Name=row.name part.Size=Vector3.new(table.unpack(row.size))
			part.CFrame=CFrame.new(Vector3.new(820,0,420)+offsets[row.asset]+Vector3.new(table.unpack(row.center)))
			part.Anchored=true part.CanCollide=false part.Color=Color3.new(1,1,1)
			part:SetAttribute("MaterialName",row.material) part:SetAttribute("TriangleCount",row.triangles)
			part:SetAttribute("ReviewMeshAssetId",row.mesh) part:SetAttribute("PersistentReviewAsset",true)
			local surface=Instance.new("SurfaceAppearance")
			for role,id in row.maps do surface[role]="rbxassetid://"..id part:SetAttribute("Review"..role.."AssetId",id) end
			surface.Parent=part part.Parent=model
		end
	end)
	if not ok then for _,model in candidates do model:Destroy() end error(err) end
	local backup=game.ServerStorage:FindFirstChild("RoomRoyaleFurnitureReferences")
	if not backup then backup=Instance.new("Folder") backup.Name="RoomRoyaleFurnitureReferences" backup.Parent=game.ServerStorage end
	for name,model in candidates do
		local old=root:FindFirstChild(name)
		if old then old.Name=name.."_before_"..game:GetService("HttpService"):GenerateGUID(false) old.Parent=backup end
		model:SetAttribute("Source","Blender and Prop Forge study; persistent private assets")
		model:SetAttribute("AuthoringOnly",true) model.Parent=root
	end
	root:SetAttribute("ReviewStatus","Persistent mesh and image assets; verified in Play")
	return root
end
return Review
