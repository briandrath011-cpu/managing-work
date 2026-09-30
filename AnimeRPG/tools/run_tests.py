#!/usr/bin/env python3
"""
Runs the Luau unit tests in tests/*.spec.luau with the standalone `luau` VM.

The shared game modules (ReplicatedStorage/Modules) use Roblox-style requires
(`require(script.Parent.X)`). This script bundles them into one Luau file with a
virtual `script` instance tree and small stubs for Vector3 / Color3 / Random / Enum,
so the pure game logic (damage, spins + pity, progression, quests, data validation)
can be tested outside Roblox Studio.

Usage:  python3 tools/run_tests.py            (luau must be on PATH, or set LUAU_BIN)
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULES = ROOT / "src" / "ReplicatedStorage" / "Modules"
TESTS = ROOT / "tests"

# Modules that need the real Roblox engine (remotes, services) are skipped.
SKIP = {"Shared/Net.luau", "Shared/Signal.luau", "Shared/ObjectPool.luau", "Shared/Maid.luau"}


def luau_binary() -> str:
    candidate = os.environ.get("LUAU_BIN") or shutil.which("luau")
    if not candidate:
        sys.exit("luau binary not found. Install it from https://github.com/luau-lang/luau/releases or set LUAU_BIN.")
    return candidate


def lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_bundle() -> str:
    parts = [(ROOT / "tests" / "harness" / "stubs.luau").read_text()]
    parts.append("local __root = __makeNode('Modules', 'Folder', nil)")
    for path in sorted(MODULES.rglob("*.luau")):
        rel = path.relative_to(MODULES).as_posix()
        if rel in SKIP:
            continue
        source = path.read_text()
        # `export type` is only legal at module top level; the bundle wraps modules in functions.
        source = re.sub(r"^export type", "type", source, flags=re.MULTILINE)
        segments = rel[:-5].split("/")
        parts.append(
            "__registerModule(__root, {%s}, function(script)\n%s\nend)"
            % (", ".join(lua_string(s) for s in segments), source)
        )
    parts.append((ROOT / "tests" / "harness" / "framework.luau").read_text())
    for spec in sorted(TESTS.glob("*.spec.luau")):
        parts.append("do -- %s\n%s\nend" % (spec.name, spec.read_text()))
    parts.append("__finish()")
    return "\n".join(parts)


def main() -> int:
    bundle = build_bundle()
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as handle:
        handle.write(bundle)
        bundle_path = handle.name
    result = subprocess.run([luau_binary(), bundle_path])
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
