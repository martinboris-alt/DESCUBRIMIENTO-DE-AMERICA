"""Regenera SOLO el héroe con piernas/botas visibles (sin capa larga)."""
import urllib.request, json, time, os

API_KEY = "msy_SplTfe4oJCiVxpOBaZ8ZApzJ0wTVTWtM6oYr"
BASE = "https://api.meshy.ai/openapi/v2/text-to-3d"
OUT = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\recovered_meshy"
os.makedirs(OUT, exist_ok=True)
H = {"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"}

PROMPT = ("Stylized low-poly Spanish conquistador hero for a platformer game, "
    "shiny steel morion helmet with tall red plume, polished breastplate, "
    "puffy slashed doublet sleeves, armored thighs with tassets, separated "
    "legs, tall brown leather boots clearly visible, gloved hands, heroic "
    "A-pose with arms and legs apart, exaggerated broad shoulders, strong "
    "readable silhouette, bright saturated colors, Crash Bandicoot Spyro "
    "cartoon style, game ready character")
NEG = ("long cape, cloak, robe, dress, skirt, realistic, photoreal, high poly, "
    "dark, blurry, extra limbs, fused legs")


def api(method, url, data=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=H, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def poll(tid):
    while True:
        t = api("GET", f"{BASE}/{tid}")
        print(f"  [{tid[:8]}] {t['status']} {t.get('progress',0)}%", flush=True)
        if t["status"] in ("SUCCEEDED", "FAILED", "EXPIRED"):
            return t
        time.sleep(15)


print("[*] hero v2: preview...", flush=True)
pid = api("POST", BASE, {"mode": "preview", "prompt": PROMPT, "art_style": "realistic",
    "negative_prompt": NEG, "ai_model": "meshy-5", "topology": "triangle",
    "target_polycount": 6000, "should_remesh": True})["result"]
pt = poll(pid)
if pt["status"] == "SUCCEEDED":
    print("[*] hero v2: refine...", flush=True)
    rid = api("POST", BASE, {"mode": "refine", "preview_task_id": pid})["result"]
    rt = poll(rid)
    if rt["status"] != "SUCCEEDED":
        rt = pt
    glb = rt.get("model_urls", {}).get("glb")
    if glb:
        dst = os.path.join(OUT, "hero_conquistador_v2.glb")
        urllib.request.urlretrieve(glb, dst)
        print(f"[=] hero_conquistador_v2.glb {os.path.getsize(dst)/1e6:.1f}MB", flush=True)
print("HERO2_DONE", flush=True)
