"""Edita el héroe en Blender: recorta la capa larga a una capa corta hasta
la cintura (para que se vean las piernas), suaviza el corte y re-riggea al
esqueleto del juego con pesos automáticos. Sobrescribe hero_conquistador.glb.

Uso:  blender -b --python tools/fix_hero_cape.py
"""
import bpy
import bmesh
import math
import sys
from mathutils import Vector

SRC = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\recovered_meshy\hero_conquistador.glb"
DST = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\nuevo-proyecto-de-juego\assets\models\hero_conquistador.glb"
TARGET_H = 1.85
# umbrales de capa (espacio local original z: -1 pies .. +1 cabeza),
# configurables por argv:  -- CAPE_Y CAPE_Z
_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CAPE_Y = float(_argv[0]) if len(_argv) > 0 else -0.15
CAPE_Z = float(_argv[1]) if len(_argv) > 1 else 0.48

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

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

# ── acortar la capa comprimiéndola en altura (robusto, sin agujeros) ──
# La capa está en Y negativo. Los vértices de la capa por debajo del nivel
# de hombros se "suben" hacia la cintura, dejando una capa corta y las
# piernas visibles. No se borra geometría => no quedan agujeros.
KEEP_Z = 0.30      # nivel original donde acaba la capa corta (~cintura)
SQUASH = 0.18      # cuánto se conserva de la longitud original colgante
n = 0
for v in mesh.data.vertices:
    if v.co.y < CAPE_Y and v.co.z < KEEP_Z:
        v.co.z = KEEP_Z + (v.co.z - KEEP_Z) * SQUASH
        # acerca un poco la capa al cuerpo para que no quede acampanada
        v.co.y = CAPE_Y + (v.co.y - CAPE_Y) * 0.7
        n += 1
mesh.data.update()
print(f"[*] capa acortada: {n} vértices comprimidos")

# ── recentrar: pies en z=0, centrado X/Y ──────────────────────────────
bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
minz = min(v.z for v in bb)
cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2
cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
mesh.location -= Vector((cx, cy, minz))
bpy.ops.object.transform_apply(location=True)
bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
H = max(v.z for v in bb)
W = max(v.x for v in bb) - min(v.x for v in bb)

# ── armature ajustado ─────────────────────────────────────────────────
arm_data = bpy.data.armatures.new("Rig")
rig = bpy.data.objects.new("Rig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")

def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = Vector(head); b.tail = Vector(tail)
    if parent:
        b.parent = arm_data.edit_bones[parent]

aw = W * 0.5
bone("root", (0, 0, 0), (0, 0.12 * H, 0))
bone("pelvis", (0, 0, 0.50 * H), (0, 0, 0.56 * H), "root")
bone("spine", (0, 0, 0.56 * H), (0, 0, 0.66 * H), "pelvis")
bone("chest", (0, 0, 0.66 * H), (0, 0, 0.80 * H), "spine")
bone("neck", (0, 0, 0.80 * H), (0, 0, 0.86 * H), "chest")
bone("head", (0, 0, 0.86 * H), (0, 0, 1.0 * H), "neck")
for s, sgn in (("L", 1), ("R", -1)):
    bone(f"thigh.{s}", (sgn * 0.16 * aw, 0, 0.50 * H), (sgn * 0.20 * aw, 0, 0.27 * H), "pelvis")
    bone(f"shin.{s}", (sgn * 0.20 * aw, 0, 0.27 * H), (sgn * 0.22 * aw, 0, 0.06 * H), f"thigh.{s}")
    bone(f"foot.{s}", (sgn * 0.22 * aw, 0, 0.06 * H), (sgn * 0.22 * aw, -0.12 * H, 0.01 * H), f"shin.{s}")
    bone(f"upper_arm.{s}", (sgn * 0.30 * aw, 0, 0.78 * H), (sgn * 0.62 * aw, 0, 0.62 * H), "chest")
    bone(f"forearm.{s}", (sgn * 0.62 * aw, 0, 0.62 * H), (sgn * 0.85 * aw, 0, 0.50 * H), f"upper_arm.{s}")
    bone(f"hand.{s}", (sgn * 0.85 * aw, 0, 0.50 * H), (sgn * 0.95 * aw, 0, 0.44 * H), f"forearm.{s}")
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
try:
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    wm = "auto"
except RuntimeError:
    bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
    wm = "envelope"

scale = TARGET_H / H
rig.scale = (scale, scale, scale)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(scale=True)

for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.scale(1024, 1024)

tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
print(f"[*] hero recapado+riggeado: {tris} tris, pesos={wm}")

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
    export_yup=True, export_skins=True, export_animations=False,
    export_image_format="JPEG", export_jpeg_quality=85)
import os
print(f"[=] {os.path.basename(DST)}: {os.path.getsize(DST)/1e6:.2f} MB")
print("CAPE_FIX_OK")
