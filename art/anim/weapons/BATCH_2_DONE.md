# Batches 2-3: DONE, self-checked (weapons animator, 2026-10-30)

Batch 2 = the other body sets and melee (Revolver / SMG / Rifle / Shotgun / Sniper Hold, Lowered, Equip, Draw, Holster;
QuickMeleeBash; Bat, Katana, Riot Shield). Batch 3 = every gun-part clip on the remodelled guns as soon as
`art/anim/guns/DONE.md` listed them (all nine at 02:49): Fire, Reload, ReloadEmpty / Tactical, Inspect, the shotgun
shell loop, the sniper bolt. Per-clip table: `DONE.md`. Captures: `captures/anim/weapons/<Clip>_{side,game}_<fps>.png`
(1x strips at 15 fps, 6 fps for clips over 2 s; gameplay camera; every frame = 0.25x for fire / melee contacts).

Self-check (graded by HQ's fresh grader after the task):
- Lengths, loops and names = the code's / the targets page; markers on the target frames.
- Hands: the exporter measures every frame; on-gun hands within 0.02 studs except 4 short moments listed in DONE.md
  (max 0.06). The gun slides into both hands' reach automatically when a pose asks for more than R15 arms allow.
- Gun parts move through the remodel's own Motor6Ds; tested in Studio (Animator drives them through the grip weld).
- Mechanisms are worked by the off hand (the gun is welded to the gun hand in game).
- Long guns: bladed stance / underarm shotgun because of the reach limit (DONE.md "Known limits").
