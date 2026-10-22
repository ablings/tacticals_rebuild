# 02 Shop: RIVALS feel audit (2026-10-21)

Scope: `ui/shop/ShopScreen.lua`. Shared code (`ui/lobby/Kit.lua`, `ui/matchplace/Theme.lua`) is proposed only. Frames are in `notes/rivals_rec/`.

## What RIVALS does
- **Interactability:**
  - Clicking a bundle opens a small centred detail card (`t0073.0s` -> `t0074.0s`): the items with names, counts, a red "x4 VALUE", a big red X and a green price.
  - While the purchase runs, the green button shows three dots (`t0073.4s`). Single items use the same card (`t0080.0s`, `t0097.6s`).
  - Afterwards a "Purchase Complete" banner drops in and the tile gets a check (`t0099.0s`).
  - The offer carousel slides between pages: `t0071.0s` catches a half-slid card.
- **Cleanliness:**
  - One grid type per page: banner bundles (`t0068.4s`), uniform key tiles (`t0084.0s`), a daily strip with a timer (`t0094.3s`).
  - The price is always one pill at the bottom of the tile.
  - Hover shows one white two-line tooltip (`t0083.9s`, `t0160.0s`).
- **Kid-friendly:**
  - Big numbers ("+40", "+1,100") do the talking.
  - "Limited time offer!" ribbons (`t0081.0s`).
  - Obvious "VIEW" buttons (`t0072.0s`).
  - A check marks owned items (`t0099.7s`).
  - The reveal is a full-screen 3D item with its name (`t0019.6s`).

## Gap table
| Our element | RIVALS | Quality | Sev |
|---|---|---|---|
| `Refresh` destroys and rebuilds the page and all its viewports on every confirm click or data change | Tiles persist and only their state changes | Interact. | P1 |
| Buy = the price tag turns into "Confirm" for 3 s (`priceTag` l.97-104) | Detail card, then dots while pending | Kid / Interact. | P1 |
| Every viewport is built on open (`setOpen` -> `Refresh`) | Opens instantly | Interact. (standing rule) | P1 |
| Tab switch is an instant swap | The page changes quickly and the selected tab pops | Interact. | P2 |
| Offer slides toggle `Visible` (l.417-422) | Slide | Interact. | P2 |
| Wallet text snaps (l.605) | Counter reacts (inferred) | Interact. | P2 |
| "kit" price leaves for the Kit room with no cue | VIEW / buy in place | Kid | P2 |
| Yellow `C.amber`/`C.olive` on Tags, OWNED, strokes and the scrollbar | (amber is tutorial-only for us) | Look / Clean | P2 |
| Static Tag pills | Callouts stand out | Kid | P3 |
| Owned = grey "Owned" plate | Check | Kid | P3 |
| Four stacked hover effects (spotlight, grow, tilt, `Tac.hoverBrackets`) | Grow + highlight | Clean | P3 |
| 18 px caps rarity line | Short, large words | Kid | P3 |

## Ranked changes
1. **Diff-refresh.**
   - Where: `Screen.Refresh` (l.602). Rebuild only on a tab change; otherwise update the tag states and the wallet in place.
   - `priceTag` (l.59) returns an `update()` closure.
   - Size: M. Kit: none.
   - Keeps our look: yes.
2. **Detail card replaces Confirm-in-place.**
   - Where: add `detailCard(spec)` beside `priceTag`. Use it from `bundleCard` (l.258), the offer slides (l.395/407), the packs (l.514) and the passes (l.536).
   - The card shows the 3D item tiles with names, the value badge, our square X, and a field-green price button that shows dots until `ctx.ask` returns.
   - Delete `pending`/`pendingAt`.
   - Size: L. Kit: `Kit.modal(w,h)` (from the `Kit.whoops` pattern, l.897) and `Kit.busy(btn)`.
   - Keeps our look: yes.
3. **Preload at join.**
   - Where: `Screen.Init` (l.648). Build all four pages hidden, so `SetTab` only toggles `Visible`.
   - Open behind `Kit.loadingDots` while the pages build.
   - Size: M. Kit: none.
   - Keeps our look: yes.
4. **Wallet count-up.**
   - Where: l.605. Tween the number (0.4 s) and pulse the pill (UIScale 1.12 -> 1, Back).
   - Size: S. Kit: `Kit.countTo(label, from, to, t)`, shared with the hub wallet.
   - Keeps our look: yes.
5. **Tab and page motion.**
   - Where: `SetTab` (l.624) and the tab loop (l.606-613).
   - Tween the colour (0.12 s), pop the icon (1.15 -> 1), and slide-fade the page 24 px over 0.15 s (CanvasGroup `pageHolder`).
   - Size: S-M. Kit: none.
   - Keeps our look: yes.
6. **Carousel slide.**
   - Where: `show(i)` (l.417). The slides go out and in at ±746 px (0.25 s); the active dot becomes a wider pill.
   - Size: S. Kit: none.
   - Keeps our look: yes.
7. **Amber out.**
   - Where:
     - l.226 fallback -> tan `#E2D2AC`;
     - l.235 Tag -> red;
     - l.245 OWNED -> cream;
     - l.499 stroke -> tan;
     - l.529 owned stroke -> field green;
     - l.291 scrollbar -> tan.
   - Size: S. Theme: add `tan` and `cream` tokens.
   - Keeps our look: restores it.
