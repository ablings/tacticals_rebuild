"""Contact sheet of the lobby duels phase 1 captures -> out/duels/phase1/sheet.png"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "duels", "phase1")
CAP = {
    "01_pad_countdown": "1v1 pad countdown (DuelTestSolo)", "02_loading": "Loading (MatchFlowUI)",
    "03_mapvote": "MapVote: Warehouse + Random", "04_mapvote_voted": "vote via MatchFlow remote",
    "05_loadout": "Loadout (Kit*, owned items)", "06_round1_arena": "round 1 in the arena (client clone)",
    "07_round_won": "round won (bot kill credited)", "08_results": "MatchEnd results 3-2",
    "09_back_at_pads": "back at the pad, arena unloaded", "10_arena_as_lobby_client": "arena with no Visual clone = lobby client",
    "11_lobby_toward_arena": "lobby east edge toward the slot", "12_nomap_2v2": "2v2 pad: NoMap, no countdown",
}
files = [f for f in sorted(os.listdir(D)) if f.endswith(".jpg")]
W, H, cols = 634, 392, 3
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * W, rows * (H + 30)), (16, 18, 16))
dr = ImageDraw.Draw(sheet)
try: font = ImageFont.truetype("arial.ttf", 20)
except Exception: font = ImageFont.load_default()
for i, f in enumerate(files):
    im = Image.open(os.path.join(D, f)).convert("RGB").resize((W, H))
    x, y = (i % cols) * W, (i // cols) * (H + 30)
    sheet.paste(im, (x, y + 30))
    dr.text((x + 8, y + 4), CAP.get(f[:-4], f), fill=(236, 232, 218), font=font)
sheet.save(os.path.join(D, "sheet.png"))
print("sheet", sheet.size)
