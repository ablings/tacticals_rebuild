# m30 grade A: positioning and layout

**Moved away from RIVALS:** the results stat labels came down with the boxes. They are 4 capture px (about 6 design px) lower than in m29. The cause is in the code: `DuelHUD.client.lua` line 618 was changed to `sl[2] + 64`, but the show pass at **line 788** still sets `cap.Position` from `sl[2] + (big and 70 or 38)`. That pass overrides the build-time value, so the labels draw at 864 + 70 = 934 instead of 928.

**m29 fixes, measured (capture px x 1.514 = design px; t0140 is 1600x900):**

| results | m29 | **m30** | t0140 |
|---|---|---|---|
| stat box top-bottom | 79.4-85.4 % | **79.9-86.1 %** | ~80.0-85.8 % |
| big digit centre | 82.5 % | **83.0 %** | 83.0 % |
| stat label centre | 87.0 % | **87.6 %** | 87.1 % |
| damage number centre | 90.6 % | **90.6 %** | 90.6 % |
| damage label centre | 93.2 % | 93.2 % | ~93.0 % |

- **Boxes at 864: landed.** The box and digits match t0140.
- **Labels 6 up: did not land** (see above). The gap from label to damage number is now 3.0 % against t0140's 3.4 %.
- **Damage row: landed.** It's unchanged at 90.6 %.

**Results buttons (first readable round), against t0140:**

| | ours | t0140 |
|---|---|---|
| outline x | 86.0-99.6 % | 86.3-99.4 % |
| Rematch y | 73.4-81.3 % (grey outline) | ~73.3-82.0 % (faded) |
| Play Again y | 82.3-90.3 % | 82.6-90.2 % |
| Leave y | 91.4-99.3 % | 91.3-99.0 % |
| outline weight | ~4.5 design px | ~4.8 design px |

The gaps (PA→Leave 1.1 % on both) and the outline weight match. Both edges run about 3-6 design px wide and low, which is within tolerance. Nothing to fix.

**results 9.3/10** (t0140)
1. Stat labels: in `DuelHUD.client.lua` line 788, change `sl[2] + (big and 70 or 38)` to `sl[2] + (big and 64 or 38)`. That moves the label top from 934 to **928** design px (centre 87.6 → **87.1 %**). Better still, read the offset from one shared constant so the build and show passes can't drift apart again.

**found 9.2/10** (t0022). Not re-flagging the settled m29 tip. This round drew a different tip ("Headshots end fights…"): its bubble runs x 159-632 capture, the left inset is 21 design px, and the **right inset is 54 design px** (t0022: 20). The glyphs are the same height as m29's (cap ~15 capture px), so the text didn't drop a size. GetTextBoundsAsync over-measures this string by about 5 %, and the fixed 0.97 factor only fits some tips.
1. Size the bubble from the drawn width one frame later: `w = tipLabel.TextBounds.X + 2*inset`, then re-apply the label position and size. For this tip that takes the bubble from about 716 to **~682 design px** wide.

**searching 9, vote 9.5, loadout 9.5, countdown 9, live 9, kill 9.8, matchpoint 9.7, death 9.8, death2 9.8/10:** the layout matches m29 and the world now renders. Nothing to fix.

**playmenu: settled** (grid top y 306). **Victory:** settled cutscene. **Mascot:** none, so a tip left edge at about x 241 is correct.

*Timing (unscored): Studio slows the short holds about 6x, so hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Results stat labels 6 design px up: line 788 offset 70 → 64 (label top 928, 87.1 %; t0140).
2. Found tip: size the bubble from `TextBounds.X` so long tips like this one don't carry a 54 px right gap (target 20; t0022).
3. (none)
4. (none)
5. (none)
6. (none)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (small: one-line label offset fix at DuelHUD line 788; tip width per tip)
