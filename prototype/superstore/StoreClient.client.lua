local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local world = workspace:WaitForChild("CartLab")
local hud = player.PlayerGui:WaitForChild("CartLabHUD")
local title = hud:WaitForChild("Title")
local hint = hud:WaitForChild("Hint")
hint.Visible = false
local request = game.ReplicatedStorage:WaitForChild("HillsideSession")
local C = {ink=Color3.fromRGB(47,66,70),cream=Color3.fromRGB(247,236,214),mint=Color3.fromRGB(122,192,166)}

local function button(name, text, y)
    local result = Instance.new("TextButton")
    result.Name, result.Text = name, text
    result.Size = UDim2.fromOffset(176, 44)
    result.Position = UDim2.fromOffset(16, y)
    result.BackgroundColor3, result.TextColor3 = C.mint, C.ink
    result.Font, result.TextSize = Enum.Font.GothamBold, 15
    result.Parent = hud
    Instance.new("UICorner", result).CornerRadius = UDim.new(0, 12)
    return result
end
local roundButton = button("StartShoppingRound", "Shop for 2:30", 12)
roundButton.Activated:Connect(function() request:FireServer("Start") end)
local parkButton = button("PracticePark", "Try the skate park", 64)
parkButton.Activated:Connect(function()
    local carts = workspace:FindFirstChild("LabCarts")
    local cart = carts and carts:FindFirstChild(tostring(player.UserId))
    request:FireServer(cart and cart.PrimaryPart and cart.PrimaryPart.Position.X > 170 and "Market" or "Practice")
end)
local guide = Instance.new("TextLabel")
guide.Name = "ShoppingGuide"
guide.AnchorPoint = Vector2.new(0.5, 0)
guide.Position = UDim2.new(0.5, 0, 0, 72)
guide.Size = UDim2.new(0.48, 0, 0, 48)
guide.BackgroundColor3, guide.BackgroundTransparency = C.cream, 0.06
guide.TextColor3 = C.ink
guide.Font, guide.TextSize, guide.TextWrapped = Enum.Font.GothamBold, 16, true
guide.Parent = hud
Instance.new("UICorner", guide).CornerRadius = UDim.new(0, 12)
local theme = Instance.new("TextLabel")
theme.Name = "ShoppingTheme"
theme.AnchorPoint = Vector2.new(0.5, 0)
theme.Position, theme.Size = UDim2.new(0.5, 0, 0, 52), UDim2.fromOffset(210, 18)
theme.BackgroundTransparency, theme.TextColor3 = 1, C.ink
theme.Font, theme.TextSize, theme.Text = Enum.Font.GothamBold, 13, "Theme: free choice"
theme.Parent = hud
local soundButton = button("SoundToggle", "Sound on", 12)
soundButton.AnchorPoint = Vector2.new(1,0)
soundButton.Position = UDim2.new(1,-16,0,12)
soundButton.Size = UDim2.fromOffset(105,44)
local muted = false
soundButton.Activated:Connect(function()
    muted = not muted
    soundButton.Text = muted and "Sound off" or "Sound on"
    local group = game.SoundService:FindFirstChild("CartEffects")
    if group then group.Volume = muted and 0 or 0.75 end
end)
local helpButton = button("ControlsHelp", "Controls", 64)
helpButton.AnchorPoint = Vector2.new(1,0)
helpButton.Position, helpButton.Size = UDim2.new(1,-16,0,64), UDim2.fromOffset(105,36)
local showControls = false
helpButton.Activated:Connect(function() showControls = not showControls end)
local elapsed, hintClock = 0, 0
RunService.RenderStepped:Connect(function(dt)
    elapsed += dt
    hintClock += dt
    if elapsed < 0.15 then return end
    elapsed = 0
    local phase = world:GetAttribute("ShoppingPhase")
    local carts = workspace:FindFirstChild("LabCarts")
    local cart = carts and carts:FindFirstChild(tostring(player.UserId))
    local body = cart and cart.PrimaryPart
    local inPark = body and body.Position.X > 170
    theme.Visible = not inPark and (phase == nil or phase == "Shop" or phase == "Closing")
    roundButton.Visible = phase == nil or phase == "Style"
    parkButton.Visible = phase == nil or phase == "Style"
    parkButton.Text = inPark and "Back to the market" or "Try the skate park"
    if not phase then title.Text = inPark and "HILLSIDE SKATE PARK" or "HILLSIDE MARKET" end
    local space = cart and cart:GetAttribute("SpaceUsed") or 0
    local saved = cart and cart:GetAttribute("BankedCount") or 0
    local touch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
    local gamepad = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
    local jump = touch and "JUMP" or (gamepad and "A" or "Space")
    local drift = touch and "DRIFT" or (gamepad and "L1" or "Ctrl")
    local brake = touch and "BRAKE" or (gamepad and "L2" or "Shift")
    local grab = touch and "Tap GRAB" or (gamepad and "Press X" or "Press E")
    if phase == "Style" then guide.Text = (player:GetAttribute("HillsideSavedCount") or 0) .. " pieces checked out for your room!"
    elseif phase == "Closing" then guide.Text = "Last chance! Drive through the green CHECKOUT."
    elseif phase == "Resolving" then guide.Text = "Your checked-out pieces are on their way!"
    elseif inPark then
        local hints = {"Ride the rollers. Carry your speed into the next hill.", "Hold " .. jump .. ", then release to jump.", "Press " .. jump .. " again in the air to tuck down.", touch and "Drag the right side to look around." or (gamepad and "Use the right stick to look around." or "Hold right mouse to look around. Scroll to zoom.")}
        guide.Text = hints[math.floor(hintClock / 6) % #hints + 1]
    elseif space >= 85 then guide.Text = "Big haul! Follow green to CHECKOUT."
    elseif space > 0 then guide.Text = "Drive through green CHECKOUT to deliver your cargo."
    elseif saved > 0 then guide.Text = "Checked out! Pick a new aisle for your next trip."
    else guide.Text = grab .. " beside a find. The green tube is your CHECKOUT." end
    if showControls then
        guide.Text = "Hold " .. jump .. ": jump / dive. " .. drift .. ": drift. " .. brake .. ": brake."
    end
    local narrow = workspace.CurrentCamera.ViewportSize.X < 900
    title.Size = UDim2.fromOffset(narrow and 210 or 250, 40)
    title.Position = UDim2.new(0.5, narrow and -105 or -125, 0, 12)
    guide.Size = UDim2.new(0, math.min(380, workspace.CurrentCamera.ViewportSize.X - 292), 0, 48)
    guide.Position = UDim2.new(0.5, 0, 0, 72)
    guide.TextSize = narrow and 12 or 16
    for i, b in {roundButton, parkButton} do
        b.Size = UDim2.fromOffset(narrow and 128 or 176, 44)
        b.Position = narrow and UDim2.fromOffset(10, 12 + (i-1)*48) or UDim2.fromOffset(16, 12+(i-1)*52)
        b.TextSize = narrow and 13 or 15
    end
end)
