local Layout=require(game.ReplicatedStorage.NeighborhoodLayout)
local Builder={}
local palettes={
	{Color3.fromRGB(218,222,207),Color3.fromRGB(72,107,101)},
	{Color3.fromRGB(231,217,200),Color3.fromRGB(139,77,55)},
	{Color3.fromRGB(208,218,225),Color3.fromRGB(58,81,104)},
	{Color3.fromRGB(227,217,211),Color3.fromRGB(107,104,73)},
}
local cream=Color3.fromRGB(242,236,220)
local wood=Color3.fromRGB(126,98,72)
local function part(parent,name,size,cf,color,material,collide)
	local p=Instance.new("Part")
	p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
	p.Material=material or Enum.Material.SmoothPlastic
	p.Anchored,p.CanCollide=true,collide~=false
	p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	p.Parent=parent
	return p
end
local function label(p,text)
	local gui=Instance.new("SurfaceGui") gui.Face=Enum.NormalId.Back gui.CanvasSize=Vector2.new(640,160) gui.Parent=p
	local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Text=text
	t.Font=Enum.Font.GothamMedium t.TextSize=42 t.TextColor3=cream t.Parent=gui
end

function Builder.Build(index, owner)
	local colors=palettes[Layout.Lots[index].Palette]
	local house=Instance.new("Model") house.Name=owner and "HouseRoom_"..owner.UserId or "VacantHouse_"..index
	house:SetAttribute("HouseIndex",index) house:SetAttribute("IsVacant",owner==nil)
	house:SetAttribute("OwnerUserId",owner and owner.UserId or 0)
	house:SetAttribute("IsHouseRoom",owner~=nil) house:SetAttribute("HouseSchemaVersion",2)
	house:SetAttribute("RoomWidth",36) house:SetAttribute("RoomDepth",32) house:SetAttribute("RoomHeight",10.8)
	house.WorldPivot=CFrame.identity
	local shell=Instance.new("Folder") shell.Name="Architecture" shell.Parent=house
	local function p(name,size,position,color,mat,collide) return part(shell,name,size,CFrame.new(position),color,mat,collide) end
	p("Foundation",Vector3.new(37,.9,33),Vector3.new(0,.45,0),Color3.fromRGB(167,158,143),Enum.Material.Concrete)
	local floor=part(house,"Floor",Vector3.new(36,.3,32),CFrame.new(0,1.05,0),Color3.fromRGB(177,143,105),Enum.Material.WoodPlanks)
	floor:SetAttribute("SurfaceType","Floor")
	local boundary=part(house,owner and "HouseRoom_"..owner.UserId.."_Plot" or "PlotBoundary",Vector3.new(34.8,.1,30.8),CFrame.new(0,1.22,0),cream,nil,false)
	boundary.Transparency=1 boundary.CanQuery=false
	local function wall(name,size,pos,key)
		local exterior=p(name,size,pos,colors[1],Enum.Material.Concrete)
		local liner=part(house,name.."Liner",Vector3.new(size.X>.8 and size.X or .10,size.Y-.1,size.Z>.8 and size.Z or .10),CFrame.new(pos+Vector3.new(pos.X==0 and 0 or -math.sign(pos.X)*.43,0,pos.Z==0 and 0 or -math.sign(pos.Z)*.43)),cream,nil,false)
		liner:SetAttribute("SurfaceType","Wall") liner:SetAttribute("SurfaceKey",key)
		return exterior
	end
	wall("WallBack",Vector3.new(36,10.8,.7),Vector3.new(0,6.6,-16),"wall_back")
	wall("WallLeft",Vector3.new(.7,10.8,32),Vector3.new(-18,6.6,0),"wall_left")
	wall("WallRight",Vector3.new(.7,10.8,32),Vector3.new(18,6.6,0),"wall_right")
	-- Front wall is segmented around a real door and two glazed window openings.
	for _,side in {-1,1} do
		local x=side*10.2
		p("FrontSill",Vector3.new(15.6,3,.7),Vector3.new(x,2.7,16),colors[1],Enum.Material.Concrete)
		p("FrontLintel",Vector3.new(15.6,2.4,.7),Vector3.new(x,10.8,16),colors[1],Enum.Material.Concrete)
		for _,dx in {-5.9,5.9} do p("WindowPier",Vector3.new(3.8,5.4,.7),Vector3.new(x+dx,6.9,16),colors[1],Enum.Material.Concrete) end
		local glass=p("WindowGlass",Vector3.new(7.8,5.4,.16),Vector3.new(x,6.9,16),Color3.fromRGB(182,209,211),Enum.Material.Glass)
		glass.Transparency=.60
		for _,dx in {-4.05,4.05} do p("WindowJamb",Vector3.new(.28,5.9,.9),Vector3.new(x+dx,6.9,16.2),cream) end
		for _,dy in {-2.85,2.85} do p("WindowTrim",Vector3.new(8.35,.25,.9),Vector3.new(x,6.9+dy,16.2),cream) end
		p("WindowMullion",Vector3.new(.16,5.45,.3),Vector3.new(x,6.9,16.2),cream)
		p("WindowCrossbar",Vector3.new(7.9,.16,.3),Vector3.new(x,6.9,16.2),cream)
		p("WindowBox",Vector3.new(8.5,.8,1.1),Vector3.new(x,3.7,16.65),colors[2])
		p("PlanterSoil",Vector3.new(8,.15,.8),Vector3.new(x,4.12,16.65),Color3.fromRGB(66,55,40),Enum.Material.Ground,false)
		for j=-3,3 do
			local leaf=p("PlanterLeaf",Vector3.new(.75,.8,.65),Vector3.new(x+j,4.45,16.65),Color3.fromRGB(95,126+j*3,76),Enum.Material.Grass,false)
			leaf.Shape=Enum.PartType.Ball
		end
	end
	p("DoorLintel",Vector3.new(4.8,2.8,.7),Vector3.new(0,10.6,16),colors[1],Enum.Material.Concrete)
	for _,x in {-2.55,2.55} do p("DoorJamb",Vector3.new(.3,8.3,1),Vector3.new(x,5.2,16.15),cream) end
	p("DoorHeader",Vector3.new(5.4,.3,1),Vector3.new(0,9.35,16.15),cream)
	local door=Instance.new("Model") door.Name="FrontDoor" door.Parent=house
	local hinge=part(door,"Hinge",Vector3.new(.1,.1,.1),CFrame.new(-2.4,1.2,16),cream,nil,false)
	hinge.Transparency=1 hinge.CanQuery=false door.PrimaryPart=hinge
	local panel=part(door,"DoorPanel",Vector3.new(4.65,7.95,.32),CFrame.new(0,5.2,16),colors[2])
	for _,y in {3.1,6.8} do part(door,"InsetPanel",Vector3.new(3.7,2.9,.12),CFrame.new(0,y,16.22),colors[2]:Lerp(cream,.08),nil,false) end
	local handle=part(door,"LeverHandle",Vector3.new(.7,.12,.16),CFrame.new(1.65,5.1,16.42),Color3.fromRGB(166,130,69),Enum.Material.Metal,false)
	part(door,"HandleRose",Vector3.new(.25,.45,.08),CFrame.new(1.85,5.1,16.3),handle.Color,Enum.Material.Metal,false)
	local prompt=Instance.new("ProximityPrompt") prompt.Name="DoorPrompt" prompt.ActionText="Open door" prompt.ObjectText="Front door"
	prompt.KeyboardKeyCode=Enum.KeyCode.E prompt.MaxActivationDistance=10 prompt.RequiresLineOfSight=false prompt.HoldDuration=0 prompt.Parent=panel
	part(house,"Ceiling",Vector3.new(36,.4,32),CFrame.new(0,12.2,0),cream):SetAttribute("SurfaceType","Ceiling")
	local roofColor=Color3.fromRGB(74,81,80)
	local pitch=math.atan(5.7/19.4)
	for _,side in {-1,1} do
		part(shell,"RoofSlope",Vector3.new(math.sqrt(19.4^2+5.7^2),.45,35.4),CFrame.new(side*9.7,15.1,0)*CFrame.Angles(0,0,-side*pitch),roofColor,Enum.Material.Slate)
		p("Fascia",Vector3.new(.4,.65,35.5),Vector3.new(side*19.4,12.25,0),cream)
		for _,z in {-16,16} do p("CornerTrim",Vector3.new(.35,10.9,.35),Vector3.new(side*18.1,6.65,z),cream) end
	end
	-- Gable triangles use wedges, with the slope rising toward the roof ridge.
	for _,z in {-16,16} do for _,side in {-1,1} do
		local wedge=Instance.new("WedgePart") wedge.Name="Gable" wedge.Size=Vector3.new(.5,5.45,18)
		wedge.CFrame=CFrame.new(side*9,14.925,z)*CFrame.Angles(0,-side*math.pi/2,0)
		wedge.Color=colors[1] wedge.Material=Enum.Material.Concrete wedge.Anchored=true wedge.Parent=shell
	end end
	p("PorchDeck",Vector3.new(21,.35,5),Vector3.new(0,1.025,18.6),wood,Enum.Material.WoodPlanks)
	for i=1,3 do p("PorchStep",Vector3.new(7,i*.3,1.25),Vector3.new(0,i*.15,24.25-i*1.1),Color3.fromRGB(184,174,153),Enum.Material.Concrete) end
	for _,x in {-9.6,9.6} do
		p("PorchPost",Vector3.new(.6,8.4,.6),Vector3.new(x,5.4,20.3),cream)
		p("PostFoot",Vector3.new(.9,.35,.9),Vector3.new(x,1.35,20.3),Color3.fromRGB(156,151,139),Enum.Material.Concrete)
		p("SideRail",Vector3.new(.2,.25,3.4),Vector3.new(x,3.8,18.9),cream)
		for j=1,4 do p("PorchBaluster",Vector3.new(.12,2.4,.12),Vector3.new(x,2.55,17.2+j*.65),cream) end
	end
	part(shell,"PorchRoof",Vector3.new(22,.35,6),CFrame.new(0,9.95,18.9)*CFrame.Angles(math.rad(8),0,0),roofColor,Enum.Material.Slate)
	p("PorchBeam",Vector3.new(20,.6,.6),Vector3.new(0,9.5,20.3),cream)
	local plaque=p("OwnerSign",Vector3.new(7,1.1,.15),Vector3.new(0,10.7,16.48),colors[2],nil,false)
	label(plaque,owner and owner.DisplayName.."'s home" or "No. "..index.."  ·  Vacant")
	for _,x in {-3.5,3.5} do
		local lantern=p("PorchLantern",Vector3.new(.4,.8,.45),Vector3.new(x,7.4,16.7),Color3.fromRGB(241,211,153),Enum.Material.Glass,false)
		local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,225,185) light.Brightness=.25 light.Range=11 light.Parent=lantern
	end
	local fixture=p("InteriorPendant",Vector3.new(1.8,.2,1.8),Vector3.new(0,10.8,0),cream,nil,false)
	p("PendantStem",Vector3.new(.1,1.2,.1),Vector3.new(0,11.4,0),wood,nil,false)
	local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,239,213) light.Range=24 light.Brightness=.5 light.Parent=fixture
	local placed=Instance.new("Folder") placed.Name="PlacedItems" placed.Parent=house
	for _,p in house:GetDescendants() do if p:IsA("BasePart") then p:SetAttribute("IsHouseRoom",owner~=nil) p:SetAttribute("OwnerUserId",owner and owner.UserId or 0) end end
	house:PivotTo(Layout.Lots[index].CFrame)
	return house
end
return Builder
