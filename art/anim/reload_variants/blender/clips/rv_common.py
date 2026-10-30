"""Shared bits for the magazine-gun reload variants (built on the weapons animator's longgun_parts.mag_reload)."""
from rbxanim import add, seq, fr


def moving_hold(c, h, f0, f1, amp=0.4):
    """f0-f1: chest and head drift and back, so the settle is never a frozen hold (end pose = the hold)"""
    seq(c, [(f0, h, "SineInOut"), ((f0 + f1) // 2, add(h, chest=(amp, 0, 0), head=(amp * 0.7, 0, 0))), (f1, h)], only=("chest", "head"))


def tug(c, mag, f0, f1, end, keys_before=()):
    """tug check after the seat: the mag pulled down 0.03 and back (Cubic Out), the hand rides it"""
    m = (f0 + f1) // 2
    for f, y, e in tuple(keys_before) + ((f0, 0, "CubicOut"), (m, -0.03, "CubicOut"), (f1, 0, "Constant"), (end, 0, "Constant")):
        c.part(mag, fr(f), (0, y, 0), ease=e)
    c.marker("MagTug", fr(m))


def gun_bump(c, t, f0, f1, d=((0, 0.025, 0), (1.5, 0, 0)), only=("gun",)):
    """a heel tap / seat bump of the gun between f0 and f1 (pose t = the tilted gun)"""
    m = f0 + max(1, (f1 - f0) // 3)
    seq(c, [(f0, t, "CubicOut"), (m, add(t, gun=d)), (f1, t)], only=only)
