@tool
class_name MapPolygon
extends Path3D
## POLIGONO della Forma del livello: i punti della curva (Path3D) sono i vertici, il poligono si
## chiude da solo. Trascina i punti nell'editor; Ctrl+clic per aggiungerne.
##   mode "terra"  → area calpestabile (piazze, isole, la città)
##   mode "acqua"  → acqua: non calpestabile, disegnata in blu (fiumi, mare). Strade e aree con
##                   over_water = true ci passano sopra (ponti, guadi, moli)
##   mode "vuoto"  → toglie la calpestabilità (dirupi, edifici enormi) senza disegnare acqua

@export_enum("terra", "acqua", "vuoto") var mode := "terra":
	set(v):
		mode = v
		_queue_preview()
## Zona del terreno dentro il poligono ("" = invariata). Vedi data/map_zones.gd.
@export var zone := ""
@export var scatter := true
@export var over_water := false

var _preview: MeshInstance3D
var _pending := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	if curve == null:
		curve = Curve3D.new()
	if not curve.changed.is_connected(_queue_preview):
		curve.changed.connect(_queue_preview)
	_queue_preview()


## Vertici in coordinate del livello (x, z). xf = trasformazione rispetto alla radice del livello.
func polygon(xf: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	if curve == null:
		return out
	var pts := curve.get_baked_points() if _has_handles() else _control_points()
	for p in pts:
		var w := xf * p
		out.append(Vector2(w.x, w.z))
	return out


func _control_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in curve.point_count:
		out.append(curve.get_point_position(i))
	return out


func _has_handles() -> bool:
	for i in curve.point_count:
		if curve.get_point_in(i) != Vector3.ZERO or curve.get_point_out(i) != Vector3.ZERO:
			return true
	return false


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
	var poly := polygon(Transform3D.IDENTITY)
	if poly.size() < 3:
		_preview.mesh = null
		return
	var col := {"terra": Color(0.4, 1.0, 0.4, 0.15), "acqua": Color(0.2, 0.5, 1.0, 0.3), "vuoto": Color(0.1, 0.1, 0.1, 0.35)}[mode] as Color
	_preview.mesh = polygon_mesh(poly, 0.2, MapPolygon.flat_mat(col, true))


## Mesh piatta di un poligono (usata anche dal costruttore per l'acqua).
static func polygon_mesh(poly: PackedVector2Array, y: float, mat: Material) -> ArrayMesh:
	var idx := Geometry2D.triangulate_polygon(poly)
	var am := ArrayMesh.new()
	if idx.is_empty():
		return am
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in idx.size():
		var p := poly[idx[k]]
		st.add_vertex(Vector3(p.x, y, p.y))
	st.set_material(mat)
	st.commit(am)
	return am


static func flat_mat(col: Color, overlay: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if overlay:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
	return m
