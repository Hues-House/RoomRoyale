local Layout=require(game.ReplicatedStorage.NeighborhoodLayout)
local NB={}
local stone=Color3.fromRGB(197,188,166)
local trim=Color3.fromRGB(236,229,210)
local metal=Color3.fromRGB(66,78,74)
local wood=Color3.fromRGB(133,103,71)
local green=Color3.fromRGB(116,152,94)
local function part(parent,name,size,pos,color,mat,collide)
	local p=Instance.new("Part") p.Name=name p.Size=size p.Position=pos p.Color=color
	p.Material=mat or Enum.Material.SmoothPlastic p.Anchored=true p.CanCollide=collide~=false
	p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent return p
end
local function cylinder(parent,name,radius,height,pos,color,mat,collide)
	local p=part(parent,name,Vector3.new(height,radius*2,radius*2),pos,color,mat,collide)
	p.Shape=Enum.PartType.Cylinder p.CFrame=CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2) return p
end
local function sign(parent,text,size,cf,color)
	local p=part(parent,"Sign",size,cf.Position,color,nil,false) p.CFrame=cf
	local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Front g.CanvasSize=Vector2.new(1000,180) g.Parent=p
	local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Text=text
	t.Font=Enum.Font.GothamMedium t.TextSize=66 t.TextColor3=trim t.Parent=g return p
end
local function bench(parent,pos,target)
	local m=Instance.new("Model") m.Name="ParkBench" m.Parent=parent
	local cf=CFrame.lookAt(pos,Vector3.new(target.X,pos.Y,target.Z))
	local function p(name,size,offset,color,mat)
		local x=part(m,name,size,pos,color,mat) x.CFrame=cf*CFrame.new(offset) return x
	end
	for _,x in {-2.8,2.8} do
		p("SteelFoot",Vector3.new(.35,2,.55),Vector3.new(x,1,0),metal,Enum.Material.Metal)
		p("GroundPlate",Vector3.new(.65,.15,2.2),Vector3.new(x,.075,0),metal,Enum.Material.Metal)
		p("BackUpright",Vector3.new(.22,3.9,.22),Vector3.new(x,1.95,.85),metal,Enum.Material.Metal)
	end
	for i=0,3 do p("SeatSlat",Vector3.new(6.4,.16,.43),Vector3.new(0,2.06,-.70+i*.47),wood,Enum.Material.Wood) end
	for i=0,2 do p("BackSlat",Vector3.new(6.4,.42,.16),Vector3.new(0,2.85+i*.47,.91),wood,Enum.Material.Wood) end
	local seat=Instance.new("Seat") seat.Name="Seat" seat.Size=Vector3.new(4,.15,1.8) seat.CFrame=cf*CFrame.new(0,2.1,0)
	seat.Transparency=1 seat.Anchored=true seat.Parent=m
end
local function lamp(parent,x,z)
	cylinder(parent,"LampBase",.55,.25,Vector3.new(x,.325,z),metal,Enum.Material.Metal)
	cylinder(parent,"LampPost",.14,8.7,Vector3.new(x,4.75,z),metal,Enum.Material.Metal)
	part(parent,"LanternCap",Vector3.new(1.3,.18,1.3),Vector3.new(x,10.1,z),metal,Enum.Material.Metal,false)
	local glass=part(parent,"Lantern",Vector3.new(.9,1.15,.9),Vector3.new(x,9.45,z),Color3.fromRGB(244,221,173),Enum.Material.Glass,false)
	local light=Instance.new("PointLight") light.Brightness=.35 light.Range=22 light.Color=glass.Color light.Parent=glass
end
local function tree(parent,x,z,scale)
	local m=Instance.new("Model") m.Name="ParkTree" m.Parent=parent
	cylinder(m,"TreeWell",3.6,.16,Vector3.new(x,.2,z),Color3.fromRGB(111,99,75),Enum.Material.Ground)
	cylinder(m,"Trunk",.4*scale,7*scale,Vector3.new(x,3.5*scale,z),Color3.fromRGB(109,86,64),Enum.Material.Wood)
	for i,spec in {{-1.9,8.4,0,6.5},{1.8,9.5,.5,6.8},{0,11.8,-.8,6.2}} do
		local p=part(m,"Canopy",Vector3.new(spec[4],spec[4]*.86,spec[4])*scale,Vector3.new(x+spec[1]*scale,spec[2]*scale,z+spec[3]*scale),Color3.fromRGB(91+i*8,128+i*7,73+i*4),Enum.Material.Grass,false)
		p.Shape=Enum.PartType.Ball
	end
