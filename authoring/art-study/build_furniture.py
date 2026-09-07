"""Build the first two mesh art candidates in a separate Blender scene.

Run with Blender MCP. Existing scenes and their objects are retained.
Coordinates are Roblox studs, displayed as 0.28 meter units in Blender.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path("D:/code/RoomRoyale/authoring/art-study")
OUT = ROOT / "assets"
OUT.mkdir(parents=True, exist_ok=True)
SCENE_NAME = "Room Royale | mesh art study"
if bpy.data.scenes.get(SCENE_NAME):
    raise RuntimeError("Study scene already exists. Retain it before rebuilding.")
scene = bpy.data.scenes.new(SCENE_NAME)
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = .28
bpy.context.window.scene = scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 40
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.world = bpy.data.worlds.new("RR studio daylight")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.65, .72, .8, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .45

def linear(rgb):
    return tuple((v / 255 / 12.92 if v / 255 <= .04045 else ((v / 255 + .055) / 1.055) ** 2.4) for v in rgb)

def material(name, rgb, roughness, weave=False, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*linear(rgb), 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = m.diffuse_color
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Metallic"].default_value = metallic
    m["srgb"] = list(rgb)
    m["roughness"] = roughness
    if weave:
        noise = m.node_tree.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 145
        noise.inputs["Detail"].default_value = 2
        bump = m.node_tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = .23
        bump.inputs["Distance"].default_value = .022
        m.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        m.node_tree.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    return m

clay = material("RR Burnt sienna wool", (170, 83, 58), .88, True)
seam = material("RR Dark piping", (116, 53, 37), .85)
ochre = material("RR Ochre woven cushion", (192, 146, 62), .88, True)
walnut = material("RR Smoked walnut", (85, 55, 37), .4)
cane = material("RR Honey cord", (191, 158, 101), .76)
bronze = material("RR Dark bronze", (53, 54, 49), .55, metallic=.3)
assets = {}
current = None

def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.validate()
    data.update()
    obj = bpy.data.objects.new(name, data)
    current.objects.link(obj)
    data.materials.append(mat)
    for p in data.polygons:
        p.use_smooth = True
    return obj

def sp(value, exponent):
    return math.copysign(abs(value) ** exponent, value)

def puff(name, radii, position, mat, e1=.6, e2=.65, bend=0, rotation=None, nu=64, nv=24):
    vertices, faces = [], []
    for j in range(nv + 1):
        v = -math.pi / 2 + math.pi * j / nv
        for i in range(nu):
            u = math.tau * i / nu
            x = radii[0] * sp(math.cos(v), e1) * sp(math.cos(u), e2)
            y = radii[1] * sp(math.cos(v), e1) * sp(math.sin(u), e2)
            z = radii[2] * sp(math.sin(v), e1)
            y += bend * (x / radii[0]) ** 2
            p = Vector((x, y, z))
            if rotation is not None:
                p = rotation @ p
            vertices.append(tuple(p + Vector(position)))
    for j in range(nv):
        for i in range(nu):
            k = j * nu + i
            nxt = j * nu + (i + 1) % nu
            faces.append((k, nxt, nxt + nu, k + nu))
    return mesh(name, vertices, faces, mat)

def curve_points(control, steps=10):
    pts = [Vector(control[0])] + [Vector(p) for p in control] + [Vector(control[-1])]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i-1:i+3]
        for j in range(steps):
            t = j / steps
            out.append(.5 * ((2*p1) + (-p0+p2)*t + (2*p0-5*p1+4*p2-p3)*t*t + (-p0+3*p1-3*p2+p3)*t*t*t))
    out.append(Vector(control[-1]))
    return out

def tube(name, path, radius, mat, sides=12, radius_end=None):
    vertices, faces = [], []
    previous_normal = None
    for i, p in enumerate(path):
        tangent = (path[min(i+1,len(path)-1)] - path[max(i-1,0)]).normalized()
        if previous_normal is None:
            ref = Vector((0, 0, 1)) if abs(tangent.z) < .9 else Vector((0, 1, 0))
            n = tangent.cross(ref).normalized()
        else:
            n = (previous_normal - tangent * previous_normal.dot(tangent)).normalized()
        previous_normal = n
        b = tangent.cross(n).normalized()
        r = radius if radius_end is None else radius + (radius_end-radius)*i/(len(path)-1)
        for j in range(sides):
            a = math.tau*j/sides
            vertices.append(tuple(p + r*(n*math.cos(a)+b*math.sin(a))))
    for i in range(len(path)-1):
        for j in range(sides):
            k = i*sides+j
            faces.append((k,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,k+sides))
    faces.extend([tuple(reversed(range(sides))), tuple((len(path)-1)*sides+j for j in range(sides))])
    return mesh(name, vertices, faces, mat)

def group(key):
    global current
    current = bpy.data.collections.new(key)
    scene.collection.children.link(current)
    assets[key] = current

group("rr_crescent_sofa_v2")
puff("Recessed walnut plinth", (5.1,2.1,.32), (0,0,.56), walnut, e1=.35, e2=.65, bend=.22)
puff("Concealed seat support", (4.5,1.8,.17), (0,0,.97), walnut, e1=.35,e2=.65)
for x in [-3.8,3.8]:
    for y in [-1.15,1.15]:
        puff("Attached rectangular support", (.24,.28,.36), (x,y,.36), bronze, e1=.18,e2=.18,nu=24,nv=12)
puff("Single deep bench cushion", (4.8,2.05,.55), (0,-.27,1.58), clay, e1=.5, e2=.7, bend=.25)
outline = []
for i in range(129):
    t = math.tau*i/128
    x, y = 4.82*sp(math.cos(t),.7), 2.07*sp(math.sin(t),.7)
    outline.append(Vector((x,y-.27+.25*(x/4.8)**2,1.71)))
tube("Continuous seat welt", outline, .023, seam, sides=6)
back_path = curve_points([(-5,-1.15,0),(-5.18,.2,0),(-4.45,1.6,0),(-2.5,2.05,0),(0,2.2,0),(2.5,2.05,0),(4.45,1.6,0),(5.18,.2,0),(5,-1.15,0)],12)
verts, faces = [], []
for i, p in enumerate(back_path):
    t = i/(len(back_path)-1)
    tangent = (back_path[min(i+1,len(back_path)-1)]-back_path[max(i-1,0)]).normalized()
    normal = Vector((-tangent.y,tangent.x,0))
    top = 3.25 + 1.3*math.sin(math.pi*t)**.65
    half, zc = (top-.85)/2, (top+.85)/2
    end = min(1, math.sin(math.pi/2*min(t,1-t)/.05)) if min(t,1-t)<.05 else 1
    end = max(.05,end)
    for j in range(28):
        a = math.tau*j/28
        verts.append(tuple(p + normal*(.58*sp(math.cos(a),.68)*end) + Vector((0,0,zc+half*sp(math.sin(a),.7)*end))))
for i in range(len(back_path)-1):
    for j in range(28):
        faces.append((i*28+j,i*28+(j+1)%28,(i+1)*28+(j+1)%28,(i+1)*28+j))
faces.extend([tuple(reversed(range(28))),tuple((len(back_path)-1)*28+j for j in range(28))])
mesh("Sweeping upholstered shell", verts, faces, clay)
for x,angle,mat in [(-3.2,-.18,ochre),(3.0,.2,clay)]:
    rot = Matrix.Rotation(angle,3,"Y") @ Matrix.Rotation(-.18,3,"X")
    puff("Loose scatter cushion", (1.03,.36,.93), (x,1.0,2.9), mat, e1=.6,e2=.56,rotation=rot,nu=40,nv=20)

group("rr_loop_bentwood_chair_v2")
# The rear legs and back form one continuous steam-bent hoop.
hoop = curve_points([(-1.25,1.0,.03),(-1.15,1.05,2.2),(-1.25,1.16,3.8),(-.92,1.2,4.55),(0,1.23,4.85),(.92,1.2,4.55),(1.25,1.16,3.8),(1.15,1.05,2.2),(1.25,1,.03)],12)
tube("Continuous bentwood back hoop",hoop,.125,walnut,sides=14)
for side in [-1,1]:
    tube("Splayed front leg",curve_points([(side*1.23,-1.28,.03),(side*1.12,-1.03,1.5),(side*1.04,-.91,2.25)],10),.105,walnut,sides=12,radius_end=.14)
    tube("Curved arm rail",curve_points([(side*1.04,-.91,2.25),(side*1.43,-.72,2.85),(side*1.53,.35,3.08),(side*1.19,1.1,3.25)],10),.09,walnut,sides=12)
    tube("Side stretcher",curve_points([(side*1.18,-1.15,.7),(side*1.11,0,.57),(side*1.18,1.03,.7)],8),.065,walnut,sides=10)
seat_ring=[Vector((1.28*math.cos(math.tau*i/80),1.28*math.sin(math.tau*i/80)-.05,2.18)) for i in range(81)]
tube("Round seat frame",seat_ring,.13,walnut,sides=12)
puff("Woven seat pad",(1.16,1.16,.12),(0,-.05,2.22),cane,e1=.45,e2=1,nu=56,nv=12)
inner=curve_points([(-.93,1.18,2.5),(-.98,1.2,3.75),(-.72,1.21,4.22),(0,1.22,4.43),(.72,1.21,4.22),(.98,1.2,3.75),(.93,1.18,2.5)],10)
tube("Inner back loop",inner,.075,walnut,sides=10)
for i in range(-6,7):
    x=i*.128
    ztop=4.35-.38*(abs(x)/.9)**2
    tube("Back cord",curve_points([(x,1.18,2.53),(x,1.13,3.2),(x,1.2,ztop)],5),.025,cane,sides=6)
for j in range(8):
    z=2.63+j*.19
    tube("Cross weave",curve_points([(-.9,1.19,z),(0,1.09,z-.035),(.9,1.19,z)],6),.018,cane,sides=6)
tube("Seat rear brace",[Vector((-.93,1.18,2.5)),Vector((.93,1.18,2.5))],.09,walnut,sides=10)

# Keep asset coordinates local, with presentation offsets on their collection instances.
stage=bpy.data.collections.new("RR presentation")
scene.collection.children.link(stage)
for key,offset in [("rr_crescent_sofa_v2",(-5,0,0)),("rr_loop_bentwood_chair_v2",(4.3,-.5,0))]:
    inst=bpy.data.objects.new(key+" display",None)
    inst.instance_type="COLLECTION"
    inst.instance_collection=assets[key]
    inst.location=offset
    stage.objects.link(inst)
    scene.collection.children.unlink(assets[key])

def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()

camera_data=bpy.data.cameras.new("RR review camera")
camera=bpy.data.objects.new("RR review camera",camera_data)
stage.objects.link(camera)
camera.location=(15,-23,13)
camera_data.type="ORTHO"
camera_data.ortho_scale=24
aim(camera,(-1,0,2))
scene.camera=camera
for name,pos,power,size in [("Key",(-6,-8,13),2200,10),("Fill",(9,-2,8),1200,8),("Rim",(-5,6,11),1900,7)]:
    d=bpy.data.lights.new(name,"AREA")
    d.energy,d.shape,d.size=power,"DISK",size
    o=bpy.data.objects.new(name,d)
    o.location=pos
    aim(o,(-2,0,2))
    stage.objects.link(o)
current=stage
floor=mesh("Neutral review floor",[(-30,-25,-.03),(30,-25,-.03),(30,25,-.03),(-30,25,-.03)],[(0,1,2,3)],material("RR backdrop",(204,201,190),.85))
scene.render.filepath=str(OUT/"furniture-review.png")
bpy.context.view_layer.update()
bpy.data.libraries.write(str(OUT/"furniture-study.blend"),{scene},path_remap="RELATIVE_ALL",fake_user=True,compress=True)
result={"scene":scene.name,"assets":{k:len(v.objects) for k,v in assets.items()},"blend":str(OUT/"furniture-study.blend")}
