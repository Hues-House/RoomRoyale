-- ServerScriptService > HouseShellBuilder  (V13 - sized for the RUNTIME 52x44 open-front room)
-- RoomService.buildRoomTemplate builds a 52(x) x 44(z) x 18(y) open-front diorama:
--   interior x in [-26,26], z in [-22,22], front (+Z) is OPEN, walls WallBack/Left/Right, Ceiling at y18.
-- This shell supplies the cottage exterior INCLUDING the front facade+door (room has no front wall),
-- a gable roof, porch, trim, chimney, windows. Floor-center origin, +Z front. PrimaryPart=ShellAnchor.

local ServerStorage = game:GetService("ServerStorage")
local B = {}
local VERSION = 13

local TRIM   = Color3.fromRGB(252,250,246)
local ROOF   = Color3.fromRGB(150,166,190)
local ROOFTR = Color3.fromRGB(238,236,232)
local DOORC  = Color3.fromRGB(226,142,162)
local DOORP  = Color3.fromRGB(208,124,144)
local STONE  = Color3.fromRGB(206,198,186)
local SHUTT  = Color3.fromRGB(150,178,142)
local WOODC  = Color3.fromRGB(168,132,96)
local GOLD   = Color3.fromRGB(214,167,82)
local PINK   = Color3.fromRGB(238,158,178)
local YELL   = Color3.fromRGB(255,214,120)
local BRICK  = Color3.fromRGB(198,150,140)
local LEAF   = Color3.fromRGB(120,170,110)
local GLASSC = Color3.fromRGB(198,226,238)
local SM = Enum.Material.SmoothPlastic

local m
local function P(name,size,cf,color,mat,collide)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf
  p.Anchored=true;p.CanCollide=(collide~=false);p.CastShadow=false
  p.Color=color or TRIM;p.Material=mat or SM
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p.Parent=m;return p
end
local function cyl(name,size,cf,color,mat,collide)
  local p=P(name,size,cf,color,mat,collide);p.Shape=Enum.PartType.Cylinder;return p
end
local function ballp(name,dia,pos,color,mat)
  local p=P(name,Vector3.new(dia,dia,dia),CFrame.new(pos),color,mat,false)
  p.Shape=Enum.PartType.Ball;return p
end
local function slab(name,pos,toward,size,color)
  local w=Instance.new("WedgePart");w.Name=name;w.Size=size
  w.CFrame=CFrame.lookAt(pos,pos+toward)
  w.Anchored=true;w.CanCollide=true;w.CastShadow=false
  w.Color=color;w.Material=SM;w.Parent=m;return w
end
local function gableHalf(name,cf,size)
  local w=Instance.new("WedgePart");w.Name=name;w.Size=size
  w.CFrame=cf;w.Anchored=true;w.CanCollide=true;w.CastShadow=false
  w.Color=TRIM;w.Material=SM;w.Parent=m;return w
end
local function lite(part,b,r,c)
  local l=Instance.new("PointLight");l.Brightness=b;l.Range=r;l.Color=c or Color3.fromRGB(255,230,190);l.Parent=part
end

local WX,WZ,WTOP=26,22,18
local OHX,OHZ=4,5
local EAVE,RISE=19,16
local RIDGEY=EAVE+RISE
local hW=WX+OHX
local hD=WZ+OHZ

