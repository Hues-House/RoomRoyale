"""Export evaluated Blender meshes and material records for the Studio review bridge."""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path("D:/code/RoomRoyale/authoring/art-study")
OUT = ROOT / "assets"
scene = bpy.data.scenes["Room Royale | mesh art study"]
bpy.context.window.scene = scene
rows = []
for inst in scene.objects:
    if inst.instance_type != "COLLECTION" or not inst.instance_collection:
        continue
    key = inst.name.split(" display")[0]
    coll = inst.instance_collection
    grouped = {}
    low = min((obj.matrix_world @ v.co).z for obj in coll.objects if obj.type == "MESH" for v in obj.data.vertices)
    for obj in coll.objects:
        if obj.type != "MESH":
            continue
        data = obj.data.copy()
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000001)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
        bm.free()
        data.update()
        data.calc_loop_triangles()
        mat = obj.data.materials[0]
        clean_name = mat.name.split(".")[0]
        group = grouped.setdefault(clean_name, {"material":clean_name,"rgb":list(mat.get("srgb",[160,160,160])),"roughness":mat.get("roughness",.65),"metallic":mat.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value,"vertices":[],"normals":[],"uvs":[],"triangles":[]})
        offset = len(group["vertices"])
        for vertex in data.vertices:
            p = obj.matrix_world @ vertex.co
            n = obj.matrix_world.to_3x3() @ vertex.normal
            group["vertices"].append([round(p.x,6),round(p.z-low,6),round(-p.y,6)])
            group["normals"].append([round(n.x,6),round(n.z,6),round(-n.y,6)])
            # Small repeat scale avoids the oversized stock wood grain of the first pass.
            if abs(n.z) >= max(abs(n.x),abs(n.y)):
                uv = (p.x*1.5,p.y*1.5)
            elif abs(n.y) > abs(n.x):
                uv = (p.x*1.5,p.z*1.5)
            else:
                uv = (p.y*1.5,p.z*1.5)
            group["uvs"].append([round(uv[0],6),round(uv[1],6)])
        for triangle in data.loop_triangles:
            if triangle.area > 1e-10:
                group["triangles"].append([offset+i for i in triangle.vertices])
        bpy.data.meshes.remove(data)
    for index,group in enumerate(grouped.values()):
        group["asset"] = key
        group["name"] = key+"_"+str(index+1)
        assert len(group["triangles"]) < 20000
        file = OUT/(group["name"]+".mesh.json")
        file.write_text(json.dumps(group,separators=(",",":")),encoding="utf-8")
        rows.append({"asset":key,"name":group["name"],"file":file.name,"material":group["material"],"vertices":len(group["vertices"]),"triangles":len(group["triangles"])})
    # Export each collection as an ordinary interchange asset as well.
    scene.collection.children.link(coll)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in coll.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(coll.objects))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(key+".glb")),use_selection=True,export_format="GLB")
    scene.collection.children.unlink(coll)
(OUT/"mesh-manifest.json").write_text(json.dumps(rows,indent=2),encoding="utf-8")
result={"parts":rows,"totalTriangles":sum(row["triangles"] for row in rows)}
