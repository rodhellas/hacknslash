@tool
class_name MapRoad
extends Path3D
## STRADA della Forma del livello: una curva (trascina i punti nell'editor, come ogni Path3D;
## con Ctrl+clic aggiungi punti, le maniglie la curvano). Rende calpestabile la fascia attorno
## alla curva e, se paved_width > 0, disegna il lastricato.
## Anteprima nell'editor: fascia trasparente = area calpestabile, fascia piena = lastricato.

## Mezza larghezza calpestabile (m) attorno alla curva.
@export var half_width := 20.0:
	set(v):
		half_width = v
		_queue_preview()
## Mezza larghezza per ogni punto della curva (facoltativo, sovrascrive half_width punto per punto).
@export var widths: PackedFloat32Array = PackedFloat32Array():
	set(v):
		widths = v
		_queue_preview()
## Zona del terreno lungo la strada ("" = decidono aree, poligoni o la strada principale).
@export var zone := ""
## Solo per la strada principale: zone lungo il percorso, es. ["0=fattoria", "0.17=bosco"] (frazione 0-1).
@export var zone_breaks: PackedStringArray = PackedStringArray()
## Larghezza del lastricato (0 = niente lastricato, solo area calpestabile).
@export var paved_width := 6.0:
	set(v):
		paved_width = v
		_queue_preview()
@export var paved_color := Color(0.6, 0.57, 0.52)
## Cordoli ai lati del lastricato.
@export var curbs := false
## Passa sopra l'acqua (ponti, guadi, moli).
@export var over_water := false
## Lampioni lungo la strada ogni N metri (0 = nessuno), a lati alterni.
@export var lamp_spacing := 0.0
@export var lamp_prop := "lampione_plasma"
## Ogni quanti lampioni mettere una pietra miliare sul lato opposto (0 = mai).
@export var milestone_every := 0

var _preview: MeshInstance3D
var _pending := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	if curve == null:
		curve = Curve3D.new()
	curve.bake_interval = 2.0
	if not curve.changed.is_connected(_queue_preview):
		curve.changed.connect(_queue_preview)
	_queue_preview()


## Punti della curva in coordinate del livello (x, z) e mezze larghezze corrispondenti.
## xf = trasformazione della strada rispetto alla radice del livello.
func sample(xf: Transform3D, step: float = 2.0) -> Array:
	var pts := PackedVector2Array()
	var ws := PackedFloat32Array()
	if curve == null or curve.point_count < 2:
		return [pts, ws]
	curve.bake_interval = step
	var baked := curve.get_baked_points()
	var length := curve.get_baked_length()
	var ctrl_off: Array = []
	for i in curve.point_count:
		ctrl_off.append(curve.get_closest_offset(curve.get_point_position(i)))
	var acc := 0.0
	for j in baked.size():
		if j > 0:
			acc += baked[j].distance_to(baked[j - 1])
		var w3 := xf * baked[j]
		pts.append(Vector2(w3.x, w3.z))
		ws.append(_width_at(minf(acc, length), ctrl_off))
	return [pts, ws]


func _width_at(off: float, ctrl_off: Array) -> float:
	if widths.size() < 2 or ctrl_off.size() < 2:
		return half_width
	for i in ctrl_off.size() - 1:
		var a := float(ctrl_off[i])
		var b := float(ctrl_off[i + 1])
		if off <= b or i == ctrl_off.size() - 2:
			var t := clampf((off - a) / maxf(b - a, 0.001), 0.0, 1.0)
			var wa := widths[i] if i < widths.size() else half_width
			var wb := widths[i + 1] if i + 1 < widths.size() else half_width
			return lerpf(wa, wb, t)
	return half_width


## Zona alla frazione t (0-1) del percorso, secondo zone_breaks.
func zone_at(t: float) -> String:
	var best := ""
	var best_t := -1.0
	for s in zone_breaks:
		var parts := s.split("=")
		if parts.size() != 2:
			continue
		var bt := float(parts[0])
		if bt <= t + 0.0001 and bt > best_t:
			best_t = bt
			best = parts[1].strip_edges()
	return best


# --- Anteprima nell'editor --------------------------------------------------------------------------

func _queue_preview() -> void:
	if not Engine.is_editor_hint() or _pending or not is_inside_tree():
		return
	_pending = true
	_rebuild_preview.call_deferred()


func _rebuild_preview() -> void:
	_pending = false
	if _preview == null or not is_instance_valid(_preview):
		_preview = MeshInstance3D.new()
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_preview)   # senza owner: non viene salvato
	var s := sample(Transform3D.IDENTITY, 2.0)
	var pts: PackedVector2Array = s[0]
	var ws: PackedFloat32Array = s[1]
	if pts.size() < 2:
		_preview.mesh = null
		return
	var am := ArrayMesh.new()
	var walk := Color(1.0, 0.85, 0.3, 0.18) if not over_water else Color(0.3, 0.7, 1.0, 0.3)
	_ribbon(am, pts, ws, 0.0, 0.25, walk)
	if paved_width > 0.0:
		var pw := PackedFloat32Array()
		pw.resize(pts.size())
		pw.fill(paved_width * 0.5)
		_ribbon(am, pts, pw, 0.0, 0.3, Color(paved_color, 0.85))
	_preview.mesh = am


## Aggiunge ad am una fascia lungo pts (mezza larghezza ws[i] per punto) all'altezza y.
## Usata per l'anteprima e, da tools/map_builder.gd, per il lastricato vero.
static func add_ribbon(am: ArrayMesh, pts: PackedVector2Array, ws: PackedFloat32Array, y: float, mat: Material) -> void:
	if pts.size() < 2:
		return
	var normals: Array = []
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var d := (b - a).normalized()
		normals.append(Vector2(-d.y, d.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(1, pts.size()):
		var pa := pts[i - 1]
		var pb := pts[i]
		var na: Vector2 = normals[i - 1] * ws[i - 1]
		var nb: Vector2 = normals[i] * ws[i]
		var v1 := Vector3(pa.x + na.x, y, pa.y + na.y)
		var v2 := Vector3(pa.x - na.x, y, pa.y - na.y)
		var v3 := Vector3(pb.x + nb.x, y, pb.y + nb.y)
		var v4 := Vector3(pb.x - nb.x, y, pb.y - nb.y)
		for v: Vector3 in [v1, v3, v2, v2, v3, v4]:
			st.add_vertex(v)
	st.set_material(mat)
	st.commit(am)


static func _ribbon(am: ArrayMesh, pts: PackedVector2Array, ws: PackedFloat32Array, _inner: float, y: float, col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	add_ribbon(am, pts, ws, y, m)
