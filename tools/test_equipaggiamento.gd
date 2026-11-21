extends SceneTree
## TEST AUTOMATICO dell'equipaggiamento visibile (fase 1, grayboxing): corpi maschili e femminili
## per ogni classe con tutte le prese, un aspetto per ogni base indossabile, pezzi che compaiono e
## spariscono, capelli nascosti dall'elmo, sesso salvato e usato in gioco.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_equipaggiamento.gd
## Non salva niente (partita di prova, slot -1).

var game: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	checks += 1
	print(("  OK       " if cond else "  FALLITO  ") + what)
	if not cond:
		fails += 1


func _wait_level(id: String, max_frames: int = 900) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			for k in 3:
				await process_frame
			return true
	return false


## Prese che contengono almeno un pezzo dello slot.
func _sockets_of(model: Node3D, App: GDScript, slot: String) -> Array:
	var out: Array = []
	for n: Node in App.pieces(model, slot):
		if not out.has(String(n.get_parent().name)):
			out.append(String(n.get_parent().name))
	return out


func _run() -> void:
	game = root.get_node("Game")
	var App: GDScript = load("res://core/appearance.gd")
	var VDB: GDScript = load("res://data/visual_db.gd")
	var IDB: GDScript = load("res://data/item_db.gd")
	var HC: GDScript = load("res://data/hero_classes.gd")
	var HD: GDScript = load("res://core/hero_data.gd")

	print("\n== 1. Corpi e prese")
	var bodies_ok := true
	for cid: String in HC.ORDER:
		var cls: Dictionary = HC.get_data(cid)
		for key: String in ["model", "model_f"]:
			var ps := load(String(cls.get(key, ""))) as PackedScene
			if ps == null:
				bodies_ok = false
				print("    manca %s di %s" % [key, cid])
				continue
			var m: Node3D = ps.instantiate()
			for pr: String in VDB.PRESE:
				if m.find_child(pr, true, false) == null:
					bodies_ok = false
					print("    %s %s: manca %s" % [cid, key, pr])
			m.free()
	_check(bodies_ok, "4 classi × 2 corpi, ognuno con le %d prese" % VDB.PRESE.size())

	print("\n== 2. Aspetto di ogni base")
	var vis_ok := true
	for base: String in IDB.BASES:
		var slot := String(IDB.BASES[base]["slot"])
		if not VDB.VISIBLE_SLOTS.has(slot):
			continue
		var v: Dictionary = VDB.get_visual(base)
		if v.is_empty() or (not v.has("scene") and (v.get("parts", []) as Array).is_empty()):
			vis_ok = false
			print("    %s senza aspetto" % base)
			continue
		for p: Array in v.get("parts", []):
			if not VDB.PRESE.has(String(p[0])) or not VDB.MATERIALS.has(String(p[4])):
				vis_ok = false
				print("    %s: presa o materiale sconosciuto %s" % [base, p])
	_check(vis_ok, "ogni arma, scudo e armatura ha il suo aspetto (prese e materiali validi)")

	print("\n== 3. Pezzi sul modello")
	var model: Node3D = (load("res://scenes/characters/legionario.tscn") as PackedScene).instantiate()
	root.add_child(model)
	var eq := {}
	for b: String in ["gladio_plasma", "scutum", "lorica", "ocreae", "caligae", "manicae", "bulla"]:
		var it: Variant = IDB.make_basic(b, 1)
		eq[it.slot] = it
	App.apply(model, eq)
	_check(_sockets_of(model, App, "arma") == ["Presa_ManoDx"], "il gladio è nella mano destra")
	_check(_sockets_of(model, App, "secondaria") == ["Presa_AvambraccioSx"], "lo scutum è sull'avambraccio sinistro")
	var legs := _sockets_of(model, App, "gambali")
	_check(legs.has("Presa_StincoDx") and legs.has("Presa_StincoSx"), "le ocreae su tutti e due gli stinchi")
	_check(_sockets_of(model, App, "calzari").size() == 2 and _sockets_of(model, App, "guanti").size() == 2, "calzari e manicae doppi")
	_check(App.pieces(model, "amuleto").is_empty(), "l'amuleto non si vede")
	var n_before: int = App.pieces(model).size()
	App.apply(model, eq)
	_check(App.pieces(model).size() == n_before, "riapplicare non duplica i pezzi (%d)" % n_before)
	var hair: Node3D = model.find_child("Capelli", true, false)
	_check(hair != null and hair.visible, "senza elmo i capelli si vedono")
	eq["elmo"] = IDB.make_basic("galea", 1)
	App.apply(model, eq)
	_check(not hair.visible and _sockets_of(model, App, "elmo") == ["Presa_Testa"], "con la galea: elmo in testa, capelli nascosti")
	var real := true
	for s: String in ["arma", "secondaria", "elmo"]:
		var ps: Array = App.pieces(model, s)
		if ps.size() != 1 or ps[0] is MeshInstance3D or (ps[0] as Node).find_children("*", "MeshInstance3D", true, false).is_empty():
			real = false
	var helm_scale: float = (App.pieces(model, "elmo")[0] as Node3D).scale.x
	_check(real and helm_scale > 1.2, "gladio, scutum e galea usano i modelli veri (elmo ingrandito sulla testa graybox: ×%.2f)" % helm_scale)
	# Armature con pelle sui corpi veri (maschio e femmina): sotto lo scheletro del corpo, piedi nascosti dai calzari
	for body: String in ["res://scenes/characters/legionario_vero.tscn", "res://scenes/characters/corpo_f_vero.tscn"]:
		var vm: Node3D = (load(body) as PackedScene).instantiate()
		root.add_child(vm)
		var ve := {}
		for b: String in ["lorica", "ocreae", "caligae", "humeralia"]:
			var vi: Variant = IDB.make_basic(b, 1)
			ve[vi.slot] = vi
		App.apply(vm, ve)
		var sk: Skeleton3D = vm.find_children("*", "Skeleton3D", true, false)[0]
		var skinned := 0
		for c: Node in sk.get_children():
			if c.has_meta(App.META) and c is MeshInstance3D and (c as MeshInstance3D).skin != null:
				skinned += 1
		var feet: Node3D = vm.find_child("Piedi", true, false)
		var hidden_ok := feet != null and not feet.visible
		App.apply(vm, {})
		_check(skinned == 4 and hidden_ok and App.pieces(vm).is_empty() and feet.visible,
			"%s: 4 pezzi di armatura con pelle sullo scheletro, piedi nascosti dai calzari, tolti e rimessi" % body.get_file())
		vm.queue_free()
	eq.erase("elmo")
	eq.erase("arma")
	App.apply(model, eq)
	_check(hair.visible and App.pieces(model, "arma").is_empty() and App.pieces(model, "elmo").is_empty(),
		"togliendo arma ed elmo i pezzi spariscono e i capelli tornano")
	var common: Variant = IDB.make_basic("lorica", 1)
	var leg: Variant = IDB.make_basic("lorica", 1)
	leg.rarity = 3
	App.apply(model, {"armatura": common})
	var c_col: Color = (App.pieces(model, "armatura")[0] as MeshInstance3D).material_override.albedo_color
	App.apply(model, {"armatura": leg})
	var l_mat: StandardMaterial3D = (App.pieces(model, "armatura")[0] as MeshInstance3D).material_override
	_check(l_mat.albedo_color != c_col and l_mat.emission_enabled, "un leggendario ha la tinta del suo colore e brilla")
	model.queue_free()

	print("\n== 4. Sesso dell'eroe")
	var hf: Variant = HD.create("Collaudatrice", "sagittario", "f")
	_check(hf.model_path() == "res://scenes/characters/sagittario_f.tscn", "eroina: corpo femminile")
	var back: Variant = HD.from_dict(JSON.parse_string(JSON.stringify(hf.to_dict())))
	_check(back.sex == "f", "il sesso resta dopo salvataggio e caricamento")
	var old_save: Dictionary = hf.to_dict()
	old_save.erase("sex")
	_check(HD.from_dict(old_save).sex == "m", "i vecchi salvataggi (senza sesso) caricano un eroe maschio")

	print("\n== 5. In gioco")
	hf.level = 5
	game.hero = hf
	game.current_slot = -1
	game.travel("ostia_nova")
	_check(await _wait_level("ostia_nova"), "Ostia Nova caricata")
	var p: Variant = game.level.player
	_check(String(p.model.scene_file_path) == "res://scenes/characters/sagittario_f.tscn", "la sagittaria usa il corpo femminile")
	_check(_sockets_of(p.model, App, "arma") == ["Presa_ManoSx"] and _sockets_of(p.model, App, "secondaria") == ["Presa_Schiena"],
		"equipaggiamento iniziale addosso: arco in mano sinistra, faretra sulla schiena")
	var boots: Variant = IDB.make_basic("caligae", 1)
	hf.add_item(boots)
	var idx: int = hf.inventory.find(boots)
	hf.equip_from_inventory(idx)
	p.refresh_stats()
	_check(App.pieces(p.model, "calzari").size() == 2, "indossando le caligae compaiono ai piedi")
	hf.unequip("calzari")
	p.refresh_stats()
	_check(App.pieces(p.model, "calzari").is_empty(), "togliendole spariscono")

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
