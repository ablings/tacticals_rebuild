"""Screen capture of one Studio window (by window name) to a PNG [TESTPLACE].
  HOUSE_STUDIO=<window name> python tools/test_place_cap.py <out.png>"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import house_fastcap
m = house_fastcap.Mcp()
print(m.call("screen_capture", {"capture_id": "testplace"}, img=sys.argv[1]))