local function buildFacadeAndBody()
  -- FRONT facade (room is open-front): two segments + header leave a 12-wide door gap (x -6..6)
  P("FacadeLeft",Vector3.new(20,WTOP,0.8),CFrame.new(-16,WTOP/2,WZ),TRIM)
  P("FacadeRight",Vector3.new(20,WTOP,0.8),CFrame.new(16,WTOP/2,WZ),TRIM)
  P("FacadeHeader",Vector3.new(12.8,4.8,0.8),CFrame.new(0,WTOP-2.4,WZ),TRIM)
  -- foundation skirt
  P("FoundF",Vector3.new(WX*2+1.2,2.4,0.7),CFrame.new(0,1.2,WZ+0.2),STONE,Enum.Material.Concrete,false)
  P("FoundB",Vector3.new(WX*2+1.2,2.4,0.7),CFrame.new(0,1.2,-WZ-0.2),STONE,Enum.Material.Concrete,false)
  P("FoundL",Vector3.new(0.7,2.4,WZ*2+1.2),CFrame.new(-WX-0.2,1.2,0),STONE,Enum.Material.Concrete,false)
  P("FoundR",Vector3.new(0.7,2.4,WZ*2+1.2),CFrame.new(WX+0.2,1.2,0),STONE,Enum.Material.Concrete,false)
  -- corner boards
  for _,c in ipairs({{-WX,WZ},{WX,WZ},{-WX,-WZ},{WX,-WZ}}) do
    P("Corner",Vector3.new(1.4,WTOP,1.4),CFrame.new(c[1],WTOP/2,c[2]),TRIM,nil,false)
  end
  -- frieze along wall tops
  P("FriezeF",Vector3.new(WX*2,1.2,0.5),CFrame.new(0,WTOP-0.4,WZ+0.35),TRIM,nil,false)
  P("FriezeB",Vector3.new(WX*2,1.2,0.5),CFrame.new(0,WTOP-0.4,-WZ-0.35),TRIM,nil,false)
  P("FriezeL",Vector3.new(0.5,1.2,WZ*2),CFrame.new(-WX-0.35,WTOP-0.4,0),TRIM,nil,false)
  P("FriezeR",Vector3.new(0.5,1.2,WZ*2),CFrame.new(WX+0.35,WTOP-0.4,0),TRIM,nil,false)
  -- Seal the small gap between the wall top (y18) and the flat roof underside (y19).
  -- The roof wedges have a FLAT bottom at EAVE(19), so these strips must stop at ~19.5
  -- (just into the roof) or they poke up THROUGH the roof as flat-white panels.
  P("FrontGapFill",Vector3.new(WX*2,1.5,0.8),CFrame.new(0,18.75,WZ),TRIM,nil,false)
  P("BackGapFill",Vector3.new(WX*2,1.5,0.8),CFrame.new(0,18.75,-WZ),TRIM,nil,false)
  P("LeftGapFill",Vector3.new(0.8,1.5,WZ*2),CFrame.new(-WX,18.75,0),TRIM,nil,false)
  P("RightGapFill",Vector3.new(0.8,1.5,WZ*2),CFrame.new(WX,18.75,0),TRIM,nil,false)
  -- chimney
  P("Chimney",Vector3.new(3.6,12,3.6),CFrame.new(-16,33,-8),BRICK,Enum.Material.Brick)
  P("ChimCap",Vector3.new(4.4,0.9,4.4),CFrame.new(-16,39.4,-8),Color3.fromRGB(150,110,100),Enum.Material.Concrete,false)
  ballp("Smoke",2.2,Vector3.new(-16,41.5,-8),Color3.fromRGB(240,240,240),Enum.Material.Neon).Transparency=0.6
end

local function buildRoof()
  slab("RoofFront",Vector3.new(0,EAVE+RISE/2,hD/2),Vector3.new(0,0,1),Vector3.new(hW*2,RISE,hD),ROOF)
  slab("RoofBack", Vector3.new(0,EAVE+RISE/2,-hD/2),Vector3.new(0,0,-1),Vector3.new(hW*2,RISE,hD),ROOF)
  P("RidgeCap",Vector3.new(hW*2+0.6,0.9,1.6),CFrame.new(0,RIDGEY+0.1,0),ROOFTR,nil,false)
  P("FasciaFront",Vector3.new(hW*2+0.8,1.4,0.7),CFrame.new(0,EAVE-0.5,hD),ROOFTR,nil,false)
  P("FasciaBack", Vector3.new(hW*2+0.8,1.4,0.7),CFrame.new(0,EAVE-0.5,-hD),ROOFTR,nil,false)
  P("SoffitFront",Vector3.new(hW*2,0.4,OHZ),CFrame.new(0,EAVE-0.2,WZ+OHZ/2),ROOFTR,nil,false)
  P("SoffitBack", Vector3.new(hW*2,0.4,OHZ),CFrame.new(0,EAVE-0.2,-WZ-OHZ/2),ROOFTR,nil,false)
  for _,sx in ipairs({-1,1}) do
    local x=sx*WX
    gableHalf("GableF_"..tostring(sx),CFrame.new(x,EAVE+RISE/2,WZ/2)*CFrame.Angles(0,math.rad(180),0),Vector3.new(0.7,RISE,WZ))
    gableHalf("GableB_"..tostring(sx),CFrame.new(x,EAVE+RISE/2,-WZ/2),Vector3.new(0.7,RISE,WZ))
    cyl("GableVent",Vector3.new(0.6,3.2,3.2),CFrame.new(x+sx*0.35,EAVE+6.5,0),WOODC,Enum.Material.WoodPlanks,false)
    cyl("GableVentC",Vector3.new(0.7,1.3,1.3),CFrame.new(x+sx*0.45,EAVE+6.5,0),GOLD,Enum.Material.Metal,false)
  end
