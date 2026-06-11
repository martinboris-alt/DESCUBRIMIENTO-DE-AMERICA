"""Construye un conquistador low-poly estilizado con armature limpio y
pesos rígidos por pieza (sin deformaciones). Huesos compatibles con
char_anim.gd: pelvis/spine/chest/neck/head, upper_arm/forearm/hand .L/.R,
thigh/shin/foot .L/.R.  El modelo mira hacia -Y en Blender (= +Z en Godot).

Ejecutar:  blender --background --python tools/blender_build_conquistador.py
"""
import bpy
import math

OUT = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\nuevo-proyecto-de-juego\assets\models\conquistador_lowpoly.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)

# ── Materiales ────────────────────────────────────────────────────────
def mat(name, color, metallic=0.0, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return m

M_STEEL   = mat("steel",   (0.50, 0.54, 0.60), 0.45, 0.40)
M_GOLD    = mat("gold",    (0.85, 0.65, 0.15), 1.0, 0.30)
M_LEATHER = mat("leather", (0.30, 0.18, 0.08), 0.0, 0.85)
M_PANTS   = mat("pants",   (0.16, 0.12, 0.20), 0.0, 0.90)
M_SKIN    = mat("skin",    (0.80, 0.58, 0.42), 0.0, 0.80)
M_CRIMSON = mat("crimson", (0.55, 0.06, 0.08), 0.0, 0.75)
M_DARK    = mat("dark",    (0.08, 0.06, 0.05), 0.0, 0.90)
M_BEARD   = mat("beard",   (0.22, 0.13, 0.06), 0.0, 0.95)

# ── Armature ──────────────────────────────────────────────────────────
arm_data = bpy.data.armatures.new("Rig")
rig = bpy.data.objects.new("Rig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")

def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = arm_data.edit_bones[parent]
    return b

bone("root", (0, 0, 0), (0, 0.25, 0))
bone("pelvis", (0, 0, 0.92), (0, 0, 1.00), "root")
bone("spine", (0, 0, 1.00), (0, 0, 1.16), "pelvis")
bone("chest", (0, 0, 1.16), (0, 0, 1.46), "spine")
bone("neck", (0, 0, 1.46), (0, 0, 1.56), "chest")
bone("head", (0, 0, 1.56), (0, 0, 1.86), "neck")
for s, sign in (("L", 1), ("R", -1)):
    bone(f"thigh.{s}", (sign * 0.10, 0, 0.92), (sign * 0.115, 0, 0.50), "pelvis")
    bone(f"shin.{s}", (sign * 0.115, 0, 0.50), (sign * 0.12, 0, 0.10), f"thigh.{s}")
    bone(f"foot.{s}", (sign * 0.12, 0, 0.10), (sign * 0.12, -0.20, 0.04), f"shin.{s}")
    bone(f"upper_arm.{s}", (sign * 0.24, 0, 1.42), (sign * 0.30, 0, 1.10), "chest")
    bone(f"forearm.{s}", (sign * 0.30, 0, 1.10), (sign * 0.335, 0, 0.84), f"upper_arm.{s}")
    bone(f"hand.{s}", (sign * 0.335, 0, 0.84), (sign * 0.345, 0, 0.70), f"forearm.{s}")

bpy.ops.object.mode_set(mode="OBJECT")

# ── Piezas de malla (cada una pesa 1.0 a un solo hueso) ───────────────
parts = []  # (objeto, hueso)

def add_part(obj, bone_name, material):
    obj.data.materials.append(material)
    parts.append((obj, bone_name))
    return obj

def box(name, size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return o

def cyl(name, r1, r2, depth, loc, rot=(0, 0, 0), verts=10):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
        depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return o

def sphere(name, r, loc, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8,
        radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o

for s, sign in (("L", 1), ("R", -1)):
    # botas
    add_part(box(f"boot.{s}", (0.15, 0.30, 0.13), (sign * 0.12, -0.05, 0.065)),
        f"foot.{s}", M_LEATHER)
    add_part(cyl(f"boot_top.{s}", 0.085, 0.075, 0.16, (sign * 0.12, 0, 0.18)),
        f"shin.{s}", M_LEATHER)
    # piernas
    add_part(cyl(f"shin.{s}", 0.075, 0.065, 0.26, (sign * 0.118, 0, 0.37)),
        f"shin.{s}", M_PANTS)
    add_part(cyl(f"thigh.{s}", 0.105, 0.085, 0.40, (sign * 0.108, 0, 0.71)),
        f"thigh.{s}", M_PANTS)
    # brazos
    add_part(sphere(f"pauldron.{s}", 0.115, (sign * 0.245, 0, 1.42), (1, 1, 0.85)),
        f"upper_arm.{s}", M_STEEL)
    add_part(cyl(f"upper_arm.{s}", 0.07, 0.06, 0.28,
        (sign * 0.27, 0, 1.26), (0, sign * 0.18, 0)),
        f"upper_arm.{s}", M_CRIMSON)
    add_part(cyl(f"forearm.{s}", 0.065, 0.055, 0.24,
        (sign * 0.318, 0, 0.97), (0, sign * 0.12, 0)),
        f"forearm.{s}", M_LEATHER)
    add_part(box(f"hand.{s}", (0.09, 0.11, 0.12), (sign * 0.34, 0, 0.77)),
        f"hand.{s}", M_SKIN)

# caderas / faldón
add_part(cyl("faulds", 0.21, 0.16, 0.20, (0, 0, 0.95)), "pelvis", M_STEEL)
# vientre
add_part(cyl("belly", 0.165, 0.185, 0.16, (0, 0, 1.10)), "spine", M_CRIMSON)
# peto
b = add_part(cyl("breastplate", 0.20, 0.165, 0.34, (0, 0, 1.30)), "chest", M_STEEL)
b.scale = (1.0, 0.78, 1.0)
bpy.context.view_layer.objects.active = b
bpy.ops.object.transform_apply(scale=True)
# gorjal
add_part(cyl("gorget", 0.10, 0.13, 0.08, (0, 0, 1.50)), "neck", M_STEEL)

# cabeza
add_part(box("head", (0.24, 0.24, 0.26), (0, 0, 1.70)), "head", M_SKIN)
add_part(box("nose", (0.05, 0.05, 0.07), (0, -0.135, 1.69)), "head", M_SKIN)
for sign in (1, -1):
    add_part(box(f"eye{sign}", (0.045, 0.02, 0.05), (sign * 0.06, -0.125, 1.74)),
        "head", M_DARK)
add_part(box("beard", (0.20, 0.06, 0.12), (0, -0.105, 1.60)), "head", M_BEARD)

# morrión (casco con cresta y ala)
add_part(sphere("helmet", 0.155, (0, 0, 1.83), (1.0, 1.05, 0.85)), "head", M_STEEL)
add_part(cyl("brim", 0.23, 0.20, 0.035, (0, 0, 1.80)), "head", M_STEEL)
crest = add_part(box("crest", (0.035, 0.30, 0.16), (0, 0.0, 1.93)), "head", M_STEEL)
add_part(box("plume", (0.03, 0.16, 0.12), (0, 0.16, 1.94), (0.5, 0, 0)),
    "head", M_CRIMSON)

# capa (cuelga del pecho hacia atrás)
add_part(box("cape", (0.44, 0.05, 0.78), (0, 0.17, 1.06), (-0.12, 0, 0)),
    "chest", M_CRIMSON)

# espada en la mano derecha (hoja hacia abajo)
add_part(box("blade", (0.045, 0.012, 0.62), (-0.345, -0.02, 0.38)), "hand.R", M_STEEL)
add_part(box("guard", (0.16, 0.04, 0.04), (-0.345, -0.02, 0.70)), "hand.R", M_GOLD)
add_part(cyl("grip", 0.025, 0.025, 0.12, (-0.345, -0.02, 0.78)), "hand.R", M_LEATHER)
add_part(sphere("pommel", 0.035, (-0.345, -0.02, 0.85)), "hand.R", M_GOLD)

# ── Skinning rígido y unión ───────────────────────────────────────────
mesh_objs = []
for obj, bone_name in parts:
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    mesh_objs.append(obj)

bpy.ops.object.select_all(action="DESELECT")
for o in mesh_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = mesh_objs[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "Conquistador"

mod = body.modifiers.new("arm", "ARMATURE")
mod.object = rig
body.parent = rig

# sombreado plano estilizado
bpy.ops.object.shade_flat()

tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print(f"[*] conquistador low-poly: {tris} tris, {len(body.data.vertices)} verts")

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
    export_yup=True, export_skins=True, export_animations=False)
import os
print(f"[=] {os.path.basename(OUT)}: {os.path.getsize(OUT)/1e6:.2f} MB")
print("BUILD_OK")
