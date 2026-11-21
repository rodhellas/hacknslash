import os
M = PROJ + "arte/modelli/legionario_m/mixamo/"
P = "Sword And Shield "
# nome nel gioco -> (file, togli lo spostamento orizzontale, ciclo)
CLIPS = {
 "idle": (P + "Idle", False, True), "idle_2": (P + "Idle (1)", False, True), "idle_3": (P + "Idle (2)", False, True), "idle_4": (P + "Idle (3)", False, True),
 "run": (P + "Run", True, True), "walk": (P + "Walk", True, True),
 "attack": (P + "Slash (1)", True, False), "attack_2": (P + "Slash (3)", True, False), "attack_3": (P + "Attack (2)", True, False),
 "attack_4": (P + "Kick", True, False), "attack_5": (P + "Slash", True, False), "attack_6": (P + "Slash (2)", True, False),
 "attack_7": (P + "Attack", True, False), "attack_8": (P + "Attack (1)", True, False), "attack_9": (P + "Attack (3)", True, False),
 "cast": (P + "Casting", True, False), "cast_2": (P + "Casting (1)", True, False), "cast_3": (P + "Power Up", True, False),
 "hit": (P + "Impact", True, False), "hit_2": (P + "Impact (1)", True, False), "hit_3": (P + "Impact (2)", True, False), "hit_4": ("Reaction", True, False),
 "death": (P + "Death", False, False), "death_2": (P + "Death (1)", False, False), "death_3": ("Dying", False, False),
 "block": (P + "Block", True, False), "block_2": (P + "Block (1)", True, False), "dodge": ("Standing Dodge Backward", True, False),
}

def channelbag(action):
    from bpy_extras import anim_utils
    return anim_utils.action_get_channelbag_for_slot(action, action.slots[0])

arm = bpy.data.objects["Armature"]
arm.name = "legionario_m_Rig"; arm.data.name = "legionario_m_Rig"
# via la posa a T importata
if arm.animation_data:
    old = arm.animation_data.action
    arm.animation_data.action = None
    if old: bpy.data.actions.remove(old)
else:
    arm.animation_data_create()
for t in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(t)
hips = arm.data.bones["mixamorig:Hips"]
W = arm.matrix_world.to_3x3() @ hips.matrix_local.to_3x3()
vert = max(range(3), key=lambda i: abs(W[2][i]))
log = {}
for name, (fn, strip, loop) in CLIPS.items():
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=M + fn + ".fbx")
    new_objs = [o for o in bpy.data.objects if o not in before]
    acts = [a for a in bpy.data.actions if a not in acts_before]
    a = acts[0]
    a.name = name
    a.use_fake_user = True
    moved = 0.0
    if strip:
        cb = channelbag(a)
        hor = [fc for fc in cb.fcurves if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index != vert]
        net = max(abs(fc.keyframe_points[-1].co.y - fc.keyframe_points[0].co.y) for fc in hor)
        if net > 0.3:
            for fc in hor:
                v0 = fc.keyframe_points[0].co.y
                for k in fc.keyframe_points:
                    moved = max(moved, abs(k.co.y - v0))
                    k.co.y = v0; k.handle_left.y = v0; k.handle_right.y = v0
                fc.update()
    for o in new_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    for extra in acts[1:]:
        bpy.data.actions.remove(extra)
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, int(a.frame_range[0]), a)
    try:
        st.action_slot = a.slots[0]
    except Exception as e:
        pass
    tr.mute = True
    log[name] = [int(a.frame_range[0]), int(a.frame_range[1]), round(moved, 1)]
for m in list(bpy.data.armatures):
    if m.users == 0: bpy.data.armatures.remove(m)
bpy.ops.wm.save_as_mainfile(filepath=PROJ + "arte/modelli/legionario_m/legionario_m_rig.blend", compress=True)
result = {"vertical_channel": vert, "clips": log, "tracks": len(arm.animation_data.nla_tracks)}
