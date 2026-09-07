-- Install temporarily in ServerScriptService in Test; remove after verification.
assert(game:GetService("RunService"):IsStudio())
assert(game.PlaceId==86511797738570)
assert(game.ServerStorage:GetAttribute("NeighborhoodPreviewProfiles")==true)
local Http=game:GetService("HttpService")
local report=Instance.new("StringValue") report.Name="NeighborhoodAcceptance" report.Parent=game.ServerStorage
local results={}
local function check(name,condition,detail)
	table.insert(results,{name=name,passed=condition,detail=detail})
	report.Value=Http:JSONEncode(results)
	assert(condition,name..": "..tostring(detail))
end
local ok,err=pcall(function()
	local player=game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
	local Housing=require(game.ServerScriptService.HousingService)
	local Lots=require(game.ServerScriptService.HouseLotService)
	local Door=require(game.ServerScriptService.HouseDoorController)
	local Geometry=require(game.ServerScriptService.HousePlacementGeometry)
	local Builder=require(game.ServerScriptService.HouseTemplateBuilder)
	local Layout=require(game.ReplicatedStorage.NeighborhoodLayout)
	local Progression=require(game.ServerScriptService.ProgressionService)
	local house
	for _=1,100 do house=Housing.GetHouseRoom(player) if house then break end task.wait(.2) end
	check("player receives home",house~=nil)
	local vacant=0
	for _,h in workspace.HousingDistrict:GetChildren() do if h:GetAttribute("IsVacant") then vacant+=1 end end
	check("eight populated lots",#workspace.HousingDistrict:GetChildren()==8 and vacant==7,{homes=8,vacant=vacant})
	local profileService=require(game.ServerStorage.ProfileService)
	local mock
	for _,store in profileService._active_profile_stores do
		check("no live profile in acceptance",store._loaded_profiles["p_"..player.UserId]==nil)
		mock=mock or store._mock_loaded_profiles["p_"..player.UserId]
	end
	check("mock profile confirmed",mock~=nil and mock._is_user_mock==true)
	local cf=house:GetPivot()
	local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Include params.FilterDescendantsInstances={house} params.RespectCanCollide=true
	local function doorwayHit() return workspace:Raycast(cf:PointToWorldSpace(Vector3.new(0,5.2,20)),cf:VectorToWorldSpace(Vector3.new(0,0,-8)),params) end
	player.Character:PivotTo(cf*CFrame.new(0,4.6,22))
	check("closed door blocks passage",doorwayHit()~=nil)
	check("open request accepted",Door.SetOpen(house,true,player))
	task.wait(.6)
	check("open door clears passage",house:GetAttribute("DoorOpen")==true and doorwayHit()==nil)
	player.Character:PivotTo(cf*CFrame.new(0,4.6,16))
	check("door will not close through avatar",Door.SetOpen(house,false,player)==false)
	player.Character:PivotTo(cf*CFrame.new(0,4.6,22))
	check("close request accepted",Door.SetOpen(house,false,player)) task.wait(.6)
	check("closed state restored",house:GetAttribute("DoorOpen")==false and doorwayHit()~=nil)
	Door.SetOpen(house,true,player) task.wait(.6)
	local humanoid=player.Character:FindFirstChildOfClass("Humanoid")
	humanoid:MoveTo(cf:PointToWorldSpace(Vector3.new(0,4.6,10)))
	local reached=humanoid.MoveToFinished:Wait()
	local localPosition=cf:PointToObjectSpace(player.Character.HumanoidRootPart.Position)
	check("avatar walks through doorway",reached and localPosition.Z<13,tostring(localPosition))
	local owned={}
	for i=1,7 do local id=-92000-i local index=Lots.Reserve(id) check("unique vacancy reservation "..i,index~=nil and not owned[index]) owned[index]=id end
	check("full neighborhood rejects ninth home",Lots.Reserve(-93000)==nil)
	local index,id=next(owned)
	local replacement=Builder.Build(index,{UserId=id,DisplayName="Acceptance resident"})
	check("replace vacancy",Lots.Occupy(index,id,replacement) and #workspace.HousingDistrict:GetChildren()==8)
	check("restore vacancy on release",Lots.Release(id)==index and Lots.Snapshot()[index].vacant==true and #workspace.HousingDistrict:GetChildren()==8)
	owned[index]=nil
	for _,other in owned do Lots.Release(other) end
	local prop=Instance.new("Model")
	local part=Instance.new("Part") part.Size=Vector3.new(2,2,2) part.CFrame=cf*CFrame.new(4,2.2,-4) part.Parent=prop
	check("interior placement fits",Geometry.Fits(house,prop))
	check("grounded furniture has support",Geometry.HasSupport(house,prop,"Floor"))
	prop:PivotTo(cf*CFrame.new(4,5,-4))
	check("floating furniture rejected",not Geometry.HasSupport(house,prop,"Floor"))
	prop:PivotTo(cf*CFrame.new(16.4,5,-4))
	check("wall decor has support",Geometry.HasSupport(house,prop,"Wall"))
	prop:PivotTo(cf*CFrame.new(4,11,-4))
	check("ceiling fixture has support",Geometry.HasSupport(house,prop,"Ceiling"))
	local unloaded=Builder.Build(8)
	prop:PivotTo(unloaded:GetPivot()*CFrame.new(4,2.2,-4))
	check("saved items supported before home becomes visible",Geometry.HasSupport(unloaded,prop,"Floor")) unloaded:Destroy()
	prop:PivotTo(cf*CFrame.new(0,2.2,14)) check("door clearance rejects furniture",not Geometry.Fits(house,prop)) prop:Destroy()
	local old=Layout.LegacyHouseFrame(Vector3.new(-90,0,130))
	local legacyPosition=old:PointToWorldSpace(Vector3.new(4,1,-4))
	local legacy=Geometry.Read({cx=legacyPosition.X,cy=legacyPosition.Y,cz=legacyPosition.Z,rx=0,ry=90,rz=0},cf)
	check("legacy floor height migrates",(cf:ToObjectSpace(legacy).Position-Vector3.new(4,2.2,-4)).Magnitude<.001)
	local itemId=game.ReplicatedStorage.ItemAssets:GetChildren()[1].Name
	local prior=mock.Data.ownedItems[itemId] mock.Data.ownedItems[itemId]=true
	local localCF=CFrame.new(4,2.2,-4)*CFrame.Angles(0,.4,0)
	local saved,message=Progression.SaveHousePlacement(player,"neighborhood-acceptance",itemId,localCF,"house-local-v2")
	check("house local save accepted",saved,message)
	local entry=Progression.GetHousePlacements(player)["neighborhood-acceptance"]
	local moved=Geometry.Read(entry,Layout.Lots[8].CFrame)
	check("save follows house to opposite lot",entry.space=="house-local-v2" and (Layout.Lots[8].CFrame:ToObjectSpace(moved).Position-localCF.Position).Magnitude<.001)
	Progression.RemoveHousePlacement(player,"neighborhood-acceptance") mock.Data.ownedItems[itemId]=prior
	-- Exercise the real remote with a recovered record and the actual catalog geometry.
	local database=require(game.ReplicatedStorage.ItemDatabase)
	local source
	for _,candidate in game.ReplicatedStorage.ItemAssets:GetChildren() do
		local data=database.Get(candidate.Name)
		if candidate:IsA("Model") and data and data.PlacementSurface=="Floor" then
			local _,size=candidate:GetBoundingBox()
			if size.X<5 and size.Z<5 and size.Y<5 then source=candidate break end
		end
	end
	check("recovery fixture found",source~=nil)
	itemId=source.Name prior=mock.Data.ownedItems[itemId] mock.Data.ownedItems[itemId]=true
	local probe=source:Clone()
	local bounds,size=probe:GetBoundingBox()
	local pivot=probe:GetPivot()
	local offset=bounds.Position-pivot.Position
	local valid=cf*CFrame.new(5,Layout.House.FloorTop+size.Y/2-offset.Y,-5)
	probe:Destroy()
	check("recovered record fixture saved",Progression.SaveHousePlacement(player,"recovery-fixture",itemId,CFrame.new(0,50,0),"house-local-v2"))
	player:SetAttribute("AcceptanceItem",itemId)
	player:SetAttribute("AcceptancePlacement",valid)
	player:SetAttribute("AcceptanceRemoteReady",true)
	local restored
	for _=1,200 do
		for _,model in house.PlacedItems:GetChildren() do if model:GetAttribute("HousePlacementId")=="recovery-fixture" then restored=model break end end
		if restored then break end task.wait(.1)
	end
	check("real placement remote recovers retained record",restored~=nil)
	check("recovery uses original record id",Progression.GetHousePlacements(player)["client-recovery-fixture"]==nil)
	if restored then restored:Destroy() end
	Progression.RemoveHousePlacement(player,"recovery-fixture") mock.Data.ownedItems[itemId]=prior
	player:SetAttribute("AcceptanceRemoteReady",nil)
	check("all fixtures restored",#workspace.HousingDistrict:GetChildren()==8)
	workspace:SetAttribute("NeighborhoodAcceptancePassed",true)
end)
if not ok then table.insert(results,{name="failure",passed=false,detail=tostring(err)}) report.Value=Http:JSONEncode(results) warn(err) end
