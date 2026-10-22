Read ../../../notes/ui_rivals/image_gen_list.md (the table and the "Image-generation prompts" section). Use your image generation
tool to make items 1-10 exactly as their prompts say (512x512 each, real TRANSPARENT background/alpha, no checkerboard, no
background colour; "tintable" ones pure white #FFFFFF). If the generator can't give alpha, render on flat #00FF00 and key it out
to transparent yourself with Python (PIL), leaving clean anti-aliased edges and no green fringe.
Save into _upload/ with these exact file names:
 1 ui_close_x.png   2 kit_slot_empty.png   3 kit_leave_x.png   4 tasks_elims.png
 5 kit_cat_rifle.png kit_cat_knife.png kit_cat_grenade.png kit_cat_clock.png (one consistent set)
 6 kit_levelup.png   7 kit_reward_seal.png   8 kit_stats.png   9 tasks_check_lime.png   10 tasks_star6.png
Then save _contact_A.png: every icon on a dark #16171B grid at 128 px and 32 px with its file name, to check readability.
After saving, list the files.
