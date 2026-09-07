--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { ShadeStyle = "Drum", ShadeColor = Color3.fromRGB(232, 215, 180), StemColor = Color3.fromRGB(151, 126, 77), Lit = true } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 1 and s.X <= 3 and s.Y >= 1.8 and s.Y <= 6.5 and math.abs(s.X - s.Z) < .001, "Lamp dimensions outside authoring range")
	assert(a.ShadeStyle == "Drum" or a.ShadeStyle == "Mushroom", "Unknown shade style")
	local b = BuildParts.new(parameters, target)
	local shadeHeight = s.Y * .28
	b.cylinder("Foot", s.X * .55, .15, Vector3.new(0, .075, 0), a.StemColor, Enum.Material.Metal, "Stem")
	b.cylinder("Stem", s.X * .08, s.Y - shadeHeight, Vector3.new(0, .15 + (s.Y - shadeHeight) / 2, 0), a.StemColor, Enum.Material.Metal, "Stem")
	local shadeY = s.Y - shadeHeight / 2
	if a.ShadeStyle == "Drum" then
		b.cylinder("Shade", s.X, shadeHeight, Vector3.new(0, shadeY, 0), a.ShadeColor, Enum.Material.Fabric, "Shade")
	else
		b.ball("Shade", Vector3.new(s.X, shadeHeight, s.Z), Vector3.new(0, shadeY, 0), a.ShadeColor, Enum.Material.SmoothPlastic, "Shade")
	end
	local bulb = b.ball("Bulb", Vector3.new(.18, .18, .18), Vector3.new(0, s.Y - shadeHeight - .05, 0), Color3.fromRGB(255, 229, 173), Enum.Material.Neon, "Bulb")
	local light = Instance.new("PointLight")
	light.Name, light.Color, light.Brightness, light.Range = "WarmLight", bulb.Color, .65, 7
	light.Enabled, light.Shadows, light.Parent = a.Lit, false, bulb
	b.anchor()
end

return Generator
