class_name Appearance
extends RefCounted
## Equipaggiamento visibile: mette nelle prese del modello (Presa_Testa, Presa_ManoDx...) i pezzi
## degli oggetti indossati, presi da VisualDB.VISUALS. Si richiama a ogni cambio di equipaggiamento:
## toglie tutti i pezzi vecchi e mette quelli nuovi.
## Funziona con qualsiasi modello che abbia le prese: eroi (Player) e, in futuro, nemici umani.

const META := "equip_slot"


## Aggiorna i pezzi sul modello. equipment: slot -> Item (come HeroData.equipment).
## transmog: slot -> id della base da mostrare al posto di quella vera; dyes: slot -> tinta (VisualDB.DYES).
static func apply(model: Node3D, equipment: Dictionary, transmog: Dictionary = {}, dyes: Dictionary = {}) -> void:
	if model == null:
		return
	clear(model)
	if model.has_meta("_fx_meshes"):
		model.remove_meta("_fx_meshes")   # cache delle mesh di Fx.flash
	var hidden: Array = []
	for slot: String in VisualDB.VISIBLE_SLOTS:
		var it: Item = equipment.get(slot)
		if it == null:
			continue
		var vis := VisualDB.get_visual(String(transmog.get(slot, it.base_id)))
		if vis.is_empty():
			continue
		hidden.append_array(vis.get("hide", []))
		if vis.has("scene"):
			_add_scene(model, slot, vis)
		else:
			for p: Array in vis.get("parts", []):
				var part := p
				# Doppia arma: l'arma in "secondaria" va nella mano sinistra
				if slot == "secondaria" and it.slot == "arma":
					part = p.duplicate()
					part[0] = String(p[0]).replace("Dx", "Sx")
				_add_part(model, slot, part, it.rarity, String(dyes.get(slot, "")))
	# Parti del corpo coperte dall'equipaggiamento (es. capelli sotto l'elmo)
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n.has_meta("body_part"):
			(n as Node3D).visible = not hidden.has(String(n.name))


## Toglie tutti i pezzi dell'equipaggiamento dal modello.
static func clear(model: Node3D) -> void:
	for n: Node in pieces(model):
		n.get_parent().remove_child(n)
		n.queue_free()


## Pezzi attualmente sul modello (tutti, o solo quelli di uno slot).
static func pieces(model: Node3D, slot: String = "") -> Array:
	var out: Array = []
	for name: String in VisualDB.PRESE:
		var s := model.find_child(name, true, false)
		if s == null:
			continue
		for c: Node in s.get_children():
			if c.has_meta(META) and (slot == "" or String(c.get_meta(META)) == slot):
				out.append(c)
	return out


static func _socket(model: Node3D, name: String) -> Node3D:
	return model.find_child(name, true, false) as Node3D


static func _add_part(model: Node3D, slot: String, p: Array, rarity: int, dye: String = "") -> void:
	var s := _socket(model, String(p[0]))
	if s == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(String(p[1]), p[3])
	mi.position = p[2]
	if p.size() > 5:
		mi.rotation_degrees = p[5]
	var mat_id := String(p[4])
	if mat_id == "energia":
		# Guscio di energia attorno al metallo (colore della rarità per leggendari e set)
		var ec: Color = VisualDB.MATERIALS["energia"]
		if rarity >= Item.Rarity.LEGGENDARIO:
			ec = Item.RARITY_COLORS[rarity]
		Vfx.make_energy(mi, ec)
		mi.name = "Equip_%s_%d" % [slot, s.get_child_count()]
		mi.set_meta(META, slot)
		s.add_child(mi)
		return
	var col: Color = VisualDB.MATERIALS.get(mat_id, Color.MAGENTA)
	var glow: float = VisualDB.GLOW.get(mat_id, 0.0)
	if dye != "" and glow <= 0.0:
		col = VisualDB.MATERIALS.get(dye, col)
	if rarity >= Item.Rarity.LEGGENDARIO:
		# Leggendari e set: tinta del colore di rarità e un leggero bagliore
		var rc: Color = Item.RARITY_COLORS[rarity]
		col = rc if glow > 0.0 else col.lerp(rc, 0.3)
		glow = maxf(glow, 0.5)
	mi.material_override = Fx.mat(col, glow)
	if glow > 1.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Equip_%s_%d" % [slot, s.get_child_count()]
	mi.set_meta(META, slot)
	s.add_child(mi)


static func _add_scene(model: Node3D, slot: String, vis: Dictionary) -> void:
	var ps := load(String(vis["scene"])) as PackedScene
	if ps == null:
		return
	for key: String in ["socket", "mirror"]:
		if not vis.has(key):
			continue
		var s := _socket(model, String(vis[key]))
		if s == null:
			continue
		var n := ps.instantiate() as Node3D
		if key == "mirror":
			n.scale.x = -1.0
		n.name = "Equip_%s_%s" % [slot, key]
		n.set_meta(META, slot)
		s.add_child(n)


static func _mesh(kind: String, size: Vector3) -> Mesh:
	match kind:
		"box":
			var b := BoxMesh.new()
			b.size = size
			return b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = size.x
			c.height = size.y
			c.bottom_radius = size.z
			c.radial_segments = 12
			c.rings = 1
			return c
		"capsule":
			var k := CapsuleMesh.new()
			k.radius = size.x
			k.height = size.y
			k.radial_segments = 12
			k.rings = 4
			return k
		_:
			var sp := SphereMesh.new()
			sp.radius = size.x
			sp.height = size.y
			sp.radial_segments = 14
			sp.rings = 7
			return sp
