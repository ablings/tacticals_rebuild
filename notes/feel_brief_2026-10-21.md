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

## RIVALS numbers (UI session, read from the reference place's scripts; springs = Spring.new(start, damper, speed))
- Equip: spring(0, 0.625, 12.5), Value = 1 on equip (0.5 on a quick swap) -> 0; offset CFrame.new(0, -0.5v, 0.25v) * Angles(-45deg v, 0, 45deg v).
  ~8 % overshoot, settles in ~0.35-0.4 s.
- Aim: spring(0, 1, 30), speed 30 x AimSpeed in / 30 out; Sniper AimSpeed 0.55 (omega 16.5, 92.5 % in ~0.24 s).
- FOV: spring(0, 1, 20 x AimSpeed), target AimFOVOffset (Sniper -50) x the scoped-zoom setting; FOV = base + offset x FOV/80.
- Scope overlay swaps in at aim value >= 0.925 (viewmodel pushed out of view); no black blink; out at omega 30.

## More RIVALS notes (main PC, 2026-10-21 afternoon)
5. Hit feedback: number at the hit point accumulating per target, red tick hitmarker, red-pink body flash (UI). Lead: HitConfirm payload
   -> done, fix/hitinfo.lua [HITINFO] (6th client arg { pos, victim, dealt, source, weapon, pellet, backstab }).
6. Reload: big readable motion (rifle rolls up-right 40-50 deg, off hand fetches the mag, swings back with the draw's overshoot), ~1.5 s;
   muzzle flash sprite per shot, tiny hip dot crosshair.
7-9. Throwables: tap throws at once; HOLD shows a dashed arc preview (aim while held, strength unchanged) -> matches port 31 (tap = instant
   full strength, hold up to 5 s); overhand windup animation (left arm points, right hand cocks back past the head and whips); fast flat
   arc + thin white trail for Grenade / Flashbang; Satchel-style charges lobbed high and limited (charge count); after a throw the next
   item rises in from below when charges remain, gated by a cooldown widget under the crosshair; per-gadget launch angle / speed;
   nearby blast = white screen bloom + dark smoke plume.
