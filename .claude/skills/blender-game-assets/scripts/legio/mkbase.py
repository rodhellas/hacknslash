# crea la mesh di base (ripulita e ridotta) e l'oggetto di lavoro
SRC = globals()["SRC"]; BASE = globals()["BASE"]; NAME = globals()["NAME"]; TRIS = globals().get("TRIS", 3000)
for n in (NAME, "pz_tmp"):
    ob = bpy.data.objects.get(n)
    if ob: bpy.data.objects.remove(ob, do_unlink=True)
if BASE in bpy.data.meshes: bpy.data.meshes.remove(bpy.data.meshes[BASE])
t = import_clean(TRIPO + SRC, "pz_tmp"); decimate_to(t, TRIS, tol=100)
b = t.data.copy(); b.name = BASE; b.use_fake_user = True
t.name = NAME; t.data.name = NAME
result = {"tris": tri_count(t.data), "mat": t.data.materials[0].name if t.data.materials else None}
