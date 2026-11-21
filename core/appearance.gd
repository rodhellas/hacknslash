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
		var dye := String(dyes.get(slot, ""))
		var dual := slot == "secondaria" and it.slot == "arma"
		if vis.has("skinned") and _add_skinned(model, slot, vis, it.rarity, dye):
			pass
		elif vis.has("scene") and _add_scene(model, slot, vis, it.rarity, dye, dual):
			pass
		else:
			for p: Array in vis.get("parts", []):
				var part := p
				# Doppia arma: l'arma in "secondaria" va nella mano sinistra
				if slot == "secondaria" and it.slot == "arma":
					part = p.duplicate()
					part[0] = String(p[0]).replace("Dx", "Sx")
				_add_part(model, slot, part, it.rarity, dye)
	# Parti del corpo coperte dall'equipaggiamento (es. capelli sotto l'elmo)
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n.has_meta("body_part") or (n is MeshInstance3D and VisualDB.BODY_PARTS.has(String(n.name)) and not n.has_meta(META)):
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
	# Pezzi con pelle (armature vere): figli dello scheletro del corpo
	var sk := _skeleton(model)
	if sk != null:
		for c: Node in sk.get_children():
			if c.has_meta(META) and (slot == "" or String(c.get_meta(META)) == slot):
				out.append(c)
	return out


static func _skeleton(model: Node3D) -> Skeleton3D:
	var list := model.find_children("*", "Skeleton3D", true, false)
	return list[0] as Skeleton3D if not list.is_empty() else null


## Pezzo con pelle (lorica, schinieri...): GLB con lo stesso scheletro del corpo, uno per corpo
## ("skinned": {"m": ..., "f": ...}, corpo dal metadato "corpo" della scena). La sua mesh passa sotto lo
## scheletro del corpo e si piega con lui. Falso se il corpo è graybox o il file manca.
static func _add_skinned(model: Node3D, slot: String, vis: Dictionary, rarity: int, dye: String) -> bool:
	if not model.has_meta("corpo"):
		return false
	var path := String((vis["skinned"] as Dictionary).get(String(model.get_meta("corpo")), ""))
	if path == "" or not ResourceLoader.exists(path):
		return false
	var sk := _skeleton(model)
	var ps := load(path) as PackedScene
	if sk == null or ps == null:
		return false
	var inst := ps.instantiate()
	var overlay := _tint_overlay(rarity, dye)
	var n := 0
	for node: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null:
			continue
		mi.get_parent().remove_child(mi)
		mi.owner = null
		sk.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.skeleton = NodePath("..")
		mi.name = "Equip_%s_%d" % [slot, n]
		mi.set_meta(META, slot)
		if overlay != null:
			mi.material_overlay = overlay
			mi.set_meta("_own_overlay", overlay)
		n += 1
	inst.free()
	return n > 0


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


## Pezzo vero (modello .glb/.tscn). Falso se il file non c'è (allora si usano i pezzi graybox).
## dual: arma tenuta nella mano sinistra (doppia arma), presa Dx -> Sx.
static func _add_scene(model: Node3D, slot: String, vis: Dictionary, rarity: int, dye: String, dual: bool) -> bool:
	var path := String(vis["scene"])
	if not ResourceLoader.exists(path):
		return false
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var energy: PackedScene = null
	if vis.has("energy") and ResourceLoader.exists(String(vis["energy"])):
		energy = load(String(vis["energy"])) as PackedScene
	var overlay := _tint_overlay(rarity, dye)
	for key: String in ["socket", "mirror"]:
		if not vis.has(key):
			continue
		var sock := String(vis[key])
		if dual:
			sock = sock.replace("Dx", "Sx")
		var s := _socket(model, sock)
		if s == null:
			continue
		var n := ps.instantiate() as Node3D
		if sock == "Presa_Testa":
			n.scale = Vector3.ONE * _graybox_head_scale(model)
		if key == "mirror":
			n.scale.x = -n.scale.x
		if overlay != null:
			for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = overlay
				mi.set_meta("_own_overlay", overlay)   # Fx.flash la rimette dopo il lampo
		if energy != null:
			# Guscio di energia attorno alla lama (colore della rarità per leggendari e set)
			var ec: Color = VisualDB.MATERIALS["energia"]
			if rarity >= Item.Rarity.LEGGENDARIO:
				ec = Item.RARITY_COLORS[rarity]
			var en := energy.instantiate() as Node3D
			en.name = "Energia"
			for mi: Node in en.find_children("*", "MeshInstance3D", true, false):
				Vfx.make_energy(mi as MeshInstance3D, ec)
			n.add_child(en)
		n.name = "Equip_%s_%s" % [slot, key]
		n.set_meta(META, slot)
		s.add_child(n)
	return true


## Gli elmi veri sono fatti sulla testa del corpo vero (larga VisualDB.HEAD_WIDTH). Finché il corpo
## è graybox (testa = sfera più grossa) si ingrandiscono per contenerla; col corpo vero la scala è 1.
static func _graybox_head_scale(model: Node3D) -> float:
	var head := model.get_node_or_null("Graybox/Testa") as MeshInstance3D
	if head == null or not head.mesh is SphereMesh:
		return 1.0
	var w: float = (head.mesh as SphereMesh).radius * 2.0 * head.scale.x
	return maxf(1.0, (w + 0.01) / VisualDB.HEAD_WIDTH)


## Tinta di un pezzo vero (che ha già la sua texture): moltiplica per il colore della tinta scelta
## nella scheda Aspetto e aggiunge un leggero bagliore del colore di rarità per leggendari e set.
static func _tint_overlay(rarity: int, dye: String) -> Material:
	var mul: StandardMaterial3D = null
	if dye != "" and VisualDB.MATERIALS.has(dye):
		mul = StandardMaterial3D.new()
		mul.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mul.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		mul.albedo_color = Color.WHITE.lerp(VisualDB.MATERIALS[dye], 0.65)
	var add: StandardMaterial3D = null
	if rarity >= Item.Rarity.LEGGENDARIO:
		add = StandardMaterial3D.new()
		add.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		add.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		add.albedo_color = (Item.RARITY_COLORS[rarity] as Color) * 0.18
	if mul != null and add != null:
		mul.next_pass = add
		return mul
	return mul if mul != null else add


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
