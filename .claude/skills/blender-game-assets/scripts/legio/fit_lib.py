# Funzioni per far calzare l'armatura sul corpo con lo scheletro (Blender, davanti = -Y, z in alto)
from mathutils.bvhtree import BVHTree
import bmesh

def rig_and_parts(rig_name):
    arm = bpy.data.objects[rig_name]
    parts = {o.name: o for o in arm.children if o.type == 'MESH' and not o.name.startswith("pz_")}
    return arm, parts

def bone_w(arm, name):
    return arm.matrix_world @ arm.data.bones["mixamorig:" + name].head_local

def world_verts(o):
    mw = o.matrix_world
    return [mw @ v.co for v in o.data.vertices]

def bvh_world(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
    t = BVHTree.FromBMesh(bm); bm.free(); return t

def penetration(piece, pts, axis_fn, margin):
    """Punti del corpo che stanno fuori dal pezzo: raggio dall'asse (dentro il pezzo) verso il punto."""
    bvh = bvh_world(piece); bad = 0
    for p in pts:
        a = axis_fn(p); d = p - a; L = d.length
        if L < 1e-4: continue
        h = bvh.ray_cast(a, d.normalized(), L + margin)
        if h[0] is not None and h[3] < L + margin:
            bad += 1
    return bad

def set_data(o, base, mat):
    o.data.vertices.foreach_set("co", [c for v in base.vertices for c in v.co])
    o.data.transform(mat); o.data.update()

def skin_to(piece, body_parts, arm, bones_filter=None):
    """Pesi copiati dalla pelle più vicina (Data Transfer), poi modificatore Armature."""
    for g in list(piece.vertex_groups): piece.vertex_groups.remove(g)
    src = list(body_parts)
    # unisce temporaneamente le parti del corpo in una copia per il trasferimento
    tmp_me = bpy.data.meshes.new("tmp_src"); bm = bmesh.new()
    names = []
    for o in src:
        for g in o.vertex_groups:
            if g.name not in names: names.append(g.name)
    tmp = bpy.data.objects.new("tmp_src", tmp_me); bpy.context.scene.collection.objects.link(tmp)
    for n in names: tmp.vertex_groups.new(name=n)
    verts = []; faces = []; weights = []
    for o in src:
        mw = o.matrix_world; off = len(verts)
        gmap = {g.index: g.name for g in o.vertex_groups}
        for v in o.data.vertices:
            verts.append(mw @ v.co); weights.append([(gmap[g.group], g.weight) for g in v.groups])
        for p in o.data.polygons:
            faces.append([off + i for i in p.vertices])
    tmp_me.from_pydata(verts, [], faces); tmp_me.update()
    for i, ws in enumerate(weights):
        for n, w in ws:
            tmp.vertex_groups[n].add([i], w, 'REPLACE')
    for n in names:
        if bones_filter is None or bones_filter(n):
            piece.vertex_groups.new(name=n)
    activate(piece)
    m = piece.modifiers.new("DT", 'DATA_TRANSFER'); m.object = tmp
    m.use_vert_data = True; m.data_types_verts = {'VGROUP_WEIGHTS'}
    m.vert_mapping = 'POLYINTERP_NEAREST'
    m.layers_vgroup_select_src = 'ALL'; m.layers_vgroup_select_dst = 'NAME'
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(tmp, do_unlink=True); bpy.data.meshes.remove(tmp_me)
    # pesi: max 4 e normalizzati
    limit_weights(piece, 4)
    # imparenta al rig mantenendo la posizione mondo
    mw = piece.matrix_world.copy()
    piece.parent = arm; piece.matrix_world = mw
    am = piece.modifiers.new("Armature", 'ARMATURE'); am.object = arm

def rest(arm):
    if arm.animation_data:
        arm.animation_data.action = None
        for t in arm.animation_data.nla_tracks: t.mute = True
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

def inside(bvh, p, dirs=((0.577, 0.577, 0.577), (-0.6, 0.5, 0.62), (0.3, -0.8, 0.52))):
    """Punto dentro il volume chiuso: maggioranza dei raggi con numero dispari di intersezioni."""
    votes = 0
    for d in dirs:
        d = Vector(d).normalized(); q = p.copy(); n = 0
        for _ in range(40):
            h = bvh.ray_cast(q, d)
            if h[0] is None: break
            n += 1; q = h[0] + d * 1e-4
        votes += n % 2
    return votes >= 2

def outside_pts(piece, pts, grow=0.0):
    """Punti del corpo NON coperti (fuori dal volume del pezzo). grow: margine verso l'esterno lungo la normale non usato."""
    bvh = bvh_world(piece)
    return [p for p in pts if not inside(bvh, p)]

def flare(o, cx, cy, z_top, z_bot, a):
    """Allarga in x/y la parte sotto z_top, fino a +a al bordo z_bot (svasatura verso i fianchi)."""
    me = o.data
    for v in me.vertices:
        if v.co.z < z_top:
            t = min(1.0, (z_top - v.co.z) / max(1e-6, z_top - z_bot)); f = 1.0 + a * t * t
            v.co.x = cx + (v.co.x - cx) * f; v.co.y = cy + (v.co.y - cy) * f
    me.update()

def side_clean(piece):
    """Pezzo doppio (destra x<0 / sinistra x>0): ogni metà tiene solo i pesi delle ossa del suo lato."""
    mw = piece.matrix_world
    names = {g.index: g.name for g in piece.vertex_groups}
    for v in piece.data.vertices:
        x = (mw @ v.co).x
        bad = "Left" if x < 0 else "Right"
        for g in list(v.groups):
            if bad in names[g.group]:
                piece.vertex_groups[names[g.group]].remove([v.index])
    activate(piece)
    bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return sum(1 for v in piece.data.vertices if not v.groups)

def reskin_side(name, rig, srcs):
    arm, parts = rig_and_parts(rig); rest(arm)
    o = bpy.data.objects[name]
    for m in list(o.modifiers): o.modifiers.remove(m)
    mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    skin_to(o, [parts[n] for n in srcs], arm)
    side_clean(o)
    return fill_orphans(o, {"pz_ocrea": "Leg", "pz_caliga": "Foot", "pz_humeralia": "Arm"}[name])

def fill_orphans(piece, bone_by_side):
    """Vertici senza pesi -> 100% all'osso indicato per il loro lato ({'Right': ..., 'Left': ...})."""
    mw = piece.matrix_world; n = 0
    for v in piece.data.vertices:
        if v.groups: continue
        sd = "Right" if (mw @ v.co).x < 0 else "Left"
        g = piece.vertex_groups.get("mixamorig:" + sd + bone_by_side) or piece.vertex_groups.new(name="mixamorig:" + sd + bone_by_side)
        g.add([v.index], 1.0, 'REPLACE'); n += 1
    return n

def vert_sides(piece):
    """Lato di ogni vertice secondo il centro della sua parte connessa (non la sua x)."""
    me = piece.data; mw = piece.matrix_world
    adj = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices; adj[a].append(b); adj[b].append(a)
    side = [None] * len(me.vertices)
    for s in range(len(me.vertices)):
        if side[s] is not None: continue
        comp = [s]; seen = {s}; i = 0
        while i < len(comp):
            for n in adj[comp[i]]:
                if n not in seen: seen.add(n); comp.append(n)
            i += 1
        cx = sum((mw @ me.vertices[k].co).x for k in comp) / len(comp)
        for k in comp: side[k] = "Right" if cx < 0 else "Left"
    return side

def side_clean(piece):
    sides = vert_sides(piece)
    names = {g.index: g.name for g in piece.vertex_groups}
    for v in piece.data.vertices:
        bad = "Left" if sides[v.index] == "Right" else "Right"
        for g in list(v.groups):
            if bad in names[g.group]:
                piece.vertex_groups[names[g.group]].remove([v.index])
    activate(piece)
    bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    piece["_sides"] = "".join("R" if s == "Right" else "L" for s in sides)
    return sum(1 for v in piece.data.vertices if not v.groups)

def fill_orphans(piece, bone_by_side):
    sides = vert_sides(piece); n = 0
    for v in piece.data.vertices:
        if v.groups: continue
        sd = sides[v.index]
        g = piece.vertex_groups.get("mixamorig:" + sd + bone_by_side) or piece.vertex_groups.new(name="mixamorig:" + sd + bone_by_side)
        g.add([v.index], 1.0, 'REPLACE'); n += 1
    return n
