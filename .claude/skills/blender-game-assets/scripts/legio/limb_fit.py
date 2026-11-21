# Adatta un pezzo di braccio/gamba sul lato destro (x<0), lo specchia a sinistra, unisce, copia i pesi.
KIND = globals()["KIND"]; SRC = globals()["SRC"]; RIG = globals()["RIG"]; TAG = globals().get("TAG", "")
TRIS = globals().get("TRIS", 1500)
arm, parts = rig_and_parts(RIG); rest(arm)
NAME = "pz_" + KIND
for n in (NAME, NAME + "_sx", "pz_tmp"):
    ob = bpy.data.objects.get(n)
    if ob: bpy.data.objects.remove(ob, do_unlink=True)
o = import_clean(TRIPO + SRC, NAME); decimate_to(o, TRIS, tol=60)
base = o.data.copy()
L = [v.co.copy() for v in base.vertices]
lmn = Vector([min(c[i] for c in L) for i in range(3)]); lmx = Vector([max(c[i] for c in L) for i in range(3)])
lc = (lmn + lmx) / 2
side = lambda p: p.x < 0
def wv(name): return [p for p in world_verts(parts[name]) if side(p)]
info = {}
if KIND == "ocrea":
    knee = bone_w(arm, "RightLeg"); ank = bone_w(arm, "RightFoot")
    top = knee.z + 0.07; bot = ank.z + 0.01
    sz = (top - bot) / (lmx.z - lmn.z)
    def axis(p):
        t = (p.z - ank.z) / (knee.z - ank.z); return ank.lerp(knee, max(0, min(1, t))) * 1.0 + Vector((0, 0, 0))
    gam = wv("Gambe")
    pts = [p for p in gam if bot + 0.03 < p.z < knee.z + 0.03 and p.y < axis(p).y + 0.005]
    mid = ank.lerp(knee, 0.5)
    sec = [p for p in gam if abs(p.z - mid.z) < 0.03]
    b_w = max(p.x for p in sec) - min(p.x for p in sec)
    lsec = [c for c in L if abs((c.z - lmn.z) * sz + bot - mid.z) < 0.03]
    l_w = max(c.x for c in lsec) - min(c.x for c in lsec)
    s0 = (b_w + 0.02) / l_w
    def M(k, d):
        # centro x del pezzo sull'asse della gamba; in y la parte davanti del pezzo davanti alla tibia (d = spostamento)
        return Matrix.Translation((mid.x, mid.y + d, bot)) @ Matrix.Diagonal((s0 * k, s0 * k, sz, 1)) @ Matrix.Translation((-lc.x, -lc.y, -lmn.z))
    ds = [-0.04, -0.03, -0.02, -0.01, 0.0, 0.01, 0.02]
    TIGHT_DIR = (0, -1, 0); TIGHT_P = mid.copy()
    hide = []
elif KIND == "caliga":
    pie = wv("Piedi"); gam = wv("Gambe")
    ank = bone_w(arm, "RightFoot")
    f_len = max(p.y for p in pie) - min(p.y for p in pie); f_w = max(p.x for p in pie) - min(p.x for p in pie)
    f_cx = (max(p.x for p in pie) + min(p.x for p in pie)) / 2; f_cy = (max(p.y for p in pie) + min(p.y for p in pie)) / 2
    s_len = f_len * 1.10 / (lmx.y - lmn.y)
    s_w = max(s_len, f_w * 1.12 / (lmx.x - lmn.x))
    h = (lmx.z - lmn.z) * s_len
    def axis(p): return Vector((ank.x, ank.y, p.z))
    pts = [p for p in gam if p.z < h - 0.03]
    shaft = [c for c in L if c.z > lmn.z + 0.6 * (lmx.z - lmn.z)]
    scx = sum(c.x for c in shaft) / len(shaft); scy = sum(c.y for c in shaft) / len(shaft)
    def M(k, d):
        return Matrix.Translation((ank.x, ank.y + d, 0.0)) @ Matrix.Diagonal((s_w * k, s_len * k, s_len, 1)) @ Matrix.Translation((-scx, -scy, -lmn.z))
    ds = [-0.02, -0.01, 0.0, 0.01, 0.02]
    KMAX = 1.3
    hide = ["Piedi"]
    info["foot"] = [round(f_len, 3), round(f_w, 3)]
