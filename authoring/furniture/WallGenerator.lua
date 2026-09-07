--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { Design = "Sunset", FrameColor = Color3.fromRGB(171, 132, 89), GroundColor = Color3.fromRGB(232, 215, 182), AccentColor = Color3.fromRGB(184, 123, 100) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 1 and s.X <= 5 and s.Y >= 1 and s.Y <= 5 and s.Z >= .12 and s.Z <= .4, "Wall piece dimensions outside authoring range")
	assert(a.Design == "Sunset" or a.Design == "Colorblock" or a.Design == "Mirror", "Unknown wall design")
	local b = BuildParts.new(parameters, target)
	b.block("Backing", Vector3.new(s.X, s.Y, s.Z * .5), Vector3.new(0, s.Y / 2, -s.Z * .25), a.FrameColor, Enum.Material.Wood, "Frame")
	local canvas = b.block("Canvas", Vector3.new(s.X - .15, s.Y - .15, s.Z * .1), Vector3.new(0, s.Y / 2, .01), a.GroundColor, Enum.Material.SmoothPlastic, "Ground")
	for _, sign in ipairs({ -1, 1 }) do
		b.block("FrameX_" .. sign, Vector3.new(.09, s.Y, s.Z), Vector3.new(sign * (s.X / 2 - .045), s.Y / 2, 0), a.FrameColor, Enum.Material.Wood, "Frame")
		b.block("FrameY_" .. sign, Vector3.new(s.X - .18, .09, s.Z), Vector3.new(0, s.Y / 2 + sign * (s.Y / 2 - .045), 0), a.FrameColor, Enum.Material.Wood, "Frame")
	end
	if a.Design == "Sunset" then
		local sun = b.cylinder("Sun", math.min(s.X, s.Y) * .4, .015, Vector3.new(0, s.Y * .63, s.Z * .2), a.AccentColor, Enum.Material.SmoothPlastic, "Accent")
		-- Cylinder's local X is its axis; orient the disk toward the room (+Z).
		sun.CFrame = CFrame.new(sun.Position) * CFrame.Angles(0, math.pi / 2, 0)
		b.block("Horizon", Vector3.new(s.X - .22, s.Y * .24, .018), Vector3.new(0, s.Y * .22, s.Z * .3), a.AccentColor:Lerp(a.GroundColor, .35), Enum.Material.SmoothPlastic, "Accent")
	elseif a.Design == "Colorblock" then
		for i = 1, 3 do
			b.block("Panel_" .. i, Vector3.new((s.X - .3) / 3, s.Y * (.2 + i * .14), .015), Vector3.new((i - 2) * (s.X - .22) / 3, s.Y * .48, s.Z * .2), a.AccentColor:Lerp(a.GroundColor, (i - 1) * .24), Enum.Material.SmoothPlastic, "Accent")
		end
	else
		canvas.Color, canvas.Material, canvas.Reflectance = Color3.fromRGB(174, 203, 202), Enum.Material.Glass, .3
	end
	b.anchor()
end

return Generator
