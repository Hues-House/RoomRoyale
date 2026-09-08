"""Sync managed Hillside scripts only. Dry run unless --write is supplied.

Scene instances, properties, extra scripts and existing referents are retained.
XML serialization can change whitespace/escaping without changing property values.
"""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import uuid
import xml.etree.ElementTree as ET


SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
FIELDS = {"Source", "Disabled"}


def parse(path):
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True, insert_pis=True))
    return ET.parse(path, parser=parser)


def index(root):
    nodes = {}

    def walk(parent, path):
        for item in parent.findall("Item"):
            name = item.findtext("Properties/string[@name='Name']", item.get("class"))
            current = path + (name,)
            nodes.setdefault(current, []).append(item)
            walk(item, current)

    walk(root, ())
    return nodes


def one(nodes, path):
    matches = nodes.get(path, [])
    if len(matches) != 1:
        raise ValueError(f"Expected one instance at {'.'.join(path)}; found {len(matches)}")
    return matches[0]


def signature(item):
    props = item.find("Properties")
    source = props.findtext("*[@name='Source']", "")
    source = source.replace("\r\n", "\n").replace("\r", "\n").rstrip("\n") + "\n"
    return (item.get("class"), hashlib.sha256(source.encode()).hexdigest(),
            props.findtext("bool[@name='Disabled']", "false") == "true")


def protected_tree(root, managed, added):
    """Remove only authorized differences before comparing all retained XML."""
    root = copy.deepcopy(root)
    nodes = index(root)
    for path in sorted(added, key=len, reverse=True):
        parent = one(nodes, path[:-1]) if path[:-1] else root
        parent.remove(one(nodes, path))
    nodes = index(root)
    for path in managed - added:
        item = one(nodes, path)
        item.set("class", "ManagedScript")
        props = item.find("Properties")
        for prop in list(props):
            if prop.get("name") in FIELDS:
                props.remove(prop)
    return ET.tostring(root)


def synchronize(build, snapshot):
    expected = index(build.getroot())
    managed = {path for path, rows in expected.items()
               if any(row.get("class") in SCRIPT_CLASSES for row in rows)}
    if not managed:
        raise ValueError("Candidate contains no managed scripts")
    result = copy.deepcopy(snapshot)
    root = result.getroot()
    actual = index(root)
    referents = [node.get("referent") for node in root.iter("Item") if node.get("referent")]
    if len(referents) != len(set(referents)):
        raise ValueError("Snapshot already contains duplicate referents")
    used = set(referents)
    added, updated = set(), []
    for path in sorted(managed, key=lambda value: (len(value), value)):
        source = one(expected, path)
        if path not in actual:
            parent = one(actual, path[:-1]) if path[:-1] else root
            item = copy.deepcopy(source)
            # Descendant scripts are handled separately at their own mapped paths.
            if item.findall("Item"):
                raise ValueError(f"New script has child instances: {'.'.join(path)}")
            if any(ref.text not in (None, "null", "nil") for ref in item.iter("Ref")):
                raise ValueError(f"New script contains an external reference: {'.'.join(path)}")
            referent = "RBX" + uuid.uuid4().hex.upper()
            while referent in used:
                referent = "RBX" + uuid.uuid4().hex.upper()
            item.set("referent", referent)
            used.add(referent)
            parent.append(item)
            actual[path] = [item]
            added.add(path)
            continue
        item = one(actual, path)
        if item.get("class") not in SCRIPT_CLASSES:
            raise ValueError(f"Refusing to replace a scene asset at {'.'.join(path)}")
        if signature(item) == signature(source):
            continue
        item.set("class", source.get("class"))
        props = item.find("Properties")
        for prop in list(props):
            if prop.get("name") in FIELDS:
                props.remove(prop)
        for prop in source.find("Properties"):
            if prop.get("name") in FIELDS:
                props.append(copy.deepcopy(prop))
        updated.append(".".join(path))
    actual = index(root)
    for path in managed:
        if signature(one(actual, path)) != signature(one(expected, path)):
            raise ValueError(f"Managed script mismatch: {'.'.join(path)}")
    before = protected_tree(snapshot.getroot(), managed - added, set())
    after = protected_tree(root, managed, added)
    if before != after:
        raise ValueError("Preservation check failed: unrelated XML changed")
    all_refs = [node.get("referent") for node in root.iter("Item") if node.get("referent")]
    if len(all_refs) != len(set(all_refs)):
        raise ValueError("Result contains duplicate referents")
    return result, {"managedScripts": len(managed), "updated": updated,
                    "added": sorted(".".join(path) for path in added),
                    "scenePreserved": True, "uniqueReferents": True}


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path,
                        default=repo / "build/superstore/RoomRoyale-Hillside-M1-Candidate.rbxlx")
    parser.add_argument("--write", action="store_true", help="Apply the validated changes")
    args = parser.parse_args()
    target = repo / "places/RoomRoyale-Hillside.rbxlx"
    result, report = synchronize(parse(args.build), parse(target))
    report["snapshot"] = str(target)
    report["written"] = False
    if args.write and (report["updated"] or report["added"]):
        with tempfile.NamedTemporaryFile(dir=target.parent, suffix=".rbxlx", delete=False) as output:
            temporary = Path(output.name)
            result.write(output, encoding="utf-8", xml_declaration=True)
        try:
            reparsed = parse(temporary)
            if ET.tostring(reparsed.getroot()) != ET.tostring(result.getroot()):
                raise ValueError("Serialized snapshot did not round-trip")
            temporary.replace(target)
            report["written"] = True
        finally:
            temporary.unlink(missing_ok=True)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
