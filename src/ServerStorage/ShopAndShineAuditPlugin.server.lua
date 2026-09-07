-- Shop & Shine Audit Plugin
-- INSTALL: right-click this script in ServerStorage -> "Save as Local Plugin..."
-- Then a "Shop & Shine" toolbar appears with an Audit button. Works in Edit and Play.

local toolbar = plugin:CreateToolbar("Shop & Shine")
local button = toolbar:CreateButton("Audit", "Run Shop & Shine project audit", "rbxassetid://6031071053")

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 440, 540, 320, 300)
local widget = plugin:CreateDockWidgetPluginGui("ShopAndShineAudit", info)
widget.Title = "Shop & Shine Audit"

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(36, 36, 38)
root.Parent = widget

local runBtn = Instance.new("TextButton")
runBtn.Size = UDim2.new(1, -16, 0, 32)
runBtn.Position = UDim2.new(0, 8, 0, 8)
runBtn.Text = "Run Audit"
runBtn.Font = Enum.Font.GothamBold
runBtn.TextSize = 16
runBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 90)
runBtn.TextColor3 = Color3.new(1, 1, 1)
runBtn.Parent = root

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -56)
scroll.Position = UDim2.new(0, 8, 0, 48)
scroll.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.Parent = root

local out = Instance.new("TextLabel")
out.Size = UDim2.new(1, -8, 0, 0)
out.AutomaticSize = Enum.AutomaticSize.Y
out.BackgroundTransparency = 1
out.TextXAlignment = Enum.TextXAlignment.Left
out.TextYAlignment = Enum.TextYAlignment.Top
out.Font = Enum.Font.Code
out.TextSize = 14
out.TextColor3 = Color3.fromRGB(220, 220, 220)
out.TextWrapped = true
out.Text = "Press Run Audit."
out.Parent = scroll

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local SURFACES = { Floor = true, Wall = true, Ceiling = true, Table = true, Shelf = true }

