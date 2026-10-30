#!/bin/bash
cd "$(dirname "$0")"
gen() {
  name="$1"; what="$2"
  python ../../../../roblox_kits/tools/art/gen_image.py "${name}_side.png" "a clean orthographic reference illustration for a video game prop: ${what}. Side view (front view for the shield, top view for the wraps), perfectly flat to the camera, no perspective, the whole object in frame with margin, flat even lighting, crisp outlines, clear separation between parts, no hands, no text, no labels, no watermark" --size 1024 > "log_${name}.txt" 2>&1
  echo "done $name $?"
}
while IFS=$'\t' read -r n w; do
  gen "$n" "$w" &
  while [ $(jobs -r | wc -l) -ge 3 ]; do sleep 5; done
done < prompts2.tsv
wait
echo ALLDONE
