#!/usr/bin/env python3
"""Genere une couche de particules (poussiere, eclats, flash) calee sur les
impacts des planches du logo Garden Fence Studio."""

import numpy as np
from PIL import Image
import os, math

W, H, NF = 1920, 1080, 246
FPS = 30

# --- geometrie relevee sur la video source -------------------------------
IMPACTS = [20, 26, 33, 43, 58]          # frames d impact des 5 planches
PLANK_X = [765, 860, 955, 1050, 1145]   # centre horizontal de chaque planche
BASE_Y  = 617                            # ligne de sol (pied des planches)

rng = np.random.default_rng(20260913)

OUT = "dust"
os.makedirs(OUT, exist_ok=True)

# --- construction des particules ------------------------------------------
parts = []   # dicts: f0, x, y, vx, vy, life, size, bright, grav, drag

def burst(cx, cy, f0, n, kind):
    for _ in range(n):
        if kind == "dust":
            ang = rng.uniform(-math.pi * 0.95, -math.pi * 0.05)   # vers le haut
            spd = rng.uniform(1.2, 5.5)
            life = rng.integers(16, 40)
            size = rng.uniform(1.1, 2.6)
            br = rng.uniform(120, 210)
            grav, drag = 0.10, 0.955
        else:  # eclats de bois, plus rapides, plus nets
            ang = rng.uniform(-math.pi * 0.85, -math.pi * 0.15)
            spd = rng.uniform(4.0, 11.0)
            life = rng.integers(10, 24)
            size = rng.uniform(0.8, 1.7)
            br = rng.uniform(200, 255)
            grav, drag = 0.30, 0.985
        parts.append(dict(
            f0=int(f0), x=cx + rng.uniform(-26, 26), y=cy + rng.uniform(-7, 5),
            vx=math.cos(ang) * spd * rng.uniform(0.7, 1.9),
            vy=math.sin(ang) * spd,
            life=int(life), size=size, br=br, grav=grav, drag=drag))

for i, (fi, cx) in enumerate(zip(IMPACTS, PLANK_X)):
    burst(cx, BASE_Y, fi, 70, "dust")
    burst(cx, BASE_Y, fi, 22, "chip")

# poussiere ambiante qui flotte apres la construction
for _ in range(90):
    f0 = int(rng.integers(20, 200))
    parts.append(dict(
        f0=f0, x=rng.uniform(680, 1240), y=rng.uniform(300, 640),
        vx=rng.uniform(-0.35, 0.35), vy=rng.uniform(-0.55, -0.12),
        life=int(rng.integers(70, 150)), size=rng.uniform(0.9, 1.9),
        br=rng.uniform(35, 85), grav=0.0, drag=1.0))

# --- pre-calcul des trajectoires ------------------------------------------
tracks = []
for p in parts:
    x, y, vx, vy = p["x"], p["y"], p["vx"], p["vy"]
    pts = []
    for k in range(p["life"]):
        vy += p["grav"]
        vx *= p["drag"]; vy *= p["drag"]
        x += vx; y += vy
        if y > BASE_Y + 4:          # rebond amorti au sol
            y = BASE_Y + 4; vy = -vy * 0.32; vx *= 0.7
        a = (1.0 - k / p["life"]) ** 1.6
        pts.append((x, y, p["br"] * a, p["size"]))
    tracks.append((p["f0"], pts))

# --- noyau gaussien pour dessiner un point doux ---------------------------
def blob(sigma, R=4):
    ax = np.arange(-R, R + 1)
    g = np.exp(-(ax[:, None] ** 2 + ax[None, :] ** 2) / (2 * sigma ** 2))
    return g

# --- flash d'impact (halo radial court au sol) ----------------------------
yy, xx = np.mgrid[0:H, 0:W]

def render(n):
    buf = np.zeros((H, W), np.float32)

    # halo d'impact
    for fi, cx in zip(IMPACTS, PLANK_X):
        d = n - fi
        if 0 <= d < 8:
            amp = 70.0 * (1 - d / 8.0) ** 2
            r2 = ((xx - cx) / 95.0) ** 2 + ((yy - (BASE_Y - 6)) / 26.0) ** 2
            m = (r2 < 4)
            buf[m] += amp * np.exp(-r2[m])

    # particules
    for f0, pts in tracks:
        k = n - f0
        if 0 <= k < len(pts):
            x, y, br, size = pts[k]
            if br < 2:
                continue
            xi, yi = int(round(x)), int(round(y))
            if not (5 <= xi < W - 5 and 5 <= yi < H - 5):
                continue
            g = blob(max(0.55, size * 0.5)) * br
            buf[yi - 4:yi + 5, xi - 4:xi + 5] += g

    # la poussiere s eteint avec le fade out du logo (frames 213-246)
    if n > 212:
        buf *= max(0.0, 1.0 - (n - 212) / 32.0)

    return np.clip(buf, 0, 255).astype(np.uint8)

for n in range(NF):
    a = render(n)
    Image.fromarray(np.dstack([a, a, a])).save(f"{OUT}/{n:04d}.png",
                                               compress_level=1)
    if n % 40 == 0:
        print("frame", n, flush=True)

print("done", len(parts), "particules")
