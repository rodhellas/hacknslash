M = PROJ + "arte/modelli/legionario_m/mixamo/"
objs = import_model(M + "legionario_m_skin.fbx")
res = {"objects": []}
for o in objs:
    d = {"name": o.name, "type": o.type, "parent": o.parent.name if o.parent else None,
         "loc": [round(c, 3) for c in o.location], "rot": [round(c, 3) for c in o.rotation_euler], "scale": [round(c, 4) for c in o.scale]}
    if o.type == 'MESH':
        d["tris"] = tri_count(o.data); d["vgroups"] = len(o.vertex_groups)
        d["mods"] = [(m.type, getattr(m, "object", None) and m.object.name) for m in o.modifiers]
        d["mats"] = [s.material.name for s in o.material_slots if s.material]
        mn, mx = world_bounds(o); d["wbounds"] = [[round(c, 3) for c in mn], [round(c, 3) for c in mx]]
    if o.type == 'ARMATURE':
        d["bones"] = len(o.data.bones)
        hb = o.data.bones["mixamorig:Head"]; d["head_world"] = [round(c, 3) for c in (o.matrix_world @ hb.head_local)]
        d["names_sample"] = [b.name for b in o.data.bones][:8]
    res["objects"].append(d)
res["actions"] = [(a.name, [int(x) for x in a.frame_range]) for a in bpy.data.actions]
res["images"] = [(i.name, list(i.size), i.packed_file is not None) for i in bpy.data.images if i.size[0]]
result = res
