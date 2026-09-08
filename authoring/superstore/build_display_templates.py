"""Reuse the recorded private furniture study assets without uploading anything."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
rows = json.loads((ROOT / "authoring/art-study/private-assets.json").read_text())
doc = ET.Element("roblox", version="4")
folder = ET.SubElement(doc, "Item", attrib={"class": "Folder"})
props = ET.SubElement(folder, "Properties")
ET.SubElement(props, "string", name="Name").text = "DesignerFurniture"
models = {}


def value(parent, kind, name, text):
    ET.SubElement(parent, kind, name=name).text = str(text)


def vector(parent, name, xyz):
    v = ET.SubElement(parent, "Vector3", name=name)
    for axis, number in zip("XYZ", xyz):
        ET.SubElement(v, axis).text = str(number)


for row in rows:
    if row["asset"] not in models:
        model = ET.SubElement(folder, "Item", attrib={"class": "Model"})
        value(ET.SubElement(model, "Properties"), "string", "Name", row["asset"])
        models[row["asset"]] = model
    part = ET.SubElement(models[row["asset"]], "Item", attrib={"class": "MeshPart"})
    p = ET.SubElement(part, "Properties")
    value(p, "string", "Name", row["name"])
    white = ET.SubElement(p, "Color3", name="Color")
    for component in "RGB":
        ET.SubElement(white, component).text = "1"
    for key, flag in {"Anchored": True, "CanCollide": False, "CanTouch": False, "CanQuery": False}.items():
        value(p, "bool", key, str(flag).lower())
    vector(p, "Size", row["size"])
    vector(p, "InitialSize", row["size"])
    content = ET.SubElement(p, "Content", name="MeshId")
    ET.SubElement(content, "url").text = f"rbxassetid://{row['mesh']}"
    cf = ET.SubElement(p, "CoordinateFrame", name="CFrame")
    for axis, number in zip("XYZ", row["center"]):
        ET.SubElement(cf, axis).text = str(number)
    for i in range(3):
        for j in range(3):
            ET.SubElement(cf, f"R{i}{j}").text = "1" if i == j else "0"
    surface = ET.SubElement(part, "Item", attrib={"class": "SurfaceAppearance"})
    sp = ET.SubElement(surface, "Properties")
    for role, asset_id in row["maps"].items():
        content = ET.SubElement(sp, "Content", name=role)
        ET.SubElement(content, "url").text = f"rbxassetid://{asset_id}"

path = ROOT / "authoring/superstore/designer-furniture.rbxmx"
ET.indent(doc)
ET.ElementTree(doc).write(path, encoding="utf-8", xml_declaration=True)
print(f"Wrote {len(models)} models, {len(rows)} mesh parts to {path}")
