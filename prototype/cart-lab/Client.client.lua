local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local runtime = ReplicatedStorage:WaitForChild("RideRuntime")
local Chassis = require(runtime:WaitForChild("Chassis"))
local Profiles = require(runtime:WaitForChild("Profiles"))
local Cargo = require(script.Parent:WaitForChild("CartLabCargo"))
local Runner = require(script.Parent:WaitForChild("CartLabRunner"))
local Feedback = require(script.Parent:WaitForChild("CartLabFeedback"))
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local event = ReplicatedStorage:WaitForChild("CartLabEvent")
local carts = workspace:WaitForChild("LabCarts")
local cargo = Cargo.new(carts, player)
local runner = Runner.new(carts, player)
local feedback = Feedback.new(carts, player)
local held, braking, focused = false, false, true
local cancelPending = false
local inputEdges = {}

local function readMovement()
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then return controls:GetMoveVector() end
	if lastInput.Name:match("^Gamepad") then
		for _, input in UserInputService:GetGamepadState(lastInput) do
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				return Vector3.new(input.Position.X, 0, -input.Position.Y)
			end
		end
		return Vector3.zero
	end
	local function down(a, b)
		return (UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(b)) and 1 or 0
	end
	return Vector3.new(down(Enum.KeyCode.D, Enum.KeyCode.Right) - down(Enum.KeyCode.A, Enum.KeyCode.Left), 0,
		down(Enum.KeyCode.S, Enum.KeyCode.Down) - down(Enum.KeyCode.W, Enum.KeyCode.Up))
end

local function queueEdge()
	if #inputEdges >= 8 then
		table.clear(inputEdges)
		cancelPending = true
		return
	end
	table.insert(inputEdges, {held = held, steer = math.clamp(readMovement().X, -1, 1), enabled = focused and not GuiService.MenuIsOpen and not cancelPending})
end
local controller, cart, body, telemetry
local cameraSubject
local savedCamera
local cameraFocus
local initialZoomUntil = 0
local lastUi = 0
local lastFeedback = 0
local noticeUntil = 0
local lastMode = "Idle"
local wasBoosting = false
local previousDriftTier = 0
local wasJumpReady = false
local previousGrounded = true
local controlledHumanoid, previousJumpEnabled
local resetVersion = 0
local riding = false
local nativeJumpButton, nativeJumpVisible

local function setNativeJumpHidden(hidden)
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	local button = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if hidden and button then
		if nativeJumpButton ~= button then
			nativeJumpButton, nativeJumpVisible = button, button.Visible
		end
		button.Visible = false
	elseif nativeJumpButton then
		if nativeJumpButton.Parent then nativeJumpButton.Visible = nativeJumpVisible end
		nativeJumpButton = nil
	end
end

local function restoreJump()
	if controlledHumanoid and controlledHumanoid.Parent then
		controlledHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, previousJumpEnabled)
	end
	controlledHumanoid = nil
end

local gui = Instance.new("ScreenGui")
gui.Name = "CartLabHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function textLabel(name, size, position, text, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundColor3 = Color3.fromRGB(28, 36, 51)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.fromRGB(247, 242, 226)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	return label
end

local title = textLabel("Title", UDim2.fromOffset(246, 40), UDim2.new(0.5, -123, 0, 12), "CART LAB  /  PLAYTEST", 16)
local state = textLabel("State", UDim2.fromOffset(250, 60), UDim2.new(0.5, -125, 1, -116), "Ready to roll", 21)
local status = textLabel("Capacity", UDim2.fromOffset(250, 40), UDim2.new(0.5, -125, 1, -55), "Cart space 0 / 100  |  Saved 0", 14)
local spaceBack = Instance.new("Frame")
spaceBack.Size = UDim2.new(1, -20, 0, 5)
spaceBack.Position = UDim2.new(0, 10, 1, -7)
spaceBack.BackgroundColor3 = Color3.fromRGB(68, 75, 89)
spaceBack.BorderSizePixel = 0
spaceBack.Parent = status
local spaceFill = Instance.new("Frame")
spaceFill.Size = UDim2.fromScale(0, 1)
spaceFill.BackgroundColor3 = Color3.fromRGB(107, 230, 195)
spaceFill.BorderSizePixel = 0
spaceFill.Parent = spaceBack
local fillBack = Instance.new("Frame")
fillBack.Size = UDim2.new(1, -20, 0, 5)
fillBack.Position = UDim2.new(0, 10, 1, -8)
fillBack.BackgroundColor3 = Color3.fromRGB(68, 75, 89)
fillBack.BorderSizePixel = 0
fillBack.Parent = state
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(107, 230, 195)
fill.BorderSizePixel = 0
fill.Parent = fillBack

