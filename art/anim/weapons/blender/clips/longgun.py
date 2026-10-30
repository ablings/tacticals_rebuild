"""Shared long-gun (shouldered) poses and clips: Rifle, Shotgun, Sniper, SMG sets build on this.

Reach: R15 arms reach 1.73 studs from shoulders 1.94 apart and these guns are 2-6 studs long, so a support hand forward
of the magwell with the butt in the shoulder needs a bladed stance: hips + waist turn the chest ~55-60 deg to the gun
side and the gun yaws back to world-forward (all poses are in chest space). The head turns back as far as the neck may.
Positions: studs from the Waist pivot in the chest frame (x right, y up, -z forward)."""
from rbxanim import Clip, P, add, mix, seq, fr


def add_t(a, b):
    return tuple(x + y for x, y in zip(a, b))


class Gun:
    def __init__(self, prefix, butt, support, blade=56, lean=5, knees=0.08, wide=0.0, heavy=1.0, height=0.0,
                 cheek=(-8, 5), support_rot=(0, -15, 0), pocket=None):
        self.prefix, self.butt, self.support = prefix, butt, support
        self.blade, self.lean, self.knees, self.wide, self.heavy, self.height = blade, lean, knees, wide, heavy, height
        self.cheek, self.support_rot = cheek, support_rot
        self.pocket = pocket

    # ---- poses
    def hold(self, c):
        b = self.blade
        pocket = self.pocket or (0.55, 1.33 + self.height, -0.42)
        feet = dict(footL=((0.05 - self.wide, 0, -0.3), (0, b * 0.35, 0)), footR=((0.05 + self.wide, 0, 0.25), (0, -b * 0.25, 0)))
        return P(root=(0, -self.knees, 0.03, -self.lean * 0.4, -b * 0.5, 0), chest=(-self.lean * 0.6, -b * 0.5, 0),
                 head=(self.cheek[0], 15, self.cheek[1]),
                 gun=(self.butt, pocket, (0, b, 0)),
                 R=("gun", (0, 0, 0), (0, 0, 0)), L=("gun", self.support, self.support_rot),
                 poleR=(1.4, -0.5, 1.2), poleL=(-1.8, -0.9, -0.2), **feet)

    def lowered(self, c, down=30):
        h = self.hold(c)
        sup = (self.support[0], self.support[1] - 0.05, self.support[2] * 0.3)
        return P(h, gun=(self.butt, (0.5, 1.22 + self.height, -0.45), (-down, self.blade - 4, 0)), head=(-2, 15, 0),
                 L=("gun", sup, self.support_rot), poleL=(-1.8, -1.2, 0.0))

    def sling(self, c):
        """on the back: diagonal, muzzle down to the left, grip up behind the right shoulder"""
        h = self.hold(c)
        return P(h, gun=((0, 0, 0), (0.55, 1.95, 0.75), (-120, 0, -35)), head=(0, 10, 0),
                 R=("free", (0.75, 1.95, 0.5), (-170, 0, 0)), L=("free", (-0.95, -0.15, -0.3), (10, 0, 0)),
                 poleR=(1.8, 1.0, 0.5))

    # ---- clips
    def breathe(self, c, p, amp=0.5, sink=0.015):
        seq(c, [(0, p), (30, add(p, chest=(amp, 0, 0), root=(0, -sink, 0, 0, 0, 0))), (60, p)])

    def c_hold(self):
        c = Clip(self.prefix + "Hold", 1.0, loop=True)
        self.breathe(c, self.hold(c))
        return c

    def c_lowered(self):
        c = Clip(self.prefix + "Lowered", 1.0, loop=True)
        self.breathe(c, self.lowered(c), amp=0.4)
        return c

    def c_equip(self, up=11, settle=4):
        """f0-f(up) Quart Out muzzle arcs up from low, f(up)-f(up+settle) Back Out 4%, hold to f21"""
        c = Clip(self.prefix + "Equip", 0.35)
        h, l = self.hold(c), self.lowered(c)
        over = add(h, gun=((0, 0.015, -0.02), (0.8, 0, 0)))
        seq(c, [(0, l, "QuartOut"), (up, over, "BackOut:0.5"), (up + settle, h), (21, add(h, chest=(0.15, 0, 0)))])
        return c

    def c_fire(self, length=0.12, peak=1, rise=3.5, push=0.07, chest=1.0, ret=7, ease="CubicOut", dip=False, extra=None):
        c = Clip(self.prefix + "Fire", length)
        h = self.hold(c)
        b = self.butt
        pk = P(h, gun=(b, add_t(h["gun"][1], (0, 0.01, push)), add_t(h["gun"][2], (rise, 0.3, 0))))
        pk = add(pk, chest=(chest, 0, 0), poleL=(0, -0.2, 0))
        keys = [(0, h, "Linear"), (peak, pk, ease)]
        if dip:
            keys += [(peak + int(ret * 0.6), P(h, gun=(b, h["gun"][1], add_t(h["gun"][2], (-0.6, 0, 0)))), "SineInOut")]
        keys += [(peak + ret, h)]
        if int(round(length * 60)) > peak + ret:
            keys += [(int(round(length * 60)), h)]
        seq(c, keys)
        c.marker("ShellEject", fr(1))
        if extra:
            extra(c, h)
        return c

    def c_draw(self, length=0.60, grip=6, swing=18, mount=28, back=32):
        """from the back sling: f0-f(grip) Cubic Out gun hand over the right shoulder (Grip); swing over and down on an arc;
        off hand catches the support f(swing); mount Quart Out; Back 4%; hold"""
        c = Clip(self.prefix + "Draw", length)
        h, s = self.hold(c), self.sling(c)
        start = P(s, R=("free", (0.8, -0.2, 0.0), (0, 0, 0)), L=("free", (-0.95, -0.2, -0.1), (0, 0, 0)), poleR=(1.8, -0.5, 0.5))
        grab = P(s, R=("gun", (0, 0, 0), (0, 0, 0)))
        mid = P(h, gun=(self.butt, (0.75, 1.55, -0.55), (-30, self.blade * 0.7, -40)), L=("free", (-0.45, 0.9, -0.9), (70, 0, 0)),
                head=(-2, 12, 0))
        over = add(h, gun=((0, 0.015, -0.02), (0.6, 0, 0)))
        end = int(round(length * 60))
        seq(c, [(0, start, "CubicOut"), (grip, grab, "CubicInOut"), (swing - 6, mid, "CubicInOut"), (swing, P(mid, L=("gun", (self.support[0], self.support[1], self.support[2] * 0.3), self.support_rot)), "QuartOut"),
                (mount, over, "BackOut:0.5"), (back, h), (end, h)])
        c.marker("Grip", fr(grip))
        return c

    def c_holster(self, length=0.60, release=24):
        """f0-f10 Cubic InOut off the shoulder, off hand releases f8; f10-f(release) Sine InOut up over the shoulder;
        release; hand down Cubic Out"""
        c = Clip(self.prefix + "Holster", length)
        h, s = self.hold(c), self.sling(c)
        off = P(h, gun=(self.butt, (0.9, 1.5, -0.8), (-30, self.blade * 0.6, -50)), L=("free", (-0.6, 0.6, -0.7), (60, 0, 0)))
        after = P(s, R=("free", (0.95, -0.15, -0.1), (0, 0, 0)), L=("free", (-0.95, -0.15, -0.1), (0, 0, 0)))
        end = int(round(length * 60))
        seq(c, [(0, h, "CubicInOut"), (10, off, "SineInOut"), (release, P(s), "CubicOut"), (end, after)],
            only=("root", "chest", "head", "gun", "R", "poles", "feet"))
        seq(c, [(0, h, "CubicOut"), (8, off, "SineInOut"), (release, P(s, L=after["L"])), (end, after)], only=("L",))
        c.marker("Holstered", fr(release))
        return c
