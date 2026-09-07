local Layout=require(game.ReplicatedStorage.NeighborhoodLayout)
local Geometry={}

function Geometry.Read(entry,houseFrame)
	local cf=CFrame.new(entry.cx,entry.cy,entry.cz)*CFrame.fromEulerAnglesXYZ(math.rad(entry.rx),math.rad(entry.ry),math.rad(entry.rz))
	if entry.space=="house-local-v2" then return houseFrame*cf end
	-- Old saves contain no lot ID. Infer only the nearest known old lot; never rewrite the record on load.
	local old,distance=Layout.LegacyHouseFrame(cf.Position)
	if distance>55 then return nil end
	return houseFrame*CFrame.new(0,Layout.House.FloorTop,0)*old:ToObjectSpace(cf)
end

function Geometry.Fits(house,item)
	local pivot,size=item:GetBoundingBox()
	local min,max=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
	for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
		local p=house:GetPivot():PointToObjectSpace(pivot:PointToWorldSpace(Vector3.new(x*size.X/2,y*size.Y/2,z*size.Z/2)))
		min,max=min:Min(p),max:Max(p)
	end end end
	local h=Layout.House
	if min.X< -h.Width/2+.45 or max.X>h.Width/2-.45 or min.Z< -h.Depth/2+.45 or max.Z>h.Depth/2-.45 then return false end
	if min.Y<h.FloorTop-.25 or max.Y>h.FloorTop+h.WallHeight then return false end
	-- Reserve the entry and full inward door swing, independently of decor overlap rules.
	if max.X> -2.8 and min.X<3 and max.Z>h.Depth/2-5.3 then return false end
	return true
end

function Geometry.HasSupport(house,item,surface)
	local cf,size=item:GetBoundingBox()
	local frame=house:GetPivot()
	local function hit(direction,length,kind)
		-- Intersect actual support-part bounds before the house is parented to Workspace.
		-- Saved homes must finish loading before replacing the visible vacancy.
		for _,part in house:GetDescendants() do
			if not part:IsA("BasePart") or not part.CanQuery then continue end
			if part:GetAttribute("SurfaceType")~=kind and not (kind=="Floor" and part:IsDescendantOf(house.PlacedItems)) then continue end
			local origin=part.CFrame:PointToObjectSpace(cf.Position)
			local ray=part.CFrame:VectorToObjectSpace(direction)
			local near,far=0,length
			local normal=Vector3.zero
			for _,axis in {Vector3.xAxis,Vector3.yAxis,Vector3.zAxis} do
				local o,d,half=origin:Dot(axis),ray:Dot(axis),part.Size:Dot(axis)/2
				if math.abs(d)<1e-7 then
					if math.abs(o)>half then far=-1 break end
				else
					local a,b=(-half-o)/d,(half-o)/d
					if a>b then a,b=b,a end
					if a>near then near=a normal=part.CFrame:VectorToWorldSpace(axis*(-math.sign(d))) end
					far=math.min(far,b)
				end
			end
			if near<=far and far>=0 and (kind~="Floor" or normal.Y>.8) then return true end
		end
		return false
	end
	-- Project the oriented bounding box onto the test direction.
	local function extent(direction)
		return math.abs(cf.RightVector:Dot(direction))*size.X/2+math.abs(cf.UpVector:Dot(direction))*size.Y/2+math.abs(cf.LookVector:Dot(direction))*size.Z/2+.3
	end
	if surface=="Wall" then
		for _,direction in {frame.RightVector,-frame.RightVector,frame.LookVector,-frame.LookVector} do
			if hit(direction,extent(direction),"Wall") then return true end
		end
		return false
	elseif surface=="Ceiling" then
		return hit(Vector3.yAxis,extent(Vector3.yAxis),"Ceiling")
	end
	return hit(-Vector3.yAxis,extent(Vector3.yAxis),"Floor")
end
return Geometry
