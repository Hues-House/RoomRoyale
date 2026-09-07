"""Validate actual mesh records and GLB containers without a Roblox upload."""
import json
import math
import struct
from pathlib import Path

root=Path(__file__).parent/'assets'
manifest=json.loads((root/'mesh-manifest.json').read_text())
report={}
for row in manifest:
    data=json.loads((root/row['file']).read_text())
    vertices=data['vertices']
    assert len(vertices)==len(data['normals'])==len(data['uvs'])
    assert all(math.isfinite(x) for field in ['vertices','normals','uvs'] for v in data[field] for x in v)
    assert len(data['triangles'])<20000
    for tri in data['triangles']:
        assert len(set(tri))==3 and min(tri)>=0 and max(tri)<len(vertices)
    item=report.setdefault(row['asset'],{'parts':0,'triangles':0,'low':[math.inf]*3,'high':[-math.inf]*3})
    item['parts']+=1
    item['triangles']+=len(data['triangles'])
    for axis in range(3):
        item['low'][axis]=min(item['low'][axis],min(v[axis] for v in vertices))
        item['high'][axis]=max(item['high'][axis],max(v[axis] for v in vertices))
for name,item in report.items():
    assert abs(item['low'][1])<1e-5, (name,'floating geometry',item['low'])
    item['dimensionsStuds']=[round(hi-lo,4) for lo,hi in zip(item.pop('low'),item.pop('high'))]
    blob=(root/(name+'.glb')).read_bytes()
    magic,version,length=struct.unpack_from('<III',blob)
    assert magic==0x46546c67 and version==2 and length==len(blob)
    n,kind=struct.unpack_from('<II',blob,12)
    assert kind==0x4e4f534a
    doc=json.loads(blob[20:20+n])
    assert doc['meshes'] and doc['materials']
    item['glbBytes']=length
out=Path(__file__).parent/'verification.json'
out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