local instruction = UserInputService.TouchEnabled and "Stick to drive. Swipe to look. Hold JUMP straight, release to fly. Press again in air to dive."
	or "WASD: drive  •  Right-drag: look  •  Hold Space straight: charge, release: fly, press in air: dive  •  Shift: brake  •  E: grab"
local hint = textLabel("Hint", UDim2.new(0.8, 0, 0, 44), UDim2.new(0.1, 0, 0, 60), instruction, 13)
local notice = textLabel("Notice", UDim2.new(0.7, 0, 0, 40), UDim2.new(0.15, 0, 0, 111), "", 16)
notice.Visible = false

local Audio = require(ReplicatedStorage:WaitForChild("CartAudio"))
Audio.preload()
local wasDiving = false

local function showNotice(message)
	notice.Text = message
	notice.Visible = true
	noticeUntil = os.clock() + 2.5
end

local function jumpAction(_, inputState)
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if not riding then
		held = false
		cancelPending = true
		return cart and cart:GetAttribute("Ejected") and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		held = true
		queueEdge()
	elseif inputState == Enum.UserInputState.End then
		held = false
		queueEdge()
	elseif inputState == Enum.UserInputState.Cancel then
		held = false
		cancelPending = true
	end
	return Enum.ContextActionResult.Sink
end
local function brakeAction(_, inputState)
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	braking = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	return Enum.ContextActionResult.Sink
end
local function grabAction(_, inputState)
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then event:FireServer("Grab") end
	return Enum.ContextActionResult.Sink
