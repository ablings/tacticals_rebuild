# Body batch 1 (cover core): DONE, 4 grader rounds used (anim-body, 2026-10-30)

Grades (roblox-animation-grader, xhigh): r1 3.0 -> r2 6.7 -> r3 7.1 -> r4 **7.9** (pass mark 8.0; limit of 4 rounds reached,
logged below the mark). Per clip at r4: IdleTall(+Left) 8.6, LookPos/Neg 8.6, ShuffleTall(+Right) 8.4, CrouchPeek(+Left) 8.3,
ShuffleCrouch(+Right) 8.0, LookPos/NegCrouch 7.7, Crouch(+Left) 7.6, Brace 7.2 (8.3 tall, 6.5 crouched).
After r4 (not re-graded, round limit): **CoverBraceCrouch** added (fixes the crouched brace popping the base pose), crouch
lowered 0.06 (head box top 3.22-3.26: hidden by the arena's 3.4 low walls; a 3.0 wall still shows ~0.25 of the head),
shuffle lanes 0.05 wider and tall feet straight at the close (the 0.1 heel touch).

| Clip | Len | Loop | Priority | Owns | Markers |
|---|---|---|---|---|---|
| CoverIdleTall / Left | 1.00 | yes | Action3 | whole body | - |
| CoverCrouch / Left | 1.00 | yes | Action3 | whole body | - |
| CoverCrouchPeek / Left | 1.00 | yes | Action3 | hips, legs, chest (arms from the Hold) | - |
| CoverLookPos / Neg | 1.00 | yes | Action4 | chest, head | - |
| CoverLookPosCrouch / NegCrouch (NEW) | 1.00 | yes | Action4 | chest, head (crouch pitch under the turn) | - |
| CoverShuffleTall / TallRight (NEW mirror) | 0.60 | yes | Action4 | hips, legs | Footstep x6 (L/R) |
| CoverShuffleCrouch / CrouchRight (NEW mirror) | 0.72 | yes | Action4 | hips, legs | Footstep x6 |
| CoverBrace | 0.75 | no | Action4 | chest, head, arms | - |
| CoverBraceCrouch (NEW) | 0.75 | no | Action4 | chest, head, arms | - |

Source `art/anim/body/blender/clips/b1_cover.py`; captures `captures/anim/body/b1/` (+ grader evidence `b1/grade_r2..r4`).
Systems hand-offs: `art/anim/body/HANDOFF_systems.md`. Publishing: see `art/anim/body/DONE.md`.
