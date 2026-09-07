local TweenService=game:GetService("TweenService")
local Door={}
local states=setmetatable({}, {__mode="k"})

function Door.SetOpen(house, open, player)
	local state=states[house]
	if not state or state.busy or house.Parent==nil then return false end
	if player then
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position-state.closed.Position).Magnitude>12 then return false end
	end
	if house:GetAttribute("DoorOpen")==open then return true end
	if not open then
		local params=OverlapParams.new()
		params.FilterType=Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances={house}
		for _,part in workspace:GetPartBoundsInBox(state.closed*CFrame.new(2.4,4,0),Vector3.new(5.2,8.5,3),params) do
			local character=part:FindFirstAncestorOfClass("Model")
			if character and character:FindFirstChildOfClass("Humanoid") then return false end
		end
	end
	state.busy=true
	house:SetAttribute("DoorMoving",true)
	for _,p in state.leaf:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end
	local tween=TweenService:Create(state.value,TweenInfo.new(.45,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{
		Value=state.closed*CFrame.Angles(0,open and math.rad(105) or 0,0),
	})
	tween:Play()
	tween.Completed:Once(function()
		if not states[house] then return end
		state.busy=false
		house:SetAttribute("DoorOpen",open)
		house:SetAttribute("DoorMoving",false)
		state.prompt.ActionText=open and "Close door" or "Open door"
		state.leaf.DoorPanel.CanCollide=true
	end)
	return true
end

function Door.Attach(house)
	if states[house] then return end
	local leaf=house:FindFirstChild("FrontDoor")
	local prompt=leaf.DoorPanel.DoorPrompt
	local value=Instance.new("CFrameValue")
	value.Name="DoorTransform"
	value.Value=leaf:GetPivot()
	value.Parent=leaf
	local state={leaf=leaf,closed=value.Value,value=value,prompt=prompt,busy=false}
	states[house]=state
	house:SetAttribute("DoorOpen",false)
	local changed=value.Changed:Connect(function(cf) leaf:PivotTo(cf) end)
	local triggered=prompt.Triggered:Connect(function(player) Door.SetOpen(house,not house:GetAttribute("DoorOpen"),player) end)
	house.Destroying:Once(function() changed:Disconnect() triggered:Disconnect() states[house]=nil end)
end
return Door
