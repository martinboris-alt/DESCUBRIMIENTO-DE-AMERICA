"""Optimiza los GLB de Meshy para el juego: limpia objetos basura,
decima mallas y reduce texturas a 1K. Ejecutar con Blender headless:
  blender --background --python tools/blender_optimize_assets.py
"""
import bpy
import os
import sys

MODELS = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\nuevo-proyecto-de-juego\assets\models"
RECOVERED = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\recovered"

# (entrada, salida, tris objetivo, tamaño max textura, conservar armature)
JOBS = [
    (RECOVERED + r"\jungle_tree_refined.glb", "jungle_tree_opt.glb", 22000, 1024, False),
]


def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def process(src, dst, target_tris, tex_size, keep_armature):
    clean_scene()
    src_path = src if os.path.isabs(src) else os.path.join(MODELS, src)
    bpy.ops.import_scene.gltf(filepath=src_path)

    # Elimina objetos basura: mallas diminutas sin material ni vertex groups
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            junk = (len(obj.data.vertices) < 100
                    and not any(obj.data.materials)
                    and len(obj.vertex_groups) == 0)
            if junk:
                print(f"  [-] eliminando objeto basura: {obj.name}")
                bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type not in ("ARMATURE", "EMPTY"):
            bpy.data.objects.remove(obj, do_unlink=True)
    if not keep_armature:
        for obj in list(bpy.data.objects):
            if obj.type == "ARMATURE":
                bpy.data.objects.remove(obj, do_unlink=True)

    # Decimado
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        tris = tri_count(obj)
        if target_tris and tris > target_tris:
            ratio = target_tris / tris
            mod = obj.modifiers.new("dec", "DECIMATE")
            mod.ratio = ratio
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier="dec")
            print(f"  [~] {obj.name}: {tris} -> {tri_count(obj)} tris")

    # Reduce texturas
    for img in bpy.data.images:
        if img.size[0] > tex_size or img.size[1] > tex_size:
            print(f"  [~] textura {img.name}: {img.size[0]}x{img.size[1]} -> {tex_size}")
            img.scale(tex_size, tex_size)

    out = os.path.join(MODELS, dst)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_image_format="JPEG",
        export_jpeg_quality=80,
        export_animations=True,
        export_skins=keep_armature,
        export_yup=True,
    )
    mb = os.path.getsize(out) / 1e6
    print(f"  [=] {dst}: {mb:.1f} MB")


for job in JOBS:
    print(f"[*] procesando {job[0]} ...")
    try:
        process(*job)
    except Exception as e:
        print(f"  [!] ERROR en {job[0]}: {e}")
        sys.exit(1)

print("OPTIMIZACION_OK")
