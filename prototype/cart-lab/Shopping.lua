local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Rules = require(game.ReplicatedStorage:WaitForChild("CartPickupRules"))
local Shopping = {}
Shopping.__index = Shopping
local ink, cream = Color3.fromRGB(47, 66, 70), Color3.fromRGB(247, 236, 214)
local mint, amber, red = Color3.fromRGB(122, 192, 166), Color3.fromRGB(245, 185, 92), Color3.fromRGB(232, 133, 112)

local function label(parent, name, y, height, size)
    local result = Instance.new("TextLabel")
    result.Name, result.Text = name, ""
    result.Size, result.Position = UDim2.new(1, -20, 0, height), UDim2.fromOffset(10, y)
    result.BackgroundTransparency = 1
    result.TextColor3, result.Font, result.TextSize = ink, Enum.Font.GothamBold, size
    result.TextWrapped = true
    result.Parent = parent
    return result
end

function Shopping.new(gui, player, carts)
    local self = setmetatable({player = player, carts = carts, candidate = nil, used = nil}, Shopping)
    local panel = Instance.new("Frame")
    panel.Name = "ShoppingCapacity"
    panel.AnchorPoint = Vector2.new(0.5, 1)
    panel.Position = UDim2.new(0.5, 0, 1, -12)
    panel.Size = UDim2.fromOffset(340, 112)
    panel.BackgroundColor3, panel.BackgroundTransparency = cream, 0.04
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    self.panel = panel
    self.capacity = label(panel, "Capacity", 5, 24, 15)
    self.delivered = label(panel, "Delivered", 29, 20, 13)
    local track = Instance.new("Frame")
    track.Name = "SpaceTrack"
    track.Position, track.Size = UDim2.fromOffset(12, 53), UDim2.new(1, -24, 0, 8)
    track.BorderSizePixel, track.BackgroundColor3 = 0, Color3.fromRGB(206, 212, 198)
    track.ClipsDescendants, track.Parent = true, panel
    local fill = Instance.new("Frame")
    fill.Name, fill.Size, fill.BorderSizePixel = "SpaceFill", UDim2.fromScale(0, 1), 0
    fill.BackgroundColor3, fill.Parent = mint, track
    self.fill = fill
    self.nextPiece = label(panel, "FocusedPiece", 65, 42, 14)
    local highlight = Instance.new("Highlight")
    highlight.Name = "FocusedShoppingPiece"
    highlight.FillTransparency, highlight.OutlineTransparency = 0.85, 0
    highlight.DepthMode, highlight.Parent = Enum.HighlightDepthMode.Occluded, gui
    self.highlight = highlight
    self.connection = RunService.RenderStepped:Connect(function() self:update(gui) end)
    return self
end

function Shopping:update(gui)
    local cart = self.carts:FindFirstChild(tostring(self.player.UserId))
    local body = cart and cart.PrimaryPart
    local character = self.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = cart and cart:FindFirstChild("DriverSeat")
    local mounted = body and humanoid and humanoid.Health > 0 and seat and seat.Occupant == humanoid and not cart:GetAttribute("Ejected")
    local world = workspace:FindFirstChild("CartLab")
    local phase = world and world:GetAttribute("ShoppingPhase")
    local canShop = mounted and (phase == nil or phase == "Shop")
    self.candidate = canShop and Rules.select(CollectionService:GetTagged("CartLabPickup"), body, {cart, character}) or nil
    local visual = self.candidate and self.candidate:FindFirstChild("PickupVisual")
    self.highlight.Adornee = visual and visual.Value or self.candidate
    self.highlight.Enabled = self.candidate ~= nil
    local used = cart and cart:GetAttribute("SpaceUsed") or 0
    local delivered = cart and cart:GetAttribute("BankedCount") or self.player:GetAttribute("HillsideSavedCount") or 0
    local required = self.candidate and self.candidate:GetAttribute("PickupSpace")
    local capacity = Rules.capacityState(used, required)
    local color = capacity.full and red or (capacity.nearlyFull and amber or mint)
    self.capacity.Text = string.format("%s  %d / %d  ·  %d free", capacity.full and "CART FULL" or (capacity.nearlyFull and "NEARLY FULL" or "CART SPACE"), used, Rules.capacity, capacity.free)
    self.delivered.Text = string.format("%d pieces checked out", delivered)
    if used ~= self.used then
        if self.tween then self.tween:Cancel() end
        self.tween = TweenService:Create(self.fill, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(capacity.ratio, 1), BackgroundColor3 = color})
        self.tween:Play()
        self.used = used
    end
    if self.candidate then
        local device = UserInputService.PreferredInput
        local action = device == Enum.PreferredInput.Touch and "Tap GRAB" or (device == Enum.PreferredInput.Gamepad and "X: grab" or "E: grab")
        self.nextPiece.Text = string.format("%s · %d space\n%s", self.candidate:GetAttribute("PickupName"), required, capacity.fits and ("Fits · " .. action) or ("Won't fit · " .. capacity.free .. " free. Checkout first."))
        self.highlight.OutlineColor = capacity.fits and mint or red
    elseif phase == "Style" then self.nextPiece.Text = "Your delivered collection is ready."
    elseif phase and phase ~= "Shop" then self.nextPiece.Text = "Shopping closed · follow green to CHECKOUT"
    elseif not mounted then self.nextPiece.Text = "Get on your cart to grab a piece."
    elseif capacity.nearlyFull then self.nextPiece.Text = "Follow the green signs to CHECKOUT"
    else self.nextPiece.Text = "Drive beside a piece to see if it fits." end
    local camera = workspace.CurrentCamera
    local narrow = camera and camera.ViewportSize.X < 900
    self.panel.Size = UDim2.fromOffset(camera and math.clamp(camera.ViewportSize.X - 330, 220, 340) or 340, 112)
    self.capacity.TextSize = narrow and 13 or 15
    self.nextPiece.TextSize = narrow and 12 or 14
    local notice = gui:FindFirstChild("Notice")
    if notice then notice.Position = UDim2.new(0.15, 0, 0, 124) end
    local state = gui:FindFirstChild("State")
    if state then
        state.Size, state.Position = UDim2.fromOffset(narrow and 210 or 250, 32), UDim2.new(0.5, narrow and -105 or -125, 1, -160)
        state.TextSize = narrow and 14 or 16
    end
end

function Shopping:grab(remote)
    local candidate = self.candidate
    if candidate and candidate.Parent then remote:FireServer("Grab", candidate:GetAttribute("PickupId")) end
end

return Shopping
