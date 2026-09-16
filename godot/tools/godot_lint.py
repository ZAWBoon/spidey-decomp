#!/usr/bin/env python3
"""Static checker for the Godot track (runs without the engine).
1. gdparse every .gd file (syntax).
2. Verify every .tscn: ext/sub resource ids resolve, paths exist,
   node parents resolve, load_steps matches.
3. Verify project.godot autoloads + main scene exist.
4. Verify preload() paths + used input actions exist.
Usage: python3 godot/tools/godot_lint.py   (exit 1 on failure)
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fails: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    fails.append(msg)
    print(f"[FAIL] {msg}")


def warn(msg: str) -> None:
    warnings.append(msg)
    print(f"[WARN] {msg}")


def ok(msg: str) -> None:
    print(f"[ok] {msg}")


def res_path(p: str) -> Path:
    assert p.startswith("res://"), p
    return ROOT / p[len("res://"):]


# ------------------------------------------------------------- 1. gdparse ---
gd_files = sorted(ROOT.rglob("*.gd"))
ok(f"found {len(gd_files)} gdscript files")
for gd in gd_files:
    r = subprocess.run(["gdparse", str(gd)], capture_output=True, text=True)
    if r.returncode != 0:
        err = (r.stderr or r.stdout).strip().splitlines()
        fail(f"{gd.relative_to(ROOT)}: {err[0] if err else 'parse error'}")
ok("gdparse clean") if not fails else None

# ----------------------------------------------------- 2. tscn references ---
EXT_RE = re.compile(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]')
EXT_RE2 = re.compile(r'\[ext_resource[^\]]*id="([^"]+)"[^\]]*path="([^"]+)"\]')
SUB_RE = re.compile(r'\[sub_resource[^\]]*id="([^"]+)"\]')
NODE_RE = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"(.*)\]$')
PARENT_RE = re.compile(r'parent="([^"]+)"')
REF_RE = re.compile(r'(?:ExtResource|SubResource)\("([^"]+)"\)')
STEPS_RE = re.compile(r'\[gd_scene load_steps=(\d+)')

for tscn in sorted(ROOT.rglob("*.tscn")):
    text = tscn.read_text()
    rel = tscn.relative_to(ROOT)
    ext_ids: dict[str, str] = {}
    for m in list(EXT_RE.finditer(text)) + list(EXT_RE2.finditer(text)):
        path, rid = (m.group(1), m.group(2)) if "path=" in m.group(0)[:30] else (m.group(2), m.group(1))
        # EXT_RE: (path, id); EXT_RE2: (id, path)
        if m.re is EXT_RE2:
            rid, path = m.group(1), m.group(2)
        else:
            path, rid = m.group(1), m.group(2)
        ext_ids[rid] = path
        if path.startswith("res://") and not res_path(path).exists():
            fail(f"{rel}: missing ext_resource {path}")
    sub_ids = set(SUB_RE.findall(text))
    for ref in set(REF_RE.findall(text)):
        if ref not in ext_ids and ref not in sub_ids:
            fail(f"{rel}: dangling resource ref {ref}")
    # node parents
    known = {"."}
    for line in text.splitlines():
        m = NODE_RE.match(line.strip())
        if not m:
            continue
        name, _typ, rest = m.group(1), m.group(2), m.group(3)
        pm = PARENT_RE.search(rest)
        parent = pm.group(1) if pm else None
        full = name if parent is None else (parent + "/" + name if parent != "." else name)
        if parent is not None and parent not in known:
            fail(f"{rel}: node '{name}' has unknown parent '{parent}'")
        known.add(full)
    # load_steps
    m = STEPS_RE.search(text)
    if m:
        expect = len(ext_ids) + len(sub_ids) + 1
        if int(m.group(1)) != expect:
            warn(f"{rel}: load_steps={m.group(1)} but counted {expect}")
ok("tscn references checked")

# ------------------------------------------------------- 3. project.godot ---
proj = (ROOT / "project.godot").read_text()
for m in re.finditer(r'^(\w+)="\*res://([^"]+)"', proj, re.M):
    p = ROOT / m.group(2)
    if not p.exists():
        fail(f"project.godot: missing autoload {m.group(2)}")
m = re.search(r'run/main_scene="res://([^"]+)"', proj)
if m and not (ROOT / m.group(1)).exists():
    fail(f"project.godot: missing main scene {m.group(1)}")
ok("project.godot checked")

# ------------------------------------------------- 4. preloads + actions ---
defined_actions = set(re.findall(r'"([a-z_]+)"', re.search(
    r"ACTION_NAMES.*?=\s*\[(.*?)\]", (ROOT / "autoload/game.gd").read_text(),
    re.S).group(1)))
used_actions: set[str] = set()
for gd in gd_files:
    text = gd.read_text()
    for p in set(re.findall(r'preload\("(res://[^"]+)"\)', text)):
        if not res_path(p).exists():
            fail(f"{gd.relative_to(ROOT)}: missing preload {p}")
    if gd.name != "game.gd":
        used_actions |= set(re.findall(r'is_action_(?:pressed|just_pressed|just_released)\("([^"]+)"\)', text))
        used_actions |= set(re.findall(r'action_(?:press|release)\("([^"]+)"\)', text))
unknown = used_actions - defined_actions
if unknown:
    fail(f"input actions used but not defined: {sorted(unknown)}")
else:
    ok(f"input actions ok ({len(used_actions)} used)")

# ------------------------------------------------------------------ report --
print(f"---\nfiles: {len(gd_files)} gd, {len(list(ROOT.rglob('*.tscn')))} tscn")
print(f"result: {len(fails)} failures, {len(warnings)} warnings")
sys.exit(1 if fails else 0)
