RIG = globals().get("RIG", "legionario_m_Rig"); BASE = globals().get("BASE", "pz_base"); NAME = globals().get("NAME", "pz_lorica")
arm, parts = rig_and_parts(RIG); rest(arm)
o = bpy.data.objects[NAME]; base = bpy.data.meshes[BASE]
neck = bone_w(arm, "Neck"); hips = bone_w(arm, "Hips")
bp = parts["Busto"]; mw = bp.matrix_world
busto = [(mw @ v.co, (mw.to_3x3() @ v.normal).normalized()) for v in bp.data.vertices]
pos = [p for p, n in busto]
b_sh = max(p.z for p in pos if 0.10 <= abs(p.x) <= 0.14)
z_ch = neck.z - 0.32
ch = [p for p in pos if abs(p.z - z_ch) < 0.03 and abs(p.x) < 0.25]
b_w = max(p.x for p in ch) - min(p.x for p in ch); b_d = max(p.y for p in ch) - min(p.y for p in ch); b_cy = (max(p.y for p in ch) + min(p.y for p in ch)) / 2
L = [v.co.copy() for v in base.vertices]
lmn = Vector([min(c[i] for c in L) for i in range(3)]); lmx = Vector([max(c[i] for c in L) for i in range(3)])
lcx = (lmn.x + lmx.x) / 2; lw_all = lmx.x - lmn.x
l_sh = max(c.z for c in L if 0.11 * lw_all <= abs(c.x - lcx) <= 0.155 * lw_all)
bot = hips.z + globals().get("BOTO", -0.09)
sz = (b_sh + globals().get("SHO", 0.035) - bot) / (l_sh - lmn.z)
lz_ch = lmn.z + (z_ch - bot) / sz
lch = [c for c in L if abs(c.z - lz_ch) < 0.03 / sz]
l_w = max(c.x for c in lch) - min(c.x for c in lch); l_d = max(c.y for c in lch) - min(c.y for c in lch); l_cy = (max(c.y for c in lch) + min(c.y for c in lch)) / 2
sx0 = (b_w + 0.03) / l_w; sy0 = (b_d + 0.03) / l_d
# punti da coprire: busto tra vita e spalle, spinti fuori di 6 mm lungo la normale; escluso il collo (|x|<0.09 sopra il petto)
need = [p + n * 0.006 for p, n in busto if bot + 0.03 < p.z < b_sh - 0.02 and not (abs(p.x) < 0.09 and p.z > neck.z - 0.06)]
log = []; k = globals().get("K0", 1.04); best = None; FL = globals().get("FLARE", 0.0); ZF = globals().get("ZF", 0.25)
for _ in range(8):
    M = Matrix.Translation((0, b_cy, bot)) @ Matrix.Diagonal((sx0 * k, sy0 * k, sz, 1)) @ Matrix.Translation((-lcx, -l_cy, -lmn.z))
    set_data(o, base, M)
    if FL: flare(o, 0, b_cy, bot + ZF, bot, FL)
    out = outside_pts(o, need)
    log.append((round(k, 3), len(out)))
    if len(out) <= len(need) * 0.004: break
    k *= 1.02
import collections
zs = collections.Counter(round(p.z, 2) for p in out)
xs = collections.Counter(round(p.x, 1) for p in out)
mn, mx = bounds(o)
result = {"need": len(need), "log": log, "out_z": dict(sorted(zs.items())[-8:]), "out_x": dict(xs), "size": [round(mx[i] - mn[i], 3) for i in range(3)], "top": round(mx.z, 3)}
# tieni il k migliore
bestk = min(log, key=lambda t: t[1])[0]
M = Matrix.Translation((0, b_cy, bot)) @ Matrix.Diagonal((sx0 * bestk, sy0 * bestk, sz, 1)) @ Matrix.Translation((-lcx, -l_cy, -lmn.z))
set_data(o, base, M)
if FL: flare(o, 0, b_cy, bot + ZF, bot, FL)
result["bestk"] = bestk
sc = bpy.context.scene; workbench(sc); cam = wb_cam(sc)
c = Vector((0, 0, 1.3))
shots = {"fronte": dict(loc=(0, -4, 1.3), target=c, ortho=1.2), "lato": dict(loc=(4, 0, 1.3), target=c, ortho=1.2),
         "retro": dict(loc=(0, 4, 1.3), target=c, ortho=1.2), "iso": dict(loc=(2.5, -2.5, 3.0), target=c, ortho=1.4)}
f = render_shots({"lor": [o] + list(parts.values())}, shots, "SCRATCH/lor_", engine='BLENDER_WORKBENCH', res=(400, 400), cam=cam)
make_sheet(f, "SCRATCH/sheet_lorica_f.png", 4)
