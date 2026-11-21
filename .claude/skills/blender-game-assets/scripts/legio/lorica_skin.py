RIG = globals().get("RIG", "legionario_m_Rig"); NAME = globals().get("NAME", "pz_lorica")
arm, parts = rig_and_parts(RIG); rest(arm)
o = bpy.data.objects[NAME]
skin_to(o, [parts["Busto"], parts["Braccia"]], arm)
nz = sum(1 for v in o.data.vertices if len(v.groups) == 0)
sc = bpy.context.scene; workbench(sc); cam = wb_cam(sc)
def pose(name, frame):
    a = bpy.data.actions[name]; arm.animation_data.action = a
    try: arm.animation_data.action_slot = a.slots[0]
    except Exception: pass
    sc.frame_set(frame); bpy.context.view_layer.update()
files = []
for i, (n, f, cam_loc) in enumerate([("idle", 60, (2.6, -4.2, 1.9)), ("run", 6, (2.6, -4.2, 1.9)), ("attack", 26, (2.6, -4.2, 1.9)),
                                       ("cast", 16, (2.6, -4.2, 1.9)), ("attack", 26, (-3, 3.5, 1.9)), ("hit", 8, (-3, 3.5, 1.9))]):
    pose(n, f)
    files += render_shots({f"{i}{n}": [o] + list(parts.values())}, {"p": dict(loc=cam_loc, target=Vector((0, 0, 1.1)), ortho=2.3)}, "SCRATCH/lsk_", engine='BLENDER_WORKBENCH', res=(400, 400), cam=cam)
make_sheet(files, "SCRATCH/sheet_lorica_pose.png", 3)
rest(arm)
bpy.ops.wm.save_mainfile()
result = {"verts_without_weights": nz, "groups": len(o.vertex_groups), "tris": tri_count(o.data)}
