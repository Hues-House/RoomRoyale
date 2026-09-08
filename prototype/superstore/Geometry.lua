local G = {}
G.colors = {
	cream = Color3.fromRGB(247, 236, 214), ink = Color3.fromRGB(47, 66, 70),
	peach = Color3.fromRGB(237, 156, 121), lilac = Color3.fromRGB(182, 160, 214),
	mint = Color3.fromRGB(122, 192, 166), blue = Color3.fromRGB(127, 180, 207),
	yellow = Color3.fromRGB(249, 207, 114), wood = Color3.fromRGB(186, 142, 99),
}

function G.part(parent, name, size, cf, color, collides, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide = collides ~= false
	p.CanTouch = false
	p.CanQuery = p.CanCollide
	p.Shape = shape or Enum.PartType.Block
	p.Parent = parent
	return p
end

function G.sign(parent, text, cf, width, height, color)
	local board = G.part(parent, "Sign_" .. text:gsub("\n", "_"), Vector3.new(width, height, 0.35), cf, color, false)
	for _, face in {Enum.NormalId.Front, Enum.NormalId.Back} do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 28
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.88)
		label.Position = UDim2.fromScale(0.03, 0.06)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = G.colors.ink
		label.TextScaled = true
		label.Text = text
		label.Parent = gui
	end
	return board
end

function G.floatingSign(parent, name, text, position, color, width, distance)
	local anchor = G.part(parent, name, Vector3.one, CFrame.new(position), color, false)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "WayfindingSign"
	gui.Size = UDim2.fromOffset(width or 190, 58)
	gui.AlwaysOnTop = false
	gui.MaxDistance = distance or 125
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = 0.04
	label.TextColor3 = G.colors.ink
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", label)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = G.colors.cream
	stroke.Thickness = 2
	return anchor
end

function G.road(parent, name, a, b, width, color, roll)
	local forward = (b-a).Unit
	local cf = CFrame.lookAt((a+b)/2, (a+b)/2+forward) * CFrame.Angles(0, 0, roll or 0)
	return G.part(parent, name, Vector3.new(width, 1, (b-a).Magnitude + 0.15), cf*CFrame.new(0,-0.5,0), color, true)
end

function G.arrow(parent, position, heading, color, scale)
	local cf = CFrame.new(position) * CFrame.Angles(0, heading, 0)
	local s = scale or 1
	G.part(parent, "Wayfinding", Vector3.new(0.85*s,0.025,3.3*s),cf*CFrame.new(0,0,0.85*s),color,false)
	for _, sign in {-1,1} do
		G.part(parent,"Wayfinding",Vector3.new(0.85*s,0.025,3*s),cf*CFrame.new(sign*s,0.035,-1.7*s)*CFrame.Angles(0,sign*math.rad(40),0),color,false)
	end
end

function G.triangle(parent, name, a, b, c, color)
	local ab,ac,bc=b-a,c-a,c-b
	if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
	elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
	ab,ac,bc=b-a,c-a,c-b
	local right=ac:Cross(ab).Unit
	local up=bc:Cross(right).Unit
	local back=bc.Unit
	local height=math.abs(ab:Dot(up))
	for _,data in {{(a+b)/2,right,back,math.abs(ab:Dot(back))},{(a+c)/2,-right,-back,math.abs(ac:Dot(back))}} do
		local p=Instance.new("WedgePart")
		p.Name=name
		p.Size=Vector3.new(0.2,height,data[4])
		local normal=right.Y>0 and right or -right
		p.CFrame=CFrame.fromMatrix(data[1]-normal*0.1,data[2],up,data[3])
		p.Anchored=true
		p.Color=color
		p.Material=Enum.Material.SmoothPlastic
		p.CanTouch=false
		p.Parent=parent
	end
end

return G
