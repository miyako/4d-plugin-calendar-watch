"""Compile actual plugin/SDK sources against a non-release macOS host shim."""
from pathlib import Path
import os
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
API = ROOT / "4D Plugin API"

with tempfile.TemporaryDirectory(prefix="calendar-ownership-") as directory:
    executable = str(Path(directory) / "ownership")
    subprocess.run([
        "clang++", "-std=c++11", "-x", "objective-c++", "-g",
        "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
        "-Wno-deprecated-declarations", "-Wno-#pragma-messages",
        "-include", str(ROOT / "4D Plugin_Prefix.pch"),
        "-I", str(API), "-I", str(API / "Classes"),
        str(ROOT / ".github/tests/string_ownership.mm"),
        str(API / "4DPluginAPI.c"),
        *map(str, sorted((API / "Classes").glob("*.cpp"))),
        "-framework", "Cocoa", "-framework", "Carbon",
        "-framework", "CoreServices", "-lsqlite3", "-o", executable,
    ], check=True)
    failed = []
    for model in ("allocated", "null"):
        for scenario in ("callback", "file", "copy", "array"):
            result = subprocess.run(
                [executable, model, scenario],
                env={**os.environ, "UBSAN_OPTIONS": "halt_on_error=1"},
            )
            if result.returncode:
                failed.append((model, scenario))
    if failed:
        raise SystemExit(f"Failed ownership cases: {failed}")
