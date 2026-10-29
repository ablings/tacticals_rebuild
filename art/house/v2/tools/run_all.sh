#!/bin/sh
# 1965 House: rebuild everything in order (furniture first: the house and the exterior load its D65 masters), then previews.
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")"
D=${HOUSE_DEVICE:-OPTIX,CUDA}   # Shadow PC: HOUSE_DEVICE=CUDA (OptiX kernel fails there)
R=../renders
[ -z "$SKIP_TEX" ] && python make_tiles_1965.py > $R/tiles.log 2>&1
[ -z "$SKIP_TEX" ] && python make_decals_1965.py > $R/decals.log 2>&1
"$B" -b --factory-startup --python build_furniture_1965.py -- --device $D > $R/furniture_build.log 2>&1 && grep DONE $R/furniture_build.log
python footprint_diff.py | tail -1
"$B" -b --factory-startup --python build_house.py -- --device $D > $R/house_build.log 2>&1 && grep -E "coplanar|1965|DONE" $R/house_build.log
"$B" -b --factory-startup --python build_exterior_1965.py -- --device $D > $R/exterior_build.log 2>&1 && grep DONE $R/exterior_build.log
"$B" -b ../house.blend --python preview_1965.py -- "$(cd $R && pwd -W)/preview" --samples 24 --device ${D%%,*} > $R/preview.log 2>&1; grep -c VIEW $R/preview.log
echo ALL DONE
