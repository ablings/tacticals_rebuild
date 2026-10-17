"""Contact sheet of the match place flow captures (out/match) -> notes/match_place_flow_sheet.png"""
import os
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
D = os.path.join(ROOT, "out", "match")
CAP = {
    "01_loading": "1 join: the place's loading screen (then Waiting/Loading)",
    "02_mapvote": "2 MapVote: Warehouse + Random (1v1 maps only)",
    "02_mapvote_voted": "2b a vote (MatchFlow Vote Random) on the tile",
    "03_loadout": "3 Loadout: owned kit (defaults), Map: Warehouse",
    "04_loadout_picked": "3b after ;give: Revolver + Knife picked, Flash refused",
    "05_round1_hud": "4 round 1 on MatchCore: DuelHUD score / timer",
    "06_kill_round_won": "4b kill feed + TEAM A WINS THE ROUND",
    "07_tutorial": "tutorial server (StudioTutorialServer): unchanged",
    "08_results": "5 MatchEnd: results 3-1 (test bot match: no rewards)",
    "09_intro_logo": "follow-up: quick intro logo held until Loaded",
    "10_round3_before_fix": "before: round 3 respawn, camera looking backwards",
    "11_round3_after_fix": "after: round 3 respawn, camera behind the player",
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
out = os.path.join(ROOT, "notes", "match_place_flow_sheet.png")
sheet.save(out)
print("sheet", sheet.size, out)