end
local function buildPark(root)
	local park=Instance.new("Folder") park.Name="CentralPark" park.Parent=root
	part(park,"Green",Vector3.new(57,.18,287),Vector3.new(0,.09,27.5),green,Enum.Material.Grass)
	for _,x in {-36,36} do
		part(park,"Promenade",Vector3.new(11,.2,309),Vector3.new(x,.1,29.5),stone,Enum.Material.Concrete)
		for _,edge in {-5.7,5.7} do part(park,"Curb",Vector3.new(.35,.25,309),Vector3.new(x+edge,.125,29.5),trim,Enum.Material.Concrete) end
	end
	part(park,"GardenSpine",Vector3.new(7,.2,314),Vector3.new(0,.1,28),stone,Enum.Material.Concrete)
	for _,z in {-123,173,58,-16} do part(park,"Crosswalk",Vector3.new(83,.2,7),Vector3.new(0,.1,z),stone,Enum.Material.Concrete) end
	part(park,"PlazaApproach",Vector3.new(18,.35,45),Vector3.new(0,.175,197),stone,Enum.Material.Concrete)
	for _,lot in Layout.Lots do
		local pos=lot.CFrame.Position local side=math.sign(pos.X)
		part(root,"GardenWalk",Vector3.new(7.5,.2,7),Vector3.new(side*44.75,.1,pos.Z),stone,Enum.Material.Concrete)
		for _,dz in {-25,25} do part(root,"GardenBorder",Vector3.new(30,.35,.4),Vector3.new(pos.X,.175,pos.Z+dz),stone,Enum.Material.Concrete) end
		local post=part(root,"MailboxPost",Vector3.new(.22,3.1,.22),Vector3.new(side*46,1.55,pos.Z+7),wood,Enum.Material.Wood)
		part(root,"Mailbox",Vector3.new(1.15,.8,.85),post.Position+Vector3.new(0,1.75,0),metal,Enum.Material.Metal)
	end
	local f=Instance.new("Folder") f.Name="FountainCourt" f.Parent=park
	cylinder(f,"Court",17,.15,Vector3.new(0,.23,32),trim,Enum.Material.Concrete)
	cylinder(f,"Basin",7,1.2,Vector3.new(0,.8,32),stone,Enum.Material.Concrete)
	cylinder(f,"Water",6.5,.1,Vector3.new(0,1.43,32),Color3.fromRGB(87,153,155),Enum.Material.Glass,false)
	cylinder(f,"Pedestal",.75,2.7,Vector3.new(0,2.25,32),stone,Enum.Material.Concrete)
	cylinder(f,"UpperBowl",2.7,.45,Vector3.new(0,3.75,32),stone,Enum.Material.Concrete)
	cylinder(f,"UpperWater",2.4,.06,Vector3.new(0,4,32),Color3.fromRGB(106,174,174),Enum.Material.Glass,false)
	for _,x in {-21,21} do for _,z in {-85,-43,83,132} do tree(park,x,z,1+(math.abs(z)%3)*.08) end end
	for _,x in {-15,15} do for _,z in {9,55} do bench(park,Vector3.new(x,.2,z),Vector3.new(0,0,32)) end end
	for _,x in {-27,27} do for _,z in {-99,-25,49,123,183} do lamp(park,x,z) end end
	for _,x in {-88,88} do for _,z in {-125,-55,20,95,168} do tree(root,x,z,1.15) end end
	for _,x in {-22,22} do
		bench(park,Vector3.new(x,.2,154),Vector3.new(0,0,154))
		part(park,"FlowerBed",Vector3.new(11,.6,4),Vector3.new(x,.3,162),stone,Enum.Material.Concrete)
		for i=-4,4 do
			local p=part(park,"Lavender",Vector3.new(.7,1.3,.7),Vector3.new(x+i,1.2,162),Color3.fromRGB(128,123+i*2,151),Enum.Material.Grass,false) p.Shape=Enum.PartType.Ball
		end
	end
