-- Shared dimensions are in studs; the review avatar is 5.74 studs tall.
local Layout = {
	Version = 8,
	House = {Width=36, Depth=32, WallHeight=10.8, FloorTop=1.2, DoorWidth=4.8, DoorHeight=8},
	Spawn = Vector3.new(0,.525,258),
	Queue = Vector3.new(0,.5,208),
	Plaza = Vector3.new(0,0,240),
	Lots = {},
}
for side = 1, 2 do
	for row, z in {132,58,-16,-90} do
		local index = (side-1)*4+row
		local x = side==1 and -68 or 68
		Layout.Lots[index] = {
			Index=index,
			CFrame=CFrame.new(x,0,z)*CFrame.Angles(0,side==1 and math.pi/2 or -math.pi/2,0),
			Palette=(index-1)%4+1,
		}
	end
end
function Layout.LegacyHouseFrame(worldPosition)
	local closest, distance
	for side = 1, 2 do
		for _,z in {130,40,-50,-140} do
			local frame=CFrame.new(side==1 and -90 or 90,0,z)*CFrame.Angles(0,side==1 and math.pi/2 or -math.pi/2,0)
			local delta=(worldPosition-frame.Position).Magnitude
			if not distance or delta<distance then closest,distance=frame,delta end
		end
	end
	return closest, distance
end
return Layout
