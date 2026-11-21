arm = bpy.data.objects["legionario_m_Rig"]; parts = [o for o in arm.children if o.type == 'MESH']
for o in list(bpy.context.scene.objects):
    if o.name.startswith("WbCam"): bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data.action = None
for t in arm.animation_data.nla_tracks: t.mute = False
for o in parts: o.color = (1, 1, 1, 1)
size = export_glb(PROJ + "modelli/corpi/legionario_m.glb", [arm] + parts, export_skins=True, export_animations=True,
                  export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_image_format='JPEG')
for t in arm.animation_data.nla_tracks: t.mute = True
bpy.ops.wm.save_mainfile()
result = {"kb": size // 1024}
