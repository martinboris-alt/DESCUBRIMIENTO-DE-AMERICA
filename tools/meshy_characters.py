"""Genera personajes/props mejorados con Meshy AI siguiendo principios de
diseño AAA: silueta legible, lectura por color, proporciones estilizadas,
y pidiendo bajo recuento de polígonos para juego.

Uso:  python tools/meshy_characters.py            (lanza y descarga todo)
      python tools/meshy_characters.py <task_id>  (reanuda una tarea)
Las salidas van a recovered_meshy/  (luego se optimizan con Blender).
"""
import urllib.request
import json
import time
import os
import sys

API_KEY = "msy_SplTfe4oJCiVxpOBaZ8ZApzJ0wTVTWtM6oYr"
BASE = "https://api.meshy.ai/openapi/v2/text-to-3d"
OUT = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\recovered_meshy"
os.makedirs(OUT, exist_ok=True)

HEADERS = {"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"}

# Principios AAA aplicados en los prompts:
#  - silueta: "clear strong silhouette, readable from distance"
#  - lectura de color: paletas distintas héroe/enemigo/jefe
#  - estilizado: "stylized low-poly, Crash Bandicoot / Spyro style"
#  - pose neutra para rig: "A-pose"
ASSETS = [
    {
        "name": "hero_conquistador",
        "prompt": ("Stylized low-poly Spanish conquistador hero for a platformer "
            "game, shiny steel morion helmet with tall red plume, polished "
            "breastplate, short red cape, brown leather boots and gloves, "
            "heroic confident A-pose, exaggerated broad shoulders and strong "
            "silhouette, bright saturated colors, clean readable shapes, "
            "Crash Bandicoot Spyro cartoon style, game ready character"),
        "art_style": "realistic",
        "neg": "realistic, photoreal, high poly, scary, gore, dark, blurry, extra limbs",
    },
    {
        "name": "enemy_jaguar_warrior",
        "prompt": ("Stylized low-poly Aztec jaguar warrior enemy for a platformer "
            "game, jaguar pelt helmet with open jaws, teal and orange war paint, "
            "feathered shield, obsidian club, menacing crouched A-pose, strong "
            "readable silhouette distinct from a knight, bright saturated colors, "
            "Crash Bandicoot cartoon style, game ready character"),
        "art_style": "realistic",
        "neg": "realistic, photoreal, high poly, gore, blurry, knight armor, extra limbs",
    },
    {
        "name": "boss_temple_guardian",
        "prompt": ("Stylized low-poly giant Aztec stone golem temple guardian boss "
            "for a platformer game, carved jade and gold serpent motifs, glowing "
            "green eyes, massive imposing A-pose, huge fists, towering threatening "
            "silhouette, bright saturated colors, Crash Bandicoot cartoon style, "
            "game ready boss character"),
        "art_style": "realistic",
        "neg": "realistic, photoreal, high poly, human, small, blurry, extra limbs",
    },
]


def api(method, url, data=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def submit(asset):
    res = api("POST", BASE, {
        "mode": "preview",
        "prompt": asset["prompt"],
        "art_style": asset["art_style"],
        "negative_prompt": asset["neg"],
        "ai_model": "meshy-5",
        "topology": "triangle",
        "target_polycount": 6000,
        "should_remesh": True,
    })
    return res["result"]


def poll(task_id):
    while True:
        t = api("GET", f"{BASE}/{task_id}")
        st = t["status"]
        prog = t.get("progress", 0)
        print(f"  [{task_id[:8]}] {st} {prog}%", flush=True)
        if st in ("SUCCEEDED", "FAILED", "EXPIRED"):
            return t
        time.sleep(15)


def refine(task_id):
    """Pide la versión refinada (texturada) del preview."""
    res = api("POST", BASE, {"mode": "refine", "preview_task_id": task_id})
    return res["result"]


def download(t, name):
    urls = t.get("model_urls", {})
    glb = urls.get("glb")
    if not glb:
        print(f"  [!] sin glb para {name}")
        return
    dst = os.path.join(OUT, name + ".glb")
    urllib.request.urlretrieve(glb, dst)
    print(f"  [=] {name}.glb -> {os.path.getsize(dst)/1e6:.1f} MB", flush=True)


def run_asset(asset):
    print(f"[*] {asset['name']}: enviando preview...", flush=True)
    pid = submit(asset)
    pt = poll(pid)
    if pt["status"] != "SUCCEEDED":
        print(f"  [!] preview falló: {pt['status']}")
        return
    print(f"[*] {asset['name']}: refinando (texturas)...", flush=True)
    rid = refine(pid)
    rt = poll(rid)
    if rt["status"] != "SUCCEEDED":
        print(f"  [!] refine falló, uso preview")
        rt = pt
    download(rt, asset["name"])


def main():
    for a in ASSETS:
        try:
            run_asset(a)
        except Exception as e:
            print(f"  [!] ERROR {a['name']}: {type(e).__name__} {e}", flush=True)
            try:
                print("  BODY", e.read().decode())
            except Exception:
                pass
    print("MESHY_DONE", flush=True)


if __name__ == "__main__":
    main()
