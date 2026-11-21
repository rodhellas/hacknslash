RIG = globals()["RIG"]; OUT = globals()["OUT"]
arm, parts = rig_and_parts(RIG); rest(arm)
pcs = [o for o in bpy.data.objects if o.name.startswith("pz_") and o.type == 'MESH' and o.parent == arm]
show = pcs + [p for n, p in parts.items() if n != "Piedi"]   # i piedi li nasconde il calzare
sc = bpy.context.scene; workbench(sc); cam = wb_cam(sc)
def pose(name, frame):
    a = bpy.data.actions[name]; arm.animation_data.action = a
    try: arm.animation_data.action_slot = a.slots[0]
    except Exception: pass
    sc.frame_set(frame); bpy.context.view_layer.update()
files = []
for i, (n, f, cl) in enumerate([("idle", 60, (2.6, -4.2, 1.9)), ("run", 6, (2.6, -4.2, 1.9)), ("run", 12, (-3, 3.5, 1.9)),
                                 ("attack", 26, (2.6, -4.2, 1.9)), ("cast", 16, (-3, -3.5, 1.9)), ("death", 118, (2.6, -4.2, 2.5))]):
    pose(n, f)
    files += render_shots({f"{i}{n}": show}, {"p": dict(loc=cl, target=Vector((0, 0, 0.9)), ortho=2.4)}, "SCRATCH/pa_", engine='BLENDER_WORKBENCH', res=(420, 420), cam=cam)
make_sheet(files, "SCRATCH/" + OUT, 3)
rest(arm)
result = {"pieces": [p.name for p in pcs]}
