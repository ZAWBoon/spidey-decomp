#!/usr/bin/env python3
"""gd_verify: static cross-reference checks for the Godot remake.

gdparse/gdlint only prove syntax+style. This proves the wiring that breaks
games silently: sound names, input actions, static APIs, rig call arity,
shared enums, groups, has_method targets, class refs, onready node paths,
signal wiring. Exit 1 on any failure.

Usage:  python3 tools/gd_verify.py   (run from godot/)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # godot/
fails: list[str] = []
infos: list[str] = []

BUILTINS = set("""
Object RefCounted Resource Node Node2D Node3D Area2D Area3D StaticBody2D StaticBody3D
CharacterBody2D CharacterBody3D AnimatableBody2D AnimatableBody3D RigidBody2D RigidBody3D
CollisionShape2D CollisionShape3D CollisionObject2D CollisionObject3D CollisionPolygon2D CollisionPolygon3D
MeshInstance2D MeshInstance3D Label2D Label3D Camera2D Camera3D AudioStreamPlayer AudioStreamPlayer2D
AudioStreamPlayer3D AudioListener2D AudioListener3D AudioStream AudioStreamWAV AudioServer
ImmediateMesh ArrayMesh BoxMesh SphereMesh CapsuleMesh CylinderMesh TorusMesh PlaneMesh QuadMesh PrismMesh
TubeTrailMesh RibbonTrailMesh StandardMaterial3D BaseMaterial3D ShaderMaterial Shader Material Mesh
Shape2D Shape3D BoxShape2D BoxShape3D CircleShape2D SphereShape3D CapsuleShape2D CapsuleShape3D
CylinderShape2D CylinderShape3D WorldBoundaryShape2D WorldBoundaryShape3D ConvexPolygonShape2D ConvexPolygonShape3D
InputEventKey InputEventMouseButton InputEventJoypadButton InputEventJoypadMotion InputEventAction InputEvent
InputEventMouseMotion InputEventScreenTouch InputEventScreenDrag InputMap Input Engine Time Tween Timer SceneTree
JoyAxis JoyButton Key MouseButton PackedScene PackedByteArray PackedFloat32Array PackedInt32Array PackedStringArray
PackedVector2Array PackedVector3Array PackedColorArray RandomNumberGenerator FileAccess DirAccess JSON
Vector2 Vector2i Vector3 Vector3i Vector4 Vector4i Color Rect2 Rect2i AABB Transform2D Transform3D Basis Quaternion
Plane Projection String StringName NodePath Variant Array Dictionary Callable Signal RID Viewport Window CanvasItem
Control Button Label TextureRect ColorRect ProgressBar VBoxContainer HBoxContainer MarginContainer CenterContainer
ScrollContainer Panel PanelContainer SplitContainer HSplitContainer VSplitContainer TabContainer TabBar
Texture2D Image ImageTexture Gradient GradientTexture1D GradientTexture2D Curve AnimationPlayer Animation
AnimationTree GPUParticles2D GPUParticles3D CPUParticles2D CPUParticles3D ParticleProcessMaterial
OmniLight2D OmniLight3D SpotLight3D DirectionalLight2D DirectionalLight3D WorldEnvironment Environment Sky
ProceduralSkyMaterial PhysicalSkyMaterial SkyMaterial RemoteTransform2D RemoteTransform3D Marker2D Marker3D
Path2D Path3D PathFollow2D PathFollow3D MultiMeshInstance2D MultiMeshInstance3D MultiMesh Decal ReflectionProbe
VoxelGI GridMap BoneAttachment3D Skeleton2D Skeleton3D PhysicalBone2D PhysicalBone3D SpringArm2D SpringArm3D
GeometryInstance2D GeometryInstance3D VisualInstance2D VisualInstance3D CanvasLayer CanvasModulate ParallaxBackground
ParallaxLayer Line2D Polygon2D Sprite2D Sprite3D AnimatedSprite2D AnimatedSprite3D YSort TouchScreenButton
HSeparator VSeparator HSlider VSlider HScrollBar VScrollBar SpinBox LineEdit TextEdit CodeEdit FileDialog
AcceptDialog ConfirmationDialog Popup PopupMenu PopupPanel MenuButton MenuBar OptionButton CheckBox CheckButton
ItemList Tree GraphNode GraphEdit SubViewport SubViewportContainer ViewportTexture CameraTexture
PhysicsServer2D PhysicsServer3D RenderingServer OS DisplayServer ProjectSettings Performance
PhysicsRayQueryParameters2D PhysicsRayQueryParameters3D AudioBusLayout StyleBox StyleBoxFlat StyleBoxTexture
Theme Font FontFile SystemFont LabelSettings AudioEffect AudioEffectReverb
""".split())

UI_ACTIONS = {"ui_accept", "ui_cancel", "ui_select", "ui_focus_next", "ui_focus_prev",
              "ui_left", "ui_right", "ui_up", "ui_down", "ui_page_up", "ui_page_down",
              "ui_home", "ui_end", "ui_cut", "ui_copy", "ui_paste", "ui_undo", "ui_redo",
              "ui_text_backspace", "ui_text_delete", "ui_text_submit"}


def strip_comments(s: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in s.splitlines())


def strip_strings(s: str) -> str:
    return re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)


def balanced_inner(text: str, open_idx: int) -> str:
    """Inner text of the paren group opening at open_idx (index of '(')."""
    depth = 0
    for i in range(open_idx, len(text)):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1:i]
    return ""


def split_top(s: str) -> list[str]:
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return [p for p in (x.strip() for x in parts) if p]


def main() -> int:
    gd_files = sorted(ROOT.rglob("*.gd"))
    tscn_files = sorted(ROOT.rglob("*.tscn"))
    src = {p: strip_comments(p.read_text()) for p in gd_files}
    code = "\n".join(src.values())
    nostr = strip_strings(code)

    def rel(p: Path) -> str:
        return str(p.relative_to(ROOT))

    # ---- class map + duplicate class_names ----
    classmap: dict[str, Path] = {}
    for p, text in src.items():
        for name in re.findall(r"class_name\s+(\w+)", text):
            if name in classmap:
                fails.append(f"duplicate class_name {name}: {rel(classmap[name])} + {rel(p)}")
            classmap[name] = p
    infos.append(f"[ok] classes mapped ({len(classmap)})")

    # ---- 1. sound names ----
    sfx = src[ROOT / "autoload/sfx.gd"]
    defined_sfx = set(re.findall(r'_streams\["([^"]+)"\]', sfx))
    used_sfx = set(re.findall(r'Sfx\.play(?:_at)?\(\s*"([^"]+)"', code))
    missing = sorted(used_sfx - defined_sfx)
    if missing:
        fails.append(f"unknown sounds played: {missing}")
    else:
        infos.append(f"[ok] sounds ({len(used_sfx)} used, {len(defined_sfx)} defined)")

    # ---- 2. input actions ----
    game = src[ROOT / "autoload/game.gd"]
    m = re.search(r"ACTION_NAMES.*?=\s*\[(.*?)\]", game, re.S)
    actions = set(re.findall(r'"([^"]+)"', m.group(1))) | UI_ACTIONS if m else set()
    used_in: set[str] = set()
    for mm in re.finditer(r"Input\.(?:is_action_pressed|is_action_just_pressed|"
                          r"is_action_just_released|get_vector)\(([^)]*)\)", code):
        used_in |= set(re.findall(r'"([^"]+)"', mm.group(1)))
    missing = sorted(used_in - actions)
    if missing:
        fails.append(f"unknown input actions used: {missing}")
    else:
        infos.append(f"[ok] input actions ({len(used_in)} used)")

    # ---- 3. static/helper APIs ----
    for cls in ["FX", "Blockout", "SkyDeco"]:
        if cls not in classmap:
            fails.append(f"class {cls} not found for API check")
            continue
        methods = set(re.findall(r"(?:static\s+)?func\s+(\w+)\s*\(", src[classmap[cls]]))
        calls = set(re.findall(r"\b" + cls + r"\.(\w+)\s*\(", nostr))
        missing = sorted(c for c in calls if c not in methods)
        if missing:
            fails.append(f"{cls}.* unknown: {missing}")
        else:
            infos.append(f"[ok] {cls} API ({len(calls)} calls)")

    # ---- 4. rig call arity ----
    pairs = [("player/hero_rig.gd", "func tick(", "player/player.gd", "hero.tick("),
             ("enemies/thug_rig.gd", "func tick(", "enemies/thug.gd", "rig_node.tick(")]
    for def_file, def_mark, call_file, call_mark in pairs:
        dtext, ctext = src[ROOT / def_file], src[ROOT / call_file]
        di = dtext.index(def_mark) + len(def_mark) - 1
        ci = ctext.index(call_mark) + len(call_mark) - 1
        n_params = len(split_top(balanced_inner(dtext, di)))
        n_args = len(split_top(balanced_inner(ctext, ci)))
        if n_params != n_args:
            fails.append(f"{def_file} tick takes {n_params} but {call_file} passes {n_args}")
        else:
            infos.append(f"[ok] {def_file} tick arity ({n_params})")

    # ---- 5. shared enum refs (X.State.Y) ----
    for cls, member in set(re.findall(r"\b([A-Z]\w*)\.State\.(\w+)", nostr)):
        if cls not in classmap:
            fails.append(f"enum ref {cls}.State.{member}: class {cls} unknown")
            continue
        em = re.search(r"enum\s+State\s*\{([^}]*)\}", src[classmap[cls]])
        members = [x.strip() for x in em.group(1).split(",")] if em else []
        if member not in members:
            fails.append(f"enum ref {cls}.State.{member} not in {cls} enum State")

    # ---- 6. groups ----
    added = set(re.findall(r'add_to_group\("([^"]+)"', code))
    for t in tscn_files:
        for mm in re.finditer(r"groups=\[([^\]]*)\]", t.read_text()):
            added |= set(re.findall(r'"([^"]+)"', mm.group(1)))
    queried = set(re.findall(r'(?:is_in_group|get_nodes_in_group|'
                             r'get_first_node_in_group)\("([^"]+)"', code))
    missing = sorted(queried - added)
    if missing:
        fails.append(f"groups queried but never added: {missing}")
    else:
        infos.append(f"[ok] groups ({len(queried)} queried, {len(added)} added)")

    # ---- 7. has_method targets ----
    targets = set(re.findall(r'has_method\("([^"]+)"', code))
    for t in sorted(targets):
        if not re.search(r"func\s+" + re.escape(t) + r"\s*\(", code):
            fails.append(f'has_method("{t}") has no matching func anywhere')
    if targets:
        infos.append(f"[ok] has_method targets ({len(targets)})")

    # ---- 8. class references ----
    # ALL_CAPS identifiers are consts by convention (THUG_SCENE, ...); bare
    # `State` is an own-class enum. Neither is a class reference.
    proj = (ROOT / "project.godot").read_text()
    autoloads: set[str] = set()
    in_auto = False
    for line in proj.splitlines():
        if line.strip() == "[autoload]":
            in_auto = True
            continue
        if line.startswith("["):
            in_auto = False
        if in_auto and "=" in line:
            autoloads.add(line.split("=", 1)[0].strip())
    known = set(classmap) | BUILTINS | autoloads
    refs: set[str] = set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\s*\(", nostr))
    refs |= set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\.[A-Za-z_]+", nostr))
    refs |= set(re.findall(r"\bas\s+([A-Z][A-Za-z0-9_]*)", nostr))
    refs |= set(re.findall(r"\bis\s+([A-Z][A-Za-z0-9_]*)", nostr))
    refs |= set(re.findall(r"->\s*([A-Z][A-Za-z0-9_]*)", nostr))
    refs |= set(re.findall(r":\s*([A-Z][A-Za-z0-9_]*)\s*=", nostr))
    refs |= set(re.findall(r"Array\[([A-Z][A-Za-z0-9_]*)\]", nostr))
    refs |= set(re.findall(r"extends\s+([A-Z][A-Za-z0-9_]*)", nostr))
    unknown = sorted(r for r in refs if r not in known and r != "State" and not r.isupper())
    if unknown:
        fails.append(f"unknown classes referenced: {unknown}")
    else:
        infos.append(f"[ok] class refs ({len(refs)} distinct)")

    # ---- 9. onready node paths vs sibling tscn ----
    # $X / %X resolve at ready-time from the scene -> tscn nodes only.
    # get_node("X") often runs later and can see code-built names too, so
    # those accept `.name = "X"` assignments from the same file as well.
    checked = 0
    for p, text in src.items():
        t = p.with_suffix(".tscn")
        if not t.exists():
            continue
        nodes = set(re.findall(r'\[node name="([^"]+)"', t.read_text()))
        text_ns = strip_strings(text)
        refs_n = set(re.findall(r"\$([A-Za-z_]\w*)", text_ns))
        refs_n |= set(re.findall(r"%([A-Za-z_]\w*)", text_ns))
        missing = sorted(r for r in refs_n if r not in nodes)
        if missing:
            fails.append(f"{rel(p)} refs missing nodes in {t.name}: {missing}")
        code_names = set(re.findall(r'\.name\s*=\s*"([^"]+)"', text))
        for mm in re.finditer(r'get_node\("([^"]+)"', text):
            target = mm.group(1).split("/")[0]
            if target not in nodes and target not in code_names:
                fails.append(f"{rel(p)} get_node(\"{target}\") not in {t.name} nor .name list")
        checked += 1
    infos.append(f"[ok] onready/tscn pairs checked ({checked})")

    # ---- 10. signal wiring ----
    for p, text in src.items():
        text_ns = strip_strings(text)
        defined = set(re.findall(r"func\s+(\w+)\s*\(", text_ns))
        for mm in re.finditer(r"\.connect\(\s*([A-Za-z_]\w*)", text_ns):
            name = mm.group(1)
            if name.startswith("_") and name not in defined:
                fails.append(f"{rel(p)} connects missing method {name}")
        signals = set(re.findall(r"signal\s+(\w+)", text_ns))
        for sig in set(re.findall(r"(\w+)\.emit\s*\(", text_ns)):
            if sig not in signals:
                fails.append(f"{rel(p)} emits undeclared signal {sig}")
    infos.append("[ok] signal wiring scan done")

    print(f"gd_verify: {len(gd_files)} gd, {len(tscn_files)} tscn")
    for i in infos:
        print(i)
    for f in fails:
        print("[FAIL]", f)
    print(f"result: {len(fails)} failures")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
