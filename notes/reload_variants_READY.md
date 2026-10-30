# reload_variants READY (2026-10-30, animation trainer)

- Reference (measured in RIVALS' live range): `notes/reload_variants_ref.md`; contact sheet `notes/reload_variants_sheet.jpg`;
  revolver dump close-up `captures/reload_variants_revolver_dump.png`.
- Design for our 9 guns at exactly each gun's ReloadTime: `notes/reload_variants_design.md` (variant table, rounds-left ranges,
  beats at 60 fps, gun-part motion, shared anchor markers, code pick rule).
- Vault: `05 Animation/Animation Styles/Grounded Tactical.md` section "Ammo-aware reloads at a fixed length"; clip list row; training log.

Key facts for the animator:
- RIVALS revolver: 1-5 spent = one 3.1 s clip; the count shows as the number of live rounds in the cylinder face and in the dump.
  Empty is ~1 s shorter there; ours keeps every variant at 120 f (2.0 s).
- Revolver needs `Round1..Round6` (one part per chamber, Motor6D to Cylinder) plus `LooseRound` and `SpeedLoader` props.
- Dual Pistols need `SlideR/L`, `MagBaseR/L`.
- Existing tactical / empty clips: retime to the lengths in the design (Retain = tactical, Dry = empty) and add the Drop middle variant.
- Pump: `ReloadEndEmpty` is replaced by `ShellPort` (first shell when empty: port load + pump).

Not done (out of scope): building clips, code changes. The play lock was held by "upload" the whole time (renewed); this study used
the Roblox Player only, no Studio Play, so it ran without the lock after a 20 min wait.
