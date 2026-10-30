# Body batch 5 (deaths, idles, breathing, social, door, bot leans): DONE, 4 grader rounds (anim-body, 2026-10-30)
Grades: r1 5.7 -> r2 6.3 -> r3 6.4 -> r4 **6.7** (pass 8.0; round limit reached, logged below the mark).
Per clip (r4): DeathBackward 8.3, DeathExplosion 8.3, DeathCover 8.0, Defeat 8.3, DoorOpen 8.3, IdleFidgetShift 8.3,
IdleFidgetLook 8.3, BreatheCalm/Heavy 8.2, RoundReady 8.2, BotLeanLeft/Right 8.2, Victory 8.0, IdleFidgetGunCheck 7.2,
DeathForward 6.0, DeathHeadshot 5.6, DeathCrumple 5.4.
After r4 (not re-graded): DeathForward's end pose re-fixed (r4 floated 0.5 on its arms: arms now flat at the sides with the
elbow pole toward the back for the whole clip, torso 0.08 off the floor).
Open (logged): DeathCrumple ends propped on a shin (needs a re-pose that lays hip and shoulder down); DeathHeadshot thighs fold
through each other in the buckle; gun-check forearm 0.2 through the slide. Edward decided (2026-10-30): players get the bots' body shape (hip 2.192), so the ground poses fit
players once systems makes that change (hand-off 23).
Source `blender/clips/b5_life.py`; captures `captures/anim/body/b5/` + `b5_grade*`, `grade_final_C`.
