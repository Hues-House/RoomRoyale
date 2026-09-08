--!strict
-- Generated from authoring/cart-flatbed/flatbed_spec.py by build_flatbed.py.
local Flatbed = {}
local MATERIALS = {Orange = {rgb = {236, 102, 29}, roughness = 0.32, metallic = 0.12, roblox = "SmoothPlastic", reflectance = 0.04}, Steel = {rgb = {151, 165, 170}, roughness = 0.3, metallic = 0.75, roblox = "Metal", reflectance = 0.12}, Deck = {rgb = {193, 201, 202}, roughness = 0.35, metallic = 0.7, roblox = "Metal", reflectance = 0.09}, Rubber = {rgb = {36, 44, 49}, roughness = 0.73, metallic = 0, roblox = "SmoothPlastic", reflectance = 0}, Grip = {rgb = {64, 57, 49}, roughness = 0.64, metallic = 0, roblox = "SmoothPlastic", reflectance = 0}}
local PIECES = {
    {name = "Rail_Left", shape = "Cylinder", position = {-2.3, -0.815, 0}, size = {6.4, 0.23, 0.23}, axis = {0, 0, 1}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Rail_Right", shape = "Cylinder", position = {2.3, -0.815, 0}, size = {6.4, 0.23, 0.23}, axis = {0, 0, 1}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Rail_Front", shape = "Cylinder", position = {0, -0.815, -3.2}, size = {4.6, 0.23, 0.23}, axis = {1, 0, 0}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Corner_FrontL", shape = "Ball", position = {-2.3, -0.815, -3.2}, size = {0.23, 0.23, 0.23}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Corner_FrontR", shape = "Ball", position = {2.3, -0.815, -3.2}, size = {0.23, 0.23, 0.23}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Rail_Rear", shape = "Cylinder", position = {0, -0.815, 3.2}, size = {4.6, 0.23, 0.23}, axis = {1, 0, 0}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Corner_RearL", shape = "Ball", position = {-2.3, -0.815, 3.2}, size = {0.23, 0.23, 0.23}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "Corner_RearR", shape = "Ball", position = {2.3, -0.815, 3.2}, size = {0.23, 0.23, 0.23}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_01", shape = "Cylinder", position = {-1.8, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_02", shape = "Cylinder", position = {-1.2, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_03", shape = "Cylinder", position = {-0.6, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_04", shape = "Cylinder", position = {0, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_05", shape = "Cylinder", position = {0.6, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_06", shape = "Cylinder", position = {1.2, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckWire_07", shape = "Cylinder", position = {1.8, -0.755, 0}, size = {6.26, 0.11, 0.11}, axis = {0, 0, 1}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckCross_01", shape = "Cylinder", position = {0, -0.78, -2.1}, size = {4.5, 0.11, 0.11}, axis = {1, 0, 0}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckCross_02", shape = "Cylinder", position = {0, -0.78, -0.7}, size = {4.5, 0.11, 0.11}, axis = {1, 0, 0}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckCross_03", shape = "Cylinder", position = {0, -0.78, 0.7}, size = {4.5, 0.11, 0.11}, axis = {1, 0, 0}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "DeckCross_04", shape = "Cylinder", position = {0, -0.78, 2.1}, size = {4.5, 0.11, 0.11}, axis = {1, 0, 0}, material = "Deck", parent = "VisualRoot", motor = nil},
    {name = "ChassisRail_L", shape = "Block", position = {-1.75, -0.97, 0}, size = {0.23, 0.25, 5.9}, material = "Steel", parent = "VisualRoot", motor = nil},
    {name = "HandleSocket_L", shape = "Block", position = {-1.75, -0.78, 2.82}, size = {0.38, 0.31, 0.48}, material = "Steel", parent = "VisualRoot", motor = nil},
    {name = "HandleUpright_L", shape = "Cylinder", position = {-1.75, 0.375, 3.135}, size = {2.43298, 0.28, 0.28}, axis = {0, 0.965893, 0.258942}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "HandleElbow_L", shape = "Ball", position = {-1.75, 1.55, 3.45}, size = {0.28, 0.28, 0.28}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "ChassisRail_R", shape = "Block", position = {1.75, -0.97, 0}, size = {0.23, 0.25, 5.9}, material = "Steel", parent = "VisualRoot", motor = nil},
    {name = "HandleSocket_R", shape = "Block", position = {1.75, -0.78, 2.82}, size = {0.38, 0.31, 0.48}, material = "Steel", parent = "VisualRoot", motor = nil},
    {name = "HandleUpright_R", shape = "Cylinder", position = {1.75, 0.375, 3.135}, size = {2.43298, 0.28, 0.28}, axis = {0, 0.965893, 0.258942}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "HandleElbow_R", shape = "Ball", position = {1.75, 1.55, 3.45}, size = {0.28, 0.28, 0.28}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "HandleBar", shape = "Cylinder", position = {0, 1.55, 3.45}, size = {3.5, 0.28, 0.28}, axis = {1, 0, 0}, material = "Orange", parent = "VisualRoot", motor = nil},
    {name = "HandleGrip", shape = "Cylinder", position = {0, 1.55, 3.45}, size = {2.36, 0.344, 0.344}, axis = {1, 0, 0}, material = "Grip", parent = "VisualRoot", motor = nil},
    {name = "Caster_FL", shape = "Block", position = {-1.75, -1.16, -2.35}, size = {0.78, 0.24, 0.55}, material = "Steel", parent = "VisualRoot", motor = "CasterMount_FL"},
    {name = "Fork_FLL", shape = "Block", position = {-2.05, -1.52, -2.22}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_FL", motor = nil},
    {name = "Fork_FLR", shape = "Block", position = {-1.45, -1.52, -2.22}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_FL", motor = nil},
    {name = "Wheel_FL", shape = "Cylinder", position = {-1.75, -1.85, -2.2}, size = {0.44, 1.3, 1.3}, axis = {1, 0, 0}, material = "Rubber", parent = "Caster_FL", motor = "WheelMount_FL"},
    {name = "WheelHub_FL", shape = "Cylinder", position = {-1.75, -1.85, -2.2}, size = {0.55, 0.38, 0.38}, axis = {1, 0, 0}, material = "Deck", parent = "Wheel_FL", motor = nil},
    {name = "Caster_FR", shape = "Block", position = {1.75, -1.16, -2.35}, size = {0.78, 0.24, 0.55}, material = "Steel", parent = "VisualRoot", motor = "CasterMount_FR"},
    {name = "Fork_FRL", shape = "Block", position = {1.45, -1.52, -2.22}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_FR", motor = nil},
    {name = "Fork_FRR", shape = "Block", position = {2.05, -1.52, -2.22}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_FR", motor = nil},
    {name = "Wheel_FR", shape = "Cylinder", position = {1.75, -1.85, -2.2}, size = {0.44, 1.3, 1.3}, axis = {1, 0, 0}, material = "Rubber", parent = "Caster_FR", motor = "WheelMount_FR"},
    {name = "WheelHub_FR", shape = "Cylinder", position = {1.75, -1.85, -2.2}, size = {0.55, 0.38, 0.38}, axis = {1, 0, 0}, material = "Deck", parent = "Wheel_FR", motor = nil},
    {name = "Caster_RL", shape = "Block", position = {-1.75, -1.16, 2.35}, size = {0.78, 0.24, 0.55}, material = "Steel", parent = "VisualRoot", motor = "CasterMount_RL"},
    {name = "Fork_RLL", shape = "Block", position = {-2.05, -1.52, 2.48}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_RL", motor = nil},
    {name = "Fork_RLR", shape = "Block", position = {-1.45, -1.52, 2.48}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_RL", motor = nil},
    {name = "Wheel_RL", shape = "Cylinder", position = {-1.75, -1.85, 2.5}, size = {0.44, 1.3, 1.3}, axis = {1, 0, 0}, material = "Rubber", parent = "Caster_RL", motor = "WheelMount_RL"},
    {name = "WheelHub_RL", shape = "Cylinder", position = {-1.75, -1.85, 2.5}, size = {0.55, 0.38, 0.38}, axis = {1, 0, 0}, material = "Deck", parent = "Wheel_RL", motor = nil},
    {name = "Caster_RR", shape = "Block", position = {1.75, -1.16, 2.35}, size = {0.78, 0.24, 0.55}, material = "Steel", parent = "VisualRoot", motor = "CasterMount_RR"},
    {name = "Fork_RRL", shape = "Block", position = {1.45, -1.52, 2.48}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_RR", motor = nil},
    {name = "Fork_RRR", shape = "Block", position = {2.05, -1.52, 2.48}, size = {0.12, 0.78, 0.37}, material = "Steel", parent = "Caster_RR", motor = nil},
    {name = "Wheel_RR", shape = "Cylinder", position = {1.75, -1.85, 2.5}, size = {0.44, 1.3, 1.3}, axis = {1, 0, 0}, material = "Rubber", parent = "Caster_RR", motor = "WheelMount_RR"},
    {name = "WheelHub_RR", shape = "Cylinder", position = {1.75, -1.85, 2.5}, size = {0.55, 0.38, 0.38}, axis = {1, 0, 0}, material = "Deck", parent = "Wheel_RR", motor = nil},
}

local function vector(value): Vector3
    return Vector3.new(value[1], value[2], value[3])
end

local function cosmetic(name: string): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = false
    part.Massless = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    return part
end

local function motor(name: string, parent: BasePart, child: BasePart): Motor6D
    local joint = Instance.new("Motor6D")
    joint.Name = name
    joint.Part0 = parent
    joint.Part1 = child
    joint.C0 = parent.CFrame:ToObjectSpace(child.CFrame)
    joint.C1 = CFrame.identity
    joint.Parent = child
    joint:SetAttribute("RestC0", joint.C0)
    return joint
end

function Flatbed.build(cart: Model, body: BasePart): BasePart
    local previous = cart:FindFirstChild("VisualRoot")
    if previous and previous:GetAttribute("FlatbedOwned") == true then previous:Destroy() end
    local root = cosmetic("VisualRoot")
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1
    root.CastShadow = false
    root.CFrame = body.CFrame
    root:SetAttribute("FlatbedOwned", true)
    root.Parent = cart
    motor("VisualMount", body, root)
    body.Transparency = 1
    local byName: {[string]: BasePart} = {VisualRoot = root}
    for _, piece in PIECES do
        local part = cosmetic(piece.name)
        part.Shape = Enum.PartType[piece.shape]
        part.Size = vector(piece.size)
        local localFrame = CFrame.new(vector(piece.position))
        if piece.axis then
            local right = vector(piece.axis)
            local reference = if math.abs(right.Y) < 0.95 then Vector3.yAxis else Vector3.zAxis
            local up = (reference - right * reference:Dot(right)).Unit
            localFrame = CFrame.fromMatrix(vector(piece.position), right, up, right:Cross(up))
        end
        part.CFrame = root.CFrame * localFrame
        local material = MATERIALS[piece.material]
        part.Color = Color3.fromRGB(material.rgb[1], material.rgb[2], material.rgb[3])
        part.Material = Enum.Material[material.roblox]
        part.Reflectance = material.reflectance
        part.Parent = root
        local parent = byName[piece.parent]
        if piece.motor then
            local joint = motor(piece.motor, parent, part)
            joint:SetAttribute("Axis", if string.sub(piece.motor, 1, 5) == "Wheel" then "X" else "Y")
        else
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = parent
            weld.Part1 = part
            weld.Parent = part
        end
        byName[piece.name] = part
    end
    for name, position in {HandleLeft = {-0.95, 1.55, 3.45}, HandleRight = {0.95, 1.55, 3.45}} do
        local attachment = Instance.new("Attachment")
        attachment.Name = name
        attachment.Position = vector(position)
        attachment.Parent = root
    end
    cart:SetAttribute("CargoDeckY", -0.7)
    cart:SetAttribute("WheelRadius", 0.65)
    cart:SetAttribute("FlatbedCosmeticParts", #PIECES + 1)
    return root
end

return Flatbed
