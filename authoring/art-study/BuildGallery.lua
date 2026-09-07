-- Authoring plugin / Edit mode only. Source installation is documented in README.md.
local source = game.ServerStorage.RoomRoyaleMeshStudySource
local root = require(source.ImportReview).Root()
local function part(name, size, position, color)
	local p = root:FindFirstChild(name) or Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, position, color
	p.Anchored = true
	p.Parent = root
	return p
end
part("ReviewFloor", Vector3.new(36,.4,22), Vector3.new(820,-.2,421), Color3.fromRGB(196,191,180))
part("ReviewWall", Vector3.new(36,11.5,.25), Vector3.new(820,5.75,414), Color3.fromRGB(186,184,171))
part("LampPlinth", Vector3.new(4,3,4), Vector3.new(832,1.5,420), Color3.fromRGB(130,130,116))
for i, spec in {
	{Vector3.new(814,9,427),.30,Color3.fromRGB(255,242,223)},
	{Vector3.new(830,8,426),.22,Color3.fromRGB(232,240,255)},
} do
	local p = part("ReviewFill"..i, Vector3.one, spec[1], Color3.new(1,1,1))
	p.Transparency, p.CanCollide = 1, false
	local light = p:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows = 28, spec[2], spec[3], false
	light.Parent = p
end
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(830,7.7,440),Vector3.new(820,2.8,420))
-- Existing avatar is retained. The live review uses user 70509515 at measured height 5.739976.
