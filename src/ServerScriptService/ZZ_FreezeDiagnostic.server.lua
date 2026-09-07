-- TEMPORARY diagnostic for the multiplayer lobby freeze. DELETE once the cause is found.
-- Logs each player's humanoid/physics state shortly after they spawn, plus what geometry
-- is around them, so a freeze can be attributed without a live debugger.

local Players = game:GetService("Players")

local function snap(player: Player, tag: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and root and root:IsA("BasePart")) then
		warn(string.format("[FREEZE] %s %s character=%s humanoid=%s root=%s",
			player.Name, tag, tostring(character ~= nil), tostring(humanoid ~= nil), tostring(root ~= nil)))
		return
	end

	local owner = "?"
	local ok, result = pcall(function() return root:GetNetworkOwner() end)
	if ok then owner = result and result.Name or "SERVER" end

	warn(string.format("[FREEZE] %s %s ws=%s jp=%s jh=%s plat=%s sit=%s anchored=%s state=%s owner=%s inCart=%s weld=%s platform=%s",
		player.Name, tag,
		tostring(humanoid.WalkSpeed), tostring(humanoid.JumpPower), tostring(humanoid.JumpHeight),
		tostring(humanoid.PlatformStand), tostring(humanoid.Sit), tostring(root.Anchored),
		tostring(humanoid:GetState()), owner,
		tostring(character:GetAttribute("InCart")),
		tostring(character:FindFirstChild("DriverWeld", true) ~= nil),
		tostring(humanoid.SeatPart and humanoid.SeatPart:GetFullName() or "none")))

	-- A character ragdolls when its Motor6Ds are disabled while the BallSocketConstraints
	-- on the rig are present, and a ragdolled character cannot walk. This is the signal
	-- that separates "ragdolled" from "held still by something else".
	local motorsOn, motorsOff, offNames = 0, 0, {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") then
			if d.Enabled then
				motorsOn += 1
			else
				motorsOff += 1
				if #offNames < 8 then table.insert(offNames, d.Name) end
			end
		end
	end
	warn(string.format("[FREEZE] %s %s motor6d on=%d off=%d %s  <-- any 'off' means RAGDOLLED",
		player.Name, tag, motorsOn, motorsOff,
		#offNames > 0 and ("[" .. table.concat(offNames, ",") .. "]") or ""))

	-- Anything welding or constraining the character to the world will show up here.
	local attached = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("AlignPosition")
			or d:IsA("BodyPosition") or d:IsA("AlignOrientation") then
			if d.Name ~= "Neck" then table.insert(attached, d.ClassName .. ":" .. d.Name) end
		end
	end

	-- Is the character encased in geometry (for example a house built on top of spawn)?
	local nearby = {}
	local okBox, parts = pcall(function()
		return workspace:GetPartBoundsInBox(root.CFrame, root.Size + Vector3.new(3, 5, 3))
	end)
	if okBox and parts then
		for _, p in ipairs(parts) do
			if not p:IsDescendantOf(character) then
				table.insert(nearby, p:GetFullName())
				if #nearby >= 6 then break end
			end
		end
	end

	warn(string.format("[FREEZE] %s %s pos=%s constraints=[%s] nearby=[%s]",
		player.Name, tag, tostring(root.Position),
		#attached > 0 and table.concat(attached, ", ") or "none",
		#nearby > 0 and table.concat(nearby, " | ") or "none"))
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(2)
		snap(player, "spawn+2s")
		task.wait(6)
		snap(player, "spawn+8s")
	end)
	if player.Character then
		task.spawn(function()
			task.wait(2)
			snap(player, "existing+2s")
		end)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end

print("[FreezeDiagnostic] armed (TEMPORARY - delete this script once diagnosed)")