local function runAudit()
	local lines, fails, warns = {}, 0, 0
	local function add(s) table.insert(lines, s) end
	local function FAIL(s) fails += 1 add("[FAIL] " .. s) end
	local function WARN(s) warns += 1 add("[warn] " .. s) end
	local function OK(s) add("[ ok ] " .. s) end
	local function H(s) add("") add("== " .. s .. " ==") end

	-- 1) expected scripts exist
	H("Script presence")
	local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	local groups = {
		{ game:GetService("ServerScriptService"), { "RoundManager", "LobbyBootstrap", "ShowroomBootstrap", "StoreSetup", "RoomService", "CartService", "JudgeService", "HousingService", "ProgressionService", "CurrencyPickupService" } },
		{ game:GetService("ReplicatedStorage"), { "ItemDatabase", "ItemCatalogData", "ShopTargeting", "ViewportIcon" } },
		{ sps, { "RoundClient", "CartController", "PickupEffect", "StyleController", "JudgeClient", "StoreItemPrompt", "PlacementController", "HousingClient" } },
	}
	local missing = 0
	for _, g in ipairs(groups) do
		local parent, names = g[1], g[2]
		if parent then
			for _, n in ipairs(names) do
				if not parent:FindFirstChild(n, true) then
					missing += 1
					FAIL("missing " .. n .. " in " .. parent.Name)
				end
			end
		else
			WARN("StarterPlayerScripts not found")
		end
	end
	if missing == 0 then OK("all expected scripts found") end

	-- 2) catalog integrity
	H("ItemCatalogData")
	local catalog
	local mod = game:GetService("ReplicatedStorage"):FindFirstChild("ItemCatalogData")
	if not mod then
		FAIL("ItemCatalogData not found")
	else
		local seen, dupes = {}, 0
		for key in string.gmatch(mod.Source, "\n\t(%a[%w_]*)%s*=%s*entry%(") do
			if seen[key] then dupes += 1 FAIL("duplicate catalog key: " .. key) end
			seen[key] = true
		end
		if dupes == 0 then OK("no duplicate catalog keys") end
		local okReq, result = pcall(function()
			return require(mod:Clone()) -- clone dodges stale require cache
		end)
		if not okReq then
			FAIL("catalog failed to load: " .. tostring(result))
		else
			catalog = result
			local count, eligible, depts = 0, 0, {}
			for id, data in pairs(catalog) do
				count += 1
				if type(data) ~= "table" then
					FAIL(tostring(id) .. ": entry is not a table")
				else
					if not data.Name or data.Name == "" then FAIL(id .. ": missing Name") end
					if data.PlacementSurface and not SURFACES[data.PlacementSurface] then
						WARN(id .. ": unusual PlacementSurface '" .. tostring(data.PlacementSurface) .. "'")
					end
					if data.ShowroomEligible then
						eligible += 1
						depts[data.Department] = (depts[data.Department] or 0) + 1
						if type(data.Price) ~= "number" or data.Price <= 0 then
							WARN(id .. ": showroom item without positive Price")
						end
						if type(data.SpawnChance) ~= "number" or data.SpawnChance <= 0 or data.SpawnChance > 1 then
							WARN(id .. ": SpawnChance outside (0,1]")
						end
					end
				end
			end
			OK(count .. " items, " .. eligible .. " showroom-eligible")
			local deptList = {}
			for d, n in pairs(depts) do table.insert(deptList, d .. "(" .. n .. ")") end
			table.sort(deptList)
			add("       departments: " .. table.concat(deptList, ", "))
		end
	end

	-- 3) showroom loot slots (runtime-built)
	H("Showroom loot slots")
	local slots = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("PlacementSurface") and d:GetAttribute("Department") and d:GetAttribute("RarityBias") then
			table.insert(slots, d)
		end
	end
	if #slots == 0 then
		add("[skip] no slots in DataModel (Showroom builds at runtime - run audit during a playtest for slot checks)")
	else
		OK(#slots .. " slots found")
		local combo = {}
		for _, s in ipairs(slots) do
			local dept = s:GetAttribute("Department")
			local surf = s:GetAttribute("PlacementSurface")
			combo[dept .. "|" .. surf] = true
			if not SURFACES[surf] then WARN(s.Name .. ": unusual surface '" .. tostring(surf) .. "'") end
			if not s:GetAttribute("StoreSubsection") then WARN(s.Name .. ": missing StoreSubsection") end
			if catalog then
				local found = false
				for _, data in pairs(catalog) do
					if type(data) == "table" and data.ShowroomEligible and data.Department == dept then
						found = true
						break
					end
				end
				if not found then FAIL(s.Name .. ": Department '" .. dept .. "' has no eligible catalog items") end
			end
		end
		if catalog then
			for id, data in pairs(catalog) do
				if type(data) == "table" and data.ShowroomEligible and data.Department then
					local surf = data.PlacementSurface or "Floor"
					if not combo[data.Department .. "|" .. surf] then
						WARN(id .. ": no slot matches " .. data.Department .. "/" .. surf)
					end
				end
			end
		end
	end

	-- 4) cohort lint
	H("Cohort lint (raw Players:GetPlayers in server code)")
	local hits = 0
	for _, d in ipairs(game:GetService("ServerScriptService"):GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			local n = select(2, string.gsub(d.Source, "Players:GetPlayers%(%)", ""))
			if n > 0 then
				hits += n
				WARN(d.Name .. ": " .. n .. " call(s)")
			end
		end
	end
	if hits == 0 then
		OK("no raw GetPlayers calls in server scripts")
	else
		add("       (rewire these to the round cohort / getActivePlayers for true multiplayer)")
	end

	-- 5) conventions
	H("Conventions")
	local roomService = game:GetService("ServerScriptService"):FindFirstChild("RoomService")
	if roomService then
		if string.find(roomService.Source, "ProximityPromptStyle.Default", 1, true) then
			FAIL("RoomService sets Default prompt style (convention: Custom + PromptController)")
		else
			OK("RoomService prompt style ok (Custom convention)")
		end
		local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
		if not (sps and sps:FindFirstChild("PromptController", true)) then
			FAIL("PromptController missing but Custom prompts are the convention")
		else
			OK("PromptController present")
		end
		if string.find(roomService.Source, "BillboardGui", 1, true) then
			WARN("RoomService still references BillboardGui")
		else
			OK("RoomService has no BillboardGui refs")
		end
	end

	add("")
	add("Done: " .. fails .. " FAIL, " .. warns .. " warn")
	local text = table.concat(lines, "\n")
	out.Text = text
	out.TextColor3 = fails > 0 and Color3.fromRGB(255, 170, 170) or Color3.fromRGB(200, 235, 210)
	print("\n[Shop & Shine Audit]\n" .. text)
end

runBtn.MouseButton1Click:Connect(runAudit)
