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
    workspace = find_child(root, "Workspace")
    require(workspace.get("class") == "Workspace", "Missing Workspace")
    # This engine-restricted setting must already exist before server scripts run.
    # Inspect the artifact as well as the project so a valid-looking config that
    # Rojo does not serialize cannot silently restore the engine default.
    destroy_heights = workspace.findall("Properties/*[@name='FallenPartsDestroyHeight']")
    require(len(destroy_heights) == 1, "Workspace must serialize FallenPartsDestroyHeight")
    destroy_height = float(destroy_heights[0].text)
    require(destroy_height == -100, f"Unexpected Workspace destroy height: {destroy_height}")
    configured_height = project["tree"]["Workspace"].get("$properties", {}).get("FallenPartsDestroyHeight")
    require(configured_height == destroy_height, "Workspace destroy height differs from Rojo configuration")
    lighting=find_child(root,"Lighting")
    require(lighting.findtext("Properties/token[@name='LightingStyle']") == "0", "Realistic lighting must serialize")
    require(lighting.findtext("Properties/bool[@name='PrioritizeLightingQuality']") == "true", "Lighting quality priority must serialize")
    require(lighting.findtext("Properties/token[@name='Technology']") == "4", "Future compatibility token must prevent Studio lighting migration")
    materials=find_child(root,"MaterialService")
    material_files=list((repo/"assets/materials").glob("*.model.json"))
    require(len(materials.findall("Item"))==len(material_files)==6,"Expected six curated material variants")
    for source in material_files:
        spec=json.loads(source.read_text())
        name=source.name.removesuffix(".model.json")
        variant=find_child(materials,name)
        require(variant.get("class")=="MaterialVariant",f"Wrong material class: {name}")
        require(variant.find("Properties/BinaryString[@name='AttributesSerialize']") is not None,"Material provenance/ownership attributes must serialize")
        for channel in ("ColorMap","NormalMap","RoughnessMap"):
            actual=variant.findtext(f"Properties/Content[@name='{channel}Content']/uri")
            require(actual==spec["Properties"][channel],f"Material map differs: {name}/{channel}")
            require(actual.startswith("rbxassetid://") and actual.removeprefix("rbxassetid://").isdigit(),"Unverified material URL")
        require(float(variant.findtext("Properties/float[@name='StudsPerTile']"))==spec["Properties"]["StudsPerTile"],"Material scale differs")
        require(variant.find("Properties/Content[@name='MetalnessMapContent']/null") is not None,"Natural materials must remain nonmetallic")
        require(variant.find("Properties/PhysicalProperties[@name='CustomPhysicalProperties']") is None,"Material must retain base physics")
    storage = find_child(root, "ServerStorage")
    visuals = find_child(storage, "VisualAssets")
    require({instance_name(i) for i in visuals.findall("Item")} == {"Oak", "Palm", "Boulder"}, "Expected exactly three curated visual templates")
    for source in (repo / "assets/visuals").glob("*.rbxmx"):
        original = ET.parse(source).getroot().find("Item")
        template = find_child(visuals, source.stem)
        require(template.get("class") == "Model", "Visual template must be a Model")
        require(template.find("Properties/BinaryString[@name='AttributesSerialize']") is not None, "Visual provenance attributes must serialize")
        pivot = find_child(template, "GroundPivot")
        require(template.findtext("Properties/Ref[@name='PrimaryPart']") == pivot.get("referent"), "Visual pivot must survive export")
        require(pivot.findtext("Properties/float[@name='Transparency']") == "1", "Pivot must be invisible")
        for axis in ("X", "Y", "Z"):
            require(float(pivot.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{axis}")) == 0, "Visual pivot must be normalized at ground origin")
        parts = template.findall("Item")
        require(len(parts) <= 16, "Visual template part budget exceeded")
        for part in parts:
            require(part.get("class") in ("Part", "MeshPart"), "Imported scripts/packages are forbidden")
            for field, expected in (("Anchored", "true"), ("CanCollide", "false"), ("CanQuery", "false"), ("CanTouch", "false")):
                require(part.findtext(f"Properties/bool[@name='{field}']") == expected, f"Unsafe template physics: {source.stem}/{field}")
            if part.get("class") == "MeshPart":
                authored = find_child(original, instance_name(part))
                dimensions = json.loads((repo / "docs/graphics/native_mesh_dimensions.json").read_text())
                record = next(d for d in dimensions if d["model"] == source.stem and d["name"] == instance_name(part))
                for axis, expected in zip(("X", "Y", "Z"), record["meshSize"]):
                    actual_size = part.findtext(f"Properties/Vector3[@name='InitialSize']/{axis}")
                    require(actual_size is not None and float(actual_size) > 0 and abs(float(actual_size) - expected) < 0.0001,
                            f"Missing source mesh scale metadata: {source.stem}/{instance_name(part)}/{axis}")
                for field in ("MeshContent", "TextureContent"):
                    actual = part.findtext(f"Properties/Content[@name='{field}']/uri")
                    require(actual == authored.findtext(f"Properties/Content[@name='{field}']/uri") and actual.startswith("rbxassetid://"), "Visual mesh/texture mapping differs")
                surface = find_child(part, "RollboxMeshSurface")
                source_surface = find_child(authored, "RollboxMeshSurface")
                require(surface.get("class") == "SurfaceAppearance", "Mesh surface must use PBR")
                for field in ("ColorMapContent", "RoughnessMapContent"):
                    require(surface.findtext(f"Properties/Content[@name='{field}']/uri") == source_surface.findtext(f"Properties/Content[@name='{field}']/uri"), "Mesh PBR export differs")
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
