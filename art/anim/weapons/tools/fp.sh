#!/bin/sh
# fp.sh <Clip> <gun|-> <t1,t2,...> -> captures/anim/weapons/<Clip>_fp.png (first-person frames side by side)
CAPS="C:/Users/aroki/Documents/tacticals_rebuild/captures/anim/weapons"; H="C:/Users/aroki/Documents/tacticals_rebuild/art/anim/weapons"
L=""
for t in $(echo $3 | tr ',' ' '); do
  sh "$H/tools/strip.sh" $1 fp 1 $2 "" $t $t > /dev/null 2>&1
  cp "$CAPS/$1_fp_1.png" "$CAPS/_fp_$t.png"; L="$L $CAPS/_fp_$t.png"
done
python - "$CAPS/$1_fp.png" $L <<'PY'
import sys
from PIL import Image
ims=[Image.open(p).convert("RGB") for p in sys.argv[2:]]
ims=[i.resize((i.width//2,i.height//2)) for i in ims]
o=Image.new("RGB",(sum(i.width for i in ims),ims[0].height)); x=0
for i in ims: o.paste(i,(x,0)); x+=i.width
o.save(sys.argv[1])
PY
for t in $(echo $3 | tr ',' ' '); do rm -f "$CAPS/_fp_$t.png"; done; rm -f "$CAPS/$1_fp_1.png"
echo "$CAPS/$1_fp.png"
