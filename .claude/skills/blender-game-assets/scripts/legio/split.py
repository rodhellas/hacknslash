import bmesh
arm = bpy.data.objects["legionario_m_Rig"]; body = bpy.data.objects["legionario_m"]
arm.animation_data.action = None
limit_weights(body, 4)
me = body.data
# normali uguali prima e dopo il taglio: niente cuciture di luce tra le parti
me.normals_split_custom_set_from_vertices([v.normal.copy() for v in me.vertices])
def part_of(bone):
    b = bone.replace("mixamorig:", "")
    if b.startswith("Head"): return "Testa"
    if any(k in b for k in ("Thumb", "Index", "Middle", "Ring", "Pinky")) or b.endswith("Hand"): return "Mani"
    if b.endswith("ForeArm") or b.endswith("Arm"): return "Braccia"
    if b.endswith("UpLeg") or b.endswith("Leg"): return "Gambe"
    if "Foot" in b or "Toe" in b: return "Piedi"
    return "Busto"
gname = {g.index: g.name for g in body.vertex_groups}
vpart = []
for v in me.vertices:
    best = max(v.groups, key=lambda g: g.weight, default=None)
    vpart.append(part_of(gname[best.group]) if best else "Busto")
from collections import Counter
fpart = [Counter(vpart[i] for i in p.vertices).most_common(1)[0][0] for p in me.polygons]
counts = Counter(fpart)
order = ["Testa", "Mani", "Braccia", "Gambe", "Piedi"]   # il resto resta "Busto"
for name in order:
    activate(body)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    sel = [i for i, p in enumerate(body.data.polygons) if fpart_cur[i] == name] if False else None
    # ricalcola le parti sulla mesh attuale (gli indici cambiano dopo ogni separazione)
    gname = {g.index: g.name for g in body.vertex_groups}
    cur = body.data
    vp = []
    for v in cur.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        vp.append(part_of(gname[best.group]) if best else "Busto")
    for p in cur.polygons:
        p.select = Counter(vp[i] for i in p.vertices).most_common(1)[0][0] == name
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')
    new = [o for o in bpy.context.selected_objects if o != body][0]
    new.name = name; new.data.name = name
body.name = "Busto"; body.data.name = "Busto"
parts = {o.name: tri_count(o.data) for o in arm.children if o.type == 'MESH'}
bpy.ops.wm.save_as_mainfile(filepath=PROJ + "arte/modelli/legionario_m/legionario_m_rig.blend", compress=True)
result = {"faces_per_part": dict(counts), "tris": parts, "mods_ok": all(any(m.type == 'ARMATURE' for m in o.modifiers) for o in arm.children if o.type == 'MESH')}
