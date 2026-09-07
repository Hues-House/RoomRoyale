--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { Pattern = "Border", Repeats = 6, GroundColor = Color3.fromRGB(218, 207, 180), PatternColor = Color3.fromRGB(133, 153, 123) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 2 and s.X <= 10 and s.Y >= .08 and s.Y <= .2 and s.Z >= 2 and s.Z <= 10, "Rug dimensions outside authoring range")
	assert(a.Pattern == "Border" or a.Pattern == "Stripe" or a.Pattern == "Check" or a.Pattern == "Round", "Unknown rug pattern")
	assert(a.Repeats % 1 == 0 and a.Repeats >= 2 and a.Repeats <= 8, "Repeats must be 2 through 8")
	local b, fabric = BuildParts.new(parameters, target), Enum.Material.Fabric
	if a.Pattern == "Round" then
		assert(math.abs(s.X - s.Z) < .001, "Round rug needs equal width and depth")
		b.cylinder("RoundGround", s.X, s.Y * .7, Vector3.new(0, s.Y * .35, 0), a.PatternColor, fabric, "Pattern")
		b.cylinder("RoundCenter", s.X * .78, s.Y * .3, Vector3.new(0, s.Y * .85, 0), a.GroundColor, fabric, "Ground")
	else
		b.block("Ground", Vector3.new(s.X, s.Y * .7, s.Z), Vector3.new(0, s.Y * .35, 0), a.GroundColor, fabric, "Ground")
		local y, thickness = s.Y * .85, s.Y * .3
		if a.Pattern == "Border" then
			local border = math.min(s.X, s.Z) * .065
			for _, side in ipairs({ -1, 1 }) do
				b.block("BorderX_" .. side, Vector3.new(border, thickness, s.Z * .88), Vector3.new(side * s.X * .43, y, 0), a.PatternColor, fabric, "Pattern")
				b.block("BorderZ_" .. side, Vector3.new(s.X * .88, thickness, border), Vector3.new(0, y, side * s.Z * .43), a.PatternColor, fabric, "Pattern")
			end
		elseif a.Pattern == "Stripe" then
			for i = 1, a.Repeats do
				b.block("Stripe_" .. i, Vector3.new(s.X, thickness, s.Z / a.Repeats * .4), Vector3.new(0, y, -s.Z / 2 + s.Z / a.Repeats * (i - .5)), a.PatternColor, fabric, "Pattern")
			end
		else
			for x = 1, a.Repeats do
				for z = 1, a.Repeats do
					if (x + z) % 2 == 0 then
						b.block("Check_" .. x .. "_" .. z, Vector3.new(s.X / a.Repeats, thickness, s.Z / a.Repeats), Vector3.new(-s.X / 2 + s.X / a.Repeats * (x - .5), y, -s.Z / 2 + s.Z / a.Repeats * (z - .5)), a.PatternColor, fabric, "Pattern")
					end
				end
			end
		end
	end
	b.anchor()
end

return Generator
