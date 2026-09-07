-- ReplicatedStorage.ViewportIcon
-- Creates a ViewportFrame showing a 3D thumbnail of an item model.
-- Usage: ViewportIcon.Fill(parentFrame, itemId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemAssets = ReplicatedStorage:WaitForChild("ItemAssets", 10)

local ViewportIcon = {}

local LIGHT_DIR = Vector3.new(-1, -1, -2).Unit
local AMBIENT  = Color3.fromRGB(180, 175, 165)
local LIGHT_COLOR = Color3.fromRGB(255, 250, 240)

function ViewportIcon.Fill(parent: GuiObject, itemId: string): ViewportFrame?
	-- Clear any existing viewport
	local existing = parent:FindFirstChild("ItemViewport")
	if existing then existing:Destroy() end

	local template = ItemAssets and ItemAssets:FindFirstChild(itemId)
	if not template then return nil end

	local vf = Instance.new("ViewportFrame")
	vf.Name = "ItemViewport"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.Ambient = AMBIENT
	vf.LightColor = LIGHT_COLOR
	vf.LightDirection = LIGHT_DIR
	vf.Parent = parent

	local clone = template:Clone()
	-- Strip scripts, sounds, anything non-visual
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	clone:PivotTo(CFrame.new())
	clone.Parent = vf

	-- Camera framing: fit the model's bounding box
	local cam = Instance.new("Camera")
	local cf, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local dist = maxDim * 1.6
	cam.CFrame = CFrame.new(
		cf.Position + Vector3.new(dist * 0.5, dist * 0.4, dist * 0.7),
		cf.Position
	)
	cam.Parent = vf
	vf.CurrentCamera = cam

	return vf
end

-- Category emoji fallbacks for when model isn't available
ViewportIcon.Emoji = {
	Seating   = "\u{1F6CB}",  -- couch
	Bedroom   = "\u{1F6CF}",  -- bed
	Table     = "\u{1FA91}",  -- chair (closest)
	Lighting  = "\u{1F4A1}",  -- light bulb
	Electronics = "\u{1F4FA}", -- TV
	Storage   = "\u{1F4E6}",  -- package
	Rug       = "\u{1F9F6}",  -- yarn
	Bathroom  = "\u{1F6BF}",  -- shower
	Decor     = "\u{1F33F}",  -- herb
	Default   = "\u{1F4E6}",  -- package
}

function ViewportIcon.GetEmoji(category: string): string
	return ViewportIcon.Emoji[category] or ViewportIcon.Emoji.Default
end

return ViewportIcon
