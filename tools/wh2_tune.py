"""Warehouse 2 light tuning loop (round 8, PC quality). Sets the night look LIVE in the Edit build copy (no installer run), captures
the tuning cameras at EditQualityLevel 21 and prints the light numbers per view.

  python tools/wh2_tune.py <outdir> key=value ...      (values are Lua expressions)

Keys (default = the round-6c values in fix/map_warehouse2.lua):
  amb, out (Color3 rgb strings "r,g,b"), exp, bright, diffuse, specular, density, haze, contrast, sat, bloom, thresh
  endPoint, endRange, endSpot, endAngle, endSpotRange   (light bars on rows n +-45)
  midPoint, midRange, midSpot, midAngle, midSpotRange   (rows n +-15)
  wall, wallRange, wallAngle                            (the 4 corner wall bars)
  roof ("r,g,b": roof sheet colour), door (door light brightness)
Summary line: worst near-black share over the player-height hall views, spawn shield faces A / B and their ratio."""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = dict(amb="16,17,20", out="30,32,38", exp="0", bright="1", diffuse="0.12", specular="0.2", density="0.32", haze="0.4",
         contrast="0.16", sat="-0.12", bloom="0.6", thresh="1.3",
         endPoint="0.4", endRange="30", endSpot="2.3", endAngle="100", endSpotRange="20",
         midPoint="0.25", midRange="30", midSpot="4", midAngle="90", midSpotRange="20",
         wall="2.6", wallRange="28", wallAngle="100", roof="112,114,112", door="0.9", housingShadow="true", pointShadow="true", curtainS="62,64,64", block="178,175,168", clad="172,174,172", fillColor="255,238,214")

LUA = r'''
local T = { %s }
local L = game:GetService("Lighting")
local function c3(s) local r, g, b = s:match("([%%d.]+),%%s*([%%d.]+),%%s*([%%d.]+)") return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
-- the place's own Lighting is saved once by wh2_env.lua (Lighting._WH2EnvSaved); this only overrides the Warehouse 2 values
L.ClockTime, L.Brightness, L.ExposureCompensation = 0, T.bright, T.exp
L.Ambient, L.OutdoorAmbient = c3(T.amb), c3(T.out)
L.EnvironmentDiffuseScale, L.EnvironmentSpecularScale = T.diffuse, T.specular
local atm = L:FindFirstChildOfClass("Atmosphere") atm.Density, atm.Haze = T.density, T.haze
local g = L:FindFirstChild("MapGrade") g.Contrast, g.Saturation = T.contrast, T.sat
local b = L:FindFirstChildOfClass("BloomEffect") b.Intensity, b.Threshold = T.bloom, T.thresh
settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21
local map = workspace.Warehouse2
local n = 0
for _, d in map:GetDescendants() do
	if d:IsA("Light") and d.Parent and d.Parent.Name == "Lens" then
		local beam = d.Parent.Parent and d.Parent.Parent.Parent
		local mid = beam and (beam.Name == "LightBeam_2" or beam.Name == "LightBeam_3")
		if d:IsA("PointLight") then d.Brightness, d.Range, d.Shadows, d.Color = mid and T.midPoint or T.endPoint, mid and T.midRange or T.endRange, T.pointShadow, c3(T.fillColor)
		elseif d:IsA("SpotLight") then
			d.Brightness, d.Angle, d.Range = mid and T.midSpot or T.endSpot, mid and T.midAngle or T.endAngle, mid and T.midSpotRange or T.endSpotRange
		end
		n += 1
	elseif d:IsA("SpotLight") and d.Parent and d.Parent.Name == "LightSource" then
		d.Brightness, d.Range, d.Angle = T.wall, T.wallRange, T.wallAngle n += 1
	elseif d:IsA("SpotLight") and d.Parent and d.Parent.Name:match("^DoorLight_") then
		d.Brightness = T.door n += 1
	elseif d:IsA("BasePart") and (d.Name == "Housing" or d.Name == "Clamp") and d.Parent and d.Parent.Name:match("^LightBar_") then
		d.CastShadow = T.housingShadow
	elseif d:IsA("BasePart") and d.Name == "Shutter" and d.Parent and d.Parent.Name == "Door_S" then
		d.Color = c3(T.curtainS)
	elseif d:IsA("BasePart") and (d:GetAttribute("_tuneOrig") == "block" or d:GetAttribute("_tuneOrig") == "clad"
		or d.Color == Color3.fromRGB(178, 175, 168) or d.Color == Color3.fromRGB(172, 174, 172)) and not d:IsA("MeshPart") then
		local k = d:GetAttribute("_tuneOrig") or (d.Color == Color3.fromRGB(178, 175, 168) and "block" or "clad")
		d:SetAttribute("_tuneOrig", k)
		d.Color = c3(T[k])
	elseif d:IsA("BasePart") and d.Name == "RoofSheet" then
		d.Color = c3(T.roof)
	end
end
return "tuned " .. n .. " lights | q " .. tostring(settings().Rendering.EditQualityLevel)
'''


