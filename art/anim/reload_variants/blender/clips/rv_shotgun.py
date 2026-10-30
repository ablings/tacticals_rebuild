"""Pump Shotgun reload variants (design "Pump Shotgun"): the per-shell rhythm stays fixed (StartDelay 0.2 s = 12 f, ShellTime
0.5 s = 30 f per shell); the count shows in which piece plays.
  ShotgunReloadStart_Dry (12 f): reload started empty: roll the ejection port up 45 (not belly up), off hand to the saddle.
  ShotgunReloadShell_Port (30 f): the first shell when empty goes into the ejection port (ShellIn f12), the off hand racks
    the Pump (PumpClosed f25), then the gun rolls belly up (= the shell clip's start pose).
  ShotgunReloadShell_B (30 f): a tube shell from the receiver side-saddle, shorter reach, thumb press on the gate
    (ShellIn f14). Alternate with the existing ShotgunReloadShell (A).
  ShotgunReloadShell_Last (30 f): the shell that fills the tube: as A, then a palm slap on the loading gate (GateSlap f20).
ShotgunReloadEnd (existing) closes every count; ShotgunReloadEndEmpty is no longer needed (the pump moved to Shell_Port)."""
import shotgun
from rbxanim import Clip, P, add, seq, fr
from longgun_parts import held_at, add_t

GUN = "PumpShotgun"
TOOL = "PumpShotgun"
G = shotgun.G
PORT, SADDLE, PUMP = shotgun.PORT, shotgun.SADDLE, shotgun.PUMP
SHELL_REST = (0.0, 0.16, -0.99)          # LoadShell rest (in the loading port, on the lifter)
EJECT = (0.12, 0.34, -0.93)              # LoadShell centre dropped into the ejection port (right side, top)
CHAMBER = (0.0, 0.26, -1.02)             # LoadShell centre once the pump closes on it (inside the receiver)
EPW = (0.40, 0.40, -0.70)                # off-hand wrist dropping a shell into the ejection port (gun rolled port up)
SADDLE_B = (-0.45, 0.22, -0.32)          # off-hand wrist pulling a shell off the side-saddle
BASE_LENS = {"ShotgunReloadStart_Dry": 0.2, "ShotgunReloadShell_Port": 0.5, "ShotgunReloadShell_B": 0.5, "ShotgunReloadShell_Last": 0.5}
BASE_NAMES = {"ShotgunReloadStart_Dry": "ShotgunReloadStart", "ShotgunReloadShell_Port": "ShotgunReloadShell",
              "ShotgunReloadShell_B": "ShotgunReloadShell", "ShotgunReloadShell_Last": "ShotgunReloadShell"}
BODY = ("root", "chest", "head", "gun", "R", "poles", "feet")


def port_up(c):
    h = G.hold(c)
    return P(h, gun=((0, 0.2, -0.8), (-0.02, 1.08, -0.95), (-8, G.blade, -45)), head=(-12, 14, 0), L=("gun", SADDLE, (0, 0, 0)),
             poleR=(1.5, -0.9, 0.9))


def start_dry():
    """f0-f12 Cubic Out roll the ejection port up 45 deg, muzzle -8; off hand from the pump to the saddle"""
    c = Clip("ShotgunReloadStart_Dry", 0.2)
    h, pu = G.hold(c), port_up(c)
    seq(c, [(0, h, "CubicOut"), (12, pu)], only=BODY)
    seq(c, [(0, h, "CubicOut"), (12, pu)], only=("L",))
    return c


def shell_port():
    """port-up pose, shell in hand: f0-f8 Sine InOut to above the ejection port; f8-f12 Cubic Out thumb drops it in (ShellIn
    f12); f12-f14 hand to the Pump; Pump back f14-f18 Quart Out, hold f18-f20, forward f20-f25 Cubic In hard stop
    (PumpClosed f25: the shell rides into the chamber); f25-f30 roll belly up, off hand to the saddle"""
    c = Clip("ShotgunReloadShell_Port", 0.5)
    pu, b = port_up(c), shotgun.belly_up(c)
    above = P(pu, L=("gun", add_t(EPW, (0.05, 0.12, 0.08)), (0, 0, 0)))
    drop = P(pu, L=("gun", EPW, (0, 0, 0)))
    pump0 = P(pu, L=("gun", PUMP, G.support_rot))
    pump1 = P(pu, L=("gun", add_t(PUMP, (0, 0, 0.35)), G.support_rot))
    sad = P(b, L=("gun", SADDLE, (0, 0, 0)))
    seq(c, [(0, pu, "SineInOut"), (8, above, "CubicOut"), (12, drop, "CubicOut"), (14, pump0, "QuartOut"), (18, pump1, "SineInOut"),
            (20, pump1, "CubicIn"), (25, add(pump0, gun=((0, 0, -0.02), (0.5, 0, 0))), "CubicOut"), (30, sad)])
    for f, z, e in ((0, 0, "Constant"), (14, 0, "QuartOut"), (18, 0.35, "SineInOut"), (20, 0.35, "CubicIn"), (25, 0, "Constant"),
                    (30, 0, "Constant")):
        c.part("Pump", fr(f), (0, 0, z), ease=e)
    d_ej = tuple(a - b for a, b in zip(EJECT, SHELL_REST))
    d_ch = tuple(a - b for a, b in zip(CHAMBER, SHELL_REST))
    w_ep = tuple(w - d for w, d in zip(EPW, d_ej))
    held_at(c, "LoadShell", 0, w_ep, ease="Constant"); held_at(c, "LoadShell", 12, w_ep, ease="Constant")
    held_at(c, "LoadShell", 29, PORT, ease="Constant"); held_at(c, "LoadShell", 30, PORT)
    for f, pos, e in ((0, d_ej, "Constant"), (12, d_ej, "Constant"), (20, d_ej, "CubicIn"), (25, d_ch, "Constant"), (30, (0, 0, 0), "Constant")):
        c.part("LoadShell", fr(f), pos, ease=e)
    c.inhand("LoadShell", 0, 1, ease="Constant"); c.inhand("LoadShell", fr(11), 1, ease="Linear")
    c.inhand("LoadShell", fr(12), 0, ease="Constant"); c.inhand("LoadShell", fr(29), 0, ease="Constant")
    c.inhand("LoadShell", fr(30), 1, ease="Constant")
    c.marker("ShellIn", fr(12)); c.marker("PumpClosed", fr(25))
    return c


