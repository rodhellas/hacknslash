"""Funzioni per sistemare i GLB di Tripo (Legio 3000). Da accodare a bpy_lib.py (stesso job).

Tripo: modello normalizzato a ~100 unità di altezza, Z in alto, vertici spezzati lungo le cuciture UV
(centinaia di "parti"), solo texture del colore (2048), materiale HASHED. Vedi docs/MODELLI_TRIPO.md.
"""
import numpy as np
def make_sheet(paths, out, cols):
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p, check_existing=False)
        w, h = im.size
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        imgs.append(a); bpy.data.images.remove(im)
    h, w = imgs[0].shape[:2]
    rows = (len(imgs) + cols - 1) // cols
    big = np.ones((rows * h, cols * w, 4), dtype=np.float32)
    for i, a in enumerate(imgs):
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * h
        big[y0:y0 + h, c * w:(c + 1) * w] = a
    im = bpy.data.images.new("sheet_tmp", cols * w, rows * h, alpha=True)
    im.pixels[:] = big.ravel()
    im.filepath_raw = out; im.file_format = 'PNG'; im.save()
    bpy.data.images.remove(im)

def shots_ortho(o, size=None):
    mn, mx = world_bounds(o)
    c = (mn + mx) / 2; d = mx - mn; s = size or max(d) * 1.1; r = max(d) * 3
    return {
        "fronte": dict(loc=(c.x, c.y - r, c.z), target=c, ortho=s),
        "destra": dict(loc=(c.x + r, c.y, c.z), target=c, ortho=s),
        "retro": dict(loc=(c.x, c.y + r, c.z), target=c, ortho=s),
        "sopra": dict(loc=(c.x, c.y, c.z + r), target=c, ortho=s),
        "iso": dict(loc=(c.x - r * 0.6, c.y - r * 0.6, c.z + r * 0.6), target=c, ortho=s),
        "iso_retro": dict(loc=(c.x + r * 0.6, c.y + r * 0.6, c.z + r * 0.4), target=c, ortho=s),
    }

def workbench(sc):
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'TEXTURE'
    sc.render.film_transparent = False

def wb_cam(sc):
    cam = sc.objects.get("WbCam_" + sc.name)
    if not cam:
        cam = bpy.data.objects.new("WbCam_" + sc.name, bpy.data.cameras.new("WbCam_" + sc.name))
        sc.collection.objects.link(cam)
    cam.data.clip_end = 100000
    sc.camera = cam
    return cam

import bmesh
from mathutils import Matrix, Vector
PROJ = "C:/Users/Budo/Documents/GodotProjects/hacknslash/"
TRIPO = PROJ + "arte/tripo/"

def import_clean(path, name):
    """Import Tripo GLB, drop the empty, apply transforms, weld UV-seam splits."""
    objs = import_model(path)
    mesh = [o for o in objs if o.type == 'MESH'][0]
    mw = mesh.matrix_world.copy()
    mesh.parent = None
    mesh.matrix_world = mw
    for o in objs:
        if o.type == 'EMPTY':
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    activate(mesh)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.name = name; mesh.data.name = name
    weld(mesh)
    return mesh

def weld(o, dist=None):
    bm = bmesh.new(); bm.from_mesh(o.data)
    d = dist or max(o.dimensions) * 1e-5
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=d)
    bm.to_mesh(o.data); bm.free()

def loose_groups(o):
    """[(set(poly indices), centroid)] for each connected part."""
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    seen = set(); out = []
    for f in bm.faces:
        if f.index in seen: continue
        grp = {f.index}; stack = [f]; seen.add(f.index)
        while stack:
            x = stack.pop()
            for e in x.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); grp.add(g.index); stack.append(g)
        c = sum((bm.faces[i].calc_center_median() for i in grp), Vector()) / len(grp)
        out.append((grp, c))
    bm.free()
    return out

def delete_polys(o, keep):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(o.data); bm.free()

def xform(o, mat):
    o.data.transform(mat); o.data.update()

def bounds(o):
    xs = [v.co for v in o.data.vertices]
    return Vector([min(c[i] for c in xs) for i in range(3)]), Vector([max(c[i] for c in xs) for i in range(3)])

def game_mat(o, name, tex=1024, rough=0.75, metal=0.0):
    """Opaque material, base colour only (Tripo), texture scaled down and packed."""
    m = o.data.materials[0]
    m.name = name
    try:
        m.surface_render_method = 'DITHERED'
    except Exception:
        pass
    m.blend_method = 'OPAQUE' if hasattr(m, "blend_method") else None
    m.use_backface_culling = True
    bs = [n for n in m.node_tree.nodes if n.bl_idname == 'ShaderNodeBsdfPrincipled'][0]
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Alpha'].default_value = 1.0
    for l in list(m.node_tree.links):
        if l.to_socket == bs.inputs['Alpha']:
            m.node_tree.links.remove(l)
    img = [n for n in m.node_tree.nodes if n.bl_idname == 'ShaderNodeTexImage'][0].image
    img.name = name + "_albedo"
    if tex and img.size[0] > tex:
        img.scale(tex, tex)
    img.pack()
    return m

def wb_scene_shots(o, out_prefix, views=("fronte", "destra", "retro", "sopra", "iso", "iso_retro")):
    sc = bpy.context.scene
    workbench(sc)
    cam = wb_cam(sc)
    sh = shots_ortho(o)
    files = render_shots({o.name: [o]}, {k: sh[k] for k in views}, out_prefix, engine='BLENDER_WORKBENCH', res=(500, 500), cam=cam)
    return files
