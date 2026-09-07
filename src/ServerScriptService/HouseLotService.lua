local Layout=require(game.ReplicatedStorage.NeighborhoodLayout)
local Builder=require(script.Parent.HouseTemplateBuilder)
local Door=require(script.Parent.HouseDoorController)
local Lots={}
local assigned={}
local houses={}
local district

function Lots.Ensure()
	if district and district.Parent then return district end
	district=workspace:FindFirstChild("HousingDistrict") or Instance.new("Folder")
	district.Name="HousingDistrict" district.Parent=workspace
	-- The saved Edit gallery is rebuilt in the server so door connections are live.
	for _,m in district:GetChildren() do m:Destroy() end
	for index in Layout.Lots do
		local house=Builder.Build(index,nil)
		house.Parent=district Door.Attach(house) houses[index]=house
	end
	return district
end

function Lots.Reserve(userId)
	Lots.Ensure()
	for index,id in assigned do if id==userId then return index end end
	for index in Layout.Lots do
		if not assigned[index] then assigned[index]=userId return index end
	end
	return nil
end

function Lots.Occupy(index,userId,house)
	if assigned[index]~=userId then return false end
	local old=houses[index]
	house.Parent=district
	houses[index]=house
	Door.Attach(house)
	if old then old:Destroy() end
	return true
end

function Lots.Release(userId)
	for index,id in assigned do
		if id==userId then
			-- Build before removing the current house so the street is never left blank.
			local vacancy=Builder.Build(index,nil)
			vacancy.Parent=district Door.Attach(vacancy)
			local old=houses[index]
			houses[index]=vacancy assigned[index]=nil
			if old then old:Destroy() end
			return index
		end
	end
	return nil
end

function Lots.Snapshot()
	local result={}
	for index in Layout.Lots do
		result[index]={index=index,userId=assigned[index],house=houses[index],vacant=houses[index] and houses[index]:GetAttribute("IsVacant")}
	end
	return result
end
return Lots
