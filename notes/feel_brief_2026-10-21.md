# Weapon feel brief, 2026-10-21 (Edward via the main PC lead / Roblox training, watching RIVALS)
Edward: "there are two feels in this game our game doesn't have. One is weapon switching ... bounce and select effects ... The other is
sniping: it feels like a smooth transition from unscoped to scoped, and quick switching weapons ... I mainly want sniping to feel as
smooth as this game does." Sniping first.

## Split (agreed with the UI session)
- UI: ScopeController (overlay grow/fade, instant drop on tool change), HotbarController (slot pop / glow), HUD.lua (crosshair fade, weapon
  name), CameraController ONLY the scope FOV blend + scoped sensitivity. Measures RIVALS' scope / equip timings from the reference place.
- Lead: WeaponController (equip / draw, DrawTime, ADS state, IsDrawing), gun sway / bob / recoil spring, quick-switch rules, server side.

## RIVALS observations (main PC, frames ~0.4 s apart)
1. Sway: the gun lags behind camera turns / strafes and dips toward centre, then springs back; strong bob when moving; run pose rotates
   the gun across the body. -> spring-damped offset driven by camera angular velocity + move speed.
2. Equip: camera eases (no cut); the gun enters from bottom-right, rolled, rises / rotates into rest with a slight overshoot, ~0.4-0.6 s.
   -> every equip = offset tween (down-right, rolled -> rest) with Back / spring easing + small camera kick, on the SAME spring as the sway.
3. Recoil: big gun kick (pitch up + pull back), back to rest over ~0.6-1 s on the same spring, separate from camera recoil; heaviest on
   Sniper / Flare Gun / RPG.
4. Quick switch: leaving the Sniper (scoped or just after a shot) drops the scope and rechamber at once; next weapon draws immediately;
   server accepts its shots straight away.

## Translation note (lead)
RIVALS is first person with a viewmodel; Tacticals is third person over the shoulder (first person only when scoped). So "viewmodel"
springs become (a) arm / gun pose offsets on the character (Motor6D Transform layered on the hold animations), and (b) a small camera
spring for the kick / settle. Check with Edward whether he wants a first-person hip view like RIVALS, or the RIVALS feel kept in our
third-person camera.
