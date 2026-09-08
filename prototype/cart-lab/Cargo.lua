--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage:WaitForChild("CartItemPresentation"))
local Audio = require(ReplicatedStorage:WaitForChild("CartAudio"))
local Cargo = {}
Cargo.__index = Cargo

local function part(model: Model, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
	local item = Instance.new("Part")
	item.Size = size
	item.CFrame = offset
	item.Color = color
	item.Shape = shape or Enum.PartType.Block
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.Material = Enum.Material.SmoothPlastic
	item.Parent = model
	return item
end

local function itemModel(item, scale)
	local model = Presentation.create(item.templateId, scale)
	if model then
		model.Name = item.id
		model:SetAttribute("CargoId", item.id)
		model:SetAttribute("ItemId", item.itemId)
		model:SetAttribute("VariantId", item.variantId)
	end
	return model
end

local function setHidden(model: Model, hidden: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.LocalTransparencyModifier = if hidden then 1 else 0 end
	end
end

local function presentationFrame(entry)
	if not entry.visual or not entry.visual.Parent then entry.visual = entry.cart:FindFirstChild("VisualRoot", true) end
	return entry.visual and entry.visual.CFrame or entry.body.CFrame
end

function Cargo.new(carts: Folder, player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "CartLabCargoVisuals"
	folder.Parent = workspace
	local self = setmetatable({folder = folder, carts = {}, pending = {}, arrivals = {}, departures = {}, consumed = {}, connections = {}, flights = {}, deliveries = {}, player = player, clock = 0}, Cargo)
	local function add(cart: Instance)
		if not cart:IsA("Model") or self.carts[cart] or cart.Parent ~= carts then return end
		local cargo = cart:FindFirstChild("Cargo")
		local body = cart:FindFirstChild("Body")
		if not cargo or not body or not body:IsA("BasePart") then
			if not self.pending[cart] then self.pending[cart] = cart.ChildAdded:Connect(function() add(cart) end) end
			return
		end
		if self.pending[cart] then self.pending[cart]:Disconnect(); self.pending[cart] = nil end
		local entry = {cart = cart, body = body, pieces = {}, recordConnections = {}, lastUpdate = 0, settledAt = self.clock, connections = {}}
		self.carts[cart] = entry
		local function rebuild()
			local present, pieces = {}, {}
			for _, record in cargo:GetChildren() do
				present[record.Name] = true
				if self.consumed[record.Name] then continue end
				local itemId, templateId = record:GetAttribute("ItemId"), record:GetAttribute("TemplateId")
				local order = record:GetAttribute("Order")
				if type(itemId) ~= "string" or type(templateId) ~= "string" or type(order) ~= "number" then continue end
				local piece = entry.pieces[record.Name]
				if piece and piece.templateId ~= templateId then piece.model:Destroy(); piece = nil end
				if not piece then
					local model = itemModel({id = record.Name, itemId = itemId, templateId = templateId, variantId = record:GetAttribute("VariantId")})
					if not model then continue end
					model.Parent = folder
					local minimum, size = Presentation.bounds(model)
					piece = {model = model, itemId = itemId, templateId = templateId, minimum = minimum, size = size, born = self.clock, order = order, offset = CFrame.identity}
					entry.pieces[record.Name] = piece
					entry.settledAt = self.clock
				end
				table.insert(pieces, piece)
			end
			local height = Presentation.stack(pieces, cart:GetAttribute("CargoDeckY") or -0.7)
			cart:SetAttribute("CargoVisualHeight", height)
			for _, piece in pieces do
				piece.model:PivotTo(presentationFrame(entry) * piece.offset)
				setHidden(piece.model, entry.hidden == true)
			end
			for id, piece in entry.pieces do
				if not present[id] then
					if self.departures[id] then self.departures[id].model:Destroy() end
					self.departures[id] = {model = piece.model, cf = piece.model:GetPivot(), expires = self.clock + 2}
					entry.pieces[id] = nil
					entry.settledAt = self.clock
				end
			end
		end
		local function watchRecord(record)
			if entry.recordConnections[record] then return end
			entry.recordConnections[record] = record.AttributeChanged:Connect(rebuild)
			rebuild()
		end
		table.insert(entry.connections, cargo.ChildAdded:Connect(watchRecord))
		table.insert(entry.connections, cargo.ChildRemoved:Connect(function(record)
			if entry.recordConnections[record] then entry.recordConnections[record]:Disconnect(); entry.recordConnections[record] = nil end
			rebuild()
		end))
		for _, record in cargo:GetChildren() do watchRecord(record) end
		table.insert(entry.connections, cart:GetAttributeChangedSignal("CargoDeckY"):Connect(rebuild))
		local templates = ReplicatedStorage:WaitForChild("CartItemTemplates")
		table.insert(entry.connections, templates.DescendantAdded:Connect(function() task.defer(rebuild) end))
		rebuild()
	end
	table.insert(self.connections, carts.ChildAdded:Connect(add))
	table.insert(self.connections, carts.ChildRemoved:Connect(function(cart)
		if self.pending[cart] then self.pending[cart]:Disconnect(); self.pending[cart] = nil end
		local entry = self.carts[cart]
		if not entry then return end
		for _, connection in entry.connections do connection:Disconnect() end
		for _, connection in entry.recordConnections do connection:Disconnect() end
		for _, piece in entry.pieces do piece.model:Destroy() end
		self.carts[cart] = nil
	end))
	for _, cart in carts:GetChildren() do task.spawn(add, cart) end
	return self
end

function Cargo:destroy()
	for _, connection in self.connections do connection:Disconnect() end
	for _, connection in self.pending do connection:Disconnect() end
	for _, entry in self.carts do
		for _, connection in entry.connections do connection:Disconnect() end
		for _, connection in entry.recordConnections do connection:Disconnect() end
	end
	self:clearDelivery()
	self.folder:Destroy()
end

function Cargo:pickup(receipt)
	if receipt.item and typeof(receipt.position) == "Vector3" then
		self.arrivals[receipt.item.id] = {position = receipt.position, received = self.clock}
	end
end

function Cargo:departingModel(cart, item)
	if self.consumed[item.id] then return nil, nil end
	local entry = self.carts[cart]
	local piece = entry and entry.pieces[item.id]
	local departed = self.departures[item.id]
	local model = if piece then piece.model else if departed then departed.model else itemModel(item)
	if not model then return nil, nil end
	self.consumed[item.id] = self.clock + 3
	local start = if piece then model:GetPivot() else if departed then departed.cf else cart.PrimaryPart.CFrame * CFrame.new(0, 0, -1)
	if piece then entry.pieces[item.id] = nil end
	self.departures[item.id] = nil
	self.arrivals[item.id] = nil
	model.Parent = self.folder
	setHidden(model, false)
	model:PivotTo(start)
	return model, start
end

function Cargo:deposit(receipt)
	local world = workspace:FindFirstChild("CartLab")
	local destination = receipt.position or (world and world:GetAttribute("CheckoutTarget"))
	local cart = receipt.cart
	if typeof(destination) ~= "Vector3" or not cart or not cart.PrimaryPart then return end
	for index, item in receipt.items do
		local model, start = self:departingModel(cart, item)
		if not model then continue end
		local rare = item.rarity ~= nil and item.rarity ~= "Common"
		local duration = 0.7 + math.clamp(item.space / 40, 0, 1) * 0.35 + (if rare then 0.12 else 0)
		if rare then
			local glow = Instance.new("Highlight")
			glow.FillColor = Color3.fromRGB(255, 220, 130)
			glow.FillTransparency = 0.65
			glow.OutlineTransparency = 0.3
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Parent = model
		end
		table.insert(self.flights, {model = model, baseScale = model:GetScale(), start = start, target = destination, startTime = self.clock + (index - 1) * 0.12, duration = duration, rare = rare})
	end
end

function Cargo:clearDelivery()
	for _, models in self.deliveries do for _, model in models do model:Destroy() end end
	table.clear(self.deliveries)
	for _, flight in self.flights do flight.model:Destroy() end
	table.clear(self.flights)
	for _, departure in self.departures do departure.model:Destroy() end
	table.clear(self.departures)
	table.clear(self.arrivals)
	table.clear(self.consumed)
end

function Cargo:deliver(receipt)
	local owner = receipt.ownerUserId
	if self.deliveries[owner] then for _, model in self.deliveries[owner] do model:Destroy() end end
	local models = {}
	self.deliveries[owner] = models
	local pieces = {}
	for index, item in receipt.items do
		local model = itemModel(item, 1)
		if not model then continue end
		model.Parent = self.folder
		local minimum, size = Presentation.bounds(model)
		table.insert(pieces, {model = model, minimum = minimum, size = size, order = index})
	end
	Presentation.stack(pieces, 0, Vector2.new(42, 30))
	for index, piece in pieces do
		local target = receipt.room * piece.offset
		local start = target + Vector3.new(0, 20, 0)
		piece.model:PivotTo(start)
		table.insert(models, piece.model)
		table.insert(self.flights, {model = piece.model, start = start, destination = target, startTime = self.clock + (index - 1) * 0.09, duration = 0.85, delivery = true})
	end
end

function Cargo:poof(receipt)
	local cart = receipt.cart
	if not cart or not cart.PrimaryPart then return end
	local cloud = Instance.new("Model")
	cloud.Name = "ClosingPoof"
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local puff = part(cloud, Vector3.one * 1.8, CFrame.new(math.cos(angle), (index % 2) * 0.6, math.sin(angle)), Color3.fromRGB(246, 238, 225), Enum.PartType.Ball)
		puff.CastShadow = false
		puff.Transparency = 0.25
	end
	cloud.Parent = self.folder
	local cloudStart = cart.PrimaryPart.CFrame * CFrame.new(0, 1.5, 0)
	cloud:PivotTo(cloudStart)
	table.insert(self.flights, {model = cloud, start = cloudStart, startTime = self.clock, duration = 0.85, cloud = true})
	for index, item in receipt.items do
		local model, start = self:departingModel(cart, item)
		if not model then continue end
		table.insert(self.flights, {model = model, baseScale = model:GetScale(), start = start, startTime = self.clock, duration = 0.7, poof = true, angle = index * 2.4})
	end
end

function Cargo:step(dt: number, cameraPosition: Vector3)
	self.clock += dt
	for id, expires in self.consumed do if self.clock > expires then self.consumed[id] = nil end end
	for id, departure in self.departures do if self.clock > departure.expires then departure.model:Destroy(); self.departures[id] = nil end end
	for id, arrival in self.arrivals do
		if (arrival.startTime and self.clock - arrival.startTime > 0.4) or self.clock - arrival.received > 3 then self.arrivals[id] = nil end
	end
	for _, entry in self.carts do
		local distance = (entry.body.Position - cameraPosition).Magnitude
		local own = entry.cart:GetAttribute("OwnerUserId") == self.player.UserId
		local interval = own and 0 or (distance < 80 and 1 / 30 or 1 / 10)
		if self.clock - entry.lastUpdate < interval then continue end
		entry.lastUpdate = self.clock
		local hidden = distance > 180
		if hidden ~= entry.hidden then
			entry.hidden = hidden
			for _, piece in entry.pieces do
				setHidden(piece.model, hidden)
			end
		end
		if hidden then continue end
		local angular = entry.body.CFrame:VectorToObjectSpace(entry.body.AssemblyAngularVelocity)
		local velocity = entry.body.CFrame:VectorToObjectSpace(entry.body.AssemblyLinearVelocity)
		local lean = math.clamp(angular.Y * 0.025 + velocity.X * 0.0015, -0.075, 0.075)
		local visualFrame = presentationFrame(entry) * CFrame.Angles(0, 0, lean)
		local load = math.clamp(entry.cart:GetAttribute("CargoWeightRatio") or 0, 0, 1)
		local settlingAge = self.clock - entry.settledAt
		local settling = math.exp(-settlingAge * 6) * math.abs(math.sin(settlingAge * 14)) * load * 0.16
		for id, piece in entry.pieces do
			local age = self.clock - piece.born
			local bounce = math.exp(-age * 7) * math.abs(math.sin(age * 16)) * 0.3
			local rattle = math.sin(self.clock * 7 + piece.offset.X) * math.min(math.abs(velocity.Z) / 1200, 0.045) * (1 - load * 0.4)
			local target = visualFrame * CFrame.new(0, settling, 0) * piece.offset * CFrame.new(0, bounce + rattle, 0)
			local arrival = self.arrivals[id]
			if arrival then
				arrival.startTime = arrival.startTime or self.clock
				local alpha = math.clamp((self.clock - arrival.startTime) / 0.3, 0, 1)
				if alpha >= 1 and not arrival.packed then
					arrival.packed = true
					if own then Audio.play("pack", entry.body, {pitch = 0.95 + math.min(piece.size.Y, 5) * 0.03}) end
				end
				local position = arrival.position:Lerp(target.Position, 1 - (1 - alpha) ^ 2) + Vector3.new(0, math.sin(alpha * math.pi) * 2, 0)
				target = CFrame.new(position) * target.Rotation
			end
			piece.model:PivotTo(target)
		end
	end
	for index = #self.flights, 1, -1 do
		local flight = self.flights[index]
		if not flight.model.Parent then table.remove(self.flights, index); continue end
		local alpha = math.clamp((self.clock - flight.startTime) / flight.duration, 0, 1)
		if alpha >= 1 then
			if flight.delivery then flight.model:PivotTo(flight.destination) else flight.model:Destroy() end
			table.remove(self.flights, index)
		elseif flight.delivery then
			local drop = math.min(1, alpha / 0.82)
			local bounce = if alpha > 0.82 then math.sin((alpha - 0.82) / 0.18 * math.pi) * 0.4 else 0
			flight.model:PivotTo(flight.start:Lerp(flight.destination, drop * drop) + Vector3.new(0, bounce, 0))
		elseif flight.cloud then
			flight.model:ScaleTo(0.6 + (1 - (1 - alpha) ^ 2) * 2)
			flight.model:PivotTo(flight.start + Vector3.new(0, alpha * 2, 0))
			for _, puff in flight.model:GetChildren() do puff.Transparency = 0.25 + alpha * 0.75 end
		elseif flight.poof then
			local offset = Vector3.new(math.cos(flight.angle) * 2.5, 2, math.sin(flight.angle) * 2.5) * alpha
			flight.model:PivotTo(flight.start + offset)
			flight.model:ScaleTo(flight.baseScale * math.max(0.05, 1 + math.sin(alpha * math.pi) * 0.3 - alpha))
			for _, part in flight.model:GetDescendants() do if part:IsA("BasePart") then part.LocalTransparencyModifier = alpha ^ 2 end end
		else
			local position = flight.start.Position:Lerp(flight.target, alpha * alpha) + Vector3.new(math.sin(alpha * math.pi * 2) * alpha * 0.8, math.sin(alpha * math.pi) * 2, 0)
			flight.model:PivotTo(CFrame.new(position) * flight.start.Rotation * CFrame.Angles(0, alpha * math.pi, alpha * 0.35))
			local shrink = math.clamp((alpha - 0.7) / 0.3, 0, 1)
			flight.model:ScaleTo(flight.baseScale * math.max(0.08, 1 - shrink * shrink))
		end
	end
end

return Cargo
