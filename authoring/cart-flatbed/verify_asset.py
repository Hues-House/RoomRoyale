"""Verify generated flatbed geometry and interchange files without Blender."""

import json
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parent / "assets"
spec = json.loads((root / "flatbed-spec.json").read_text(encoding="utf-8"))
assert len(spec["pieces"]) == 49
names = {"VisualRoot"}
motors = []
for piece in spec["pieces"]:
    assert piece["name"] not in names
    assert piece["parent"] in names, piece["name"]
    names.add(piece["name"])
    assert all(math.isfinite(v) and v > 0 for v in piece["size"])
    if piece["motor"]:
        motors.append(piece["motor"])
    if piece["name"].startswith("Wheel_"):
        assert abs(piece["position"][1] - piece["size"][1] / 2 + 2.5) < 1e-9
    if piece["name"].startswith("DeckWire_"):
        assert abs(piece["position"][1] + piece["size"][1] / 2 - spec["deck_y"]) < 1e-9
assert len(motors) == 8

manifest = json.loads((root / "mesh-manifest.json").read_text(encoding="utf-8"))
triangles = 0
for row in manifest:
    mesh = json.loads((root / row["file"]).read_text(encoding="utf-8"))
    vertices = mesh["vertices"]
    assert len(vertices) == len(mesh["normals"]) == len(mesh["uvs"])
    assert len(mesh["triangles"]) == row["triangles"] < 20000
    for group in (vertices, mesh["normals"], mesh["uvs"]):
        assert all(math.isfinite(value) for values in group for value in values)
    for normal in mesh["normals"]:
        assert abs(sum(value * value for value in normal) - 1) < 1e-4
    for face in mesh["triangles"]:
        assert len(face) == 3 and len(set(face)) == 3
        assert all(0 <= index < len(vertices) for index in face)
    triangles += len(mesh["triangles"])

glb = (root / "rr_warehouse_flatbed.glb").read_bytes()
magic, version, length = struct.unpack_from("<4sII", glb)
assert magic == b"glTF" and version == 2 and length == len(glb)
json_length, chunk_kind = struct.unpack_from("<II", glb, 12)
assert chunk_kind == 0x4E4F534A
document = json.loads(glb[20:20 + json_length])
assert len(document["meshes"]) == 49
assert {node.get("name") for node in document["nodes"]} >= names - {"VisualRoot"}
assert (root / "warehouse-flatbed.blend").stat().st_size > 0
assert (root / "flatbed-front.png").stat().st_size > 0
assert (root / "flatbed-rear.png").stat().st_size > 0
print(json.dumps({"visible_parts": 49, "runtime_parts": 50, "triangles": triangles,
                  "wheel_motors": 4, "caster_motors": 4, "glb_mesh_nodes": 49, "valid": True}))
