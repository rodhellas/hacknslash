class_name Fx
extends RefCounted
## Materiali condivisi ed effetti visivi. Gli effetti "veri" (shader, per elemento) sono in core/vfx.gd;
## qui restano le particelle semplici e le funzioni storiche, che ora passano da Vfx.

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
	# Tween legato al nodo: se il nodo sparisce (cambio livello) il callback non parte
	root.create_tween().tween_callback(func() -> void:
		_apply_overlay(root, root.get_meta("_overlay_base") if root.has_meta("_overlay_base") else null)).set_delay(time)


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
	for gi: Variant in meshes(root):
		if is_instance_valid(gi):
			var g := gi as GeometryInstance3D
			# Senza lampo torna la sovrapposizione propria del pezzo (tinta dell'equipaggiamento vero)
			g.material_overlay = m if m != null or not g.has_meta("_own_overlay") else g.get_meta("_own_overlay")


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
	# Numeri grandi (critici, colpi forti): compaiono ingranditi e "battono" sul posto
	if size >= 56:
		l.scale = Vector3.ONE * 1.9
		tw.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", pos + Vector3(randf_range(-0.5, 0.5), 1.4, 0.0), 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## Anello luminoso a terra che si espande (onde d'urto, colpi ad area).
static func ring(parent: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	Vfx.shockwave(parent, pos, radius, color, duration)


## Indicatore a terra di un'area che sta per essere colpita (si riempie fino al colpo).
static func telegraph(parent: Node, pos: Vector3, radius: float, color: Color, time: float) -> void:
	Vfx.telegraph(parent, pos, radius, color, time)


## Colpo che cade dal cielo e arriva a terra dopo `delay` secondi (meteora, bombardamento, saetta).
static func strike(parent: Node, pos: Vector3, delay: float, color: Color, size: float = 0.8, element: String = "fuoco") -> void:
	Vfx.strike(parent, pos, delay, element, size)


## Falce del fendente attorno al personaggio (attacchi in mischia).
static func swing(owner: Node3D, yaw: float, arc_deg: float, reach: float, color: Color, time: float = 0.15) -> void:
	Vfx.slash(owner, yaw, arc_deg, reach, color, time)


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


# --- Particelle (segnaposto: sostituibili con GPUParticles3D/shader veri) ------------------------

static var _shrink_curve: Curve = null
static var _particle_meshes: Dictionary = {}


static func _curve() -> Curve:
	if _shrink_curve == null:
		_shrink_curve = Curve.new()
		_shrink_curve.add_point(Vector2(0.0, 1.0))
		_shrink_curve.add_point(Vector2(1.0, 0.0))
	return _shrink_curve


static func _pmesh(size: float) -> Mesh:
	var key := snappedf(size, 0.01)
	if not _particle_meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * size
		_particle_meshes[key] = bm
	return _particle_meshes[key]


## Esplosione di schegge luminose (colpi, morti, esplosioni). gravity negativa = cadono.
static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 10, speed: float = 5.0,
		size: float = 0.1, life: float = 0.45, gravity: float = -9.0, spread: float = 180.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curve()
	p.mesh = _pmesh(size)
	p.material_override = mat(color, 4.0, false, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Esplosione: lampo, anello, schegge, luce, segno a terra (per elemento, vedi Vfx.explosion).
static func explosion(parent: Node, pos: Vector3, radius: float, color: Color, element: String = "") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	Vfx.explosion(parent, pos, radius, element if element != "" else "fisico", color if element == "" else Color(0, 0, 0, 0))
	burst(parent, pos + Vector3(0, 0.5, 0), color, int(clampf(radius * (3.0 if Settings.reduced_vfx else 6.0), 6, 40)), radius * 3.0, 0.16, 0.5, -6.0)
	burst(parent, pos + Vector3(0, 0.3, 0), Color(0.25, 0.22, 0.2), int(clampf(radius * 3.0, 6, 20)), radius * 1.5, 0.35, 0.8, 1.5)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = radius * 2.5
	parent.add_child(light)
	light.global_position = pos + Vector3(0, 1.5, 0)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)


## Schegge allungate che volano nella direzione del moto (scintille dei colpi fisici, ghiaccio).
static func shards(parent: Node, pos: Vector3, color: Color, amount: int = 8, speed: float = 6.0, life: float = 0.35) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12.0, 0)
	p.particle_flag_align_y = true
	p.scale_amount_curve = _curve()
	if not _particle_meshes.has("shard"):
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.32, 0.04)
		_particle_meshes["shard"] = bm
	p.mesh = _particle_meshes["shard"]
	p.material_override = mat(color, 5.0, false, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Colonna di luce verticale (livello, checkpoint, portale).
static func pillar(parent: Node, pos: Vector3, color: Color, height: float = 10.0, time: float = 1.0) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 1.0
	cm.height = height
	mi.mesh = cm
	var c := color
	c.a = 0.55
	var m := new_mat(c, 4.0, true, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height * 0.5, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.2, 1, 1.2), time * 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_delay(time * 0.2)
	tw.chain().tween_callback(mi.queue_free)
	burst(parent, pos + Vector3(0, 0.3, 0), color, 24, 7.0, 0.12, time, 2.0, 25.0)


## Scia continua che segue un nodo (proiettili). Viene liberata insieme al nodo.
static func trail(owner: Node3D, color: Color, size: float = 0.12) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.25
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.spread = 180.0
	p.scale_amount_curve = _curve()
	p.mesh = _pmesh(size)
	p.material_override = mat(color, 4.0, false, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(p)
	return p


## Fumetto di testo sopra un personaggio (frasi degli NPC).
static func popup_speech(owner: Node3D, text: String, height: float = 3.3, time: float = 3.5) -> void:
	for c in owner.get_children():
		if c.has_meta("_speech"):
			c.queue_free()
	var l := Label3D.new()
	l.set_meta("_speech", true)
	l.text = text
	l.modulate = Color(1, 0.97, 0.88)
	l.font_size = 28
	l.outline_size = 10
	l.pixel_size = 0.01
	l.width = 520.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 4
	l.position.y = height
	owner.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(time)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
