local Feedback = {}
Feedback.__index = Feedback

local WARM = Color3.fromRGB(255, 190, 70)
local READY = Color3.fromRGB(90, 228, 255)
local JUMP = Color3.fromRGB(166, 255, 204)
local COLORS = {ColorSequence.new(WARM), ColorSequence.new(READY), ColorSequence.new(JUMP)}

local function attachment(body, name, position)
	local result = Instance.new("Attachment")
	result.Name, result.Position, result.Parent = name, position, body
	return result
end

local function emitter(at, color)
	local result = Instance.new("ParticleEmitter")
	result.Name = "CartSparks"
	result.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	result.Color = color
	result.LightEmission = 0.8
	result.LightInfluence = 0
	result.Lifetime = NumberRange.new(0.12, 0.3)
	result.Speed = NumberRange.new(3, 8)
	result.VelocityInheritance = 0.25
	result.SpreadAngle = Vector2.new(40, 50)
	result.EmissionDirection = Enum.NormalId.Back
	result.Acceleration = Vector3.new(0, -18, 0)
	result.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	result.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	result.Rate = 0
	result.Enabled = false
	result.Parent = at
	return result
end

local function create(cart, body, folder)
	local record = {cart = cart, body = body, attachments = {}, sparks = {}, trails = {}, bars = {}, color = 0,
		lastBoost = false, lastCharge = 0, lastGrounded = true, lastMode = "Idle", lastReset = cart:GetAttribute("ResetVersion"),
		compression = 0, bounce = 0, lastUpdate = 0, wheelAngle = 0, casterAngle = 0, wheelJoints = {}, casterJoints = {}}
	for _, x in {-1.75, 1.75} do
		local at = attachment(body, "CartFeedbackWheel", Vector3.new(x, -1.7, 2.3))
		table.insert(record.attachments, at)
		table.insert(record.sparks, emitter(at, COLORS[1]))
		local edge = attachment(body, "CartFeedbackTrailEdge", Vector3.new(x, -1.25, 2.3))
		table.insert(record.attachments, edge)
		local trail = Instance.new("Trail")
		trail.Name = "CartBoostTrail"
		trail.Attachment0, trail.Attachment1 = at, edge
		trail.FaceCamera = true
		trail.Color = COLORS[2]
		trail.LightEmission = 0.7
		trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
		trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
		trail.Lifetime = 0.18
		trail.MaxLength = 12
		trail.MinLength = 0.15
		trail.Enabled = false
		trail.Parent = at
		table.insert(record.trails, trail)
	end
	local chargeAt = attachment(body, "CartJumpPulse", Vector3.new(0, -1.9, 0))
	table.insert(record.attachments, chargeAt)
	record.jumpBurst = emitter(chargeAt, COLORS[3])
	record.jumpBurst.EmissionDirection = Enum.NormalId.Top
	record.jumpBurst.SpreadAngle = Vector2.new(85, 85)
	record.jumpBurst.Speed = NumberRange.new(7, 13)
	for _ = 1, 4 do
		local bar = Instance.new("Part")
		bar.Name = "JumpChargeEdge"
		bar.Anchored = true
		bar.CanCollide, bar.CanQuery, bar.CanTouch = false, false, false
		bar.CastShadow = false
		bar.Material = Enum.Material.Neon
		bar.Color = JUMP
		bar.Transparency = 1
		bar.Parent = folder
		table.insert(record.bars, bar)
	end
	local function bind(child)
		if child:IsA("Motor6D") and child.Name:match("^WheelMount_") then
			record.wheelJoints[child] = child.C0
		elseif child:IsA("Motor6D") and child.Name:match("^CasterMount_") then
			record.casterJoints[child] = child.C0
		elseif child:IsA("Motor6D") and child.Name == "VisualMount" then
			record.mount = child
		end
	end
	record.added = cart.DescendantAdded:Connect(bind)
	record.removed = cart.DescendantRemoving:Connect(function(child)
		record.wheelJoints[child], record.casterJoints[child] = nil, nil
		if record.mount == child then record.mount = nil end
	end)
	for _, child in cart:GetDescendants() do bind(child) end
	return record
end

local function clear(record)
	for _, sparks in record.sparks do sparks.Enabled = false; sparks:Clear() end
	for _, trail in record.trails do trail.Enabled = false; trail:Clear() end
	for _, bar in record.bars do bar.Transparency = 1 end
	record.jumpBurst:Clear()
	if record.mount then record.mount.C0 = CFrame.identity end
	record.compression, record.bounce, record.lastCharge = 0, 0, 0
	record.lastBoost, record.lastMode = false, "Idle"
end

local function destroyRecord(record)
	clear(record)
	record.added:Disconnect()
	record.removed:Disconnect()
	for _, value in record.attachments do value:Destroy() end
	for _, bar in record.bars do bar:Destroy() end
end

