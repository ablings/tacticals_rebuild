from bodyanim import *
def mk(p):
    def b():
        c = Clip("TPitch%d" % (p + 100), 0.1, priority="Action")
        c.root(0, y=-0.5, pitch=p); c.root(0.1, y=-0.5, pitch=p)
        return c
    return b
CLIPS = {"TPitchA": mk(20), "TPitchB": mk(-20)}
