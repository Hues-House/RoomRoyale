-- User approved private Roblox uploads on September 7 after reviewing the three candidates.
local AssetService=game:GetService("AssetService")
local Upload={}
local ledger=game.ServerStorage:FindFirstChild("RoomRoyaleFurnitureUploads")
if not ledger then ledger=Instance.new("Folder") ledger.Name="RoomRoyaleFurnitureUploads" ledger.Parent=game.ServerStorage end

local function asset(object,kind,key)
	local recorded=ledger:FindFirstChild(key)
	if recorded then return tonumber(recorded.Value) end
	local result,id=AssetService:CreateAssetAsync(object,kind,{
		Name=string.sub("RR Test - "..key,1,50),
		Description="User-approved furniture art study. Source: RoomRoyale authoring/art-study. Private Test-place authoring asset.",
	})
	assert(result==Enum.CreateAssetResult.Success,tostring(result)..": "..tostring(id))
	local value=Instance.new("StringValue") value.Name=key value.Value=tostring(id) value.Parent=ledger
	return id
end

function Upload.Part(part)
	local meshId=part:GetAttribute("ReviewMeshAssetId")
	if not meshId then meshId=asset(part.MeshContent.Object,Enum.AssetType.Mesh,part.Name) part:SetAttribute("ReviewMeshAssetId",meshId) end
	local material=part:GetAttribute("MaterialName")
	local surface=part:FindFirstChildOfClass("SurfaceAppearance")
	local maps={}
	for _,role in {"ColorMap","RoughnessMap","MetalnessMap"} do
		local id=asset(surface[role.."Content"].Object,Enum.AssetType.Image,material.." "..role)
		part:SetAttribute("Review"..role.."AssetId",id)
		maps[role]=id
	end
	return {part=part.Name,mesh=meshId,maps=maps}
end

function Upload.Apply(part)
	local id=assert(part:GetAttribute("ReviewMeshAssetId"))
	local new=AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://"..id),{CollisionFidelity=Enum.CollisionFidelity.Box})
	part:ApplyMesh(new) new:Destroy()
	local surface=Instance.new("SurfaceAppearance")
	for _,role in {"ColorMap","RoughnessMap","MetalnessMap"} do surface[role]="rbxassetid://"..assert(part:GetAttribute("Review"..role.."AssetId")) end
	local old=part:FindFirstChildOfClass("SurfaceAppearance")
	surface.Parent=part if old then old:Destroy() end
	part:SetAttribute("PersistentReviewAsset",true)
	return part.Name
end
return Upload
