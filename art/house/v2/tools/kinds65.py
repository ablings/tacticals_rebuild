"""1965 test-site House: the material kinds (hcore.K) shared by build_furniture_1965.py and build_house.py.
Palette from vault Map Styles / Test Site House ("use" column) and notes/house_1965_style.md. Everything is worn: dust on
tops, grime in creases and near the floor, chipped paint and enamel on edges, stains. No red / blue room surfaces."""
from hcore import K, DEF

DUST = 0.28        # tan film on up-facing faces
DIRT = 0.3

def _k(**kw):
    d = dict(DEF); d.update(dict(dust=DUST, dirt=DIRT)); d.update(kw); return d

NEW = {
    # woods (worn varnish: a little chip shows lighter raw wood on edges)
    "walnut65":      dict(under=(96, 62, 34), wood=True, stain=0.2, rough=0.5, mottle=0.1, paintable=True),
    "walnut_trim":   dict(under=(66, 44, 26), wood=True, stain=0.2, rough=0.5, mottle=0.08, paintable=True),
    "maple":         dict(under=(196, 156, 104), wood=True, stain=0.18, rough=0.5, mottle=0.08, paintable=True),
    "pine65":        dict(under=(168, 114, 58), wood=True, stain=0.15, rough=0.55, mottle=0.1, paintable=True),
    "birch":         dict(under=(196, 168, 120), wood=True, stain=0.15, rough=0.5, mottle=0.06, paintable=True),
    "walnut_slat65": dict(under=(96, 62, 34), wood=True, groove=True, stain=0.2, rough=0.5, mottle=0.1),
    # paints and enamels: chipped edges show the under colour (metal for enamel, raw wood for painted wood)
    # the kitchen's one saturated colour: harvest gold enamel (the brief). (206,160,52) read lemon under the warm sun,
    # so the value is lowered (184,128,36 then read peach-orange: 172,128,34) and the grime raised. The no-yellow rule is for the lobby only (Edward, 2026-10-28).
    "enamel_gold":   dict(paint=(172, 128, 34), under=(110, 108, 104), dirt=0.32, chip=0.4, metal_under=0.8, under_rough=0.35, rough=0.28, paintable=True),
    # avocado / olive enamel: the card's named alternative (not used by the kitchen since 2026-10-28)
    "enamel_olive":  dict(paint=(98, 106, 56), under=(110, 108, 104), chip=0.35, metal_under=0.8, under_rough=0.35, rough=0.28, paintable=True),
    "enamel_white":  dict(paint=(232, 228, 212), under=(70, 68, 66), chip=0.25, metal_under=0.6, rough=0.25, paintable=True),
    "enamel_cream":  dict(paint=(226, 216, 186), under=(70, 68, 66), chip=0.25, metal_under=0.6, rough=0.28, paintable=True),
    "enamel_mint":   dict(paint=(176, 204, 182), under=(200, 198, 190), chip=0.2, rough=0.2, paintable=True),
    "enamel_butter": dict(paint=(232, 214, 140), under=(200, 198, 190), chip=0.2, rough=0.2, paintable=True),
    "paint_green":   dict(paint=(92, 110, 80), under=(168, 128, 84), wood=True, chip=0.4, rough=0.55, paintable=True),
    "paint_cream":   dict(paint=(226, 220, 200), under=(168, 128, 84), wood=True, chip=0.35, rough=0.5, paintable=True),
    "paint_white65": dict(paint=(230, 226, 210), under=(150, 140, 120), wood=True, chip=0.45, rough=0.5, paintable=True),
    "paint_grey_green": dict(paint=(120, 128, 112), under=(80, 80, 80), chip=0.3, metal_under=0.7, rough=0.45, paintable=True),
    # upholstery: vinyl cracks + stains, tweed, chenille; dirt in creases
    "vinyl_cream":   dict(paint=(210, 200, 162), stitch=True, rough=0.4, mottle=0.12, bump=0.3, dirt=0.42),
    "vinyl_mustard": dict(paint=(196, 146, 46), stitch=True, rough=0.38, mottle=0.12, bump=0.3, dirt=0.4),
    "vinyl_olive":   dict(paint=(118, 124, 70), stitch=True, rough=0.4, mottle=0.12, bump=0.3, dirt=0.4),
    "tweed_olive":   dict(paint=(118, 112, 70), weave=True, stitch=True, rough=0.95, mottle=0.12, bump=0.45, dirt=0.4),
    "tweed_mustard": dict(paint=(186, 142, 58), weave=True, stitch=True, rough=0.95, mottle=0.12, bump=0.45, dirt=0.4),
    "tweed_brown":   dict(paint=(110, 84, 58), weave=True, stitch=True, rough=0.95, mottle=0.12, bump=0.45, dirt=0.4),
    "chenille":      dict(paint=(226, 218, 192), weave=True, rough=0.98, mottle=0.06, bump=0.5, paintable=True),
    "spread":        dict(paint=(200, 190, 160), weave=True, rough=0.95, mottle=0.06, bump=0.3, paintable=True),
    "linen_old":     dict(paint=(222, 214, 192), weave=True, rough=0.95, mottle=0.08, bump=0.3),
    # floor-length dining tablecloth: yellowed cream linen, dust on the top and folds, grime at the hem (fix65)
    "hem65":         dict(paint=(122, 128, 80), weave=True, rough=0.95, mottle=0.1, bump=0.3, dirt=0.55, dust=0.2),
    "tablecloth65":  dict(paint=(218, 208, 180), weave=True, rough=0.95, mottle=0.12, bump=0.35, dirt=0.5, dust=0.35, bleach=0.12, paintable=True),
    "foam":          dict(paint=(214, 192, 126), rough=0.95, mottle=0.2, bump=0.8),
    "drape_gold":    dict(paint=(190, 146, 58), weave=True, rough=0.95, mottle=0.12, bump=0.4, bleach=0.25),
    "drape_mustard": dict(paint=(196, 156, 60), weave=True, rough=0.95, mottle=0.12, bump=0.4, bleach=0.25),
    "drape_green":   dict(paint=(52, 78, 58), weave=True, rough=0.95, mottle=0.12, bump=0.4, bleach=0.25),
    "runner_moss":   dict(paint=(82, 98, 58), weave=True, rough=0.98, mottle=0.12, bump=0.5),
    "rug65":         dict(paint=(190, 170, 130), weave=True, rough=0.98, paintable=True, bump=0.5),
    # metals: chrome pitted, brass dulled, steel brushed
    "chrome65":      dict(paint=(206, 206, 202), rough=0.18, metal_paint=1.0, mottle=0.05, rust=0.12, rust_col=((96, 70, 44), (130, 100, 64)), dirt=0.35),
    "brass":         dict(paint=(180, 150, 80), rough=0.35, metal_paint=1.0, mottle=0.12, dirt=0.4),
    "steel65":       dict(paint=(160, 160, 154), rough=0.4, metal_paint=1.0, mottle=0.08, streak=0.3, dirt=0.4, paintable=True),
    "iron_black":    dict(paint=(36, 34, 32), rough=0.55, metal_paint=0.5, mottle=0.06, rust=0.2),
    "tin":           dict(paint=(170, 170, 164), rough=0.35, metal_paint=1.0, rust=0.25, paintable=True),
    # counters, ceramics, glass, plastics, paper
    "laminate":      dict(paint=(138, 134, 118), rough=0.4, mottle=0.08, vein=0.15, vein_col=(120, 116, 104), paintable=True),
    "ceramic65":     dict(paint=(232, 226, 210), rough=0.15, dirt=0.35, mottle=0.04, paintable=True),
    "ceramic_mint":  dict(paint=(176, 204, 182), rough=0.15, dirt=0.35, mottle=0.04),
    "ceramic_butter": dict(paint=(232, 214, 140), rough=0.15, dirt=0.35, mottle=0.04),
    "ceramic_olive": dict(paint=(138, 156, 74), rough=0.2, dirt=0.3, mottle=0.06),
    "tile_mint65":   dict(paint=(176, 204, 182), tile=0.75, grout=(150, 146, 132), rough=0.2, dirt=0.4),
    "tile_butter65": dict(paint=(232, 214, 140), tile=0.75, grout=(150, 146, 132), rough=0.2, dirt=0.4),
    "brick":         dict(paint=(146, 96, 70), bricks=1.0, rough=0.85, mottle=0.2, bump=0.6, dirt=0.45),
    "stone65":       dict(paint=(118, 108, 92), stones=0.9, rough=0.9, mottle=0.25, bump=0.8, dirt=0.4),
    "glass65":       dict(paint=(60, 66, 62), rough=0.1, dirt=0.25, mottle=0.06),
    "screen_crt":    dict(paint=(40, 46, 44), rough=0.12, dirt=0.2, mottle=0.08),
    "speaker_cloth": dict(paint=(150, 130, 96), weave=True, rough=0.95, bump=0.6, mottle=0.1),
    "bakelite":      dict(paint=(70, 46, 30), rough=0.3, mottle=0.1),
    "bakelite_cream": dict(paint=(226, 214, 180), rough=0.3, mottle=0.06, paintable=True),
    "phone_olive":   dict(paint=(107, 122, 58), rough=0.3, mottle=0.06),
    "paper65":       dict(paint=(232, 222, 192), rough=0.85, paintable=True, dirt=0.25, mottle=0.06),
    "canvas65":      dict(paint=(226, 216, 186), rough=0.8, paintable=True, dirt=0.15),
    "frame_gold":    dict(paint=(176, 138, 64), under=(90, 70, 40), chip=0.25, rough=0.35, metal_paint=0.7, mottle=0.1, dirt=0.5),
    "book65_olive":  dict(paint=(92, 104, 58), rough=0.7), "book65_brown": dict(paint=(110, 72, 44), rough=0.7),
    "book65_cream":  dict(paint=(214, 204, 176), rough=0.75), "book65_mustard": dict(paint=(190, 150, 60), rough=0.7),
    "book65_grey":   dict(paint=(96, 96, 90), rough=0.7), "book65_rust": dict(paint=(140, 86, 52), rough=0.7),
    "book65_green":  dict(paint=(58, 80, 62), rough=0.7),
    "record_black":  dict(paint=(18, 18, 18), rough=0.3),
    "dummy_skin":    dict(paint=(196, 192, 180), rough=0.6, mottle=0.08, dirt=0.35),
    "dummy_joint":   dict(paint=(120, 116, 106), rough=0.5, metal_paint=0.3),
    "cloth_cardigan": dict(paint=(150, 136, 96), weave=True, rough=0.95, bump=0.5),
    "cloth_suit":    dict(paint=(92, 86, 74), weave=True, rough=0.9, bump=0.3),
    "cloth_skirt":   dict(paint=(118, 124, 70), weave=True, rough=0.95, bump=0.3),
    "cloth_shirt":   dict(paint=(214, 206, 180), weave=True, rough=0.9, bump=0.25),
    "shoe":          dict(paint=(46, 34, 24), rough=0.4),
    "food_roast":    dict(paint=(122, 72, 40), rough=0.6, mottle=0.3, bump=0.6),
    "food_cake":     dict(paint=(232, 220, 190), rough=0.7, mottle=0.08),
    "wax_fruit":     dict(paint=(196, 150, 60), rough=0.3, mottle=0.25),
    "wax_fruit2":    dict(paint=(138, 156, 74), rough=0.3, mottle=0.25),
    "sand":          dict(paint=(206, 180, 136), rough=1.0, mottle=0.18, bump=0.6, dirt=0.1, dust=0.0),
    "web":           dict(paint=(226, 224, 216), rough=1.0, dirt=0.0, dust=0.0),
    "toy_olive":     dict(paint=(107, 122, 58), rough=0.35, chip=0.3, under=(200, 190, 160), paintable=True),
    "toy_mustard":   dict(paint=(204, 150, 40), rough=0.35, chip=0.3, under=(200, 190, 160), paintable=True),
    "toy_cream":     dict(paint=(236, 232, 218), rough=0.35, chip=0.3, under=(160, 120, 80), paintable=True),
    "rubber65":      dict(paint=(30, 30, 28), rough=0.9, dirt=0.4),
    "plinth65":      dict(paint=(40, 32, 24), rough=0.6, dirt=0.5),
    "shade65":       dict(paint=(226, 212, 176), weave=True, rough=0.95, mottle=0.08, bump=0.2, dirt=0.25, paintable=True),
    "bulb65":        dict(paint=(250, 236, 200), rough=0.15, dirt=0.0, mottle=0.02, dust=0.0),
    "opal":          dict(paint=(236, 230, 214), rough=0.2, dirt=0.15, mottle=0.04),
    "leaf65":        dict(paint=(64, 86, 50), rough=0.5, mottle=0.2, bump=0.3, dirt=0.25),
    "leaf65_dry":    dict(paint=(118, 110, 62), rough=0.6, mottle=0.25, bump=0.3, dirt=0.25),
    "terracotta65":  dict(paint=(156, 100, 70), rough=0.85, mottle=0.12, bump=0.5, dirt=0.4),
    "soil65":        dict(paint=(70, 54, 36), rough=0.95, mottle=0.3, bump=0.9),
    "tape":          dict(paint=(214, 196, 150), rough=0.8, mottle=0.1, dirt=0.15, dust=0.0),
    "china":         dict(paint=(236, 232, 218), rough=0.12, dirt=0.15, mottle=0.03, paintable=True),
}
for k_, v_ in NEW.items():
    K[k_] = _k(**v_)
