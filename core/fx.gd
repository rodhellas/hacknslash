class_name Fx
extends RefCounted
## Materiali condivisi ed effetti visivi segnaposto (da sostituire con particelle/shader veri).

static var _mats: Dictionary = {}
static var _overlays: Dictionary = {}


## Materiale condiviso (in cache): usalo per tutto ciò che non cambia a runtime.
static func mat(color: Color, emission: float = 0.0, transparent: bool = false, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%s" % [color.to_html(), emission, transparent, unshaded]
	if not _mats.has(key):
		_mats[key] = new_mat(color, emission, transparent, unshaded)
	return _mats[key]


## Materiale nuovo (non condiviso): per effetti che ne animano i parametri.
static func new_mat(color: Color, emission: float = 0.0, transparent: bool = false, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	if transparent or color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Tutte le geometrie sotto un nodo (in cache sul nodo stesso).
static func meshes(root: Node) -> Array:
	if root.has_meta("_fx_meshes"):
		return root.get_meta("_fx_meshes")
	var list: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		list.append(root)
	root.set_meta("_fx_meshes", list)
	return list


## Sovrapposizione di colore persistente (es. nemico che carica un colpo). null = rimuovi.
static func set_base_overlay(root: Node, color: Variant) -> void:
	root.set_meta("_overlay_base", color)
	_apply_overlay(root, color)


## Lampo di colore breve (colpo subito).
static func flash(root: Node, color: Color, time: float = 0.08) -> void:
	if root == null or not root.is_inside_tree():
		return
	_apply_overlay(root, color)
	root.get_tree().create_timer(time).timeout.connect(func() -> void:
		if is_instance_valid(root):
			_apply_overlay(root, root.get_meta("_overlay_base") if root.has_meta("_overlay_base") else null))


static func _apply_overlay(root: Node, color: Variant) -> void:
	var m: Material = null
	if color != null:
		var c: Color = color
		var key := c.to_html()
		if not _overlays.has(key):
			var om := StandardMaterial3D.new()
			om.albedo_color = c
			om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_overlays[key] = om
		m = _overlays[key]
	for gi: GeometryInstance3D in meshes(root):
		if is_instance_valid(gi):
			gi.material_overlay = m


## Testo che sale e svanisce (numeri di danno, "LIVELLO SU!", ecc.).
static func popup_text(parent: Node, pos: Vector3, text: String, color: Color, size: int = 44) -> void:
	if parent == null:
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(randf_range(-0.5, 0.5), 1.4, 0.0), 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## Anello luminoso a terra che si espande (onde d'urto, colpi ad area).
static func ring(parent: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.04
	cyl.radial_segments = 32
	mi.mesh = cyl
	var c := color
	c.a = 0.7
	var m := new_mat(c, 3.0, true, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.06, pos.z)
	mi.scale = Vector3(0.1, 1, 0.1)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


## Indicatore a terra di un'area che sta per essere colpita.
static func telegraph(parent: Node, pos: Vector3, radius: float, color: Color, time: float) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.03
	cyl.radial_segments = 40
	mi.mesh = cyl
	var c := color
	c.a = 0.0
	var m := new_mat(c, 1.5, true, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.05, pos.z)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.35, min(0.25, time))
	tw.tween_interval(max(time - 0.25, 0.0))
	tw.tween_callback(mi.queue_free)


## Sfera che cade dal cielo e arriva a terra dopo `delay` secondi (meteora, bombardamento).
static func strike(parent: Node, pos: Vector3, delay: float, color: Color, size: float = 0.8) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	mi.mesh = sm
	mi.material_override = mat(color, 6.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(-4, 22, 4)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", pos, max(delay, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Lama che ruota attorno al personaggio (attacchi in mischia).
static func swing(owner: Node3D, yaw: float, arc_deg: float, reach: float, color: Color, time: float = 0.15) -> void:
	var pivot := Node3D.new()
	owner.add_child(pivot)
	pivot.position = Vector3(0, 1.0, 0)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.05, reach)
	blade.mesh = bm
	blade.material_override = mat(color, 5.0)
	blade.position.z = -reach * 0.55
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(blade)
	var half := deg_to_rad(arc_deg) / 2.0
	pivot.rotation.y = yaw + half
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation:y", yaw - half, time)
	tw.tween_callback(pivot.queue_free)


## Icona piatta visibile solo nella minimappa.
static func minimap_icon(parent: Node3D, color: Color, radius: float, shape: String = "dot") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if shape == "arrow":
		var pm := PrismMesh.new()
		pm.size = Vector3(radius * 1.6, radius * 2.2, 0.2)
		mi.mesh = pm
		mi.rotation_degrees = Vector3(-90, 0, 0)
	elif shape == "square":
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 2, 0.2, radius * 2)
		mi.mesh = bm
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = 0.2
		cm.radial_segments = 12
		mi.mesh = cm
	mi.material_override = mat(color, 0.0, false, true)
	mi.layers = Layers.VIS_MINIMAP
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 30.0
	parent.add_child(mi)
	return mi
