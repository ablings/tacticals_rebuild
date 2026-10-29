"""notes/house_1965_sheet.jpg: the reference (study frames, notes/ref/nuketown: never shipped) next to our 1965 House, per
room and for the window views. Ours = Blender Cycles previews (tools/preview_1965.py) with the furniture placed the
installer's way; not Studio captures (the Studio import is the map builder's step).
  python art/house/v2/tools/compose_1965_sheet.py"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", ".."))
REF = os.path.join(REPO, "notes", "ref", "nuketown")
PRE = os.path.join(ROOT, "renders", "preview")
OUT = os.path.join(REPO, "notes", "house_1965_sheet.jpg")
ROWS = [
    ("Living room: fieldstone wall, wainscot, club chairs, skirted vinyl sofa, a dummy", "03_A_stone_fireplace_wall_mannequin.jpg", "h65_lr.png"),
    ("Living room 2: shag rug, kidney table, tripod lamp, spindle divider", "11_B_living_paintings_wainscot_armchair.jpg", "h65_lr2.png"),
    ("Foyer + main stair: sprig paper over wainscot, moss runner, brick planter", "04_B_stair_red_runner_wallpaper_wainscot.jpg", "h65_fy.png"),
    ("Kitchen: olive enamel (ours, not red), checker lino, twin ovens, booth", "21_A_kitchen_red_checker_floor.jpg", "h65_kt.png"),
    ("Kitchen 2: island, counters, a dummy at the counter, taped window", "16_A_kitchen_red_cabinets_mannequin.jpg", "h65_kt2.png"),
    ("Dining room: table set and left, dinette chairs, two dummies, globe pendants", "26_A_dining_checker_pendant.jpg", "h65_dr.png"),
    ("Back hall: vine paper, checker lino, hall tree, sand at the door", "09_B_backdoor_into_hall_checker.jpg", "h65_bh.png"),
    ("Mudroom: coffee band + pegboard, painted lockers, notices", "10_B_hall_vine_wallpaper_mannequin.jpg", "h65_mr.png"),
    ("Landing / gallery: turned walnut balusters, vine paper", "37_R_upper_landing_rail_dresser.jpg", "h65_ld.png"),
    ("Master bedroom: rose sprig paper, walnut bed wall, chenille spread", "30_B_upper_bedroom_bed_painting.jpg", "h65_mb.png"),
    ("Bedroom 2: knotty pine bed wall, mustard paint, plaid spread", "23_A_upper_bedroom_yellow_drape_bed.jpg", "h65_br2.png"),
    ("Kid's room: yellow vine paper + rocket frieze, carpet tiles, toys", "01_A_kidsroom_checker_carpet_shelving.jpg", "h65_br3.png"),
    ("Ground bathroom (no reference frame): mint tiles, hex floor, curtain", None, "h65_gb.png"),
    ("Upper bathroom (no reference frame): butter tiles", None, "h65_ub.png"),
    ("Window view south: the street, poles, the test house across", "06_window_view_upper_to_street_bus.jpg", "h65_win_s.png"),
    ("Window view north: backyards, fences, power line", "14_view_from_back_balcony_shed.jpg", "h65_win_n.png"),
    ("Foyer feature window: taped, framing the instrument mast", "13_B_window_vine_wallpaper_view_out.jpg", "h65_win_fy.png"),
    ("Street: dirt cul-de-sac, rounded cars, dairy truck, picket fences", "07_window_view_upper_to_truck_poles.jpg", "h65_street.png"),
    ("The second test house: mint siding, fieldstone base, open garage, dummies, sandbags", "08_A_view_in_front_door_from_porch.jpg", "h65_across.png"),
]
W, H, BAR = 800, 450, 44


def font(px, bold=True):
    for f in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf"):
        try:
            return ImageFont.truetype(f, px)
        except OSError:
            pass
    return ImageFont.load_default()


def fit(path):
    im = Image.open(path).convert("RGB")
    r = max(W / im.width, H / im.height)
    im = im.resize((int(im.width * r + 0.5), int(im.height * r + 0.5)), Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2
    return im.crop((x, y, x + W, y + H))


HEAD = 110
sheet = Image.new("RGB", (W * 2, HEAD + len(ROWS) * (H + BAR)), (20, 20, 20))
d = ImageDraw.Draw(sheet)
d.text((20, 14), "House, 1965 test-site restyle: reference (left, study only) vs ours (right)", font=font(34), fill=(236, 232, 218))
d.text((20, 62), "Ours: Blender Cycles previews of the built kit, furniture placed the installer's way (not Studio; graphics level n/a). "
       "Own models, textures, words. Layout, openings, cover boxes unchanged.", font=font(19, False), fill=(200, 196, 186))
for i, (label, ref, ours) in enumerate(ROWS):
    y = HEAD + i * (H + BAR)
    if ref and os.path.exists(os.path.join(REF, ref)):
        sheet.paste(fit(os.path.join(REF, ref)), (0, y))
    else:
        d.rectangle([0, y, W - 1, y + H - 1], fill=(40, 40, 40)); d.text((W // 2, y + H // 2), "no reference frame", font=font(24), fill=(150, 150, 146), anchor="mm")
    p = os.path.join(PRE, ours)
    if os.path.exists(p):
        sheet.paste(fit(p), (W, y))
    d.rectangle([0, y + H, 2 * W - 1, y + H + BAR - 1], fill=(34, 34, 34))
    d.text((12, y + H + 8), label, font=font(21), fill=(236, 232, 218))
    d.line([W, y, W, y + H], fill=(20, 20, 20), width=4)
sheet.save(OUT, quality=86)
print(OUT, sheet.size)
