"""Shared, editable geometry for the Blender asset and the Roblox rendition.

Coordinates are Roblox studs relative to the invisible physics Body.
The cart points toward -Z. Geometry is deliberately limited to 49 visible parts.
"""

from math import sqrt

MATERIALS = {
    "Orange": {"rgb": [236, 102, 29], "roughness": 0.32, "metallic": 0.12, "roblox": "SmoothPlastic", "reflectance": 0.04},
    "Steel": {"rgb": [151, 165, 170], "roughness": 0.3, "metallic": 0.75, "roblox": "Metal", "reflectance": 0.12},
    "Deck": {"rgb": [193, 201, 202], "roughness": 0.35, "metallic": 0.7, "roblox": "Metal", "reflectance": 0.09},
    "Rubber": {"rgb": [36, 44, 49], "roughness": 0.73, "metallic": 0.0, "roblox": "SmoothPlastic", "reflectance": 0.0},
    "Grip": {"rgb": [64, 57, 49], "roughness": 0.64, "metallic": 0.0, "roblox": "SmoothPlastic", "reflectance": 0.0},
}


def specification():
    pieces = []

    def box(name, position, size, material, parent="VisualRoot", motor=None):
        pieces.append(dict(name=name, shape="Block", position=position, size=size,
                           material=material, parent=parent, motor=motor))

    def cylinder(name, a, b, radius, material, parent="VisualRoot", motor=None):
        delta = [b[i] - a[i] for i in range(3)]
        length = sqrt(sum(v * v for v in delta))
        pieces.append(dict(name=name, shape="Cylinder", position=[(a[i] + b[i]) / 2 for i in range(3)],
                           size=[length, radius * 2, radius * 2], axis=[v / length for v in delta],
                           material=material, parent=parent, motor=motor))

    def ball(name, position, radius, material):
        pieces.append(dict(name=name, shape="Ball", position=position, size=[radius * 2] * 3,
                           material=material, parent="VisualRoot", motor=None))

    rail_y = -0.815
    for side, x in (("Left", -2.3), ("Right", 2.3)):
        cylinder("Rail_" + side, [x, rail_y, -3.2], [x, rail_y, 3.2], 0.115, "Orange")
    for end, z in (("Front", -3.2), ("Rear", 3.2)):
        cylinder("Rail_" + end, [-2.3, rail_y, z], [2.3, rail_y, z], 0.115, "Orange")
        for side, x in (("L", -2.3), ("R", 2.3)):
            ball("Corner_" + end + side, [x, rail_y, z], 0.115, "Orange")

    for index in range(7):
        x = (index - 3) * 0.6
        cylinder(f"DeckWire_{index + 1:02}", [x, -0.755, -3.13], [x, -0.755, 3.13], 0.055, "Deck")
    for index in range(4):
        z = -2.1 + index * 1.4
        cylinder(f"DeckCross_{index + 1:02}", [-2.25, -0.78, z], [2.25, -0.78, z], 0.055, "Deck")
    for side, x in (("L", -1.75), ("R", 1.75)):
        box("ChassisRail_" + side, [x, -0.97, 0], [0.23, 0.25, 5.9], "Steel")
        box("HandleSocket_" + side, [x, -0.78, 2.82], [0.38, 0.31, 0.48], "Steel")
        cylinder("HandleUpright_" + side, [x, -0.8, 2.82], [x, 1.55, 3.45], 0.14, "Orange")
        ball("HandleElbow_" + side, [x, 1.55, 3.45], 0.14, "Orange")
    cylinder("HandleBar", [-1.75, 1.55, 3.45], [1.75, 1.55, 3.45], 0.14, "Orange")
    cylinder("HandleGrip", [-1.18, 1.55, 3.45], [1.18, 1.55, 3.45], 0.172, "Grip")

    for code, x, z in (("FL", -1.75, -2.35), ("FR", 1.75, -2.35),
                       ("RL", -1.75, 2.35), ("RR", 1.75, 2.35)):
        caster = "Caster_" + code
        wheel = "Wheel_" + code
        box(caster, [x, -1.16, z], [0.78, 0.24, 0.55], "Steel", motor="CasterMount_" + code)
        for side, offset in (("L", -0.3), ("R", 0.3)):
            box("Fork_" + code + side, [x + offset, -1.52, z + 0.13], [0.12, 0.78, 0.37], "Steel", parent=caster)
        cylinder(wheel, [x - 0.22, -1.85, z + 0.15], [x + 0.22, -1.85, z + 0.15],
                 0.65, "Rubber", parent=caster, motor="WheelMount_" + code)
        cylinder("WheelHub_" + code, [x - 0.275, -1.85, z + 0.15], [x + 0.275, -1.85, z + 0.15],
                 0.19, "Deck", parent=wheel)

    assert len(pieces) == 49, len(pieces)
    return {
        "name": "RoomRoyale warehouse flatbed",
        "units": "Roblox studs, Body-local X/Y/Z, front=-Z",
        "deck_y": -0.7,
        "wheel_radius": 0.65,
        "materials": MATERIALS,
        "pieces": pieces,
        "handles": {"HandleLeft": [-0.95, 1.55, 3.45], "HandleRight": [0.95, 1.55, 3.45]},
    }
