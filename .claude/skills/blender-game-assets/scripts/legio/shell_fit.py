# Gusci aperti (ocrea, humeralia): misura la cavita del modello e la adatta all'arto destro, poi specchia e pelle.
KIND = globals()["KIND"]; SRC = globals()["SRC"]; RIG = globals()["RIG"]; TRIS = globals().get("TRIS", 1500)
GAP = globals().get("GAP", 0.015); EXTRA_W = globals().get("EXTRA_W", 0.03)
arm, parts = rig_and_parts(RIG); rest(arm)
NAME = "pz_" + KIND
for n in (NAME, NAME + "_sx", "pz_tmp"):
    ob = bpy.data.objects.get(n)
    if ob: bpy.data.objects.remove(ob, do_unlink=True)
o = import_clean(TRIPO + SRC, NAME); decimate_to(o, TRIS, tol=60)
base = o.data.copy()
L = [v.co.copy() for v in base.vertices]
lmn = Vector([min(c[i] for c in L) for i in range(3)]); lmx = Vector([max(c[i] for c in L) for i in range(3)]); lc = (lmn + lmx) / 2
bvm = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
zm = lmn.z + 0.5 * (lmx.z - lmn.z)
c = Vector((lc.x, lc.y, zm))
hx1 = bvm.ray_cast(c, Vector((1, 0, 0))); hx2 = bvm.ray_cast(c, Vector((-1, 0, 0))); hy = bvm.ray_cast(c, Vector((0, -1, 0)))
W_in = hx1[3] + hx2[3]; a_in = hy[3]; cx_in = c.x + (hx1[3] - hx2[3]) / 2
side = lambda p: p.x < 0
if KIND == "ocrea":
    knee = bone_w(arm, "RightLeg"); ank = bone_w(arm, "RightFoot")
    top = knee.z + 0.07; bot = ank.z + 0.01
    sz = (top - bot) / (lmx.z - lmn.z)
    mid = ank.lerp(knee, 0.5)
    sec = [p for p in world_verts(parts["Gambe"]) if side(p) and abs(p.z - mid.z) < 0.03]
    w = max(p.x for p in sec) - min(p.x for p in sec); front = min(p.y for p in sec)
    sc = (w + EXTRA_W) / W_in
    # modello: x->x, y->y (davanti -Y), z->z. Il fondo interno (lc.y - a_in) va a front - GAP
    ty = (front - GAP) - (lc.y - a_in) * sc
    Mx = Matrix.Translation((mid.x - cx_in * sc, ty, bot - lmn.z * sz)) @ Matrix.Diagonal((sc, sc, sz, 1))
    src = ["Gambe"]; hide = []
elif KIND == "humeralia":
    sh = bone_w(arm, "RightArm"); el = bone_w(arm, "RightForeArm"); ua = (el - sh).length
    x_in = sh.x + 0.07; x_out = sh.x - 0.75 * ua
    s_len = (x_in - x_out) / (lmx.z - lmn.z)
    mid = sh.lerp(el, 0.45)
    sec = [p for p in world_verts(parts["Braccia"]) if side(p) and abs(p.x - mid.x) < 0.03]
    w = max(p.y for p in sec) - min(p.y for p in sec); topz = max(p.z for p in sec)
    lor = bpy.data.objects.get("pz_lorica")
    if lor:   # sopra gli spallacci della lorica, se arrivano fin qui
        lz = [p.z for p in world_verts(lor) if side(p) and abs(p.x - mid.x) < 0.03 and abs(p.y - mid.y) < 0.05]
        if lz: topz = max(topz, max(lz))
    sc = (w + EXTRA_W) / W_in
    # modello +Z -> +X, x -> -Y, y -> -Z (convesso sopra, cavo sotto)
    R = Matrix(((0, 0, 1), (-1, 0, 0), (0, -1, 0))).to_4x4()
    S = Matrix.Diagonal((sc, sc, s_len, 1))
    # punto del modello (cx_in, lc.y - a_in, lmx.z) -> (x_in, mid.y, topz + GAP)
    q = Vector((cx_in, lc.y - a_in, lmx.z))
    Rq = R @ S @ q.to_4d()
    Mx = Matrix.Translation(Vector((x_in, mid.y, topz + GAP)) - Rq.to_3d()) @ R @ S
    src = ["Braccia", "Busto"]; hide = []
set_data(o, base, Mx)
o2 = o.copy(); o2.data = o.data.copy(); o2.name = NAME + "_sx"; bpy.context.scene.collection.objects.link(o2)
o2.data.transform(Matrix.Scale(-1, 4, (1, 0, 0))); o2.data.flip_normals(); o2.data.update()
activate(o, o2); bpy.ops.object.join()
o = bpy.context.view_layer.objects.active; o.name = NAME; o.data.name = NAME
skin_to(o, [parts[n] for n in src], arm)
o["hide"] = ",".join(hide)
bpy.ops.wm.save_mainfile()
mn, mx = bounds(o)
result = {"kind": KIND, "W_in": round(W_in, 2), "a_in": round(a_in, 2), "limb_w": round(w, 3), "sc": round(sc, 5), "size": [round(mx[i] - mn[i], 3) for i in range(3)]}