def main():
    out = sys.argv[1]
    v = dict(D)
    for a in [x for x in sys.argv[2:] if not x.startswith("--")]:
        k, val = a.split("=", 1)
        assert k in v, k
        v[k] = val
    def lv(k):
        x = v[k]
        return f'"{x}"' if "," in x else x
    env_lua = open(os.path.join(ROOT, "tools", "wh2_env.lua"), encoding="utf-8").read().rstrip().rsplit(chr(10), 1)[0]
    code = env_lua + chr(10) + LUA % ", ".join(f"{k} = {lv(k)}" for k in v)
    os.makedirs(out, exist_ok=True)
    json.dump(v, open(os.path.join(out, "tune.json"), "w"), indent=1)
    p = os.path.join(out, "_tune.lua")
    open(p, "w", encoding="utf-8").write(code)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    cams = os.path.join(ROOT, "captures", "warehouse2", "r8", "cams_tune.json")
    cc = [a for a in sys.argv if a.startswith("--cams=")]
    if cc:
        cams = cc[0][7:]
    only = [a for a in sys.argv if a.startswith("--only=")]
    cmd = [sys.executable, os.path.join(ROOT, "tools", "wh2_fastcap.py"), cams, out, "--lua", p]
    if only:
        cmd += ["--only", only[0][7:]]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    print("\n".join(l for l in r.stdout.splitlines() if "tuned" in l or "UNSTABLE" in l))
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from wh2_lum import lum
    res, worst = {}, (0, "")
    for f in sorted(os.listdir(out)):
        if f.startswith("new_") and f.endswith(".png"):
            k = f[4:-4]
            res[k] = r = lum(os.path.join(out, f))
            if not k.startswith("pool"): print(f"{k:34s} p50 {r['p50']:3d}  p95 {r['p95']:3d}  near-black {r['dark']:5.1f} %  centre {r['centre']:3d}")
            if k.startswith("wh") and r["dark"] > worst[0]:
                worst = (r["dark"], k)
    json.dump(res, open(os.path.join(out, "lum.json"), "w"), indent=1)
    a, b = res.get("fA_spawnA_shield_face", {}).get("centre"), res.get("fB_spawnB_shield_face", {}).get("centre")
    ratio = (min(a, b) / max(a, b)) if a and b else 0
    C = lambda k: res.get(k, {}).get("centre", 0)
    mid = (C("pool_e-20_n-15") + C("pool_e20_n15")) / 2
    btw = (C("pool_e-20_n0") + C("pool_e20_n0")) / 2
    end = (C("pool_e-20_n-45") + C("pool_e20_n45")) / 2
    btw30 = (C("pool_e-20_n-30") + C("pool_e20_n30")) / 2
    print(f"POOLS under mid bars {mid:.0f} / between (n0) {btw:.0f} = {mid / max(btw, 1):.1f}x; under end bars {end:.0f} / between (n+-30) {btw30:.0f} = {end / max(btw30, 1):.1f}x; centre line {C('pool_e0_n0')}; spawns {C('pool_e-31_n-50')} / {C('pool_e31_n50')}")
    print(f"SUMMARY worst near-black {worst[0]} % ({worst[1]}); spawn faces A {a} / B {b} (ratio {ratio:.2f})")


if __name__ == "__main__":
    main()