end
local function shop(root,x,name,color,roofHeight)
	local m=Instance.new("Model") m.Name=name:gsub(" ","") m.Parent=root
	local z=295
	part(m,"Floor",Vector3.new(31,.5,28),Vector3.new(x,.25,z),Color3.fromRGB(178,158,130),Enum.Material.WoodPlanks)
	part(m,"BackWall",Vector3.new(31,12,.6),Vector3.new(x,6.5,z+14),trim,Enum.Material.Concrete)
	for _,side in {-1,1} do
		part(m,"SideWall",Vector3.new(.6,12,28),Vector3.new(x+side*15.5,6.5,z),trim,Enum.Material.Concrete)
		local wx=x+side*9.1
		part(m,"ShopSill",Vector3.new(12.8,2.1,.6),Vector3.new(wx,1.55,z-14),color,Enum.Material.Concrete)
		local glass=part(m,"DisplayGlass",Vector3.new(10.8,7.2,.2),Vector3.new(wx,6.2,z-14),Color3.fromRGB(185,211,210),Enum.Material.Glass) glass.Transparency=.67
		for _,dx in {-5.65,5.65} do part(m,"WindowFrame",Vector3.new(.3,7.8,.55),Vector3.new(wx+dx,6.2,z-14.15),color) end
	end
	part(m,"ShopLintel",Vector3.new(31,3.2,.6),Vector3.new(x,11,z-14),color,Enum.Material.Concrete)
	part(m,"Roof",Vector3.new(32,.5,29),Vector3.new(x,12.8,z),metal,Enum.Material.Slate)
	part(m,"Parapet",Vector3.new(32,roofHeight,.6),Vector3.new(x,13+roofHeight/2,z-14.3),color,Enum.Material.Concrete)
	part(m,"Cornice",Vector3.new(32.7,.3,1),Vector3.new(x,13+roofHeight,z-14.3),trim)
	part(m,"Awning",Vector3.new(30,.25,4),Vector3.new(x,9.8,z-16),color)
	sign(m,name,Vector3.new(23,1.8,.2),CFrame.new(x,11.2,z-14.45),color)
	part(m,"Threshold",Vector3.new(5.4,.2,1.3),Vector3.new(x,.4,z-14),stone,Enum.Material.Concrete)
	for _,side in {-1,1} do
		part(m,"DisplayTable",Vector3.new(7,.3,3.4),Vector3.new(x+side*9,3.4,z-9),wood,Enum.Material.Wood)
		for _,dx in {-2.8,2.8} do part(m,"DisplaySupport",Vector3.new(.45,2.8,2.5),Vector3.new(x+side*9+dx,1.85,z-9),color) end
	end
	local ceiling=part(m,"CeilingLamp",Vector3.new(2,.1,2),Vector3.new(x,12.4,z),trim,nil,false)
	local light=Instance.new("PointLight") light.Brightness=.35 light.Range=22 light.Color=Color3.fromRGB(255,236,205) light.Parent=ceiling
end
function NB.EnsureAll()
	local existing=workspace:FindFirstChild("Neighborhood")
	if existing and existing:GetAttribute("Version")==Layout.Version then return existing end
	local root=Instance.new("Folder") root.Name="Neighborhood" root:SetAttribute("Version",Layout.Version)
	part(root,"Ground",Vector3.new(332,2,582),Vector3.new(0,-1,50),green,Enum.Material.Grass)
	part(root,"EarthMass",Vector3.new(330,26,580),Vector3.new(0,-15,50),Color3.fromRGB(125,110,85),Enum.Material.Ground)
	part(root,"Sea",Vector3.new(2048,10,2048),Vector3.new(0,-23,300),Color3.fromRGB(118,171,183),Enum.Material.SmoothPlastic)
	part(root,"RoundIslandGrass",Vector3.new(680,2,640),Vector3.new(0,-1,680),green,Enum.Material.Grass)
	part(root,"RoundIslandEarth",Vector3.new(672,26,632),Vector3.new(0,-15,680),Color3.fromRGB(125,110,85),Enum.Material.Ground)
	buildPark(root)
	local shops=Instance.new("Folder") shops.Name="Shops" shops.Parent=root
	shop(shops,-36,"THE BOTANICAL",Color3.fromRGB(79,108,91),1.4)
	shop(shops,0,"ROYALE HOME",Color3.fromRGB(163,106,82),2.5)
	shop(shops,36,"THE TEXTILE ROOM",Color3.fromRGB(94,118,137),.8)
	part(root,"MarketSquare",Vector3.new(110,.2,96),Vector3.new(0,.4,240),stone,Enum.Material.Concrete)
	for _,x in {-49,49} do tree(root,x,233,.85) lamp(root,x,257) end
	sign(root,"ROYALE GREEN",Vector3.new(16,2,.3),CFrame.new(0,6.8,183),metal)
	for _,x in {-7,7} do part(root,"WelcomePost",Vector3.new(.3,6.8,.3),Vector3.new(x,3.4,183),metal,Enum.Material.Metal) end
	root.Parent=workspace
	if existing then existing:Destroy() end
	return root
end
return NB
