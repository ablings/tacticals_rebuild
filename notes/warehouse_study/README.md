# Warehouse study (read-only survey of the Tacticals tutorial map, 2026-10-26)
Vault page: `06 Training/Map Training/tacticals-warehouse/Warehouse Study.md`. The map itself was never changed or saved.

- `warehouse_dump.json`, `warehouse_settings.json`: dumped from a temp copy of `Tutorial_place.rbxl` with `t2.lua` / `t3.lua`
  (run through `q.py`, which needs a `mcp.py` copy of `roblox_kits/tools/mcpcli.py` pointed at the current StudioMCP.exe: mcpcli's glob can pick an old version).
- `movement_configs.txt`: CoverConfig + MovementConfig sources (the numbers the sizes depend on).
- `geom.py`: pieces in plan coords (e east = -X, n north = +Z, heights above floor). `WH_WHATIF=<json>` moves pieces for what-ifs (analysis only).
- `analyze.py` -> `metrics.json` (+ grids.npz, not committed): routes, timings, exposure, spawn sight, pairing, gaps. `WH_PREFIX` names the output.
- `analyze2.py` -> `metrics2.json`: crouched exposure, sight-line lengths, spawn views, peek checks.
- `plot.py <dir>`, `plot_whatif.py <dir>`: the vault images. `cams.json` + `cam.py`: the fixed cameras (plan coords).
- Order: `python analyze.py && python analyze2.py && python plot.py <dir> && WH_WHATIF=whatif_pairing2.json WH_PREFIX=whatif2_ python analyze.py && python plot_whatif.py <dir>`
