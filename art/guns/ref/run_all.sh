#!/bin/bash
cd "$(dirname "$0")"
gen() {
  name="$1"; what="$2"
  python ../../../../roblox_kits/tools/art/gen_image.py "${name}_side.png" "a clean orthographic SIDE VIEW (left side, muzzle pointing right, perfectly horizontal, no perspective) game-reference illustration of ${what}. Realistic grounded proportions, the whole weapon in frame with margin, flat even lighting, crisp outlines, clear separation between parts (slide, frame, magazine, trigger, levers), no hands, no text, no labels, no watermark, no background objects" --size 1024 > "log_${name}.txt" 2>&1
  echo "done $name $?"
}
while IFS=$'\t' read -r n w; do
  gen "$n" "$w" &
  while [ $(jobs -r | wc -l) -ge 3 ]; do sleep 5; done
done < prompts.tsv
wait
echo ALLDONE
