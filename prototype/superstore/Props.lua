local G = require(script.Parent.Geometry)
local C = G.colors
local Props = {}

function Props.furniture(parent, id, cf, color, scale)
	local templates = game.ServerStorage:FindFirstChild("DesignerFurniture")
	local templateNames = {Sofa="rr_crescent_sofa_v2",Chair="rr_loop_bentwood_chair_v2",Lamp="rr_tide_lamp_v2"}
	local template = templates and templateNames[id] and templates:FindFirstChild(templateNames[id])
	if template then
		local clone = template:Clone()
		clone.Name = id .. "Display"
		if scale and scale ~= 1 then clone:ScaleTo(clone:GetScale() * scale) end
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("ProximityPrompt") then descendant:Destroy() end
		end
		local pivot, size = clone:GetBoundingBox()
		local base = pivot.Position - Vector3.new(0,size.Y/2,0)
		local placement = cf
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = placement * CFrame.new(-base) * p.CFrame
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			end
		end
		clone.Parent = parent
		return clone
	end
	local model = Instance.new("Model")
	model.Name = id .. "Display"
	model.Parent = parent
	local s = scale or 1
	local function piece(name, size, offset, tint, shape)
		return G.part(model,name,size*s,cf*CFrame.new(offset*s),tint or color,false,shape)
	end
	if id == "OrbitLamp" then
		local base = piece("CeramicPlinth",Vector3.new(2.4,0.48,1.6),Vector3.new(0,0.24,0),C.cream,Enum.PartType.Ball)
		base.Material=Enum.Material.SmoothPlastic
		piece("SculptedNeck",Vector3.new(0.52,1.1,0.52),Vector3.new(0,0.87,0),color,Enum.PartType.Ball)
		piece("BrassCollar",Vector3.new(0.8,0.22,0.65),Vector3.new(0,1.28,0),C.wood)
		for index=1,28 do
			local angle=index*math.pi*2/28
			local location=Vector3.new(math.cos(angle)*1.48,2.76+math.sin(angle)*1.48,0)
			local frame=cf*CFrame.new(location*s)*CFrame.Angles(0,0,angle+math.pi/2)
			local halo=G.part(model,"LuminousHalo",Vector3.new(0.35,0.22,0.22)*s,frame,Color3.fromRGB(255,225,147),false,Enum.PartType.Cylinder)
			halo.Material=Enum.Material.Neon
		end
	elseif id == "Sofa" or id == "Chair" then
		local w = id == "Sofa" and 6.8 or 3.4
		piece("Seat",Vector3.new(w,1.1,3.1),Vector3.new(0,1.6,0))
		piece("Back",Vector3.new(w,2.4,0.65),Vector3.new(0,2.5,1.3))
		for _, x in {-w/2+0.3,w/2-0.3} do
			piece("Arm",Vector3.new(0.6,1.5,3.2),Vector3.new(x,2.1,0))
			for _, z in {-1.1,1.1} do piece("Leg",Vector3.new(0.35,1,0.35),Vector3.new(x,0.5,z),C.wood) end
		end
		for _, x in (id == "Sofa" and {-1.6,1.6} or {0}) do
			piece("Cushion",Vector3.new(1.3,1.2,0.4),Vector3.new(x,2.9,0.75),C.cream)
		end
	elseif id == "Bed" then
		piece("BedBase",Vector3.new(6.2,0.65,8.1),Vector3.new(0,0.6,0),C.wood)
		piece("Headboard",Vector3.new(6.3,3.8,0.45),Vector3.new(0,2,3.8),C.wood)
		piece("Mattress",Vector3.new(6,0.8,7.8),Vector3.new(0,1.35,0),C.cream)
		piece("Duvet",Vector3.new(6.1,0.3,5.5),Vector3.new(0,1.9,-0.9),C.cream)
		piece("Throw",Vector3.new(6.2,0.15,2.3),Vector3.new(0,2.1,-2),color)
		for _,x in {-1.5,1.5} do piece("Pillow",Vector3.new(2.5,0.5,1.4),Vector3.new(x,1.9,2.5),C.cream) end
	elseif id == "Table" then
		piece("Top",Vector3.new(5.6,0.4,3.6),Vector3.new(0,3,0))
		for _, x in {-2.2,2.2} do for _, z in {-1.2,1.2} do piece("Leg",Vector3.new(0.3,2.8,0.3),Vector3.new(x,1.4,z),C.wood) end end
	elseif id == "Lamp" then
		piece("Base",Vector3.new(1.7,0.25,1.7),Vector3.new(0,0.125,0),C.wood)
		piece("Stem",Vector3.new(0.24,2.3,0.24),Vector3.new(0,1.3,0),C.cream)
		piece("MushroomCap",Vector3.new(2.7,1.5,2.7),Vector3.new(0,2.7,0),color,Enum.PartType.Ball)
		piece("Rim",Vector3.new(2.6,0.18,2.6),Vector3.new(0,2.25,0),C.cream)
	elseif id == "Plant" then
		piece("Pot",Vector3.new(1.5,1.6,1.5),Vector3.new(0,0.8,0),C.peach)
		piece("Stem",Vector3.new(0.2,2.7,0.2),Vector3.new(0,2.6,0),C.wood)
		for i=1,5 do local a=i*math.pi*0.7; piece("Leaf",Vector3.new(1.2,1.5,0.8),Vector3.new(math.cos(a)*0.65,2+i*0.25,math.sin(a)*0.65),C.mint,Enum.PartType.Ball) end
	elseif id == "Rug" then
		piece("RolledRug",Vector3.new(4,1.2,1.2),Vector3.new(0,0.6,0),color,Enum.PartType.Cylinder)
	else
		for i=1,3 do piece("Book",Vector3.new(1.7,0.22,1.3),Vector3.new((i%2)*0.1,0.11+(i-1)*0.24,0),i%2==0 and C.cream or color) end
	end
	return model
