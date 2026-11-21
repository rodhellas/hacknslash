import math
arm = bpy.data.objects["legionario_m_Rig"]; parts = [o for o in arm.children if o.type == 'MESH']
arm.animation_data.action = None
for t in arm.animation_data.nla_tracks: t.mute = True
bpy.context.scene.frame_set(1)
activate(arm)
bpy.ops.object.mode_set(mode='POSE')
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
bpy.context.view_layer.update()
MW = arm.matrix_world; MWi = MW.inverted()
def rot_about(pb, angle, pivot_world):
    R = Matrix.Translation(pivot_world) @ Matrix.Rotation(angle, 4, 'Y') @ Matrix.Translation(-pivot_world)
    pb.matrix = MWi @ R @ MW @ pb.matrix
    bpy.context.view_layer.update()
res = {}
for side, sign in (("Left", 1), ("Right", -1)):
    up = arm.pose.bones["mixamorig:" + side + "UpLeg"]; ft = arm.pose.bones["mixamorig:" + side + "Foot"]
    hip = MW @ up.head; ank = MW @ ft.head
    ang = math.atan2(abs(ank.x) - abs(hip.x), hip.z - ank.z)
    rot_about(up, sign * ang, hip)
    ank2 = MW @ ft.head
    rot_about(ft, -sign * ang, ank2)
    res[side] = {"gradi": round(math.degrees(ang), 2), "caviglia_x": round((MW @ ft.head).x, 3)}
bpy.ops.object.mode_set(mode='OBJECT')
# la nuova posa entra nella mesh, poi diventa la posa di riposo
for o in parts:
    activate(o)
    mname = [m.name for m in o.modifiers if m.type == 'ARMATURE'][0]
    bpy.ops.object.modifier_apply(modifier=mname)
    m = o.modifiers.new("Armature", 'ARMATURE'); m.object = arm
activate(arm)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
for t in arm.animation_data.nla_tracks: t.mute = True
mn = min((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
res["piedi_z_min"] = round(mn, 4)
bpy.ops.wm.save_mainfile()
result = res
