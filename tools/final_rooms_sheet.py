"""Final-lap distinctness sheet: one Play capture per room from its main entrance at player height, labelled.
Captures (Play, client camera locked, GUIs off, FOV 70, eye = floor + 5.2) are in out/polish/final/room_<name>.jpg:
hub (30,5.2,-20)->(-40,14,20); gates (0,5.2,44)->(0,5.5,75); shop (-6,5.2,70)->(4,5.5,100); armory (4,5.2,-68)->(-4,5.5,-100);
duels (-97,21.2,0)->(-125,18,0); exfil (104,5.2,0)->(140,5,0); training (-6,605.5,-6)->(60,604,40);
showroom = Showroom.CameraPoint at FOV 40 (the Kit menu camera).
Usage: python tools/final_rooms_sheet.py  -> out/polish/lobby_rooms.jpg"""
from PIL import Image, ImageDraw, ImageFont
import os
D = "out/polish/final"
rooms = [("hub", "HUB - command deck"), ("gates", "N/S GATES - airlock bulkheads"), ("shop", "OUTFITTERS - cosmetic boutique"),
         ("armory", "ARMORY - gunmetal weapons vault"), ("duels", "DUELS - arena deck"), ("exfil", "EXFIL - hangar + sky edge"),
         ("training", "TRAINING - clinical grid range"), ("showroom", "SHOWROOM - photo studio (Kit camera)")]
W, H = 800, 495
try:
    font = ImageFont.truetype("arialbd.ttf", 26)
except OSError:
    font = ImageFont.load_default()
sheet = Image.new("RGB", (W * 2, H * 4), (10, 12, 10))
for i, (k, label) in enumerate(rooms):
    im = Image.open(os.path.join(D, f"room_{k}.jpg")).convert("RGB").resize((W, H))
    d = ImageDraw.Draw(im)
    tw = d.textlength(label, font=font)
    d.rectangle([0, 0, tw + 24, 40], fill=(10, 12, 10))
    d.rectangle([0, 40, tw + 24, 43], fill=(138, 130, 60))
    d.text((12, 6), label, fill=(236, 232, 218), font=font)
    sheet.paste(im, ((i % 2) * W, (i // 2) * H))
sheet.save("out/polish/lobby_rooms.jpg", quality=88)
print("out/polish/lobby_rooms.jpg", sheet.size)
