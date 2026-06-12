"""Auto-riggea una malla humanoide de Meshy al esqueleto del juego usando
pesos automáticos (heat map) de Blender, mucho mejores que envelope.
Ajusta un armature humanoide a la caja envolvente de la malla, lo emparenta
con ARMATURE_AUTO, reduce textura a 1K y exporta GLB skinned.

Uso:  blender -b --python tools/rig_meshy.py -- <entrada.glb> <salida.glb> [yaw_deg]
Huesos compatibles con char_anim.gd.
"""
import bpy
import sys
import os
import math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
DST = argv[1]
YAW = math.radians(float(argv[2])) if len(argv) > 2 else 0.0
TARGET_H = 1.85

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

# ── localizar y limpiar la malla ──────────────────────────────────────
mesh = None
for o in list(bpy.data.objects):
    if o.type == "MESH" and (mesh is None or len(o.data.vertices) > len(mesh.data.vertices)):
        mesh = o
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# giro de cara opcional
if YAW != 0.0:
    mesh.rotation_euler = (0, 0, YAW)
    bpy.ops.object.transform_apply(rotation=True)

# ── recentrar: pies en z=0, centrado en X/Y ───────────────────────────
bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
minz = min(v.z for v in bb)
cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2
cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
mesh.location -= Vector((cx, cy, minz))
bpy.ops.object.transform_apply(location=True)

bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
H = max(v.z for v in bb)
W = max(v.x for v in bb) - min(v.x for v in bb)

# ── armature ajustado a la malla ──────────────────────────────────────
arm_data = bpy.data.armatures.new("Rig")
rig = bpy.data.objects.new("Rig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")

def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if parent:
        b.parent = arm_data.edit_bones[parent]
    return b

aw = W * 0.5  # media anchura

bone("root", (0, 0, 0), (0, 0.12 * H, 0))
bone("pelvis", (0, 0, 0.50 * H), (0, 0, 0.56 * H), "root")
bone("spine", (0, 0, 0.56 * H), (0, 0, 0.66 * H), "pelvis")
bone("chest", (0, 0, 0.66 * H), (0, 0, 0.80 * H), "spine")
bone("neck", (0, 0, 0.80 * H), (0, 0, 0.86 * H), "chest")
bone("head", (0, 0, 0.86 * H), (0, 0, 1.0 * H), "neck")
for s, sgn in (("L", 1), ("R", -1)):
    # piernas
    bone(f"thigh.{s}", (sgn * 0.16 * aw, 0, 0.50 * H), (sgn * 0.20 * aw, 0, 0.27 * H), "pelvis")
    bone(f"shin.{s}", (sgn * 0.20 * aw, 0, 0.27 * H), (sgn * 0.22 * aw, 0, 0.06 * H), f"thigh.{s}")
    bone(f"foot.{s}", (sgn * 0.22 * aw, 0, 0.06 * H), (sgn * 0.22 * aw, -0.12 * H, 0.01 * H), f"shin.{s}")
    # brazos (A-pose: bajan y se abren)
    bone(f"upper_arm.{s}", (sgn * 0.30 * aw, 0, 0.78 * H), (sgn * 0.62 * aw, 0, 0.62 * H), "chest")
    bone(f"forearm.{s}", (sgn * 0.62 * aw, 0, 0.62 * H), (sgn * 0.85 * aw, 0, 0.50 * H), f"upper_arm.{s}")
    bone(f"hand.{s}", (sgn * 0.85 * aw, 0, 0.50 * H), (sgn * 0.95 * aw, 0, 0.44 * H), f"forearm.{s}")

bpy.ops.object.mode_set(mode="OBJECT")

# ── pesos automáticos (heat map) con fallback a envelope ──────────────
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
try:
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    weight_mode = "auto"
except RuntimeError:
    bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
    weight_mode = "envelope"

# ── escalar al tamaño de juego ────────────────────────────────────────
scale = TARGET_H / H
rig.scale = (scale, scale, scale)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.ops.object.transform_apply(scale=True)

# ── reducir textura a 1K y sombreado plano ────────────────────────────
for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.scale(1024, 1024)

tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
print(f"[*] rig {os.path.basename(DST)}: {tris} tris, pesos={weight_mode}, H={H:.2f}->{TARGET_H}")

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
    export_yup=True, export_skins=True, export_animations=False,
    export_image_format="JPEG", export_jpeg_quality=85)
print(f"[=] {os.path.basename(DST)}: {os.path.getsize(DST)/1e6:.2f} MB")
print("RIG_OK")
