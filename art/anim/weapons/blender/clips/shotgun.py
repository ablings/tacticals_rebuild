"""Shotgun set (Pump Shotgun): targets section 5, on the remodelled PumpShotgun (Pump, LoadShell, Lifter, Trigger).
Underarm hold: the pump sits 1.88 studs ahead of the grip, out of an R15 support arm's reach with the butt in the shoulder
pocket, so the stock tucks along the right side under the arm (a real pump-gun technique); the off hand rides the pump."""
from rbxanim import Clip, P, add, seq, fr
from longgun import Gun
from longgun_parts import gun_inspect, add_t

GUN = "PumpShotgun"
TOOL = "PumpShotgun"
PUMP = (0.0, -0.05, -1.62)   # off-hand wrist under the rear of the pump (gun frame)
G = Gun("Shotgun", butt=(0, 0.0, 0.83), support=PUMP, blade=52, lean=6, wide=0.08, knees=0.1, pocket=(1.0, 1.12, 0.28),
        cheek=(-6, 3), support_rot=(0, 0, -20))
SADDLE = (-0.3, 0.15, -0.45)   # off-hand wrist at the side saddle shells
PORT = (0.0, -0.25, -0.75)     # off-hand wrist feeding the loading port (belly up)


def fire():
    """shot + pump (FireInterval 0.85): f1-f2 peak (muzzle +11, shoulder 0.22 back, chest +4) Linear; f2-f12 Quint Out;
    Pump back f12-f20 Quart Out 0.35 (gun rolls 5 to the off hand); hold f20-f22; forward f22-f28 Cubic In hard stop;
    f28-f51 Cubic Out settle, cancellable from f28"""
    c = Clip("ShotgunFire", 0.85)
    h = G.hold(c)
    gp, tgt, rot = h["gun"]
    pk = P(h, gun=(gp, add_t(tgt, (0, 0.02, 0.22)), add_t(rot, (11, 0.5, 0))))
    pk = add(pk, chest=(4, 0, 0), head=(2, 0, 0), root=(0, 0, 0, 1, 0, 0))
    rolled = P(h, gun=(gp, tgt, add_t(rot, (0, 0, 5))))
    back = P(rolled, L=("gun", add_t(PUMP, (0, 0, 0.35)), G.support_rot))
    seq(c, [(0, h, "Linear"), (2, pk, "QuintOut"), (12, P(rolled), "QuartOut"), (20, back, "SineInOut"), (22, back, "CubicIn"),
            (28, rolled, "CubicOut"), (51, h)])
    for f, z, e in ((0, 0, "Constant"), (12, 0, "QuartOut"), (20, 0.35, "SineInOut"), (22, 0.35, "CubicIn"), (28, 0, "Constant"),
                    (51, 0, "Constant")):
        c.part("Pump", fr(f), (0, 0, z), ease=e)
    for f, a, e in ((0, 12, "Constant"), (3, 12, "CubicOut"), (8, 0, "Constant"), (51, 0, "Constant")):
        c.part("Trigger", fr(f), (0, 0, 0), (-a, 0, 0), ease=e)
    c.marker("ShellEject", fr(18)); c.marker("PumpClosed", fr(28))
    return c


def belly_up(c):
    h = G.hold(c)
    return P(h, gun=((0, 0.2, -0.8), (-0.05, 1.05, -0.95), (-10, G.blade, 70)), head=(-12, 18, 0), L=("gun", PORT, (0, 0, 0)),
             poleR=(1.5, -0.9, 0.9))


