# Body batch 4 (transitions + hit reactions): DONE, 3 grader rounds (anim-body, 2026-10-30)
Grades: r1 5.8 -> r2 6.9 -> r3 **7.5** (pass 8.0; logged below the mark; no change after r3).
Per clip (r3): MoveStop 8.5, MoveLandHard 8.5, HitHeadshot 8.5, MoveStart 8.0, HitFlinch/F/B/L/R 8.0, HitExplosionStagger 8.0,
MoveLimp 7.5, HitBurning 7.5, TurnInPlaceLeft/Right 6.5.
Open (logged): turn legs overlap 0.2-0.3 at f11-f14 and start/end 0.16/0.25 off the idle stance; burning pat 0.3 into the hip;
limp heel peel pops 0.26/frame at toe-off. Code dependencies (hand-off 17-20): reactions as Waist/Neck offsets + Action4,
MoveRun from TimePosition 0.12 after MoveStart, limp authored at 4 studs/s (speed decision), turn contract (Cubic InOut f4-f20).
Source `blender/clips/b4_react.py`; captures `captures/anim/body/b4/` + `b4_grade*`.
