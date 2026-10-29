export MY_STUDIO_PID=40100; D="powershell -ExecutionPolicy Bypass -File desk_mine.ps1"
$D frontdlg "Asset Configuration" >/dev/null; $D click 3020 856 double; sleep 6; $D frontdlg "Asset Configuration" pin >/dev/null; sleep 0.5
$D shotr "$PWD/out/_scr.png" >/dev/null
python -c "
from PIL import Image; im=Image.open('out/_scr.png'); im.crop((500,230,900,400)).resize((800,340)).save('out/_crop.png')"