end
local function resetAction(_, inputState)
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then event:FireServer("Reset") end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority("LabHop", jumpAction, true, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonA)
ContextActionService:BindAction("LabBrake", brakeAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("LabGrab", grabAction, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:BindAction("LabReset", resetAction, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
local touchActions = {LabHop = {"JUMP", -78, -148}, LabBrake = {"BRAKE", -150, -76}, LabGrab = {"GRAB", -78, -76}, LabReset = {"RESET", -150, -148}}
local function layoutTouchActions()
	for name, value in touchActions do
		local button = ContextActionService:GetButton(name)
		if button then
			button.Size = UDim2.fromOffset(64, 64)
			ContextActionService:SetTitle(name, value[1])
			ContextActionService:SetPosition(name, UDim2.new(1, value[2], 1, value[3]))
		end
	end
end
task.spawn(function()
	-- Roblox creates its default touch layout asynchronously after BindAction.
	for _ = 1, 30 do
		RunService.Heartbeat:Wait()
		layoutTouchActions()
	end
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouchActions)
UserInputService.WindowFocusReleased:Connect(function() focused = false; held = false; braking = false; cancelPending = true end)
UserInputService.WindowFocused:Connect(function() focused = true end)
GuiService.MenuOpened:Connect(function()
	held, braking = false, false
	cancelPending = true
	table.clear(inputEdges)
end)
UserInputService.InputBegan:Connect(function(_, processed)
	if not processed and not GuiService.MenuIsOpen then focused = true end
end)

local function detach()
	restoreJump()
	setNativeJumpHidden(false)
	riding = false
	if controller then controller:destroy() end
	controller, cart, body, telemetry = nil, nil, nil, nil
	if savedCamera then
		local camera = workspace.CurrentCamera
		camera.CameraType = savedCamera.kind
		camera.CameraSubject = savedCamera.subject
		camera.FieldOfView = savedCamera.fov
		player.CameraMinZoomDistance = savedCamera.minZoom
		player.CameraMaxZoomDistance = savedCamera.maxZoom
	end
	cameraSubject, savedCamera = nil, nil
	if cameraFocus then cameraFocus:Destroy(); cameraFocus = nil end
	held, braking = false, false
	table.clear(inputEdges)
end

local cartWatches = {}
local watchSerial, newestOwnCart = 0, 0
local function watchCart(model)
	if not model:IsA("Model") or cartWatches[model] then return end
	watchSerial += 1
	local serial = watchSerial
	local function attachWhenReady()
		if model.Parent ~= carts or model:GetAttribute("OwnerUserId") ~= player.UserId then return end
		newestOwnCart = math.max(newestOwnCart, serial)
		local candidate = model:FindFirstChild("Body")
		if serial ~= newestOwnCart or not candidate or not candidate:IsA("BasePart") then return end
		if cart == model and body == candidate then return end
		detach()
		cart, body = model, candidate
		controller = Chassis.new(candidate, Profiles.Cart, {model, player.Character, cargo.folder})
		controller:setLoad(model:GetAttribute("CargoWeightRatio") or 0)
		resetVersion = model:GetAttribute("ResetVersion") or 0
	end
	cartWatches[model] = {
		model.ChildAdded:Connect(attachWhenReady),
		model:GetAttributeChangedSignal("OwnerUserId"):Connect(attachWhenReady),
	}
	attachWhenReady()
end
carts.ChildAdded:Connect(watchCart)
carts.ChildRemoved:Connect(function(model)
	if cartWatches[model] then
		for _, connection in cartWatches[model] do connection:Disconnect() end
		cartWatches[model] = nil
	end
	if model == cart then detach() end
end)
for _, model in carts:GetChildren() do watchCart(model) end

event.OnClientEvent:Connect(function(kind, payload)
	if kind == "RoundStarted" then
		cargo:clearDelivery()
	elseif kind == "Delivery" then
		cargo:deliver(payload)
		if payload.ownerUserId == player.UserId then showNotice("Your saved collection has arrived!") end
	elseif kind == "Poof" then
		cargo:poof(payload)
		if payload.cart == cart then showNotice("Store closed! Unchecked items poofed."); Audio.play("poof") end
	elseif kind == "Deposit" then
		cargo:deposit(payload)
		if payload.cart == cart then
			showNotice("WHOOSH!  " .. tostring(#payload.items) .. " items saved")
			local finishAt = 0
			for index, item in payload.items do
				local rare = item.rarity ~= nil and item.rarity ~= "Common"
				local duration = 0.7 + math.clamp(item.space / 40, 0, 1) * 0.35 + (rare and 0.12 or 0)
				local startsAt = (index - 1) * 0.12
				finishAt = math.max(finishAt, startsAt + duration)
				task.delay(startsAt, function() Audio.play("checkoutSuck", nil, {pitch=math.clamp(1.35-item.space/80,0.8,1.3)}) end)
			end
			task.delay(finishAt, function() Audio.play("checkoutComplete") end)
		end
	elseif kind == "Notice" then
		showNotice(tostring(payload))
	elseif kind == "Full" then
		showNotice(string.format("Needs %d space. Head to a tube to unload!", payload.needed))
		Audio.play("full")
	elseif kind == "Pickup" then
		cargo:pickup(payload)
		if payload.cart == cart then Audio.play("pickup") end
	end
end)

RunService.PreSimulation:Connect(function(dt)
	if not controller or not body or not cart then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seated = humanoid and humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(cart)
	riding = seated == true
	setNativeJumpHidden(riding or cart:GetAttribute("Ejected") == true)
	if seated and controlledHumanoid ~= humanoid then
		restoreJump()
		controlledHumanoid = humanoid
		previousJumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	elseif not seated then
		restoreJump()
	end
	local newResetVersion = cart:GetAttribute("ResetVersion") or 0
	if newResetVersion ~= resetVersion then
		controller:destroy()
		controller = Chassis.new(body, Profiles.Cart, {cart, player.Character, cargo.folder})
		resetVersion = newResetVersion
		held = false
		table.clear(inputEdges)
		cameraSubject = nil
	end
	local enabled = focused and seated and not GuiService.MenuIsOpen and not cancelPending and UserInputService:GetFocusedTextBox() == nil
	local movement = readMovement()
	controller:setLoad(cart:GetAttribute("CargoWeightRatio") or 0)
	telemetry = controller:step(dt, {
		throttle = enabled and math.clamp(-movement.Z, -1, 1) or 0,
		steer = enabled and math.clamp(movement.X, -1, 1) or 0,
		brake = braking,
		held = held,
		enabled = enabled == true,
		edges = inputEdges,
	})
	table.clear(inputEdges)
	cancelPending = false
	if enabled and humanoid then humanoid.Jump = false end
	if os.clock() - lastFeedback >= 0.125 then
		lastFeedback = os.clock()
		event:FireServer("Feedback", {
			mode = telemetry.mode,
			jumpCharge = telemetry.jumpCharge,
			driftCharge = telemetry.driftCharge,
			boosting = telemetry.boosting,
			grounded = telemetry.grounded,
		})
	end
end)

RunService:BindToRenderStep("CartLabCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	if body and cart and (riding or cart:GetAttribute("Ejected") == true) then
		local velocity = body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local stackHeight = cart:GetAttribute("CargoVisualHeight") or 0
		local forward = body.CFrame.LookVector * Vector3.new(1, 0, 1)
		forward = if forward.Magnitude < 0.1 then Vector3.new(0, 0, -1) else forward.Unit
		local target = body.Position + Vector3.new(0, 3, 0) + forward * 4
		if not cameraFocus then
			cameraFocus = Instance.new("Part")
			cameraFocus.Name = "CartCameraFocus"
			cameraFocus.Size = Vector3.one
			cameraFocus.Transparency = 1
			cameraFocus.Anchored = true
			cameraFocus.CanCollide, cameraFocus.CanQuery, cameraFocus.CanTouch = false, false, false
			cameraFocus.Parent = workspace
		end
		cameraFocus.CFrame = CFrame.new(target)
		if cameraSubject ~= body then
			if not savedCamera then
				savedCamera = {kind = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView,
					minZoom = player.CameraMinZoomDistance, maxZoom = player.CameraMaxZoomDistance}
			end
			cameraSubject = body
			initialZoomUntil = os.clock() + 0.1
			player.CameraMinZoomDistance = 28
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = cameraFocus
			camera.CFrame = CFrame.lookAt(target - forward * 28 + Vector3.new(0, 8, 0), target)
			camera.Focus = CFrame.new(target)
		end
		player.CameraMinZoomDistance = if os.clock() < initialZoomUntil then 28 else 12
		player.CameraMaxZoomDistance = math.max(38, stackHeight * 2 + 22)
		local desiredFov = 65 + math.clamp(velocity.Magnitude / 8, 0, 8) + (telemetry and telemetry.boosting and 3 or 0)
		camera.FieldOfView += (desiredFov - camera.FieldOfView) * (1 - math.exp(-5 * dt))
	elseif cameraSubject then
		cameraSubject = nil
		camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraType = Enum.CameraType.Custom
	end
	runner:step(dt, camera.CFrame.Position, cart, telemetry)
	feedback:step(dt, camera.CFrame.Position, cart, telemetry)
	cargo:step(dt, camera.CFrame.Position)
	if notice.Visible and os.clock() > noticeUntil then notice.Visible = false end
	local world = workspace:FindFirstChild("CartLab")
	local phase = world and world:GetAttribute("ShoppingPhase")
	local remaining = world and world:GetAttribute("ShoppingRemaining") or 0
	if phase == "Shop" then title.Text = string.format("SHOP  %d:%02d", math.floor(remaining / 60), remaining % 60)
	elseif phase == "Closing" then title.Text = "CHECKOUT CLOSES IN " .. remaining
	elseif phase == "Resolving" then title.Text = "STORE CLOSED"
	elseif phase == "Style" then title.Text = "STYLE  /  YOUR SAVED COLLECTION" end
	state.Visible = cart ~= nil
	status.Visible = cart ~= nil
	hint.Visible = phase ~= "Style" and not (world and world:GetAttribute("EnvironmentId"))
	if not telemetry or not cart then return end
		if telemetry.boosting and not wasBoosting then Audio.play("boost") end
	local driftTier = telemetry.mode == "Drift" and (telemetry.driftCharge >= 0.99 and 2 or (telemetry.driftCharge >= 0.467 and 1 or 0)) or 0
	if driftTier > previousDriftTier then Audio.play("driftReady", nil, {pitch=driftTier==2 and 1.5 or 1.2}) end
	previousDriftTier = driftTier
	local jumpReady = telemetry.mode == "JumpCharge" and telemetry.jumpCharge >= 0.99
	if jumpReady and not wasJumpReady then Audio.play("chargeReady") end
	wasJumpReady = jumpReady
	if telemetry.grounded and not previousGrounded then Audio.play("land") end
	if not telemetry.grounded and previousGrounded and lastMode == "JumpCharge" then Audio.play("jump") end
    if telemetry.diving and not wasDiving then Audio.play("dive") end
    wasDiving = telemetry.diving
    lastMode, wasBoosting, previousGrounded = telemetry.mode, telemetry.boosting, telemetry.grounded
	if os.clock() - lastUi < 0.08 then return end
	lastUi = os.clock()
	local speed = math.floor(math.abs(telemetry.speed or 0))
	local mode = telemetry.diving and "DIVE!" or (not telemetry.grounded and "FLYING" or (telemetry.boosting and "BOOST!" or (telemetry.mode == "Drift" and "DRIFT" or (telemetry.mode == "JumpCharge" and "CHARGING JUMP" or "ROLLING"))))
	state.Text = mode .. "  ·  " .. speed
	local charge = telemetry.mode == "Drift" and telemetry.driftCharge or telemetry.jumpCharge
	fill.Size = UDim2.fromScale(math.clamp(charge or 0, 0, 1), 1)
	fill.BackgroundColor3 = telemetry.mode == "Drift" and Color3.fromRGB(255, 181, 92) or Color3.fromRGB(107, 230, 195)
	status.Text = string.format("Cart space %d / 100  |  Saved %d", cart:GetAttribute("SpaceUsed") or 0, cart:GetAttribute("BankedCount") or 0)
	local space = math.clamp((cart:GetAttribute("SpaceUsed") or 0) / 100, 0, 1)
	spaceFill.Size = UDim2.fromScale(space, 1)
	spaceFill.BackgroundColor3 = space > 0.9 and Color3.fromRGB(255, 169, 126) or Color3.fromRGB(107, 230, 195)
end)
