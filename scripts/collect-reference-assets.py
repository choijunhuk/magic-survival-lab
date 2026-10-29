"""Download the curated public image list without changing source image bytes.

Uses the existing host curl and Pillow for authoring-time image validation.
Run from the repository root after editing assets/references/candidates.json.
"""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import urlparse

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/references"
ALLOWED_HOSTS = {"img.atwiki.jp", "play-lh.googleusercontent.com"}
FORMATS = {"PNG": ".png", "JPEG": ".jpg", "WEBP": ".webp", "GIF": ".gif"}


def fetch(item):
    source = item["source"]
    parsed = urlparse(source)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        return None, {**item, "error": "Source is outside the curated public CDN allowlist"}
    category = item["category"]
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", category):
        return None, {**item, "error": "Invalid category path"}
    folder = DEST / category
    folder.mkdir(parents=True, exist_ok=True)
    key = sha256(source.encode()).hexdigest()[:16]
    temporary = folder / (key + ".part")
    try:
        cached = [p for p in folder.glob(key + ".*") if p.suffix in FORMATS.values()]
        if cached:
            temporary.write_bytes(cached[0].read_bytes())
            content_type = "cached-image"
        else:
            result = subprocess.run([
                "curl", "--fail", "--location", "--silent", "--show-error",
                "--connect-timeout", "10", "--max-time", "35",
                "--max-filesize", "20971520", "--output", str(temporary),
                "--write-out", "%{content_type}", source,
            ], capture_output=True, text=True, timeout=40)
            if result.returncode:
                raise ValueError(result.stderr.strip()[:220] or "Download failed")
            content_type = result.stdout.strip()
            if not content_type.startswith("image/"):
                raise ValueError("Expected image MIME, got " + content_type)
        with Image.open(temporary) as image:
            image.verify()
        with Image.open(temporary) as image:
            image.load()
            extension = FORMATS[image.format]
            width, height = image.size
            mode = image.mode
            if width <= 0 or height <= 0:
                raise ValueError("Empty image")
        output = folder / (key + extension)
        temporary.replace(output)
        data = output.read_bytes()
        record = {**item, "file": output.relative_to(ROOT).as_posix(), "kind": "image",
                  "sha256": sha256(data).hexdigest(), "bytes": len(data),
                  "width": width, "height": height, "mode": mode,
                  "download_mime": content_type, "usage_status": "reference-only"}
        return record, None
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        return None, {**item, "error": str(error)[:250]}
    finally:
        temporary.unlink(missing_ok=True)


def main():
    candidates = json.loads((DEST / "candidates.json").read_text())["sources"]
    unique = {}
    for item in candidates:
        unique[item["source"]] = item
    records, failures = [], []
    with ThreadPoolExecutor(max_workers=4) as pool:
        for record, failure in pool.map(fetch, unique.values()):
            if record:
                records.append(record)
            else:
                failures.append(failure)
    if failures:
        report = ROOT / ".omx/artifacts/asset-expansion/collection-failures.json"
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps({"candidate_urls": len(unique), "files": records,
                                      "failures": failures}, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"failures": len(failures), "report": str(report),
                          "catalog_preserved": True}, indent=2), flush=True)
        return 1
    # Hash deduplication keeps each image once and records every alternate source.
    base = json.loads((ROOT / "assets/catalog.json").read_text())["files"]
    hashes = {item["sha256"]: item["file"] for item in base if item["kind"] == "image"}
    files, duplicates = [], []
    for record in sorted(records, key=lambda x: (x["category"], x["source"])):
        if record["sha256"] in hashes:
            canonical = hashes[record["sha256"]]
            duplicates.append({**record, "duplicate_of": canonical})
            if record["file"] != canonical:
                (ROOT / record["file"]).unlink()
        else:
            hashes[record["sha256"]] = record["file"]
            files.append(record)
    output = {"schema_version": 1, "collected_at": datetime.now(timezone.utc).isoformat(),
              "candidate_urls": len(unique), "files": files,
              "duplicates": duplicates, "failures": failures}
    pending = DEST / ".catalog.json.tmp"
    pending.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    pending.replace(DEST / "catalog.json")
    print(json.dumps({"candidates": len(unique), "new_unique": len(files),
                      "duplicates": len(duplicates), "failures": len(failures),
                      "bytes": sum(x["bytes"] for x in files)}, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
