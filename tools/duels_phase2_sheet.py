"""Contact sheet of the lobby duels phase 2 captures (out/duels/phase2) -> notes/lobby_duels_phase2_sheet.png"""
import os
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
D = os.path.join(ROOT, "out", "duels", "phase2")
CAP = {
    "00_before_phase1_round1": "BEFORE (phase 1): 8 shadowed lights",
    "01_round1_lights_after": "AFTER: 2 shadow spots + unshadowed fill",
    "02_results_D1": "D1 results while D2 (bots) ran in slot 2",
    "03_back_in_lobby_no_hud": "back in the lobby: no score bar / VICTORY",
    "04_arenas_full_waiting": "MaxArenas 1: pad holds, ARENAS FULL - WAITING",
    "05_next_match_hud_clean": "next match: HUD reset (0-0, round 1)",
    "06_2v2_round1_pips": "temporary 2v2 test map: 2 pips a side",
    "07_arena_after_budget": "final run: arena after the light budget",
}
files = [f for f in sorted(os.listdir(D)) if f.endswith(".jpg")]
W, H, cols = 634, 392, 2
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
out = os.path.join(ROOT, "notes", "lobby_duels_phase2_sheet.png")
sheet.save(out)
print("sheet", sheet.size, out)
