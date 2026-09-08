"""Compare saved Studio scenes to fresh Rojo builds; Python 3 standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


def inventory(path):
    root = ET.parse(path).getroot()
    scripts = {}
    classes = {}

    def walk(item, parent):
        cls = item.get("class")
        props = item.find("Properties")
        name = props.findtext("string[@name='Name']", cls) if props is not None else cls
        current = parent + [name]
        key = ".".join(current)
        classes[cls] = classes.get(cls, 0) + 1
        if cls in ("Script", "LocalScript", "ModuleScript"):
            source = props.findtext("*[@name='Source']", "")
            source = source.replace("\r\n", "\n").replace("\r", "\n").rstrip("\n") + "\n"
            row = {"className": cls, "sha256": hashlib.sha256(source.encode()).hexdigest(),
                   "disabled": props.findtext("bool[@name='Disabled']", "false") == "true"}
            scripts.setdefault(key, []).append(row)
        for child in item.findall("Item"):
            walk(child, current)

    for item in root.findall("Item"):
        walk(item, [])
    return scripts, classes


def verify(repo, name, project, snapshot):
    with tempfile.TemporaryDirectory(prefix="roomroyale-verify-") as temp:
        build = Path(temp) / "source.rbxlx"
        rojo = shutil.which("rojo.exe") or shutil.which("rojo.cmd") if os.name == "nt" else shutil.which("rojo")
        if not rojo:
            raise SystemExit("Install Rojo and add it to PATH before verifying saved places.")
        subprocess.run([rojo, "build", str(repo / project), "--output", str(build)], check=True)
        expected, _ = inventory(build)
    actual, classes = inventory(repo / snapshot)
    failures = []
    for path, rows in expected.items():
        if actual.get(path) != rows:
            failures.append(path)
    extras = {path: rows for path, rows in actual.items() if path not in expected}
    result = {"project": project, "snapshot": snapshot,
              "snapshotSha256": hashlib.sha256((repo / snapshot).read_bytes()).hexdigest(),
              "expectedScripts": sum(map(len, expected.values())),
              "savedScripts": sum(map(len, actual.values())), "mismatches": failures,
              "additionalSavedScripts": extras, "instanceClasses": classes}
    print(f"{name}: {result['expectedScripts']} managed scripts, {len(failures)} mismatches, "
          f"{sum(map(len, extras.values()))} additional saved scripts")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, help="Write verification evidence as JSON")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    results = {
        "main": verify(repo, "Main Test", "default.project.json", "places/RoomRoyale-Test.rbxlx"),
        "hillside": verify(repo, "Hillside", "superstore.project.json", "places/RoomRoyale-Hillside.rbxlx"),
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    raise SystemExit(1 if any(r["mismatches"] for r in results.values()) else 0)
