"""Run an installed Prop Forge Blender stage against Blender 5.2's exporter.

The installed Forge targets an older exporter with export_colors. Filter only
unsupported export options, and let --python-exit-code catch actual failures.
No installed Forge source is modified.
"""
import sys
import runpy
from pathlib import Path
import bpy

args = sys.argv[sys.argv.index("--") + 1:]
stage = Path(args[0]).resolve()
sys.path.insert(0, str(stage.parent))
import propgen

supported = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
removed = set(propgen.EXPORT_OPTIONS) - supported
print("Blender compatibility: omitted unsupported export options", sorted(removed))
propgen.EXPORT_OPTIONS = {k: v for k, v in propgen.EXPORT_OPTIONS.items() if k in supported}
sys.argv = [str(stage), "--"] + args[1:]
runpy.run_path(str(stage), run_name="__main__")
