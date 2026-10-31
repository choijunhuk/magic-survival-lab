"""Run native suites and reject Godot script errors even when its exit code is 0."""

import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
binary = os.environ.get("GODOT_BIN", "godot")
logs = ROOT / ".omx/release-implementation/test-logs"
logs.mkdir(parents=True, exist_ok=True)
failures = []
for suite in sys.argv[1:]:
    if not re.fullmatch(r"test_[a-z0-9_]+", suite):
        raise SystemExit("Invalid suite name: " + suite)
    try:
        result = subprocess.run([binary, "--headless", "--path", str(ROOT / "godot"),
                                 "--script", "res://tests/" + suite + ".gd"],
                                capture_output=True, text=True, timeout=180)
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        output = "Native suite timed out: " + suite
        result = None
    (logs / (suite + ".log")).write_text(output)
    summary = re.search(r"(\d+) checks,\s*0 failures", output)
    errors = re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", output)
    passed = result is not None and result.returncode == 0 and summary and int(summary[1]) > 0 and not errors
    if passed:
        print(f"{suite}: {summary[1]} checks PASS", flush=True)
    else:
        failures.append(suite)
        print(f"{suite}: FAIL\n{output}", flush=True)
if not sys.argv[1:]:
    raise SystemExit("Provide at least one native test suite")
raise SystemExit(1 if failures else 0)
