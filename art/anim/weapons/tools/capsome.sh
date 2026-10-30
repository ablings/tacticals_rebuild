#!/bin/sh
# capsome.sh <Clip> [...]: side + gameplay strips (<= ~13 frames each) and, for contacts, an every-frame strip
cd "$(dirname "$0")"
export MCP_WARMUP=1
for n in "$@"; do
  case $n in Pistol*|QuickMeleeBash) g=Pistol;; Revolver*) g=Revolver;; SMG*) g=MiniUzi;; Rifle*) g=AutoRifle;; Shotgun*) g=PumpShotgun;;
    Sniper*) g=Sniper;; Bat*) g=Bat;; Katana*) g=Katana;; RiotShield*) g=RiotShield;; MeleeSlash|MeleeKnife*) g=Knife;; *) g=-;; esac
  L=$(python -c "import json;print(json.load(open('../../../../out/anim_weapons/json/$n.json'))['length'])")
  f=$(python -c "print(max(4, min(15, int(12/$L))))")
  sh strip.sh $n side $f $g > /dev/null 2>&1 || echo "FAIL side $n"
  sh strip.sh $n game $f $g > /dev/null 2>&1 || echo "FAIL game $n"
  echo "done $n ($f fps)"
done