elif KIND == "humeralia":
    sh = bone_w(arm, "RightArm"); el = bone_w(arm, "RightForeArm")
    ua = (el - sh).length
    x_in = sh.x + 0.07; x_out = sh.x - 0.75 * ua
    # modello: +Z (calotta) -> +X (verso il corpo), convesso -Y -> +Z (sopra), cavo +Y -> -Z
    R = Matrix(((0, 0, 1), (-1, 0, 0), (0, -1, 0))).to_4x4()
    s_len = (x_in - x_out) / (lmx.z - lmn.z)
    def axis(p):
        t = (p.x - sh.x) / (el.x - sh.x); return sh.lerp(el, max(0, min(1, t)))
    bra = wv("Braccia")
    pts = [p for p in bra if x_out + 0.02 < p.x < sh.x - 0.03 and p.z > axis(p).z - 0.01]
    mid = sh.lerp(el, 0.4)
    def M(k, d):
        return Matrix.Translation((x_in, mid.y, mid.z + d)) @ R @ Matrix.Diagonal((s_len * k, s_len * k, s_len, 1)) @ Matrix.Translation((-lc.x, -lc.y, -lmx.z))
    ds = [0.0, 0.01, 0.02, 0.03, 0.04, 0.05]
    TIGHT_DIR = (0, 0, 1); TIGHT_P = mid.copy()
    KMAX = 1.5
    hide = []
KMAX = globals().get("KMAX", 3.0) if "KMAX" not in dir() else KMAX
if globals().get("NO_TIGHT"): TIGHT_DIR = None; globals()["TIGHT_DIR"] = None
TIGHT = globals().get("TIGHT_DIR")
best = None
if TIGHT is not None:
    # aderenza: per ogni k, sposta il pezzo (d) perché la superficie interna stia a GAP dalla pelle nella direzione TIGHT
    tdir = Vector(TIGHT)
    pc = TIGHT_P
    skin_gap = max((p - pc).dot(tdir) for p in pts if (p - pc - tdir * (p - pc).dot(tdir)).length < 0.03)
    k = 0.7
    for _ in range(40):
        if k > KMAX: break
        set_data(o, base, M(k, 0.0))
        h = bvh_world(o).ray_cast(pc, tdir)
        if h[0] is not None:
            d = (h[3] - (skin_gap + 0.015))
            dvec = -tdir * d
            set_data(o, base, Matrix.Translation(dvec) @ M(k, 0.0))
            bad = penetration(o, pts, axis, 0.004)
            if best is None or (bad, k) < (best[2], best[0]): best = (k, d, bad)
            if bad <= max(2, len(pts) * 0.01): break
        k *= 1.03
    k, d, bad = best
    set_data(o, base, Matrix.Translation(-tdir * d) @ M(k, 0.0))
else:
  for d in ds:
    k = 0.85
    for _ in range(30):
        if k > KMAX: break
        set_data(o, base, M(k, d))
        bad = penetration(o, pts, axis, 0.004)
        if bad <= max(2, len(pts) * 0.01): break
        k *= 1.03
    if best is None or (bad, k) < (best[2], best[0]): best = (k, d, bad)
  k, d, bad = best
set_data(o, base, M(k, d))
# specchio a sinistra
o2 = o.copy(); o2.data = o.data.copy(); o2.name = NAME + "_sx"; bpy.context.scene.collection.objects.link(o2)
o2.data.transform(Matrix.Scale(-1, 4, (1, 0, 0))); o2.data.flip_normals(); o2.data.update()
activate(o, o2); bpy.ops.object.join()
o = bpy.context.view_layer.objects.active; o.name = NAME; o.data.name = NAME
src = {"ocrea": ["Gambe"], "caliga": ["Piedi", "Gambe"], "humeralia": ["Braccia", "Busto"]}[KIND]
skin_to(o, [parts[n] for n in src], arm)
mn, mx = bounds(o)
o["hide"] = ",".join(hide)
bpy.ops.wm.save_mainfile()
result = dict(info, kind=KIND, k=round(k, 3), d=d, bad=bad, pts=len(pts), tris=tri_count(o.data), size=[round(mx[i] - mn[i], 3) for i in range(3)])
