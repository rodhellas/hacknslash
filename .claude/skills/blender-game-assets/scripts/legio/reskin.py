RIG = globals()["RIG"]
r = {}
for name, srcs in (("pz_ocrea", ["Gambe"]), ("pz_caliga", ["Piedi", "Gambe"]), ("pz_humeralia", ["Braccia", "Busto"])):
    if name in bpy.data.objects: r[name] = reskin_side(name, RIG, srcs)
bpy.ops.wm.save_mainfile()
result = {"senza_pesi": r}
