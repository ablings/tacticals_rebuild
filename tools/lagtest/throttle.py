"""Throttle ONE process to stand in for a weak device CPU: pin it to CORES logical cores and hard-cap its CPU time with a
Windows job object (named, so a second call can change or clear the cap).
Usage: python tools/lagtest/throttle.py <pid> <cores> <percent_of_those_cores>      e.g. 1234 1 35  (= 35% of one core)
       python tools/lagtest/throttle.py <pid> off"""
import ctypes, ctypes.wintypes as W, os, sys
k = ctypes.WinDLL("kernel32", use_last_error=True)
pid = int(sys.argv[1]); name = f"lagtest_throttle_{pid}"
k.CreateJobObjectW.restype = W.HANDLE; k.OpenProcess.restype = W.HANDLE
class RATE(ctypes.Structure):
    _fields_ = [("ControlFlags", W.DWORD), ("CpuRate", W.DWORD)]
JobObjectCpuRateControlInformation = 15
ENABLE, HARD_CAP = 0x1, 0x4
job = k.CreateJobObjectW(None, name)
if not job: sys.exit("CreateJobObject failed %d" % ctypes.get_last_error())
proc = k.OpenProcess(0x1F0FFF, False, pid)
if not proc: sys.exit("OpenProcess failed %d" % ctypes.get_last_error())
n = os.cpu_count()
if sys.argv[2] == "off":
    r = RATE(0, 0)
    k.SetInformationJobObject(job, JobObjectCpuRateControlInformation, ctypes.byref(r), ctypes.sizeof(r))
    k.SetProcessAffinityMask(proc, ctypes.c_size_t((1 << n) - 1))
    print("cleared", pid); sys.exit(0)
cores, pct = int(sys.argv[2]), float(sys.argv[3])
mask = 0
for i in range(cores): mask |= 1 << (2 * i if 2 * i < n else i)   # one logical core per physical core (skip SMT siblings)
if not k.SetProcessAffinityMask(proc, ctypes.c_size_t(mask)): print("affinity failed", ctypes.get_last_error())
if not k.AssignProcessToJobObject(job, proc):
    err = ctypes.get_last_error()
    if err != 5: print("assign failed", err)   # 5 = already in this job: fine
rate = int(cores * pct / n * 100)               # CpuRate = 1/100 % of ALL cores' cycles
r = RATE(ENABLE | HARD_CAP, max(1, rate))
ok = k.SetInformationJobObject(job, JobObjectCpuRateControlInformation, ctypes.byref(r), ctypes.sizeof(r))
print(f"pid {pid}: affinity mask {mask:#x}, cap {pct}% of {cores} core(s) = CpuRate {rate}/10000 of {n} cpus, set={bool(ok)}")
# keep the job handle open only while this process lives: the limits stay because the process is still in the job