function Feedback.new(carts, player)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "CartLabFeedback", workspace
	local self = setmetatable({records = {}, pending = {}, connections = {}, folder = folder, clock = 0, player = player}, Feedback)
	local function add(cart)
		if not cart:IsA("Model") or cart.Parent ~= carts or self.records[cart] then return end
		local body = cart:FindFirstChild("Body")
		if not body then
			if not self.pending[cart] then self.pending[cart] = cart.ChildAdded:Connect(function() add(cart) end) end
			return
		end
		if self.pending[cart] then self.pending[cart]:Disconnect(); self.pending[cart] = nil end
		self.records[cart] = create(cart, body, folder)
	end
	table.insert(self.connections, carts.ChildAdded:Connect(add))
	table.insert(self.connections, carts.ChildRemoved:Connect(function(cart)
		if self.pending[cart] then self.pending[cart]:Disconnect(); self.pending[cart] = nil end
		if self.records[cart] then destroyRecord(self.records[cart]); self.records[cart] = nil end
	end))
	for _, cart in carts:GetChildren() do add(cart) end
	return self
end

function Feedback:step(dt, cameraPosition, ownCart, telemetry)
	self.clock += dt
	local serverTime = workspace:GetServerTimeNow()
	for cart, record in self.records do
		local distance = (record.body.Position - cameraPosition).Magnitude
		local reset = cart:GetAttribute("ResetVersion")
		if distance > 110 or cart:GetAttribute("Ejected") or reset ~= record.lastReset then
			if not record.hidden or reset ~= record.lastReset then clear(record) end
			record.hidden, record.lastReset = true, reset
			continue
		end
		record.hidden = false
		local own = cart == ownCart
		if not own and self.clock - record.lastUpdate < 1 / 30 then continue end
		local elapsed = math.min(0.1, self.clock - record.lastUpdate)
		record.lastUpdate = self.clock
		local live = own and telemetry or nil
		local fresh = serverTime - (cart:GetAttribute("FeedbackAt") or 0) < 0.5
		local mode = live and live.mode or (fresh and cart:GetAttribute("FeedbackMode") or "Idle")
		local jump = live and live.jumpCharge or (fresh and cart:GetAttribute("JumpCharge") or 0)
		local drift = live and live.driftCharge or (fresh and cart:GetAttribute("DriftCharge") or 0)
		local boosting = if live then live.boosting == true else fresh and cart:GetAttribute("Boosting") == true
		local grounded = live and live.grounded
		if not live then grounded = cart:GetAttribute("Grounded") ~= false end
		local speed = record.body.AssemblyLinearVelocity.Magnitude
		local tier = boosting and 2 or (drift >= 0.99 and 2 or 1)
		if tier ~= record.color then
			for _, sparks in record.sparks do sparks.Color = COLORS[tier] end
			record.color = tier
		end
		for _, sparks in record.sparks do
			sparks.Enabled = grounded and speed > 12 and (mode == "Drift" or boosting)
			sparks.Rate = boosting and 32 or (6 + drift * 22)
			if boosting and not record.lastBoost then sparks:Emit(12) end
		end
		for _, trail in record.trails do trail.Enabled = boosting or (mode == "Drift" and drift >= 0.46) end
		if mode ~= "JumpCharge" and record.lastMode == "JumpCharge" and not grounded then
			record.jumpBurst:Emit(math.floor(8 + record.lastCharge * 14))
			record.bounce = 0.14
		elseif grounded and not record.lastGrounded and speed > 6 then
			record.bounce = -0.13
		end
		local compression = mode == "JumpCharge" and jump * 0.23 or 0
		record.compression += (compression - record.compression) * (1 - math.exp(-22 * elapsed))
		record.bounce *= math.exp(-15 * elapsed)
		if record.mount then
			record.mount.C0 = CFrame.new(0, -record.compression + record.bounce, 0)
		end
		local pulse = 0.5 + 0.5 * math.sin(self.clock * (9 + jump * 12))
		local radius = 1 + (1 - jump) * 0.12
		for i, bar in record.bars do
			bar.Transparency = mode == "JumpCharge" and (0.18 + (1 - jump) * 0.3 + pulse * 0.12) or 1
			local side = i <= 2
			local sign = i % 2 == 0 and 1 or -1
			bar.Size = side and Vector3.new(0.1 + jump * 0.05, 0.08, 5.5 * radius) or Vector3.new(4.4 * radius, 0.08, 0.1 + jump * 0.05)
			bar.CFrame = record.body.CFrame * CFrame.new(side and sign * 2.3 * radius or 0, -1.8, side and 0 or sign * 2.8 * radius)
		end
		local localVelocity = record.body.CFrame:VectorToObjectSpace(record.body.AssemblyLinearVelocity)
		record.wheelAngle = (record.wheelAngle - localVelocity.Z * elapsed / (cart:GetAttribute("WheelRadius") or 0.65)) % (math.pi * 2)
		if speed > 2 then
			local angle = math.atan2(-localVelocity.X, -localVelocity.Z)
			local difference = (angle - record.casterAngle + math.pi) % (2 * math.pi) - math.pi
			record.casterAngle += difference * (1 - math.exp(-12 * elapsed))
		end
		for joint, base in record.wheelJoints do joint.C0 = base * CFrame.Angles(record.wheelAngle, 0, 0) end
		for joint, base in record.casterJoints do
			joint.C0 = base * CFrame.new(0, record.compression - record.bounce, 0) * CFrame.Angles(0, record.casterAngle, 0)
		end
		record.lastMode, record.lastCharge, record.lastBoost, record.lastGrounded = mode, jump, boosting, grounded
	end
end

function Feedback:destroy()
	for _, connection in self.connections do connection:Disconnect() end
	for _, connection in self.pending do connection:Disconnect() end
	for _, record in self.records do destroyRecord(record) end
	self.folder:Destroy()
end

return Feedback
