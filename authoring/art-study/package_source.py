"""Package geometry and importer as an importable Studio XML model, without asset IDs."""
import json
from pathlib import Path
from xml.etree import ElementTree as ET

root=Path(__file__).parent
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
for name,file in [('ImportReview','ImportReview.lua'),('BuildGallery','BuildGallery.lua')]:
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
assert len(check.findall('.//Item[@class="ModuleScript"]'))==12
print(f'{out}: {out.stat().st_size:,} bytes, 10 mesh records, importer and gallery')
