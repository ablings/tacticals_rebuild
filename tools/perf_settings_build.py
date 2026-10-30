"""Build fix/perf_settings_1030.lua [PERFSET] from fix/perf_settings/installer.lua + ui/settings/SettingsEffectsController.lua."""
import os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = open(os.path.join(R, "fix", "perf_settings", "installer.lua"), encoding="utf-8").read().replace("\r\n", "\n")
ctrl = open(os.path.join(R, "ui", "settings", "SettingsEffectsController.lua"), encoding="utf-8").read().replace("\r\n", "\n")
assert "]==]" not in ctrl
# the long string drops its first newline; the controller's text must equal the module source byte for byte
out = src.replace("--@@CONTROLLER\n]==]", ctrl + "]==]")
open(os.path.join(R, "fix", "perf_settings_1030.lua"), "w", encoding="utf-8", newline="\n").write(out)
print("built fix/perf_settings_1030.lua", len(out))
