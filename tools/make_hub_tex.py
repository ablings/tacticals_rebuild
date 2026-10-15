"""Own procedural textures for the Tacticals hub (pass hub1).

numpy + PIL only. Every map is seamless (noise is built in the frequency domain, so it wraps; all
patterns are laid out on whole-tile periods). Colour maps are near-white neutral grey so Part.Color /
MeshPart.Color tints them in Studio. Run: python tools/make_hub_tex.py
Outputs to tex/, contact sheet to out/hub1/tex_sheet.jpg, index to tex/textures.json.
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "tex")
OUT = os.path.join(ROOT, "out", "hub1")
os.makedirs(TEX, exist_ok=True); os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1406)
INDEX = {}

# ---------------------------------------------------------------- helpers
def pnoise(h, w, beta=2.0, lo=1.0, hi=None):
    """Periodic 1/f^beta noise in [-1,1] (wraps seamlessly)."""
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.zeros_like(f)
    m = f >= lo
    if hi is not None:
        m &= f <= hi
    amp[m] = 1.0 / f[m] ** (beta / 2.0)
    ph = np.exp(2j * np.pi * rng.random((h, w)))
    n = np.real(np.fft.ifft2(amp * ph))
    n -= n.mean(); n /= (np.abs(n).max() + 1e-9)
    return n

def blur(a, sigma):
    """Periodic gaussian blur via FFT."""
    if sigma <= 0:
        return a
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]; fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))

def blur_x(a, sigma):
    h, w = a.shape
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * fx * fx)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))

def normal_from_height(hgt, strength):
    """Roblox / OpenGL style (+Y up = green) tangent normal map from a height field (units = px)."""
    dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5 * strength
    dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5 * strength
    nx, ny, nz = -dx, dy, np.ones_like(hgt)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5
    return (rgb * 255).clip(0, 255).astype(np.uint8)

def save_l(a, name):  # a in 0..1
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(TEX, name))

def save_rgb(a, name):  # a HxWx3 uint8 or grey 0..1
    if a.ndim == 2:
        a = np.repeat((np.clip(a, 0, 1) * 255).astype(np.uint8)[..., None], 3, -1)
    Image.fromarray(a, "RGB").save(os.path.join(TEX, name))

def save_rgba(rgb, alpha, name):
    h, w = alpha.shape
    if np.isscalar(rgb) or np.ndim(rgb) == 1:
        c = np.zeros((h, w, 3), np.uint8); c[:] = rgb
    else:
        c = rgb
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([c, a]), "RGBA").save(os.path.join(TEX, name))

def reg(name, use, spt, **kw):
    INDEX[name] = dict(use=use, studs_per_tile=spt, **kw)

def boxmask(h, w, x0, y0, x1, y1):
    m = np.zeros((h, w)); m[y0:y1, x0:x1] = 1; return m

def groove(h, w, lines_x=(), lines_y=(), width=4, soft=1.5):
    """Height field: 0 flat, -1 in grooves. Lines wrap."""
    g = np.zeros((h, w))
    for x in lines_x:
        for k in range(-width // 2, width - width // 2):
            g[:, (x + k) % w] = 1
    for y in lines_y:
        for k in range(-width // 2, width - width // 2):
            g[(y + k) % h, :] = 1
    return -blur(g, soft).clip(0, 1)

# ---------------------------------------------------------------- 1 smooth concrete (walls, the Concrete override)
def concrete_smooth():
    n = 1024
    base = 0.6 * pnoise(n, n, 2.2, 2) + 0.3 * pnoise(n, n, 2.0, 16) + 0.1 * pnoise(n, n, 1.5, 64)
    mott = blur(rng.random((n, n)), 1.0); mott = (mott - mott.mean()) / mott.std()
    col = 0.905 + 0.025 * base + 0.004 * mott  # ~231 +-6 levels, no specks
    save_rgb(col, "hub_concrete_smooth_color.png")
    hgt = 2.0 * base + 0.35 * blur(rng.random((n, n)), 0.8)
    save_rgb(normal_from_height(hgt, 1.2), "hub_concrete_smooth_normal.png")
    save_l(0.80 + 0.06 * pnoise(n, n, 2.0, 4), "hub_concrete_smooth_rough.png")
    reg("hub_concrete_smooth_*", "MaterialVariant 'TacConcrete' (base Concrete) = MaterialService Concrete override; all wall mass, frames, ceilings", 12,
        maps=["color", "normal", "roughness"], pattern="Organic")

# ---------------------------------------------------------------- 2 concrete with panel seams
def concrete_panels():
    n = 1024
    base = 0.6 * pnoise(n, n, 2.2, 2) + 0.3 * pnoise(n, n, 2.0, 16)
    # 2 x 2 panels (10 x 10 studs each at 20 spt), the lower row split by an offset horizontal seam
    g = groove(n, n, lines_x=(0, 512), lines_y=(0, 512), width=6, soft=1.2)
    g2 = np.zeros((n, n)); g2[766:772, 0:512] = 1; g2 = -blur(g2, 1.2).clip(0, 1)
    g3 = np.zeros((n, n)); g3[256:262, 512:1024] = 1; g3 = -blur(g3, 1.2).clip(0, 1)
    seams = np.minimum(np.minimum(g, g2), g3)
    # bolts near panel corners
    yy, xx = np.mgrid[0:n, 0:n]
    bolts = np.zeros((n, n))
    for px in (0, 512):
        for py in (0, 512):
            for ox in (28, 484):
                for oy in (28, 484):
                    cx, cy = px + ox, py + oy
                    d = np.sqrt(((xx - cx + n / 2) % n - n / 2) ** 2 + ((yy - cy + n / 2) % n - n / 2) ** 2)
                    bolts += np.clip(1 - (d / 7.0) ** 2, 0, 1)
    # slight panel-to-panel tone shift
    tone = np.zeros((n, n))
    for i, (x0, y0) in enumerate([(0, 0), (512, 0), (0, 512), (512, 512)]):
        tone[y0:y0 + 512, x0:x0 + 512] = [0.0, 0.012, -0.01, 0.006][i]
    col = 0.90 + 0.022 * base + tone + 0.10 * seams - 0.03 * bolts
    edge_dirt = blur((seams < -0.2).astype(float), 6) * 0.05
    col -= edge_dirt
    save_rgb(col, "hub_concrete_panels_color.png")
    hgt = 1.5 * base + 6.0 * seams + 2.5 * bolts
    save_rgb(normal_from_height(blur(hgt, 0.7), 1.0), "hub_concrete_panels_normal.png")
    save_l(0.78 + 0.05 * pnoise(n, n, 2, 4) - 0.1 * bolts + 0.08 * (seams < -0.2), "hub_concrete_panels_rough.png")
    reg("hub_concrete_panels_*", "MaterialVariant 'TacConcretePanels' (base Concrete): wall bay plates, door-frame cheeks, cladding", 20,
        maps=["color", "normal", "roughness"], pattern="Regular", note="one tile = 2x2 panels of 10 studs, offset sub-seams, corner bolts")

# ---------------------------------------------------------------- 3 corrugated metal sheet (deep trapezoid ribs)
def corrugated_metal():
    n = 512
    ribs = 8
    x = (np.arange(n) / n * ribs) % 1.0
    # trapezoid: flat top 40%, slope 10%, flat bottom 40%, slope 10%
    p = np.where(x < 0.4, 1.0, np.where(x < 0.5, 1 - (x - 0.4) / 0.1, np.where(x < 0.9, 0.0, (x - 0.9) / 0.1)))
    hgt = np.tile(p[None, :], (n, 1)) * 10.0
    hgt = blur(hgt, 1.2)
    drip = blur(rng.random((n, n)) * (rng.random((1, n)) > 0.7), 0.0)
    drip = np.real(np.fft.ifft2(np.fft.fft2(drip) * np.exp(-2 * (np.pi * 40) ** 2 * (np.fft.fftfreq(n)[:, None] ** 2))))
    drip = (drip - drip.min()) / (np.ptp(drip) + 1e-9)
    col = 0.86 + 0.03 * pnoise(n, n, 2, 2) + 0.04 * (hgt / 10.0 - 0.5) - 0.04 * drip
    save_rgb(col, "hub_corrugated_metal_color.png")
    save_rgb(normal_from_height(hgt, 1.0), "hub_corrugated_metal_normal.png")
    save_l(0.48 + 0.10 * drip + 0.04 * pnoise(n, n, 2, 2), "hub_corrugated_metal_rough.png")
    save_l(np.full((64, 64), 0.85), "hub_metalness_085.png")
    reg("hub_corrugated_metal_*", "MaterialVariant 'TacCorrugatedMetal' (base Metal): tunnel cladding, crate panels, upper shell bands, catwalk kick plates", 16,
        maps=["color", "normal", "roughness", "metalness=hub_metalness_085.png"], pattern="Regular", note="8 trapezoid ribs per tile, ribs run along V")

# ---------------------------------------------------------------- 4 fine corrugation (normal only, for concrete shells)
def corrugated_fine():
    n = 512
    x = np.arange(n) / n * 16 * 2 * np.pi
    hgt = np.tile(np.sin(x)[None, :] * 3.0, (n, 1)) + 0.4 * pnoise(n, n, 2, 4)
    save_rgb(normal_from_height(hgt, 1.0), "hub_corrugated_fine_normal.png")
    save_l(0.72 + 0.05 * pnoise(n, n, 2, 2), "hub_corrugated_fine_rough.png")
    save_rgb(np.full((n, n), 0.9), "hub_corrugated_fine_color.png")
    reg("hub_corrugated_fine_*", "MaterialVariant 'TacRibbed' (base Concrete): upper wall band shells and roof soffit panels (ribs from normal only)", 10,
        maps=["color(flat)", "normal", "roughness"], pattern="Regular", note="16 sine ribs per tile")

# ---------------------------------------------------------------- 5 metal floor plate (panels + tread insets)
def metal_floorplate():
    n = 1024
    base = pnoise(n, n, 2, 2)
    # 4 x 4 plate grid (5 studs each at 20 spt), alternate plates carry a lozenge tread
    lines = [0, 256, 512, 768]
    g = groove(n, n, lines_x=lines, lines_y=lines, width=5, soft=1.0)
    yy, xx = np.mgrid[0:n, 0:n]
    tread = np.zeros((n, n))
    for i in range(4):
        for j in range(4):
            if (i + j) % 2 == 0:
                cx, cy = i * 256 + 128, j * 256 + 128
                lx, ly = (xx - cx), (yy - cy)
                inside = (np.abs(lx) < 100) & (np.abs(ly) < 100)
                u = ((lx + ly) % 32); v = ((lx - ly) % 32)
                d = (np.abs(u - 16) < 3.5) & (v < 20)
                tread += (inside & d)
    tread = blur(tread, 0.8)
    bolts = np.zeros((n, n))
    for x0 in lines:
        for y0 in lines:
            for ox, oy in ((14, 14), (242, 14), (14, 242), (242, 242)):
                d = np.sqrt((xx - x0 - ox) ** 2 + (yy - y0 - oy) ** 2)
                bolts += np.clip(1 - (d / 6) ** 2, 0, 1)
    wear = blur(rng.random((n, n)), 2.0); wear = (wear - wear.mean()) / wear.std()
    col = 0.84 + 0.03 * base + 0.12 * g + 0.04 * tread - 0.06 * bolts + 0.006 * wear
    save_rgb(col, "hub_metal_floorplate_color.png")
    save_rgb(normal_from_height(5 * g + 2.2 * tread + 2.0 * bolts + 0.3 * base, 1.0), "hub_metal_floorplate_normal.png")
    save_l(0.55 + 0.05 * base - 0.12 * tread + 0.1 * (g < -0.3), "hub_metal_floorplate_rough.png")
    reg("hub_metal_floorplate_*", "MaterialVariant 'TacFloorPlate' (base Metal or DiamondPlate override): centre ring plates, landing, catwalk/bridge decks, door thresholds", 20,
        maps=["color", "normal", "roughness", "metalness=hub_metalness_085.png"], pattern="Regular", note="4x4 plates of 5 studs, checker tread inserts, bolts")

# ---------------------------------------------------------------- 6 sealed hangar floor concrete
def floor_concrete():
    n = 1024
    base = 0.6 * pnoise(n, n, 2.2, 2) + 0.4 * pnoise(n, n, 2.0, 8)
    yy, xx = np.mgrid[0:n, 0:n] / n
    arcs = np.zeros((n, n))
    for k in range(9):  # trowel arcs (periodic via sin of distance on torus-ish combos)
        cx, cy, r = rng.random(), rng.random(), 0.2 + 0.3 * rng.random()
        dx = np.minimum(np.abs(xx - cx), 1 - np.abs(xx - cx)); dy = np.minimum(np.abs(yy - cy), 1 - np.abs(yy - cy))
        d = np.sqrt(dx * dx + dy * dy)
        arcs += np.exp(-((d - r) / 0.008) ** 2) * (0.5 + 0.5 * np.sin(np.arctan2(dy, dx) * 3 + k))
    arcs = blur(arcs, 1.5)
    # 2 x 2 saw-cut joints (10 studs at 20 spt)
    cut = groove(n, n, lines_x=(0, 512), lines_y=(0, 512), width=3, soft=0.8)
    col = 0.88 + 0.03 * base + 0.08 * cut
    save_rgb(col, "hub_floor_concrete_color.png")
    save_rgb(normal_from_height(0.8 * base + 4 * cut + 0.2 * arcs, 1.0), "hub_floor_concrete_normal.png")
    save_l(0.52 + 0.06 * base - 0.05 * arcs.clip(0, 1) + 0.15 * (cut < -0.3), "hub_floor_concrete_rough.png")
    reg("hub_floor_concrete_*", "MaterialVariant 'TacFloorConcrete' (base Concrete, used only on floor slabs): hub floor field and borders (tinted 36-62)", 20,
        maps=["color", "normal", "roughness"], pattern="Organic", note="sealed, low roughness, trowel arcs in roughness, 10-stud saw cuts")

# ---------------------------------------------------------------- 7 satin metal (Metal override)
def metal_satin():
    n = 1024
    streak = blur_x(rng.standard_normal((n, n)), 40); streak /= np.abs(streak).max()
    col = 0.86 + 0.02 * pnoise(n, n, 2, 2) + 0.015 * streak
    save_rgb(col, "hub_metal_satin_color.png")
    save_rgb(normal_from_height(1.5 * streak, 1.0), "hub_metal_satin_normal.png")
    save_l(0.42 + 0.05 * streak + 0.04 * pnoise(n, n, 2, 2), "hub_metal_satin_rough.png")
    reg("hub_metal_satin_*", "MaterialVariant 'TacMetal' (base Metal) = MaterialService Metal override: trims, kerbs, pilaster caps, rails, door leaves", 10,
        maps=["color", "normal", "roughness", "metalness=hub_metalness_085.png"], pattern="Regular", note="faint brushed streaks along U")

# ---------------------------------------------------------------- overlays (Texture objects, alpha)
def panel_line_overlay():
    n = 1024
    im = Image.new("L", (n, n), 0); d = ImageDraw.Draw(im)
    w = 4
    d.rectangle([0, 0, n - 1, n - 1], outline=255, width=w)                 # tile border (shared with neighbour)
    d.line([(n // 2, 0), (n // 2, n)], fill=255, width=w)                   # two big halves
    d.line([(n // 2, n * 5 // 8), (n, n * 5 // 8)], fill=255, width=w)      # right half split
    d.line([(n * 3 // 4, n * 5 // 8), (n * 3 // 4, n)], fill=255, width=w)
    d.line([(0, n // 4), (n // 2, n // 4)], fill=255, width=w)
    for (x, y) in [(20, 20), (n // 2 - 20, 20), (20, n // 4 - 20), (n // 2 + 20, n * 5 // 8 + 20), (n - 20, n - 20), (n // 2 + 20, n - 20)]:
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=255)
    a = np.asarray(im) / 255.0
    save_rgba(255, a, "hub_overlay_panel_lines.png")
    reg("hub_overlay_panel_lines.png", "Texture (Top face), Color3 ~81 grey, Transparency 0 (0.9 as dark overlay): spawn-disc plates, pad floors, landing", "20 x 20")

def grid_overlay():
    n = 512
    im = Image.new("L", (n, n), 0); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, n - 1, n - 1], outline=255, width=2)
    for (x, y) in [(0, 0)]:
        pass
    for cx in (0, n):
        for cy in (0, n):
            d.line([(cx - 24, cy), (cx + 24, cy)], fill=255, width=6)
            d.line([(cx, cy - 24), (cx, cy + 24)], fill=255, width=6)
    save_rgba(255, np.asarray(im) / 255.0, "hub_overlay_grid.png")
    reg("hub_overlay_grid.png", "Texture, all faces, Transparency 0.75, Color3 black: training range boxes (not used in the hub)", "5 x 5")

def grate():
    n = 512
    a = np.ones((n, n))
    # bar grating: bearing bars every 32 px (6 px wide) along V, cross rods every 128 px (8 px)
    x = np.arange(n)
    holes = ((x % 32) >= 6)[None, :] & ((x % 128) >= 8)[:, None]
    a[holes] = 0
    a = blur(a, 0.6).clip(0, 1)
    shade = np.ones((n, n)) * 235
    save_rgba(np.repeat(shade[..., None], 3, -1).astype(np.uint8), a, "hub_grate_alpha.png")
    hgt = blur(a, 2.0) * 8
    save_rgb(normal_from_height(hgt, 1.0), "hub_grate_normal.png")
    reg("hub_grate_alpha.png", "Texture (Top) on near-black host part, Color3 70-80: drain grates round the spawn disc, catwalk deck insets", "3 x 3",
        extra="hub_grate_normal.png if used as a SurfaceAppearance with AlphaMode Transparency")

def trim_strip():
    w, h = 1024, 128
    im = Image.new("L", (w, h), 0); d = ImageDraw.Draw(im)
    d.rectangle([0, 10, w, 16], fill=255); d.rectangle([0, h - 17, w, h - 11], fill=255)
    for i in range(4):
        x = i * 256
        d.rectangle([x, 22, x + 4, h - 23], fill=255)
        for k in range(5):
            d.rectangle([x + 40 + k * 14, h // 2 - 10, x + 46 + k * 14, h // 2 + 10], fill=170)
        d.ellipse([x + 220, h // 2 - 6, x + 232, h // 2 + 6], fill=255)
    save_rgba(255, np.asarray(im) / 255.0, "hub_trim_strip.png")
    reg("hub_trim_strip.png", "Texture (front faces), Color3 59-81 grey: door reveals, the 2x4 display-wall role, panel strip above the olive band", "8 x 1")

def grime():
    n = 512
    g = 0.6 * pnoise(n, n, 2.0, 2) + 0.4 * pnoise(n, n, 1.6, 12)
    g = (g - g.min()) / np.ptp(g)
    yy = np.linspace(0, 1, n)[:, None]
    # vertical drip streaks + bottom-heavy gradient that still wraps (cosine in V)
    drip = blur_x(rng.random((n, n)) * 0 + 0, 1)
    streaks = np.real(np.fft.ifft2(np.fft.fft2(rng.random((n, n))) * np.exp(-2 * (np.pi * 60) ** 2 * (np.fft.fftfreq(n)[:, None] ** 2)) * np.exp(-2 * (np.pi * 1.5) ** 2 * (np.fft.fftfreq(n)[None, :] ** 2))))
    streaks = (streaks - streaks.min()) / np.ptp(streaks)
    a = (0.55 * g ** 2 + 0.45 * streaks ** 3) * (0.65 + 0.35 * np.cos(2 * np.pi * yy))
    a = (a / a.max()) * 0.6
    save_rgba(20, a, "hub_grime_overlay.png")
    reg("hub_grime_overlay.png", "Texture, Color3 black, Transparency 0.92-0.95: lower wall kick zones and props only (never on bands or floors)", 4)

def hazard():
    w, h = 512, 128
    yy, xx = np.mgrid[0:h, 0:w]
    s = ((xx + yy) // 32) % 2  # 45 deg, period 64 px -> wraps on 512 and 128
    cream = np.array([236, 232, 218]); black = np.array([10, 12, 10])
    wear = pnoise(h, w, 1.8, 8)
    wearm = (wear > 0.45)[..., None]
    col = np.where(s[..., None] == 0, cream, black).astype(float)
    col = np.where(wearm, col * 0.6 + np.array([60, 60, 58]) * 0.4, col)
    col += (pnoise(h, w, 2, 4) * 6)[..., None]
    Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGB").save(os.path.join(TEX, "hub_hazard_stripe.png"))
    reg("hub_hazard_stripe.png", "Texture (Top/front), Color3 white: pad edges, lift edges, kerb faces at the riser, KEEP CLEAR zones (cream on near-black)", "4 x 1")

def lane_marking():
    w, h = 1024, 256
    a = np.zeros((h, w))
    # runway style: solid edge line top, dashed centre stripes (each dash 1/2 tile), worn edges
    a[16:40, :] = 1
    a[h - 40:h - 16, :] = 1
    for i in range(2):
        a[96:160, i * 512 + 64: i * 512 + 448] = 1
    wear = pnoise(h, w, 1.6, 6) + 0.4 * pnoise(h, w, 1.2, 40)
    a = a * (wear < 0.35)
    a = blur(a, 0.7).clip(0, 1) * 0.95
    save_rgba(255, a, "hub_lane_marking.png")
    # chevron
    n = 512
    im = Image.new("L", (n, n), 0); d = ImageDraw.Draw(im)
    d.polygon([(96, 96), (256, 256), (96, 416), (176, 416), (336, 256), (176, 96)], fill=255)
    d.rectangle([0, 248, n, 264], fill=0)  # stencil bridge gap
    ch = np.asarray(im) / 255.0 * (pnoise(n, n, 1.6, 6) < 0.4)
    save_rgba(255, blur(ch, 0.6).clip(0, 1), "hub_chevron.png")
    reg("hub_lane_marking.png", "Texture/Decal (Top), Color3 cream 236,232,218 at 0.2 transp.: runway lane marking along walkways into each gate (edge lines + dashes)", "16 x 4")
    reg("hub_chevron.png", "Decal (Top), cream: direction chevrons toward gates", "decal 4 x 4")

def louvre():
    n = 256
    a = np.zeros((n, n))
    for i in range(0, n, 32):
        a[i:i + 6, :] = 1
    save_rgba(0, blur(a, 0.5).clip(0, 1), "hub_louvre.png")
    reg("hub_louvre.png", "Texture (Bottom) on Neon ceiling strips, Color3 black, Transparency 0.5", "0.6 x 1")

# ---------------------------------------------------------------- run + sheet
def sheet():
    files = sorted(f for f in os.listdir(TEX) if f.startswith("hub_") and f.endswith(".png"))
    cell = 220
    cols = 7
    rows = (len(files) + cols - 1) // cols
    S = Image.new("RGB", (cols * cell, rows * (cell + 22) + 40), (24, 25, 23))
    d = ImageDraw.Draw(S)
    try:
        font = ImageFont.truetype("arial.ttf", 12); big = ImageFont.truetype("arialbd.ttf", 18)
    except Exception:
        font = big = ImageFont.load_default()
    d.text((10, 10), "Tacticals hub1 textures (own, procedural, seamless; grey maps are tinted in Studio)", fill=(236, 232, 218), font=big)
    for i, f in enumerate(files):
        im = Image.open(os.path.join(TEX, f))
        if im.mode == "RGBA":
            bg = Image.new("RGB", im.size, (200, 196, 186) if ("louvre" in f or "grime" in f) else (40, 42, 38))
            # checker under alpha
            bg.paste(im, (0, 0), im)
            im = bg
        im = im.convert("RGB")
        # show tiling 2x for small/strip textures to prove seams
        tw, th = im.size
        t = Image.new("RGB", (tw * 2, th * 2))
        for a in range(2):
            for b in range(2):
                t.paste(im, (a * tw, b * th))
        t.thumbnail((cell - 8, cell - 8))
        x = (i % cols) * cell; y = 40 + (i // cols) * (cell + 22)
        S.paste(t, (x + 4 + (cell - 8 - t.size[0]) // 2, y + 4 + (cell - 8 - t.size[1]) // 2))
        d.text((x + 4, y + cell), f.replace("hub_", "").replace(".png", ""), fill=(200, 196, 186), font=font)
    S.save(os.path.join(OUT, "tex_sheet.jpg"), quality=90)

if __name__ == "__main__":
    for fn in (concrete_smooth, concrete_panels, corrugated_metal, corrugated_fine, metal_floorplate, floor_concrete, metal_satin,
               panel_line_overlay, grid_overlay, grate, trim_strip, grime, hazard, lane_marking, louvre):
        fn(); print("ok", fn.__name__)
    with open(os.path.join(TEX, "textures.json"), "w") as f:
        json.dump(dict(note="Own procedural textures (tools/make_hub_tex.py). Sheet: out/hub1/tex_sheet.jpg. 'studs_per_tile' = MaterialVariant.StudsPerTile or Texture.StudsPerTileU x V. Shown 2x2 tiled on the sheet to prove seams.",
                       textures=INDEX), f, indent=2)
    sheet(); print("sheet done")
