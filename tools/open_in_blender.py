"""Abre Blender (GUI) con los modelos del héroe para inspección manual.
Lanzar SIN -b:
  "blender.exe" --python tools/open_in_blender.py
Importa el héroe Meshy original y el riggeado del juego, lado a lado.
"""
import bpy

ORIG = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\recovered_meshy\hero_conquistador.glb"
RIGGED = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\nuevo-proyecto-de-juego\assets\models\hero_conquistador.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)

# original (sin tocar) a la izquierda
bpy.ops.import_scene.gltf(filepath=ORIG)
for o in bpy.context.selected_objects:
    o.location.x -= 1.5

# riggeado actual (con la capa recortada) a la derecha
bpy.ops.import_scene.gltf(filepath=RIGGED)
for o in bpy.context.selected_objects:
    o.location.x += 1.5

# vista cómoda
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        for space in area.spaces:
            if space.type == "VIEW_3D":
                space.shading.type = "MATERIAL"
        for region in area.regions:
            if region.type == "WINDOW":
                override = {"area": area, "region": region}
                try:
                    with bpy.context.temp_override(**override):
                        bpy.ops.view3d.view_all()
                except Exception:
                    pass

print("OPEN_READY: izquierda=original Meshy, derecha=riggeado con capa recortada")
