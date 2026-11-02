"""Validate source mapping, serialized scripts, and deterministic Rojo output.

Uses only the Python standard library. This checks the build artifact, not Roblox
runtime behavior; Studio playtests are still required.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


MAPPINGS = {
    ("ReplicatedStorage", "Shared"): "src/shared",
    ("ServerScriptService", "Server"): "src/server",
    ("StarterPlayer", "StarterPlayerScripts", "Client"): "src/client",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def instance_name(item):
    return item.findtext("Properties/string[@name='Name']")


def find_child(parent, name):
    matches = [item for item in parent.findall("Item") if instance_name(item) == name]
    require(len(matches) == 1, f"Expected exactly one instance named {name!r}")
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("place", type=Path)
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()
    project = json.loads(args.project.read_text(encoding="utf-8-sig"))
    repo = args.project.resolve().parent
    require(project["tree"]["$className"] == "DataModel", "Project must build a DataModel")
    root = ET.parse(args.place).getroot()
    require(root.tag == "roblox", "Build must be Roblox XML")
    counts = {"Script": 0, "LocalScript": 0, "ModuleScript": 0}
    for route, source_path in MAPPINGS.items():
        node = project["tree"]
        parent = root
        for name in route:
            node = node[name]
            parent = find_child(parent, name)
        require(node.get("$path") == source_path, f"Unexpected source mapping for {'/'.join(route)}")
        source_dir = repo / source_path
        require(source_dir.is_dir(), f"Missing source folder {source_path}")
        sources = list(source_dir.rglob("*.luau")) + list(source_dir.rglob("*.lua"))
        require(sources, f"No scripts in {source_path}")
        for source in sources:
            relative = source.relative_to(source_dir)
            filename = relative.name
            kind = "LocalScript" if filename.endswith((".client.luau", ".client.lua")) else (
                "Script" if filename.endswith((".server.luau", ".server.lua")) else "ModuleScript")
            stem = filename.rsplit(".", 1)[0]
            if kind != "ModuleScript":
                stem = stem.rsplit(".", 1)[0]
            item = parent
            for folder in relative.parts[:-1]:
                item = find_child(item, folder)
            # Rojo's init scripts replace their containing folder.
            if stem != "init":
                item = find_child(item, stem)
            require(item.get("class") == kind, f"Wrong instance class for {relative}")
            actual = item.findtext("Properties/*[@name='Source']", default="")
            expected = source.read_text(encoding="utf-8-sig")
            require(actual == expected, f"Serialized source differs for {source}")
            counts[kind] += 1
    for kind, count in counts.items():
        actual_count = len(root.findall(f".//Item[@class='{kind}']"))
        require(actual_count == count, f"Unexpected {kind} count: {actual_count} (source has {count})")
        require(count > 0, f"Build must include at least one {kind}")
    require(find_child(root, "Workspace").get("class") == "Workspace", "Missing Workspace")
    digest = hashlib.sha256(args.place.read_bytes()).hexdigest()
    if args.compare:
        require(args.place.read_bytes() == args.compare.read_bytes(), "Repeated build is not byte-identical")
    print(f"PASS place mapping/source smoke: {counts}; SHA256 {digest}")
    if args.compare:
        print("PASS repeated build is byte-identical")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, ET.ParseError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
