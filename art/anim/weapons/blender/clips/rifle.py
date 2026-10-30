"""Rifle set (Auto Rifle + Semi-Auto): targets section 4, on the remodelled AutoRifle (art/guns/manifest/AutoRifle.json)."""
from longgun import Gun
from longgun_parts import mag_reload, gun_inspect
from rbxanim import fr

GUN = "AutoRifle"
TOOL = "AutoRifle"
G = Gun("Rifle", butt=(0, 0.2, 1.28), support=(0.0, 0.1, -0.8), blade=56, lean=5)


def fire():
    """f1 peak (muzzle +3.5, shoulder rocks back 0.07, chest +1, off elbow drops 3) Linear; f1-f7 Cubic Out. Restarts on
    auto (fade 0.03); BoltCarrier back 0.45 f0-f1, forward f1-f3 Quad In; trigger"""
    def parts(c, h):
        for f, z, e in ((0, 0, "Linear"), (1, 0.45, "QuadIn"), (3, 0, "Constant"), (7, 0, "Constant")):
            c.part("BoltCarrier", fr(f), (0, 0, z), ease=e)
        for f, a, e in ((0, 12, "Constant"), (2, 12, "CubicOut"), (5, 0, "Constant"), (7, 0, "Constant")):
            c.part("Trigger", fr(f), (0, 0, 0), (-a, 0, 0), ease=e)
    return G.c_fire(length=0.12, rise=3.5, push=0.07, chest=1.0, ret=6, extra=parts)


def reload():
    """tactical 2.4 s: f0-f8 tilt; off hand to the mag; f16 release, out f16-f24; stow f24-f44 (chest pouch); new mag;
    f66-f70 Linear rock in + seat; f80-f92 off hand to the support; f92-f108 shoulder; hold to f144"""
    return mag_reload(G, "RifleReload", 2.4, dict(tilt=8, release=16, out=24, stowed=44, seat=70, rewrap=92, shoulder=108, end=144))


def reload_empty():
    """2.8 s: mag drops free f16-f30 (MagHide f30); new mag; seat f56-f60; f64-f80 off hand to the ChargingHandle; back
    f80-f84 Cubic Out, hold f84-f86, forward f86-f88 Quad In; back to the support; f104-f120 shoulder; hold to f168"""
    return mag_reload(G, "RifleReloadEmpty", 2.8, dict(tilt=8, release=16, hide=30, show=31, seat=60, rewrap=104, shoulder=120, end=168),
                      empty=True, drop=(0, -2.4, -0.6),
                      charge=("ChargingHandle", 0.45, (0.0, 0.55, 0.45), 80, 84, 86, 88), extra_parts=("BoltCarrier",))


def inspect():
    def parts(c):
        for f, y, e in ((0, 0, "Constant"), (60, 0, "CubicOut"), (72, -0.3, "SineInOut"), (80, -0.3, "Linear"), (90, 0, "Constant"),
                        (180, 0, "Constant")):
            c.part("Mag", fr(f), (0, y, 0), ease=e)
        for p in ("ChargingHandle", "BoltCarrier"):
            for f, z, e in ((0, 0, "Constant"), (100, 0, "CubicOut"), (104, 0.15, "SineInOut"), (124, 0.15, "QuadIn"),
                            (126, 0, "Constant"), (180, 0, "Constant")):
                c.part(p, fr(f), (0, 0, z), ease=e)
    return gun_inspect(G, "RifleInspect", 45, parts, ("SlideRack", fr(126)))


CLIPS = {"RifleHold": G.c_hold, "RifleLowered": G.c_lowered, "RifleEquip": G.c_equip, "RifleFire": fire,
         "RifleReload": reload, "RifleReloadEmpty": reload_empty, "RifleDraw": G.c_draw, "RifleHolster": G.c_holster,
         "RifleInspect": inspect}