end

local function dressZ(x,y,z,outZ,w)
  -- Sit the whole window proud of the wall/facade exterior face. Wall half-thickness
  -- is 0.4 and glass half-depth 0.15, so a 0.6 offset clears it (no z-fighting).
  w=w or 8; local h=7; local zf=z+outZ*0.6
  P("WinGlass",Vector3.new(w-1.4,h-1.2,0.3),CFrame.new(x,y,zf),GLASSC,Enum.Material.Glass,false).Transparency=0.5
  P("WinT",Vector3.new(w+0.2,0.7,0.5),CFrame.new(x,y+h/2,zf),TRIM,nil,false)
  P("WinB",Vector3.new(w+0.2,0.7,0.5),CFrame.new(x,y-h/2,zf),TRIM,nil,false)
  P("WinL",Vector3.new(0.7,h+0.6,0.5),CFrame.new(x-w/2,y,zf),TRIM,nil,false)
  P("WinR",Vector3.new(0.7,h+0.6,0.5),CFrame.new(x+w/2,y,zf),TRIM,nil,false)
  P("ShutL",Vector3.new(1.8,h-0.4,0.4),CFrame.new(x-(w/2+1.4),y,zf),SHUTT,nil,false)
  P("ShutR",Vector3.new(1.8,h-0.4,0.4),CFrame.new(x+(w/2+1.4),y,zf),SHUTT,nil,false)
end
local function dressX(x,y,z,outX,w)
  -- Sit the whole window proud of the side-wall exterior face (see dressZ note).
  w=w or 8; local h=7; local xf=x+outX*0.6
  P("WinGlass",Vector3.new(0.3,h-1.2,w-1.4),CFrame.new(xf,y,z),GLASSC,Enum.Material.Glass,false).Transparency=0.5
  P("WinT",Vector3.new(0.5,0.7,w+0.2),CFrame.new(xf,y+h/2,z),TRIM,nil,false)
  P("WinB",Vector3.new(0.5,0.7,w+0.2),CFrame.new(xf,y-h/2,z),TRIM,nil,false)
  P("WinFr",Vector3.new(0.5,h+0.6,0.7),CFrame.new(xf,y,z+w/2),TRIM,nil,false)
  P("WinBk",Vector3.new(0.5,h+0.6,0.7),CFrame.new(xf,y,z-w/2),TRIM,nil,false)
  P("ShutA",Vector3.new(0.4,h-0.4,1.8),CFrame.new(xf,y,z+(w/2+1.4)),SHUTT,nil,false)
  P("ShutB",Vector3.new(0.4,h-0.4,1.8),CFrame.new(xf,y,z-(w/2+1.4)),SHUTT,nil,false)
end

local function buildFrontDetails()
  P("DoorFrameL",Vector3.new(1.2,14,1.3),CFrame.new(-6.4,7,WZ),TRIM,nil,false)
  P("DoorFrameR",Vector3.new(1.2,14,1.3),CFrame.new(6.4,7,WZ),TRIM,nil,false)
  P("DoorFrameT",Vector3.new(14,1.2,1.3),CFrame.new(0,13.9,WZ),TRIM,nil,false)
  P("FrontDoorOpen",Vector3.new(11,13,0.5),CFrame.new(0,6.9,WZ+0.2),DOORC,nil,false)
  for _,px in ipairs({-2.6,2.6}) do for _,py in ipairs({4.4,9.4}) do
    P("DoorPanel",Vector3.new(3.4,3.8,0.25),CFrame.new(px,py,WZ+0.42),DOORP,nil,false)
  end end
  ballp("Knob",0.8,Vector3.new(3.9,6.9,WZ+0.5),GOLD,Enum.Material.Metal)
  P("Mat",Vector3.new(7,0.15,3.5),CFrame.new(0,0.62,WZ+2.6),GOLD,nil,false)
  for _,sx in ipairs({-1,1}) do
    P("Sconce",Vector3.new(0.9,1.5,0.9),CFrame.new(sx*8,10,WZ+0.4),GOLD,Enum.Material.Metal,false)
    local g=ballp("SconceGlow",0.8,Vector3.new(sx*8,10,WZ+0.9),Color3.fromRGB(255,236,200),Enum.Material.Neon)
    lite(g,1.4,16)
  end
  -- front windows in the facade segments
  windowBox(-16,10,WZ)
  windowBox(16,10,WZ)
  -- side windows on the room's left/right walls
  dressX(-WX-0.4,10,4,-1,8)
  dressX(WX+0.4,10,4,1,8)
  dressX(-WX-0.4,10,-10,-1,8)
  dressX(WX+0.4,10,-10,1,8)
