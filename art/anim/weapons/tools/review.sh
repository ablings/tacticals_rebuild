#!/bin/sh
# review.sh <set> <Clip> <f,f,f> -> out/anim_weapons/render/<Clip>_sheet.png (Blender, 3 views x frames)
R=/c/Users/aroki/Documents/tacticals_rebuild; O="C:/Users/aroki/Documents/tacticals_rebuild/out/anim_weapons/render/$2"
mkdir -p "$O"; find "$O" -name "*.png" -delete
"/c/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b $R/art/anim/weapons/blender/sets/$1.blend --python $R/art/anim/weapons/blender/render.py -- "$O" $2 --f $3 >/dev/null 2>&1
python $R/art/anim/weapons/blender/sheet.py "$O" $2 "C:/Users/aroki/Documents/tacticals_rebuild/out/anim_weapons/render/$2_sheet.png" && echo "C:/Users/aroki/Documents/tacticals_rebuild/out/anim_weapons/render/$2_sheet.png"
