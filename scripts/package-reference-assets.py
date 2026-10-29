"""Package the actual image manifests and offline atlas; no game build required."""

import json
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[1]
destination = ROOT / (sys.argv[1] if len(sys.argv) > 1 else "output/reference-assets/magic-survival-reference-pack.zip")
files = {"atlas.html", "assets/catalog.json", "assets/sources.json", "assets/display-names.json"}
for manifest in ["assets/catalog.json", "assets/references/catalog.json"]:
    files.update(item["file"] for item in json.loads((ROOT / manifest).read_text())["files"])
files.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "assets/references").glob("*.json"))
files.add("assets/references/README.md")
destination.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(destination, "w", ZIP_DEFLATED, compresslevel=6) as archive:
    for relative in sorted(files):
        path = ROOT / relative
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise ValueError("Invalid archive source: " + relative)
        archive.write(path, relative)
print(f"{destination}: {len(files)} files, {destination.stat().st_size:,} bytes")
