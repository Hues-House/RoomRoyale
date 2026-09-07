"""Keep Forge's ceramic base; rebuild the shade and neck for a clean silhouette."""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

OUT = Path('D:/code/RoomRoyale/authoring/art-study/assets')
scene = bpy.data.scenes['Room Royale | mesh art study']
bpy.context.window.scene = scene
assert not bpy.data.collections.get('rr_tide_lamp_v2'), 'Preserve the prior lamp before rebuilding'
source = bpy.data.collections.get('RR Tide lamp raw imported')
if source is None:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT/'lamp-forge-conformed.glb'))
    source = bpy.data.collections.new('RR Tide lamp raw imported')
    scene.collection.children.link(source)
    for o in set(bpy.data.objects)-before:
        for c in list(o.users_collection): c.objects.unlink(o)
        source.objects.link(o)
coll = bpy.data.collections.new('rr_tide_lamp_v2')
scene.collection.children.link(coll)

def material(name,rgb,roughness,metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*[(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in rgb],1)
    p = mat.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = mat.diffuse_color
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    mat['srgb'],mat['roughness'] = list(rgb),roughness
    return mat

glaze=material('RR Sea green ceramic',(56,132,119),.28)
glaze.node_tree.nodes['Principled BSDF'].inputs['Coat Weight'].default_value=.22
linen=material('RR Warm linen shade',(226,214,186),.9)
bronze=material('RR Lamp bronze',(77,65,43),.32,.7)

def mesh(name,verts,faces,mat):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    data.materials.append(mat)
    for p in data.polygons:p.use_smooth=True
    o=bpy.data.objects.new(name,data)
    coll.objects.link(o)
    return o

original=next(o for o in source.objects if o.type=='MESH')
data=original.data.copy()
data.transform(original.matrix_world)
bm=bmesh.new()
bm.from_mesh(data)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z>1.27],context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(data)
bm.free()
data.materials.clear()
data.materials.append(glaze)
for p in data.polygons:p.use_smooth=True
base=bpy.data.objects.new('Forge ceramic base with thumb hollow',data)
coll.objects.link(base)
base['provenance']='Prop Forge Hunyuan job 20260907084454-yu1i; original base geometry retained'

def revolved(name,profile,mat,n=80):
    verts=[(r*math.cos(math.tau*i/n),r*math.sin(math.tau*i/n),z) for r,z in profile for i in range(n)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    return mesh(name,verts,faces,mat)

revolved('Bronze neck',[(0,1.2),(.20,1.2),(.20,1.33),(.11,1.36),(.11,1.89),(0,1.89)],bronze)
revolved('Tailored linen shade',[(1.09,1.78),(.85,3.14),(.826,3.14),(1.066,1.78),(1.09,1.78)],linen,112)
for r,z in [(1.09,1.79),(.85,3.13)]:
    revolved('Shade bound rim',[(r+.009*math.cos(math.tau*i/8),z+.009*math.sin(math.tau*i/8)) for i in range(9)],linen)
scene.collection.children.unlink(source)
stage=next(c for c in scene.collection.children if c.name.startswith('RR presentation'))
inst=bpy.data.objects.new('rr_tide_lamp_v2 display',None)
inst.instance_type='COLLECTION'
inst.instance_collection=coll
inst.location=(8.5,0,3)
stage.objects.link(inst)
scene.collection.children.unlink(coll)
plinth=mesh('Lamp review plinth',[(-1.7,-1.7,0),(1.7,-1.7,0),(1.7,1.7,0),(-1.7,1.7,0),(-1.7,-1.7,3),(1.7,-1.7,3),(1.7,1.7,3),(-1.7,1.7,3)],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],material('RR Stone plinth',(147,145,131),.8))
coll.objects.unlink(plinth)
stage.objects.link(plinth)
plinth.location=(8.5,0,0)
for p in plinth.data.polygons:p.use_smooth=False
scene.camera.data.ortho_scale=30
scene.camera.location=(17,-28,14)
scene.camera.rotation_euler=(Vector((0,0,2))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'three-piece-review')
bpy.context.view_layer.update()
bpy.data.libraries.write(str(OUT/'furniture-study.blend'),{scene},path_remap='RELATIVE_ALL',fake_user=True,compress=True)
result={'lampParts':len(coll.objects),'scene':scene.name}
