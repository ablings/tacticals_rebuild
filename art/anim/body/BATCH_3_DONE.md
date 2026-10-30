# Body batch 3 (locomotion with a gun): DONE, 4 grader rounds (anim-body, 2026-10-30)
Grades: r1 5.2 -> r2 6.8 -> r3 6.8 -> r4 **7.3** (pass 8.0; round limit reached, logged below the mark).
Per clip (r4): Run 8.6, WalkAim 8.6, Backpedal 8.5, CrouchIdle 8.3, SprintPistol 7.8, CrouchWalk 7.6, Slide 6.8,
StrafeLeft/Right 6.6, Sprint (rifle) 6.0.
Open (logged): strafe legs overlap (blocky 1-stud-deep legs: needs >= 0.7 depth stagger or a step-close strafe); rifle sprint
off arm inside the chest (hidden while the weapon Hold plays: hand-off 21); slide lead leg 0.45 off the floor; crouch-walk
trailing knee box 0.16 under the floor. Cross-team blocker: the weapons Hold/Lowered clips freeze all locomotion legs
(hand-off 22). Cadence decision (WalkAim / CrouchWalk 4 steps per cycle) for the lead.
Source `blender/clips/b3_move.py`; captures `captures/anim/body/b3/` + `b3_grade*`, `grade_final_A`, `grade_final_C`.