end

function windowBox(x,y,z)
  dressZ(x,y,z,1,8)
  P("Box",Vector3.new(8.8,1.3,1.7),CFrame.new(x,y-4.1,z+0.7),WOODC,nil,false)
  ballp("Fl1",1.4,Vector3.new(x-2.7,y-3.4,z+0.7),PINK,Enum.Material.Neon)
  ballp("Fl2",1.4,Vector3.new(x,y-3.4,z+0.7),YELL,Enum.Material.Neon)
  ballp("Fl3",1.4,Vector3.new(x+2.7,y-3.4,z+0.7),TRIM,Enum.Material.Neon)
end

local function buildPorch()
  local pz=WZ
  P("PorchDeck",Vector3.new(19,0.7,9),CFrame.new(0,0.55,pz+4.5),STONE,Enum.Material.Concrete)
  P("PorchStepF",Vector3.new(15,0.6,2.4),CFrame.new(0,0.25,pz+9.4),STONE,Enum.Material.Concrete)
  for _,sx in ipairs({-1,1}) do
    P("PorchPost",Vector3.new(1,14.4,1),CFrame.new(sx*8.4,7.2,pz+8.2),TRIM)
    P("PorchRail",Vector3.new(0.5,0.6,8),CFrame.new(sx*8.4,3.4,pz+4.2),TRIM,nil,false)
    for i=0,3 do P("Balus",Vector3.new(0.35,2.8,0.35),CFrame.new(sx*8.4,2,pz+1.8+i*2.1),TRIM,nil,false) end
  end
  P("PorchBeam",Vector3.new(19,0.8,0.8),CFrame.new(0,14.6,pz+8.2),TRIM,nil,false)
  slab("PorchRoofF",Vector3.new(0,15.6,pz+7.2),Vector3.new(0,0,1),Vector3.new(20,2.4,5.2),ROOF)
  slab("PorchRoofB",Vector3.new(0,15.6,pz+2.6),Vector3.new(0,0,-1),Vector3.new(20,2.4,5.2),ROOF)
  P("PorchRidge",Vector3.new(20.4,0.6,1),CFrame.new(0,16.8,pz+4.7),ROOFTR,nil,false)
end

local function buildPlants()
  for _,sx in ipairs({-1,1}) do
    cyl("Pot",Vector3.new(2.8,2.8,2.8),CFrame.new(sx*11,1.4,WZ+10),Color3.fromRGB(196,124,94),Enum.Material.Concrete)
    ballp("Bush",4,Vector3.new(sx*11,4,WZ+10),LEAF,Enum.Material.Grass)
    ballp("Bloom",1,Vector3.new(sx*11-1.1,4.7,WZ+9.3),PINK,Enum.Material.Neon)
    ballp("Bloom2",1,Vector3.new(sx*11+0.9,4.9,WZ+10.6),YELL,Enum.Material.Neon)
  end
end

local function build()
  m=Instance.new("Model");m.Name="HouseShellDecor";m:SetAttribute("Version",VERSION)
  local anchor=P("ShellAnchor",Vector3.new(1,1,1),CFrame.new(0,0,0),TRIM,nil,false)
  anchor.Transparency=1;m.PrimaryPart=anchor
  buildFacadeAndBody();buildRoof();buildFrontDetails();buildPorch();buildPlants()
  return m
end

function B.GetShell()
  local ex=ServerStorage:FindFirstChild("HouseShellDecor")
  if ex and ex:GetAttribute("Version")==VERSION then return ex end
  if ex then ex:Destroy() end
  local mdl=build();mdl.Parent=ServerStorage;return mdl
end

return B
