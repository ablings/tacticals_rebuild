"""Pistol set (Pistol, Suppressed; Dual Pistols for now): Grounded Tactical, notes/anim_style_targets.md section 1.
Positions: studs from the Waist pivot (x right, y up, -z forward); rotations (pitch, yaw, roll) degrees."""
import rbxanim
from rbxanim import Clip, P, add, mix, seq, fr

GUN = None
TOOL = "Pistol"


def poses(c):
    a = c.anchor
    sh = a["shoulderR"]
    feet = dict(footL=((0.04, 0, -0.22), (0, 10, 0)), footR=((0.0, 0, 0.18), (0, -14, 0)))
    # HOLD: isosceles, arms near straight (elbows soft), gun at the eye line, knees ~6 deg (hips sink), chest a touch forward
    hold = P(root=(0, -0.07, 0.02, -2, 0, 0), chest=(-2, 0, 0), head=(-3, 0, 0),
             gun=((0.05, sh[1] + 0.0, -1.27), (0, 0, 0)),
             R=("gun", (0, 0, 0), (0, 0, 0)), L=("gun", (-0.13, -0.07, 0.2), (0, 0, -15)),
             poleR=(1.7, -0.6, 0.6), poleL=(-1.7, -0.6, 0.6), **feet)
    # LOWERED: gun hand at the thigh, muzzle 45 down in front of the foot, off hand relaxed at the belt
    low = P(hold, gun=((0.6, -0.05, -0.62), (-45, 4, 0)), head=(-2, 0, 0), chest=(-1, 0, 0),
            L=("free", (-0.72, -0.05, -0.45), (10, 0, 0)), poleR=(1.6, -1.0, 0.8), poleL=(-1.6, -1.0, 0.8))
    # holster mouth at the right thigh (gun muzzle down, grip up)
    holst = P(low, gun=((1.0, -0.2, 0.02), (-90, 0, 0)), head=(-6, 0, 0), poleR=(2.0, -0.6, 1.5))
    return hold, low, holst


def breathe(c, p, amp=0.4, sink=0.01, gun_amp=0.0):
    """moving hold over 1.0 s: f0-f30 Sine InOut chest up / sink, f30-f60 back; f60 = f0"""
    up = add(p, chest=(amp, 0, 0), root=(0, -sink, 0, 0, 0, 0))
    if p["gun"] is not None and gun_amp:
        up = add(up, gun=((0, 0, 0), (gun_amp, 0, 0)))
    seq(c, [(0, p), (30, up), (60, p)])


def hold():
    c = Clip("PistolHold", 1.0, loop=True)
    h, _, _ = poses(c)
    breathe(c, h)
    return c


def lowered():
    c = Clip("PistolLowered", 1.0, loop=True)
    _, l, _ = poses(c)
    breathe(c, l, gun_amp=0.5)
    return c


def equip():
    """from Lowered to Hold: f0-f10 Quart Out arc up and forward (off hand meets f8), f10-f14 Back Out 5%, f14-f21 hold"""
    c = Clip("PistolEquip", 0.35)
    h, l, _ = poses(c)
    over = add(h, gun=((0, 0.02, -0.03), (1.0, 0, 0)))
    mid = mix(l, h, 0.7)
    mid["L"] = ("gun", h["L"][1], h["L"][2])
    seq(c, [(0, l, "QuartOut"), (10, over, "BackOut:0.6"), (14, h, "SineInOut"), (21, add(h, chest=(0.2, 0, 0)))],
        only=("root", "chest", "head", "gun", "R", "poles", "feet", "parts"))
    seq(c, [(0, l, "QuartOut"), (8, h, "SineInOut"), (21, h)], only=("L",))
    return c


def fire():
    """f0 = Hold, f1 peak (wrist +8, elbows +4, shoulders 0.06 back, chest +1) Linear, f1-f9 Cubic Out return"""
    c = Clip("PistolFire", 0.15)
    h, _, _ = poses(c)
    peak = add(h, gun=((0, 0.05, 0.08), (8, 0.5, 0)), chest=(1, 0, 0), head=(0.5, 0, 0))
    seq(c, [(0, h, "Linear"), (1, peak, "CubicOut"), (9, h)])
    c.marker("ShellEject", fr(1))
    return c


def draw():
    """f0-f4 Cubic Out hand to grip; f4 Grip; f4-f10 Quart Out up out of the holster; f10-f20 Quart Out punch out (off hand
    meets f16); f20-f24 Back Out 4%; f24-f30 hold"""
    c = Clip("PistolDraw", 0.5)
    h, l, hs = poses(c)
    rest = P(hs, R=("free", (1.02, -0.22, -0.05), (0, 0, 0)), L=("free", (-1.0, -0.22, -0.05), (0, 0, 0)), head=(-4, 0, 0))
    out = add(hs, gun=((-0.1, 0.45, -0.05), (35, 0, 0)), chest=(0, 0, 0))
    over = add(h, gun=((0, 0.01, -0.02), (0.6, 0, 0)))
    seq(c, [(0, rest, "CubicOut"), (4, P(hs), "QuartOut"), (10, out, "QuartOut"), (20, over, "BackOut:0.5"),
            (24, h), (30, h)], only=("root", "chest", "head", "gun", "R", "poles", "feet"))
    seq(c, [(0, rest, "SineInOut"), (10, P(rest, L=("free", (-0.55, 0.45, -0.75), (60, 0, 0))), "QuartOut"),
            (16, h), (30, h)], only=("L",))
    c.marker("Grip", fr(4))
    return c


def holster():
    """f0-f8 Cubic InOut gun to the chest, muzzle down; f8-f16 Sine InOut to the holster mouth (head glances down f6-f12);
    f16-f19 Linear push in; f19-f27 Cubic Out hand off, relaxed"""
    c = Clip("PistolHolster", 0.45)
    h, l, hs = poses(c)
    chest = P(h, gun=((0.35, 0.55, -0.8), (-80, 0, 0)), L=("free", (-0.45, 0.4, -0.75), (60, 0, 0)))
    mouth = add(hs, gun=((0, 0.3, 0), (0, 0, 0)))
    after = P(hs, R=("free", (1.02, -0.2, -0.1), (0, 0, 0)), L=("free", (-1.0, -0.22, -0.05), (0, 0, 0)), head=(-2, 0, 0))
    seq(c, [(0, h, "CubicInOut"), (8, chest, "SineInOut"), (16, mouth, "Linear"), (19, hs, "CubicOut"), (27, after)],
        only=("root", "chest", "gun", "R", "L", "poles", "feet"))
    seq(c, [(0, h), (6, h, "SineInOut"), (12, P(h, head=(-12, 0, 0))), (20, P(h, head=(-6, 0, 0))), (27, after)],
        only=("head",))
    c.marker("Holstered", fr(19))
    return c


CLIPS = {"PistolHold": hold, "PistolLowered": lowered, "PistolEquip": equip, "PistolFire": fire,
         "PistolDraw": draw, "PistolHolster": holster}
