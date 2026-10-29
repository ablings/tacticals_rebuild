# pub1.sh NAME : close previous dialog, select, open upload, set creator; leaves a crop for checking
export MY_STUDIO_PID=40100; D="powershell -ExecutionPolicy Bypass -File desk_mine.ps1"
$D frontdlg "Asset Configuration" pin >/dev/null 2>&1; $D click 2569 822 >/dev/null 2>&1
{ echo "NAME = \"$1\""; cat lua/sel.lua; } > lua/_sel.lua; sh run.sh lua/_sel.lua >/dev/null
$D front anim_pullup_lean >/dev/null; sleep 1; $D shotr "$PWD/out/_scr.png" >/dev/null
y=$(python findsel.py); [ -z "$y" ] && { echo "no selection row"; exit 1; }
$D click 2982 $y right; sleep 1; $D click 3046 $((y+312)); sleep 1; $D click 3226 $((y+312)); sleep 3; $D frontdlg "Asset Configuration" pin
$D click 2665 383; sleep 1.5; $D wheel 2665 520 5; sleep 1; $D click 2560 409; sleep 1
$D shotr "$PWD/out/_scr.png" >/dev/null
python -c "
from PIL import Image; im=Image.open('out/_scr.png'); im.crop((350,40,1000,420)).save('out/_crop.png')"
