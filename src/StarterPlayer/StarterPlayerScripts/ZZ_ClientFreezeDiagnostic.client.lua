-- TEMPORARY. Pairs with ZZ_FreezeDiagnostic. Delete both once the freeze is diagnosed.
-- Answers the one question every server-side probe has been blind to:
-- is the client's movement input reaching the humanoid, and is the body attached to the root?
local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local TAG = "[CFREEZE] " .. player.Name .. " "

local function controlModuleMove()
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if not pm then return "no PlayerModule" end
	local ok, res = pcall(function()
		local control = require(pm):GetControls()
		return control:GetMoveVector()
	end)
	if not ok then return "GetMoveVector error: " .. tostring(res) end
	return string.format("%.2f,%.2f,%.2f", res.X, res.Y, res.Z)
end

local function boundActions()
	local ok, info = pcall(function() return CAS:GetAllBoundActionInfo() end)
	if not ok then return "error" end
	local names = {}
	for name in pairs(info) do table.insert(names, name) end
	table.sort(names)
	return #names == 0 and "none" or table.concat(names, ",")
end

local function jointCensus(character)
	local m6, bsc, weld, parts = 0, 0, 0, 0
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") then m6 += 1
		elseif d:IsA("BallSocketConstraint") then bsc += 1
		elseif d:IsA("WeldConstraint") or d:IsA("Weld") then weld += 1
		elseif d:IsA("BasePart") then parts += 1 end
	end
	return string.format("parts=%d motor6d=%d ballsocket=%d weld=%d", parts, m6, bsc, weld)
end

local function report(label)
	local character = player.Character
	if not character then print(TAG .. label .. " NO CHARACTER") return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then print(TAG .. label .. " missing humanoid or root") return end

	print(string.format("%s%s move=%.2f,%.2f,%.2f ctrl=%s ws=%s state=%s",
		TAG, label,
		humanoid.MoveDirection.X, humanoid.MoveDirection.Y, humanoid.MoveDirection.Z,
		controlModuleMove(),
		tostring(humanoid.WalkSpeed),
		tostring(humanoid:GetState())))
	print(string.format("%s%s %s rootpos=%s phase=%s inCart=%s",
		TAG, label, jointCensus(character),
		tostring(root.Position), tostring(player:GetAttribute("RoundPhase")),
		tostring(character:GetAttribute("InCart"))))
	print(string.format("%s%s boundActions=[%s]", TAG, label, boundActions()))

	-- Which movement controller did the ControlModule actually pick, and why.
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	local active = "no PlayerModule"
	if pm then
		local ok, res = pcall(function()
			local controls = require(pm):GetControls()
			local ctrl = controls:GetActiveController()
			return ctrl and tostring(getmetatable(ctrl)) or "NO ACTIVE CONTROLLER"
		end)
		active = ok and tostring(res) or ("error: " .. tostring(res))
	end
	local settings = "unreadable"
	pcall(function()
		local ugs = UserSettings():GetService("UserGameSettings")
		settings = string.format("ComputerMovementMode=%s TouchMovementMode=%s",
			tostring(ugs.ComputerMovementMode), tostring(ugs.TouchMovementMode))
	end)
	print(string.format("%s%s activeController=%s devMode=%s user[%s] lastInput=%s",
		TAG, label, active,
		tostring(game:GetService("StarterPlayer").DevComputerMovementMode),
		settings,
		tostring(game:GetService("UserInputService"):GetLastInputType())))
	local uis = game:GetService("UserInputService")
	print(string.format("%s%s KeyboardEnabled=%s GamepadEnabled=%s MouseEnabled=%s TouchEnabled=%s AccelerometerEnabled=%s viewport=%s",
		TAG, label,
		tostring(uis.KeyboardEnabled), tostring(uis.GamepadEnabled), tostring(uis.MouseEnabled),
		tostring(uis.TouchEnabled), tostring(uis.AccelerometerEnabled),
		tostring(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)))
	-- What does the client think is plugged in, and can the controls be forced on?
	local gps = {}
	pcall(function()
		for _, g in ipairs(uis:GetConnectedGamepads()) do gps[#gps+1] = tostring(g) end
	end)
	local recovery = "not attempted"
	if label == "RECOVER" then
		local ps2 = player:FindFirstChild("PlayerScripts")
		local pm2 = ps2 and ps2:FindFirstChild("PlayerModule")
		if pm2 then
			local ok, res = pcall(function()
				local controls = require(pm2):GetControls()
				controls:Enable(true)
				task.wait(0.5)
				local c = controls:GetActiveController()
				return (c and "RECOVERED -> " .. tostring(getmetatable(c)) or "still nil")
					.. " move=" .. tostring(controls:GetMoveVector())
			end)
			recovery = ok and tostring(res) or ("error: " .. tostring(res))
		end
	end
	print(string.format("%s%s gamepads=[%s] navGamepad=%s recovery=%s",
		TAG, label, table.concat(gps, ","),
		tostring(game:GetService("GuiService"):GetEmotesMenuOpen()), recovery))
end

-- Report on a schedule, and also on demand: press P at any moment you cannot move.
task.spawn(function()
	player.CharacterAdded:Wait()
	task.wait(2)  report("t+2s")
	task.wait(6)  report("t+8s")
	task.wait(4)  report("RECOVER")   -- auto-attempts controls:Enable(true)
	task.wait(3)  report("t+20s")
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		report("MANUAL")
	elseif not processed and input.KeyCode == Enum.KeyCode.O then
		report("RECOVER")
	end
end)

print(TAG .. "client diagnostic armed. Press P while stuck for an on-demand report.")
