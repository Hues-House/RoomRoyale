"""Package source geometry and private asset references as an importable Studio XML model."""
import json
from pathlib import Path
from xml.etree import ElementTree as ET

root=Path(__file__).parent
uploads=json.loads((root.parents[1]/'docs/evidence/furniture-private-assets.json').read_text())
by_name={row['part']:row for row in uploads.values()}
private=[]
for row in json.loads((root/'assets/mesh-manifest.json').read_text()):
    mesh=json.loads((root/'assets'/row['file']).read_text())
    low=[min(v[i] for v in mesh['vertices']) for i in range(3)]
    high=[max(v[i] for v in mesh['vertices']) for i in range(3)]
    upload=by_name[row['name']]
    private.append(dict(asset=row['asset'],name=row['name'],mesh=upload['mesh'],maps=upload['maps'],material=row['material'],triangles=row['triangles'],center=[(a+b)/2 for a,b in zip(low,high)],size=[b-a for a,b in zip(low,high)]))
private_json=json.dumps(private,indent=2)
(root/'private-assets.json').write_text(private_json+'\n')
(root/'PrivateAssets.lua').write_text('return game:GetService("HttpService"):JSONDecode([=['+private_json+']=])\n')
doc=ET.Element('roblox',version='4')
counter=0
def item(parent,kind,name):
    global counter
    counter+=1
    obj=ET.SubElement(parent,'Item',{'class':kind,'referent':'RBX'+str(counter)})
    props=ET.SubElement(obj,'Properties')
    ET.SubElement(props,'string',name='Name').text=name
    return obj,props
folder,_=item(doc,'Folder','RoomRoyaleMeshStudySource')
for name,file in [('ImportReview','ImportReview.lua'),('BuildGallery','BuildGallery.lua'),('UploadReview','UploadReview.lua'),('PersistentReview','PersistentReview.lua'),('PrivateAssets','PrivateAssets.lua')]:
    _,props=item(folder,'ModuleScript',name)
    code=(root/file).read_text(encoding='utf-8')
    if name=='BuildGallery':code+='\nreturn true\n'
    ET.SubElement(props,'ProtectedString',name='Source').text=code
meshes,_=item(folder,'Folder','Meshes')
manifest=json.loads((root/'assets/mesh-manifest.json').read_text())
for row in manifest:
    data=(root/'assets'/row['file']).read_text(encoding='utf-8')
    chunks=[data[i:i+150000] for i in range(0,len(data),150000)]
    obj,props=item(meshes,'ModuleScript',row['name'])
    ET.SubElement(props,'ProtectedString',name='Source').text=f'local s={{}} for i=1,{len(chunks)} do s[i]=script:FindFirstChild(tostring(i)).Value end return game:GetService("HttpService"):JSONDecode(table.concat(s))'
    for i,chunk in enumerate(chunks,1):
        _,p=item(obj,'StringValue',str(i))
        ET.SubElement(p,'string',name='Value').text=chunk
out=root/'assets/RoomRoyaleMeshStudySource.rbxmx'
ET.indent(doc)
ET.ElementTree(doc).write(out,encoding='utf-8',xml_declaration=True)
check=ET.parse(out).getroot()
assert len(check.findall('.//Item[@class="ModuleScript"]'))==15
print(f'{out}: {out.stat().st_size:,} bytes, 10 mesh records and 5 authoring modules')