def shell_b():
    """belly up, start = end = the shell clip's pose: f0-f4 off hand to the side-saddle (pull a shell); f4-f8 Sine InOut to
    the loading port; f8-f12 Cubic Out push; f12-f16 thumb presses past the gate (ShellIn f14); f16-f30 back to the saddle"""
    c = Clip("ShotgunReloadShell_B", 0.5)
    b = shotgun.belly_up(c)
    seq(c, [(0, b), (12, add(b, gun=((0, 0.02, 0), (0.5, 0, 1)))), (30, b)], only=BODY)
    sad = P(b, L=("gun", SADDLE, (0, 0, 0)))
    seq(c, [(0, sad, "SineInOut"), (4, P(b, L=("gun", SADDLE_B, (0, 0, 0))), "SineInOut"),
            (8, P(b, L=("gun", add_t(PORT, (0, -0.05, 0.12)), (0, 0, 0))), "CubicOut"), (12, P(b, L=("gun", PORT, (0, 0, 0))), "CubicOut"),
            (14, P(b, L=("gun", add_t(PORT, (0, 0.03, -0.04)), (0, 0, 0))), "SineInOut"), (16, P(b, L=("gun", PORT, (0, 0, 0))), "SineInOut"),
            (30, sad)], only=("L",))
    held_at(c, "LoadShell", 0, PORT); held_at(c, "LoadShell", 30, PORT)
    c.inhand("LoadShell", 0, 1, ease="Constant"); c.inhand("LoadShell", fr(11), 1, ease="Linear")
    c.inhand("LoadShell", fr(12), 0, ease="Constant"); c.inhand("LoadShell", fr(29), 0, ease="Constant")
    c.inhand("LoadShell", fr(30), 1, ease="Constant")
    for f, pos, e in ((0, (0, 0, 0), "Constant"), (12, (0, 0, 0), "CubicOut"), (14, (0, 0.02, -0.06), "Constant"), (30, (0, 0, 0), "Constant")):
        c.part("LoadShell", fr(f), pos, ease=e)
    c.marker("ShellIn", fr(14))
    return c


def shell_last():
    """as ShotgunReloadShell (A) to f16 (ShellIn f14), then the palm comes off f16-f17 and slaps the loading gate f17-f20
    Cubic Out (GateSlap f20, a small gun bump); f20-f30 back to the saddle"""
    c = Clip("ShotgunReloadShell_Last", 0.5)
    b = shotgun.belly_up(c)
    seq(c, [(0, b), (15, add(b, gun=((0, 0.02, 0), (0.5, 0, 1))), "CubicOut"), (20, add(b, gun=((0, 0.035, 0), (1.2, 0, 1)))), (30, b)],
        only=BODY)
    sad = P(b, L=("gun", SADDLE, (0, 0, 0)))
    seq(c, [(0, sad, "SineInOut"), (10, P(b, L=("gun", add_t(PORT, (0, -0.05, 0.12)), (0, 0, 0))), "CubicOut"),
            (14, P(b, L=("gun", PORT, (0, 0, 0)))), (16, P(b, L=("gun", PORT, (0, 0, 0))), "SineInOut"),
            (17, P(b, L=("gun", add_t(PORT, (0, -0.1, 0.02)), (0, 0, 0))), "CubicOut"),
            (20, P(b, L=("gun", add_t(PORT, (0, -0.01, 0.0)), (0, 0, 0))), "SineInOut"), (30, sad)], only=("L",))
    held_at(c, "LoadShell", 0, PORT); held_at(c, "LoadShell", 30, PORT)
    c.inhand("LoadShell", 0, 1, ease="Constant"); c.inhand("LoadShell", fr(13), 1, ease="Linear")
    c.inhand("LoadShell", fr(14), 0, ease="Constant"); c.inhand("LoadShell", fr(29), 0, ease="Constant")
    c.inhand("LoadShell", fr(30), 1, ease="Constant")
    c.marker("ShellIn", fr(14)); c.marker("GateSlap", fr(20))
    return c


POP_CHECK = ["LoadShell"]
ROUNDS = {"ShotgunReloadStart_Dry": "0 (reload started empty)", "ShotgunReloadShell_Port": "0 (the first shell when empty)",
          "ShotgunReloadShell_B": "any tube shell (alternate with A)", "ShotgunReloadShell_Last": "the shell that fills the tube"}
CLIPS = {"ShotgunReloadStart_Dry": start_dry, "ShotgunReloadShell_Port": shell_port, "ShotgunReloadShell_B": shell_b,
         "ShotgunReloadShell_Last": shell_last}
