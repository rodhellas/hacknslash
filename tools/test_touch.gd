extends SceneTree
## TEST AUTOMATICO dei controlli touch (ui/touch_controls.gd): pulsanti dentro lo schermo e senza
## sovrapposizioni, joystick che muove l'eroe, attacco tenuto premuto, abilità a mira automatica e a mano
## (anello a terra), pulsanti dei menu, tocco sul joystick che non diventa un clic, scala dell'interfaccia,
## opzione "Mai", tasto indietro di Android.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_touch.gd
## Non salva la partita (slot -1).

var game: Node
var fails := 0
var checks := 0
var touch: Variant


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	checks += 1
	print(("  OK       " if cond else "  FALLITO  ") + what)
	if not cond:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_level(id: String, max_frames: int = 900) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			return true
	return false


## Coordinate dei pulsanti -> coordinate della finestra (come arrivano da Android).
func _screen(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _touch(index: int, p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _screen(p)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _screen(p)
	Input.parse_input_event(ev)


func _button(id: String) -> Dictionary:
	for b: Dictionary in touch.buttons:
		if b["id"] == id:
			return b
	return {}


func _tap(id: String, index: int = 0) -> void:
	var c: Vector2 = _button(id)["center"]
	_touch(index, c, true)
	await _frames(2)
	_touch(index, c, false)
	await _frames(2)


func _run() -> void:
	game = root.get_node("Game")
	root.size = Vector2i(1600, 900)   # in headless la finestra è minuscola
	var HD: GDScript = load("res://core/hero_data.gd")
	var Sett: GDScript = load("res://core/settings.gd")
	var old_touch: int = Sett.touch_controls
	_check(Sett.touch_build() or not Sett.touch_enabled(), "sul PC i controlli touch non ci sono (anche con l'opzione Sempre)")
	Sett.touch_controls = 1
	_check(Sett.touch_build() or not Sett.touch_enabled(), "sul PC l'opzione Sempre non li accende")
	Sett.force_touch = true   # nel test li accendiamo come sulla versione Android

	var hero: Variant = HD.create("Collaudatore", "legionario", "m")
	hero.level = 30
	game.hero = hero
	game.current_slot = -1

	print("\n== 1. Pulsanti a video")
	game.travel("level_01")
	_check(await _wait_level("level_01"), "livello 1 caricato")
	await _frames(3)
	var lvl: Variant = game.level
	var p: Variant = lvl.player
	touch = lvl.touch
	_check(touch != null and touch.visible, "controlli touch visibili con l'opzione Sempre")
	var size: Vector2 = touch.root.size
	var inside := true
	var overlap := false
	var shown: Array = []
	for b: Dictionary in touch.buttons:
		if not b["show"]:
			continue
		shown.append(b)
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		if c.x - r < 0 or c.y - r < 0 or c.x + r > size.x or c.y + r > size.y:
			inside = false
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Dictionary = shown[i]
			var b: Dictionary = shown[j]
			if Vector2(a["center"]).distance_to(b["center"]) < float(a["radius"]) + float(b["radius"]):
				overlap = true
	_check(shown.size() == 13, "13 pulsanti: attacco, pozione, 5 abilità, 6 menu (%d)" % shown.size())
	_check(inside, "tutti dentro lo schermo")
	_check(not overlap, "nessun pulsante sovrapposto")
	var atk: Vector2 = _button("lmb")["center"]
	_check(atk.x > size.x * 0.8 and atk.y > size.y * 0.75, "attacco in basso a destra")
	# Sul touch la barra delle abilità dell'HUD si nasconde; i globi (con la cornice che sporge di ~15 px) restano
	var on_bar := false
	for gl: Control in [lvl.hud.life_globe, lvl.hud.res_globe]:
		var gr: Rect2 = gl.get_global_rect().grow(16)
		for b: Dictionary in shown:
			var r: float = b["radius"]
			if b["kind"] != "menu" and gr.grow(r).has_point(b["center"]):
				on_bar = true
	_check(not on_bar and not lvl.hud.skill_row.visible, "nessun pulsante sopra i globi dell'HUD; barra delle abilità nascosta sul touch")
	_check(lvl.hud.quest_tracker.offset_left > 60.0, "l'elenco delle missioni si sposta a destra della colonna dei menu")

	print("\n== 1b. Icone (textures/icone)")
	var IC: GDScript = load("res://core/icons.gd")
	var HC: GDScript = load("res://data/hero_classes.gd")
	var SKD: GDScript = load("res://data/skill_db.gd")
	var missing: Array = []
	for cid: String in HC.DATA:
		for ab: Dictionary in HC.DATA[cid]["abilities"]:
			if IC.ability(ab["id"]) == null:
				missing.append(ab["id"])
		for pd: Dictionary in SKD.passives(cid):
			if IC.passive(pd["id"]) == null:
				missing.append(pd["id"])
	for k: String in SKD.EXTRA:
		for ab: Dictionary in SKD.EXTRA[k]:
			if IC.ability(ab["id"]) == null:
				missing.append(ab["id"])
	_check(missing.is_empty() and IC.potion() != null, "ogni abilità e passiva ha la sua icona, e la pozione %s" % str(missing))
	var bar_ok := lvl.hud.potion_slot.icon != null
	for sl: Variant in lvl.hud.slots.values():
		if sl.icon == null:
			bar_ok = false
	_check(bar_ok, "la barra delle abilità mostra le icone (e la pozione)")
	lvl.skills_ui.toggle()
	await _frames(2)
	var with_icon := 0
	for b: Node in lvl.skills_ui.find_children("*", "Button", true, false):
		if (b as Button).icon != null:
			with_icon += 1
	_check(with_icon >= 8, "la finestra Abilità mostra le icone sui pulsanti (%d)" % with_icon)
	lvl.skills_ui.close_panel()
	await _frames(2)

	print("\n== 2. Joystick")
	var start: Vector3 = p.global_position
	var sp := Vector2(size.x * 0.15, size.y - 140.0)
	_touch(0, sp, true)
	await _frames(2)
	_drag(0, sp + Vector2(120, 0))
	await _frames(2)
	_check(p.touch_move.x > 0.9 and absf(p.touch_move.y) < 0.05, "trascinato a destra: direzione (1, 0) (%s)" % str(p.touch_move))
	await _frames(40)
	var moved: Vector3 = p.global_position - start
	var expect: Vector3 = p.screen_to_world_dir(Vector2(1, 0))
	_check(moved.length() > 1.0, "l'eroe cammina (%.1f m)" % moved.length())
	_check(moved.normalized().dot(expect.normalized()) > 0.8, "verso destra sullo schermo")
	_touch(0, sp + Vector2(120, 0), false)
	await _frames(2)
	_check(p.touch_move == Vector2.ZERO, "dito sollevato: si ferma")
	# Tocco sul joystick senza trascinare: non deve diventare un clic per camminare lì
	_touch(0, sp, true)
	await _frames(2)
	_touch(0, sp, false)
	await _frames(2)
	_check(p.move_target == Vector3.INF, "tocco nella zona del joystick: nessun clic emulato")

	print("\n== 3. Attacco")
	await _frames(30)
	# Vicino a cartelli/altari il pulsante interagisce invece di attaccare: qui si prova l'attacco
	var hidden: Array = []
	for n: Node3D in get_nodes_in_group("interactable"):
		if n.global_position.distance_to(p.global_position) < 6.0:
			n.remove_from_group("interactable")
			hidden.append(n)
	while lvl.close_top_panel():
		pass
	await _frames(2)
	var c: Vector2 = _button("lmb")["center"]
	_touch(1, c, true)
	await _frames(2)
	_check(p.touch_attack, "attacco tenuto premuto")
	_check(p.attack_cd > 0.0 or p.cast_lock > 0.0, "il primo tocco attacca")
	_touch(1, c, false)
	await _frames(2)
	_check(not p.touch_attack, "rilasciato")

	for n: Node3D in hidden:
		n.add_to_group("interactable")
	print("\n== 4. Abilità: mira automatica e a mano")
	await _frames(40)
	p.cooldowns.clear()
	p.resource = p.stats["resource_max"]
	var ab1: Dictionary = p.abilities["1"]
	await _tap("1", 2)
	_check(p.cooldown_left(ab1) > 0.0 or p.cast_lock > 0.0 or float(ab1.get("cooldown", 0.0)) == 0.0, "tocco su 1: %s lanciata" % ab1["name"])
	await _frames(40)
	p.cooldowns.clear()
	p.resource = p.stats["resource_max"]
	var slot := "rmb"
	var b2: Vector2 = _button(slot)["center"]
	_touch(3, b2, true)
	await _frames(1)
	_drag(3, b2 + Vector2(0, -150))
	await _frames(2)
	var ring: Variant = touch._aim_ring
	_check(ring != null and ring.visible, "trascinando compare l'anello di mira")
	if ring != null:
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		var ps: Vector2 = cam.unproject_position(p.global_position)
		var rs: Vector2 = cam.unproject_position(ring.global_position)
		_check(rs.y < ps.y - 20.0 and absf(rs.x - ps.x) < (ps.y - rs.y), "anello in alto sullo schermo rispetto all'eroe (trascinato in su)")
	var cl_before: float = p.cast_lock
	_touch(3, b2 + Vector2(0, -150), false)
	await _frames(1)
	_check(p.cast_lock > cl_before or p.cooldown_left(p.abilities[slot]) > 0.0, "rilasciato: abilità lanciata")
	_check(ring == null or not ring.visible, "anello nascosto")

	print("\n== 5. Pulsanti dei menu")
	await _tap("inventory")
	_check(lvl.inventory_ui.is_open, "Zaino apre l'inventario")
	_check(not _button("lmb")["show"] and _button("inventory")["show"], "con lo zaino aperto: niente joystick/abilità, menu sì")
	await _tap("inventory")
	_check(not lvl.inventory_ui.is_open, "Zaino lo richiude")
	await _tap("map")
	_check(lvl.hud.minimap.big, "Mappa apre la mappa grande")
	await _tap("map")
	await _tap("quest_log")
	_check(lvl.hud.quest_log.visible, "Diario apre il diario")
	await _tap("quest_log")
	_check(not lvl.any_panel_open(), "tutto richiuso")

	print("\n== 6. Scala dell'interfaccia")
	root.content_scale_factor = 1.25
	await _frames(3)
	_check(touch.root.size.x < size.x - 10.0, "con scala 125%% i pulsanti si ricalcolano (%.0f)" % touch.root.size.x)
	await _tap("inventory")
	_check(lvl.inventory_ui.is_open, "il tocco centra ancora il pulsante Zaino")
	await _tap("inventory")
	root.content_scale_factor = 1.0
	await _frames(3)

	print("\n== 7. Tasto indietro e opzione Mai")
	await _tap("inventory")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_check(not lvl.inventory_ui.is_open, "indietro chiude il pannello aperto")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_check(lvl.pause_menu.root.visible, "indietro senza pannelli apre la pausa")
	lvl.pause_menu.close()
	await _frames(2)
	Sett.touch_controls = 2
	await _frames(2)
	_check(not touch.visible, "opzione Mai: controlli nascosti")
	Sett.touch_controls = old_touch
	Sett.force_touch = false

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
