"""Capture the move feel Studio's screen to a PNG: python -I tools/move_feel/cap.py <out.png> [delay_s]  (HOUSE_STUDIO picks the window)"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("HOUSE_STUDIO", "Test_movefeel.rbxl")
import house_fastcap
m = house_fastcap.Mcp()
if len(sys.argv) > 2: time.sleep(float(sys.argv[2]))
print(m.call("screen_capture", {"capture_id": "movefeel"}, img=sys.argv[1]))
