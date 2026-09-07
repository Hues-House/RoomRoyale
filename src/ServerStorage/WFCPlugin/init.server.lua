--!strict
-- WFC Weaver plugin. Right-click this Script -> "Save as Local Plugin..."
-- Children: WFC3D (solver), TileExtractor (folder -> TileDefs).

if not plugin then return end -- safety: do nothing if run as a normal Script

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local WFC3D = require(script.WFC3D)
local TileExtractor = require(script.TileExtractor)

-- Toolbar + dock -----------------------------------------------------------

local toolbar = plugin:CreateToolbar("WFC Weaver")
local toggleButton = toolbar:CreateButton(
	"WFCWeaver",
	"Open the WFC Weaver panel",
	"rbxassetid://4458901886"
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, false,
	260, 320,
	220, 260
)
local widget = plugin:CreateDockWidgetPluginGui("WFCWeaverWidget", widgetInfo)
widget.Title = "WFC Weaver"

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
end)

-- UI helpers -----------------------------------------------------------------

local COLOR_BG = Color3.fromRGB(46, 46, 46)
local COLOR_ROW = Color3.fromRGB(56, 56, 56)
local COLOR_TEXT = Color3.fromRGB(230, 230, 230)
local COLOR_ACCENT = Color3.fromRGB(0, 162, 255)

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = COLOR_BG
root.BorderSizePixel = 0
root.Parent = widget

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = root

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = root

local function makeLabel(text, order)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 16)
	l.BackgroundTransparency = 1
	l.TextColor3 = COLOR_TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.SourceSansSemibold
	l.TextSize = 14
	l.Text = text
	l.LayoutOrder = order
	l.Parent = root
	return l
end

local function makeButton(text, order, accent)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, accent and 36 or 28)
	b.BackgroundColor3 = accent and COLOR_ACCENT or COLOR_ROW
	b.TextColor3 = COLOR_TEXT
	b.Font = accent and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	b.TextSize = accent and 18 or 14
	b.Text = text
	b.LayoutOrder = order
	b.BorderSizePixel = 0
	b.Parent = root
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	return b
end

local function makeVectorRow(order, defaults)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = root
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 6)
	rl.Parent = row

	local boxes = {}
	for i = 1, 3 do
		local tb = Instance.new("TextBox")
		tb.Size = UDim2.new(1 / 3, -4, 1, 0)
		tb.BackgroundColor3 = COLOR_ROW
		tb.TextColor3 = COLOR_TEXT
		tb.Font = Enum.Font.SourceSans
		tb.TextSize = 14
		tb.Text = tostring(defaults[i])
		tb.ClearTextOnFocus = false
		tb.BorderSizePixel = 0
		tb.Parent = row
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = tb
		boxes[i] = tb
	end
	return row, boxes
end

-- UI construction ----------------------------------------------------------------

makeLabel("Tile sample folder:", 1)
local folderButton = makeButton("Select Tile Folder", 2)

makeLabel("Grid size (cells X / Y / Z):", 3)
local _, gridBoxes = makeVectorRow(4, { 8, 4, 8 })

makeLabel("Cell size (studs):", 5)
local cellRow = Instance.new("Frame")
cellRow.Size = UDim2.new(1, 0, 0, 28)
cellRow.BackgroundTransparency = 1
cellRow.LayoutOrder = 6
cellRow.Parent = root
local cellBox = Instance.new("TextBox")
cellBox.Size = UDim2.fromScale(1, 1)
cellBox.BackgroundColor3 = COLOR_ROW
cellBox.TextColor3 = COLOR_TEXT
cellBox.Font = Enum.Font.SourceSans
cellBox.TextSize = 14
cellBox.Text = "12"
cellBox.ClearTextOnFocus = false
cellBox.BorderSizePixel = 0
cellBox.Parent = cellRow
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 4)
cc.Parent = cellBox

local weaveButton = makeButton("WEAVE", 7, true)

local statusLabel = makeLabel("Ready.", 8)
statusLabel.TextWrapped = true
statusLabel.Size = UDim2.new(1, 0, 0, 48)

local function setStatus(text)
	statusLabel.Text = text
end

-- Folder picking --------------------------------------------------------------

local selectedFolder = nil
local pickingConnection = nil

folderButton.MouseButton1Click:Connect(function()
	local sel = Selection:Get()
	if #sel == 1 and sel[1]:IsA("Folder") then
		selectedFolder = sel[1]
		folderButton.Text = "Folder: " .. selectedFolder.Name
		setStatus("Tile folder set.")
		return
	end
	setStatus("Click a Folder in the Explorer...")
	if pickingConnection then pickingConnection:Disconnect() end
	pickingConnection = Selection.SelectionChanged:Connect(function()
		local s = Selection:Get()
		if #s == 1 and s[1]:IsA("Folder") then
			selectedFolder = s[1]
			folderButton.Text = "Folder: " .. selectedFolder.Name
			setStatus("Tile folder set.")
			if pickingConnection then
				pickingConnection:Disconnect()
				pickingConnection = nil
			end
		end
	end)
end)