8. **Gear prices say where they go.**
   - Where: `itemCard` l.207 and the Featured l.346/458.
   - Add a cream arrow glyph (Frames), and lead the tooltip with "Get it in the Kit room".
   - An unaffordable click shakes the tag and offers the Scissors tab.
   - Size: S-M. Kit: `Kit.shake(gui)`.
   - Keeps our look: yes.
9. **Owned = cream check.**
   - Where: `priceTag` owned branch (l.63-74). Two rotated bars like the close X, on a dark plate.
   - Size: S. Kit: none.
   - Keeps our look: yes.
10. **Bobbing Tag pills.**
    - Where: l.235, 367, 511. ±3 px over a 1.6 s sine, tilted 3°.
    - Size: S. Kit: `Kit.bob(gui, amp, period)` (RenderStepped, as in `loadingDots`).
    - Keeps our look: yes.
11. **Calmer hover.**
    - Where: drop `Tac.hoverBrackets` on the shop cards (l.210, 261, 516, 538).
    - Size: S. Kit: none.
    - Keeps our look: the brackets are pass-34 decor, so ask Edward.
12. **Bigger secondary text.**
    - Where: rarity line l.202 18 -> 22 px with shorter words ("Epic Arm"); pass description l.533 20 -> 22 px.
    - Size: S. Kit: none.
    - Keeps our look: yes.

## Not verifiable from stills (inferred)
- How the detail card enters. I assume a scale pop like `Kit.open`.
- Whether the RIVALS wallet counts up.
- The carousel's direction and timing.
- Whether tags bob.
- Hover grow amounts and tooltip delay.
- The banner's drop and auto-hide timing.
- Whether the check animates.
- Reveal camera motion (`t0016-0055s`). We have no crate flow; it's a candidate for the Founder's Bundle buy only.

## Implemented (group B)
2026-10-21, `ui/shop/ShopScreen.lua` only (not run in Studio: needs a play test).
- **Update in place** (l.28-35, 94-170, 839-861, 902-914). `priceTag` builds both faces (price / owned) and returns `update()`, registered on the page being built. `Screen.Refresh` now only updates the wallet, every tag (owned, price, can't afford), the bundle tiles' OWNED labels (l.324-327) and an open detail card. Pages persist. A page whose owned set changed (`ownedSig`, l.55-62, also includes the Shop Hover setting) is marked dirty and rebuilt only when it is next shown (`showTab`, l.889-900), never under the cursor. Featured hero / Arms / Featured gear tags are live too (l.287-288, 444-449, 550).
- **Preload at join** (l.954-965, 831-833, 924-952). `Init` (called from the lobby's menu prewarm) builds all four pages (one frame apart). `SetTab` / `Open` only toggle `Visible`. An open before that finishes shows `Kit.loadingDots` and opens when ready.
- **Detail card** (l.637-773, specs l.227-247). It is a local function and could move to Kit later as a generic modal. The card is a solid `Theme.plate` card with an offset shadow block: no thin border and no left bar. It has the 3D item tiles with names and owned checks (or the pack / pass icon plus "+N scissors" / its description), the red "xN value" badge, `Kit.closeButton`, and a field-green buy button. The button shows `Kit.busy` until `ctx.ask` returns. Then the card closes on `res.ok`, or the button shakes. A module `buying` flag allows one purchase in flight (replaces `pending`/`pendingAt`).
  - The card is used by bundles (tag + card click), offer slides (pass + bundle), scissor packs (Scissors page and Featured top-left) and passes (tag + card click).
  - The `ask("BuyBundle" / "BuyRobux" / "BuyPass", id)` calls are unchanged, so Robux buys still get Roblox's own prompt.
  - The Featured hero (Founder's Bundle) still buys straight away (not in the list).
- **Wallet count-up** (l.863-874). `Kit.countTo` 0.4 s plus `Kit.pop` on the pill (centre-anchored, l.828-830). It snaps while the shop is closed.
- **Tab pop + page slide** (l.875-900). The tab colours tween 0.12 s (same colours), the selected tab's 3D icon pops (1.15), and the page slides in 24 px over 0.15 s in Scale. No fade: the page holder would have had to become a CanvasGroup with ~40 ViewportFrames inside, which is too risky.
- **Carousel slides** (l.493-512, 530-533). The old slide goes out and the new one comes in (0.25 s, Scale). Auto-advance always goes forward and only runs on the Featured tab. The active dot is a 1.9x wide pill.
- **Can't afford** (l.48-54, 157-166, detail l.755-760). The tag runs `Kit.shake` (guarded against stacking), then still opens the Kit room / detail card. In the card, buy shakes plus "Not enough scissors" and does not ask.
- **Owned = cream check** (l.63-75). This is a `Theme.plate` disc with two cream bars. It sits beside the existing grey "Owned" words on tags, on the detail card's tiles and on its button. It pops when a tag flips to owned.
- **Skipped:**
  - Amber-out, the tag bob and hover calm (Tac.hoverBrackets kept): these are colour / decor questions (Q1 / Q3).
  - The page fade (see above).
  - The "Purchase Complete" banner: the server's RichNotify already does it.
- **Existing AI tells seen (not touched):**
  - corner + thin stroke on price tags (l.106-109), item / bundle / pack / pass cards, bundle tiles, offer tiles and `Kit.closeButton` (used in the card);
  - the bundle card's left `AccentBar` (l.310);
  - all text is F.display / F.bold / F.medium, so it now follows the integrator's Theme fonts.
