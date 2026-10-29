#!/bin/sh
# 1965 House: rebuild everything in order (furniture first: the house and the exterior load its D65 masters), then previews.
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")"
R=../renders
python make_tiles_1965.py > $R/tiles.log 2>&1
python make_decals_1965.py > $R/decals.log 2>&1
"$B" -b --factory-startup --python build_furniture_1965.py > $R/furniture_build.log 2>&1 && grep DONE $R/furniture_build.log
python footprint_diff.py | tail -1
"$B" -b --factory-startup --python build_house.py > $R/house_build.log 2>&1 && grep -E "coplanar|1965|DONE" $R/house_build.log
"$B" -b --factory-startup --python build_exterior_1965.py > $R/exterior_build.log 2>&1 && grep DONE $R/exterior_build.log
"$B" -b ../house.blend --python preview_1965.py -- "$(cd $R && pwd -W)/preview" --samples 24 > $R/preview.log 2>&1; grep -c VIEW $R/preview.log
echo ALL DONE
