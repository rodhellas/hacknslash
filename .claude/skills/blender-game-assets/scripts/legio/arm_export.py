RIG = globals()["RIG"]; SEX = globals()["SEX"]
arm, parts = rig_and_parts(RIG); rest(arm)
for ob in list(bpy.context.scene.objects):
    if ob.name.startswith("WbCam"): bpy.data.objects.remove(ob, do_unlink=True)
MAP = {"pz_lorica": "lorica", "pz_ocrea": "ocreae", "pz_caliga": "caligae", "pz_humeralia": "humeralia"}
out = {}
for src, base in MAP.items():
    o = bpy.data.objects.get(src)
    if o is None: continue
    if not o.data.materials[0].name.startswith(base):
        game_mat(o, base + "_" + SEX, tex=1024, rough=0.55)
    o.data.name = base
    path = PROJ + "modelli/equipaggiamento/%s_%s.glb" % (base, SEX)
    nm = o.name; o.name = base
    size = export_glb(path, [arm, o], export_skins=True, export_animations=False, export_image_format='JPEG')
    o.name = nm
    out[base] = {"kb": size // 1024, "tris": tri_count(o.data), "hide": o.get("hide", "")}
bpy.ops.wm.save_mainfile()
result = out