-- Placement + welding -----------------------------------------------------------

local function getAnchorPart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function instantiate(result, tilesById, cellSize, origin, outputFolder)
	local placed = {}
	for x = 1, #result do
		placed[x] = {}
		for y = 1, #result[x] do
			placed[x][y] = {}
			for z = 1, #result[x][y] do
				local tileId = result[x][y][z]
				local def = tilesById[tileId]
				if not def then continue end
				-- tiles flagged SkipPlacement (e.g. Air) stay virtual
				if def.model:FindFirstChild("SkipPlacement") then continue end

				local clone = def.model:Clone()
				for _, c in clone:GetChildren() do
					if c:IsA("StringValue") and string.sub(c.Name, 1, 7) == "Socket_" then
						c:Destroy()
					end
				end

				local cf = CFrame.new(origin + Vector3.new(x - 1, y - 1, z - 1) * cellSize)
					* CFrame.Angles(0, math.rad(def.rotationY), 0)

				if clone:IsA("BasePart") then
					clone.CFrame = cf
					clone.Anchored = false
				elseif clone:IsA("Model") then
					clone:PivotTo(cf)
					for _, d in clone:GetDescendants() do
						if d:IsA("BasePart") then d.Anchored = false end
					end
				end
				clone.Name = ("%s_%d_%d_%d"):format(def.sourceName, x, y, z)
				clone.Parent = outputFolder
				placed[x][y][z] = clone
			end
		end
	end
	return placed
end

local function weldNeighbors(placed)
	local weldCount = 0
	for x = 1, #placed do
		for y = 1, #placed[x] do
			for z = 1, #placed[x][y] do
				local a = placed[x][y][z]
				if a then
					local pa = getAnchorPart(a)
					if pa then
						local neighbors = {
							placed[x + 1] and placed[x + 1][y] and placed[x + 1][y][z],
							placed[x][y + 1] and placed[x][y + 1][z],
							placed[x][y][z + 1],
						}
						for _, b in neighbors do
							if b then
								local pb = getAnchorPart(b)
								if pb then
									local weld = Instance.new("WeldConstraint")
									weld.Part0 = pa
									weld.Part1 = pb
									weld.Parent = pa
									weldCount += 1
								end
							end
						end
					end
				end
			end
		end
	end
	return weldCount
end

-- The Weave -----------------------------------------------------------------------

local weaving = false

weaveButton.MouseButton1Click:Connect(function()
	if weaving then return end
	if not selectedFolder or not selectedFolder.Parent then
		setStatus("Pick a tile folder first.")
		return
	end

	local gx = tonumber(gridBoxes[1].Text)
	local gy = tonumber(gridBoxes[2].Text)
	local gz = tonumber(gridBoxes[3].Text)
	local cellSize = tonumber(cellBox.Text)
	if not (gx and gy and gz and cellSize)
		or gx < 1 or gy < 1 or gz < 1 or cellSize <= 0 then
		setStatus("Grid/cell size must be positive numbers.")
		return
	end

	weaving = true
	weaveButton.Text = "WEAVING..."
	setStatus("Extracting tiles...")

	local ok, err = pcall(function()
		local tiles = TileExtractor.ExtractFromFolder(selectedFolder, {
			generateRotations = true,
		})
		assert(#tiles > 0, "No tiles extracted from folder")
		TileExtractor.AuditSockets(tiles)

		local tilesById = {}
		for _, t in tiles do tilesById[t.id] = t end

		setStatus(("Solving %dx%dx%d with %d tile variants..."):format(gx, gy, gz, #tiles))
		task.wait()

		local solver = WFC3D.new(tiles, { sizeX = gx, sizeY = gy, sizeZ = gz })
		local result = solver:Solve()
		assert(result, "WFC could not find a solution (check AuditSockets warnings in Output)")

		setStatus("Placing parts...")
		task.wait()

		local recording = ChangeHistoryService:TryBeginRecording("WFC Weave")

		local old = workspace:FindFirstChild("WFC_Output")
		if old then old:Destroy() end
		local outputFolder = Instance.new("Folder")
		outputFolder.Name = "WFC_Output"
		outputFolder.Parent = workspace

		-- placed at X=500 to stay clear of existing builds; edit as needed
		local origin = Vector3.new(500, cellSize / 2, 0)

		local placed = instantiate(result, tilesById, cellSize, origin, outputFolder)
		local weldCount = weldNeighbors(placed)

		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end

		setStatus(("Done. %d welds. Output in workspace.WFC_Output"):format(weldCount))
	end)

	if not ok then
		setStatus("FAILED: " .. tostring(err))
		warn("[WFC Weaver] " .. tostring(err))
	end

	weaveButton.Text = "WEAVE"
	weaving = false
end)
