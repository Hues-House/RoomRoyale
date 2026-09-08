"""Build a fresh Blender asset, preview, mesh bridge records, and matching Luau.

Run: D:/Blender/blender.exe --background --factory-startup --python-exit-code 1
     --python D:/code/RoomRoyale/authoring/cart-flatbed/build_flatbed.py
"""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from flatbed_spec import specification

if not bpy.app.background:
    raise RuntimeError("Run in a fresh background Blender process; existing interactive scenes are retained")

OUT = ROOT / "assets"
OUT.mkdir(parents=True, exist_ok=True)
spec = specification()
(OUT / "flatbed-spec.json").write_text(json.dumps(spec, indent=2), encoding="utf-8")
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "Room Royale | warehouse flatbed"
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 0.28
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 1280
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.world = bpy.data.worlds.new("Flatbed studio")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.68, 0.73, 0.8, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4


def linear(value):
    value /= 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def point(value):
    return Vector((value[0], -value[2], value[1]))


materials = {}
for name, values in spec["materials"].items():
    material = bpy.data.materials.new("Flatbed " + name)
    material.diffuse_color = (*map(linear, values["rgb"]), 1)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = material.diffuse_color
    shader.inputs["Metallic"].default_value = values["metallic"]
    shader.inputs["Roughness"].default_value = values["roughness"]
    materials[name] = material

asset = bpy.data.collections.new("Flatbed editable components")
scene.collection.children.link(asset)
objects = []
for piece in spec["pieces"]:
    position = point(piece["position"])
    sx, sy, sz = piece["size"]
    shape = piece["shape"]
    if shape == "Cylinder":
        sides = 24 if piece["name"].startswith("Wheel_") else 16
        bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=sy / 2, depth=sx, location=position)
        obj = bpy.context.object
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(point(piece["axis"]))
        for face in obj.data.polygons:
            face.use_smooth = len(face.vertices) == 4
    elif shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=sx / 2, location=position)
        obj = bpy.context.object
        for face in obj.data.polygons:
            face.use_smooth = True
    else:
        bpy.ops.mesh.primitive_cube_add(size=1, location=position)
        obj = bpy.context.object
        obj.scale = (sx, sz, sy)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.name = piece["name"]
    obj.data.materials.append(materials[piece["material"]])
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    asset.objects.link(obj)
    if shape != "Ball":
        bevel = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        bevel.width = min(0.035, min(piece["size"]) * 0.15)
        bevel.segments = 2
        bevel.limit_method = "ANGLE"
    obj["RobloxParent"] = piece["parent"]
    obj["RobloxMotor"] = piece["motor"] or ""
    obj["BodyLocalPosition"] = piece["position"]
    objects.append(obj)

bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()
groups = {}
for piece, obj in zip(spec["pieces"], objects):
    key = piece["material"]
    values = spec["materials"][key]
    group = groups.setdefault(key, {"asset": "rr_warehouse_flatbed", "material": key,
        "rgb": values["rgb"], "roughness": values["roughness"], "metallic": values["metallic"],
        "vertices": [], "normals": [], "uvs": [], "triangles": []})
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    offset = len(group["vertices"])
    for vertex in mesh.vertices:
        p = evaluated.matrix_world @ vertex.co
        n = evaluated.matrix_world.to_3x3() @ vertex.normal
        group["vertices"].append([round(p.x, 6), round(p.z, 6), round(-p.y, 6)])
        group["normals"].append([round(n.x, 6), round(n.z, 6), round(-n.y, 6)])
        group["uvs"].append([round(p.x, 6), round(p.y, 6)])
    for triangle in mesh.loop_triangles:
        if triangle.area > 1e-10:
            group["triangles"].append([offset + i for i in triangle.vertices])
    evaluated.to_mesh_clear()

manifest = []
for index, group in enumerate(groups.values(), 1):
    group["name"] = "rr_warehouse_flatbed_" + str(index)
    filename = group["name"] + ".mesh.json"
    assert len(group["triangles"]) < 20000
    (OUT / filename).write_text(json.dumps(group, separators=(",", ":")), encoding="utf-8")
    manifest.append({"name": group["name"], "file": filename, "material": group["material"],
                     "vertices": len(group["vertices"]), "triangles": len(group["triangles"])})
(OUT / "mesh-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

bpy.ops.object.select_all(action="DESELECT")
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
bpy.ops.export_scene.gltf(filepath=str(OUT / "rr_warehouse_flatbed.glb"), use_selection=True,
                         export_format="GLB", export_apply=True, export_extras=True)


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "{" + ", ".join(lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ", ".join(k + " = " + lua(v) for k, v in value.items()) + "}"
    return f"{value:.6g}"


runtime = '''--!strict
-- Generated from authoring/cart-flatbed/flatbed_spec.py by build_flatbed.py.
local Flatbed = {}
local MATERIALS = __MATERIALS__
local PIECES = {
__PIECES__
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
    for name, position in __HANDLES__ do
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
'''
runtime = runtime.replace("__MATERIALS__", lua(spec["materials"]))
runtime = runtime.replace("__PIECES__", "\n".join("    " + lua(piece) + "," for piece in spec["pieces"]))
runtime = runtime.replace("__HANDLES__", lua(spec["handles"]))
(ROOT.parents[1] / "prototype" / "cart-lab" / "Flatbed.lua").write_text(runtime, encoding="utf-8")

floor_mat = bpy.data.materials.new("Studio warm grey")
floor_mat.diffuse_color = (0.72, 0.73, 0.72, 1)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -2.5))
floor = bpy.context.object
floor.name = "Preview ground, excluded from asset"
floor.data.materials.append(floor_mat)
for name, position, energy, size in (
    ("Key", (3, 4, 9), 1400, 7), ("Fill", (-6, 1, 5), 950, 6), ("Rim", (1, -7, 7), 1200, 5)
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size = energy, "DISK", size
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = position
    light.rotation_euler = (Vector((0, 0, -0.5)) - light.location).to_track_quat("-Z", "Y").to_euler()

camera_data = bpy.data.cameras.new("Flatbed review camera")
camera = bpy.data.objects.new("Flatbed review camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = 10.5
for view, location in (("front", (8, 11, 7)), ("rear", (8, -11, 6))):
    camera.location = location
    camera.rotation_euler = (Vector((0, 0, -0.5)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT / ("flatbed-" + view + ".png"))
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "warehouse-flatbed.blend"))
all_vertices = [vertex for group in groups.values() for vertex in group["vertices"]]
low = [min(vertex[i] for vertex in all_vertices) for i in range(3)]
high = [max(vertex[i] for vertex in all_vertices) for i in range(3)]
verification = {"visible_parts": len(objects), "runtime_parts_with_root": 50,
    "triangles": sum(row["triangles"] for row in manifest), "bounds_min": low, "bounds_max": high,
    "size": [high[i] - low[i] for i in range(3)], "deck_y": -0.7,
    "ground_y": -2.5, "handle_y": 1.55, "wheel_spin_axis": "X", "caster_yaw_axis": "Y"}
assert abs(low[1] + 2.5) < 0.02
(OUT / "verification.json").write_text(json.dumps(verification, indent=2), encoding="utf-8")
print(json.dumps(verification))
