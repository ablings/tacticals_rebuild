#!/bin/sh
# capall.sh: side (15 fps) + gameplay (10 fps) strips of every right-hand clip, every-frame strips of the fire clips
cd "$(dirname "$0")"
SCR="C:/Users/aroki/Documents/roblox_kits/tools/screen.ps1"
for n in $(cat ../../../../out/anim_weapons/_all.txt | grep -v 'Left$'); do
  case $n in Pistol*|QuickMeleeBash) g=Pistol;; Revolver*) g=Revolver;; SMG*) g=MiniUzi;; Rifle*) g=AutoRifle;; Shotgun*) g=PumpShotgun;;
    Sniper*) g=Sniper;; Bat*) g=Bat;; Katana*) g=Katana;; RiotShield*) g=RiotShield;; MeleeSlash|MeleeKnife*) g=Knife;; *) g=-;; esac
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCR" stage -place anim_weapons.rbxl > /dev/null 2>&1
  f=15; L=$(python -c "import json;print(json.load(open('../../../../out/anim_weapons/json/$n.json'))['length'])")
  [ $(python -c "print(int($L>2.0))") = 1 ] && f=6
  sh strip.sh $n side $f $g > /dev/null 2>&1 || echo "FAIL side $n"
  sh strip.sh $n game $([ $f = 6 ] && echo 4 || echo 10) $g > /dev/null 2>&1 || echo "FAIL game $n"
  case $n in *Fire|QuickMeleeBash|MeleeSlash|MeleePunch|BatSwing|KatanaSlash) sh strip.sh $n side 60 $g "" 0 $(python -c "print(min($L,0.3))") > /dev/null 2>&1 || echo "FAIL 60 $n";; esac
  echo "done $n"
done
pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCR" release -place anim_weapons.rbxl > /dev/null 2>&1
echo ALLDONE