end

function Props.shelf(parent, cf, width, tint, stockId)
	local model = Instance.new("Model")
	model.Name = "StockedShelf"
	model.Parent = parent
	for _, x in {-width/2,width/2} do
		G.part(model,"Upright",Vector3.new(0.55,11,3.5),cf*CFrame.new(x,5.5,0),tint,true)
	end
	for level=0,2 do
		local y=0.5+level*3.6
		G.part(model,"Shelf",Vector3.new(width+0.5,0.4,4),cf*CFrame.new(0,y,0),C.cream,true)
		G.part(model,"ShelfLip",Vector3.new(width+0.5,0.5,0.2),cf*CFrame.new(0,y,-2),tint,false)
		for i=1,math.floor(width/4) do
			local x=-width/2+2+(i-1)*4
			Props.furniture(model,stockId,cf*CFrame.new(x,y+0.2,0),i%2==0 and tint or C.yellow,0.7)
		end
	end
	return model
end

function Props.pickup(parent, definition)
	local cf=definition.cf
	G.part(parent,"ShoppingBay_"..definition.key,Vector3.new(13,0.2,18),cf*CFrame.new(0,-0.1,0),Color3.fromRGB(220,208,185),false)
	for _,side in {-1,1} do
		G.part(parent,"BayEdge",Vector3.new(0.15,0.03,17.5),cf*CFrame.new(side*6.2,0.03,0),definition.color,false)
	end
	local visual=Props.furniture(parent,definition.itemId,cf,definition.color,1)
	if definition.specialTint then
		for _, p in visual:GetDescendants() do if p:IsA("BasePart") then p.Color=definition.specialTint end end
	end
	visual.Name="Merchandise_"..definition.key
	visual:SetAttribute("StockId",definition.key)
	visual:SetAttribute("VariantId",definition.key)
	local anchor=G.part(parent,"Stock_"..definition.key,Vector3.new(1,1,1),cf*CFrame.new(0,2,0),definition.color,false)
	anchor.Transparency=1
	anchor:SetAttribute("StockId",definition.key)
	anchor:SetAttribute("Department",definition.department)
	anchor:SetAttribute("RouteId",definition.route)
	anchor:SetAttribute("StockRemaining",definition.finiteStock)
	local prompt=Instance.new("ProximityPrompt")
	prompt.ActionText="Grab"
	prompt.ObjectText=definition.name.." / "..definition.space.." space"..(definition.finiteStock and " / LIMITED" or "")
	prompt.KeyboardKeyCode=Enum.KeyCode.E
	prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance=15
	prompt.RequiresLineOfSight=false
	prompt.Parent=anchor
	local label=Instance.new("BillboardGui")
	label.Name="StockLabel"
	label.Size=UDim2.fromOffset(180,44)
	label.StudsOffset=Vector3.new(0,3,0)
	label.MaxDistance=29
	label.Parent=anchor
	local text=Instance.new("TextLabel")
	text.Size=UDim2.fromScale(1,1)
	text.BackgroundColor3=C.cream
	text.TextColor3=C.ink
	text.Text=definition.name.."\n"..definition.space.." space"..(definition.finiteStock and " / 1 LEFT" or "")
	text.Font=Enum.Font.GothamBold
	text.TextSize=14
	text.Parent=label
	Instance.new("UICorner",text).CornerRadius=UDim.new(0,8)
	if definition.finiteStock then
		local function stockLabel()
			local remaining = anchor:GetAttribute("StockRemaining") or 0
			text.Text = if remaining == 0 then "CLAIMED\nBack next round"
				else definition.name.."\n"..definition.space.." space / "..remaining.." LEFT"
		end
		anchor:GetAttributeChangedSignal("StockRemaining"):Connect(stockLabel)
		stockLabel()
	end
	local transparency = {}
	for _, p in visual:GetDescendants() do if p:IsA("BasePart") then transparency[p] = p.Transparency end end
	local function visible()
		anchor.Transparency=1
		for p, original in transparency do p.Transparency=prompt.Enabled and original or 1 end
	end
	prompt:GetPropertyChangedSignal("Enabled"):Connect(visible)
	anchor:GetPropertyChangedSignal("Transparency"):Connect(function() if anchor.Transparency~=1 then anchor.Transparency=1 end end)
	return {itemId=definition.itemId,name=definition.name,space=definition.space,weight=definition.weight,color=definition.color,
		rarity=definition.rarity or "Common",part=anchor,prompt=prompt,label=label,available=true,
		visual=visual,visualOrigin=cf,variantId=definition.key,finiteStock=definition.finiteStock,
		requiredFloorY=definition.requireLanding and cf.Position.Y or nil}
end

return Props
