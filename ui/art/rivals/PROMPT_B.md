Read ../../../notes/ui_rivals/image_gen_list.md (the table and the "Image-generation prompts" section). Use your image generation
tool to make items 11-18 exactly as their prompts say. Transparent items need a real alpha background (no checkerboard); if the
generator can't give alpha, render on flat #00FF00 and key it out with Python (PIL) cleanly. Opaque items (11, 18) stay opaque.
Save into _upload/ with these exact file names:
 11 shop_bg_founders.png shop_bg_operator.png (1536x1024 opaque)
 12 shop_tag_random.png shop_tag_all.png (256x208)
 13 kit_inspect.png
 14 row_texture.png row_wraps.png row_damage.png row_crouch.png row_sprint.png row_slide.png row_quickattack.png row_hidehud.png row_weaponpicker.png
 15 hk_reload.png hk_quickmelee.png hk_quickutility.png
 16 pad_R2.png pad_L2.png pad_R3.png pad_A.png pad_X.png pad_Y.png pad_dpad_up.png pad_dpad_down.png pad_dpad_left.png pad_dpad_right.png (256x256)
 17 kit_locked_sparkles.png
 18 play_card_1v1.png play_card_2v2.png play_card_3v3.png (1024x640 opaque)
All 512x512 unless noted; the white icons in 13-17 pure #FFFFFF, one consistent visual weight.
Then save _contact_B.png: every image on a dark #16171B grid with its file name (icons at 128 and 32 px, the big images scaled down).
After saving, list the files.