def reload_start():
    """= ShellReload.StartDelay 0.2: f0-f12 Cubic Out roll the gun belly up 70, muzzle -10; off hand from the pump to the
    belt carrier / saddle"""
    c = Clip("ShotgunReloadStart", 0.20)
    h, b = G.hold(c), belly_up(c)
    seq(c, [(0, h, "CubicOut"), (12, b)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    seq(c, [(0, h, "CubicOut"), (12, P(b, L=("gun", SADDLE, (0, 0, 0))))], only=("L",))
    return c


def reload_shell():
    """= ShellTime 0.5, start pose = end pose: f0-f10 Sine InOut off hand saddle -> loading port with a shell; f10-f14 Cubic
    Out thumb push; f14-f16 hold; f16-f30 Sine InOut back to the saddle. A shot cuts it (fade 0.08)"""
    c = Clip("ShotgunReloadShell", 0.50)
    b = belly_up(c)
    seq(c, [(0, b), (15, add(b, gun=((0, 0.02, 0), (0.5, 0, 1)))), (30, b)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    sad = P(b, L=("gun", SADDLE, (0, 0, 0)))
    seq(c, [(0, sad, "SineInOut"), (10, P(b, L=("gun", add_t(PORT, (0, -0.05, 0.12)), (0, 0, 0))), "CubicOut"),
            (14, P(b, L=("gun", PORT, (0, 0, 0)))), (16, P(b, L=("gun", PORT, (0, 0, 0))), "SineInOut"), (30, sad)], only=("L",))
    # the shell: in the hand from the saddle, pushed home at f14 (its rest = in the loading port)
    from longgun_parts import held_at
    held_at(c, "LoadShell", 0, PORT); held_at(c, "LoadShell", 30, PORT)
    c.inhand("LoadShell", 0, 1, ease="Constant"); c.inhand("LoadShell", fr(13), 1, ease="Linear"); c.inhand("LoadShell", fr(14), 0, ease="Constant")
    c.inhand("LoadShell", fr(29), 0, ease="Constant"); c.inhand("LoadShell", fr(30), 1, ease="Constant")
    c.marker("ShellIn", fr(14))
    return c


def reload_end(empty=False):
    """End: f0-f12 Cubic InOut roll back, off hand to the pump; f12-f18 Quart Out shoulder. EndEmpty: + Pump back f12-f18,
    hold f18-f20, forward f20-f25 Cubic In; f25-f33 settle"""
    c = Clip("ShotgunReloadEndEmpty" if empty else "ShotgunReloadEnd", 0.55 if empty else 0.30)
    h, b = G.hold(c), belly_up(c)
    n = 33 if empty else 18
    mid = P(h, gun=(h["gun"][0], add_t(h["gun"][1], (-0.1, -0.1, -0.05)), add_t(h["gun"][2], (-3, 0, 5))))
    keys = [(0, P(b, L=("gun", SADDLE, (0, 0, 0))), "CubicInOut"), (12, mid, "QuartOut"), (18, h)]
    if empty:
        back = P(h, L=("gun", add_t(PUMP, (0, 0, 0.35)), G.support_rot))
        keys = [(0, P(b, L=("gun", SADDLE, (0, 0, 0))), "CubicInOut"), (12, mid, "QuartOut"), (18, back, "SineInOut"), (20, back, "CubicIn"),
                (25, h, "CubicOut"), (33, h)]
        for f, z, e in ((0, 0, "Constant"), (12, 0, "QuartOut"), (18, 0.35, "SineInOut"), (20, 0.35, "CubicIn"), (25, 0, "Constant"),
                        (33, 0, "Constant")):
            c.part("Pump", fr(f), (0, 0, z), ease=e)
        c.marker("PumpClosed", fr(25))
    seq(c, keys)
    return c


def inspect():
    def parts(c):
        for f, z, e in ((0, 0, "Constant"), (60, 0, "CubicOut"), (70, 0.15, "SineInOut"), (100, 0.15, "CubicIn"), (106, 0, "Constant"),
                        (180, 0, "Constant")):
            c.part("Pump", fr(f), (0, 0, z), ease=e)
    return gun_inspect(G, "ShotgunInspect", 50, parts, ("PumpClosed", fr(106)))


CLIPS = {"ShotgunHold": G.c_hold, "ShotgunLowered": G.c_lowered, "ShotgunEquip": lambda: G.c_equip(up=12, settle=3),
         "ShotgunFire": fire, "ShotgunReloadStart": reload_start, "ShotgunReloadShell": reload_shell,
         "ShotgunReloadEnd": reload_end, "ShotgunReloadEndEmpty": lambda: reload_end(True),
         "ShotgunDraw": lambda: G.c_draw(length=0.65, grip=6, swing=21, mount=31, back=35),
         "ShotgunHolster": lambda: G.c_holster(length=0.60, release=24), "ShotgunInspect": inspect}
