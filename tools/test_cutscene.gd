extends SceneTree
## TEST AUTOMATICO del motore delle cutscene (core/cutscene.gd, data/cutscene_db.gd).
## Cutscene di prova con tutti i tipi di inquadratura (titolo, immagine con livelli, scena nel motore, video mancante),
## pausa del gioco e HUD nascosto, avanti/salta con tastiera e mouse, telecamera ripristinata, attori mossi,
## flag "vista", trigger una sola volta, coda, area nel livello, catalogo valido.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_cutscene.gd

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frame


func _run() -> void:
	game = root.get_node("Game")
	root.size = Vector2i(1600, 900)
	var CS: GDScript = load("res://core/cutscene.gd")
	var DB: GDScript = load("res://data/cutscene_db.gd")

	print("\n== 1. Catalogo")
	var bad: Array = []
	for id: String in DB.CUTSCENES:
		var d: Dictionary = DB.CUTSCENES[id]
		if not d.has("shots") or (d["shots"] as Array).is_empty():
			bad.append(id)
		for s: Dictionary in d.get("shots", []):
			if not String(s.get("type", "image")) in ["title", "image", "video", "scene"]:
				bad.append("%s: tipo %s" % [id, s.get("type")])
		var trig := String(d.get("trigger", ""))
		if trig != "" and not (trig.begins_with("enter:") or trig.begins_with("quest_start:") or trig.begins_with("quest_done:")
				or trig.begins_with("boss:") or trig.begins_with("area:")):
			bad.append("%s: trigger %s" % [id, trig])
	_check(bad.is_empty(), "ogni cutscene ha inquadrature di tipo valido e un trigger valido %s" % str(bad))
	_check(CS.image_path("prova/cielo") == "res://textures/cutscene/prova/cielo.png" and CS.image_path("res://x.jpg") == "res://x.jpg",
		"percorsi delle immagini (textures/cutscene/<nome>.png o res://)")

	print("\n== 2. Riproduzione nel livello")
	var hero: Variant = load("res://core/hero_data.gd").create("Regista", "legionario", "m")
	game.hero = hero
	game.current_slot = -1
	game.travel("level_01")
	var lvl: Variant = null
	for i in 900:
		await process_frame
		lvl = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == "level_01" and lvl.is_node_ready() and lvl.player != null:
			break
	await _frames(10)
	var p: Variant = lvl.player
	var cam_before: Camera3D = root.get_viewport().get_camera_3d()
	var start_pos: Vector3 = p.global_position
	var done := [false, false]
	var c: Variant = CS.play("prova", func() -> void: done[0] = true)
	await _frames(3)
	_check(c != null and CS.is_playing() and paused, "parte e mette il gioco in pausa")
	_check(not lvl.hud.visible and lvl.any_panel_open(), "HUD nascosto, il livello sa che c'è una cutscene")
	_check(hero.flags.has("cs_prova") and CS.seen("prova"), "segnata come vista per l'eroe (flag cs_prova)")
	_check(c.index == 0 and c._stage.get_child_count() > 0, "inquadratura 1: titolo")
	# il titolo finisce da solo (3 s)
	for i in 240:
		await process_frame
		if c.index >= 1:
			break
	_check(c.index == 1 and c._layers.size() == 3, "inquadratura 2: immagine con 3 livelli in parallasse (segnaposto se mancano)")
	var l0: Control = c._layers[0][0]
	var l2: Control = c._layers[2][0]
	var s0: Vector2 = l0.scale
	await _frames(90)
	_check(l2.scale.x > l0.scale.x and l0.scale.x >= s0.x, "zoom in corso, il primo piano si muove più dello sfondo")
	_check(c._fx != null and c._sub_box.visible and c._speaker.text == "Narratore", "particelle (braci), sottotitolo con chi parla")
	# avanti: prima completa il testo, poi passa oltre
	await _key("ui_accept")
	_check(c.index == 1 and c._text.visible_ratio == 1.0, "Spazio: completa il testo che si sta scrivendo")
	await _key("ui_accept")
	_check(c.index == 2, "Spazio di nuovo: inquadratura successiva")
	await _frames(20)
	# clic del mouse = avanti
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(800, 400)
	Input.parse_input_event(mb)
	await process_frame
	Input.parse_input_event(mb)   # il primo completa il testo, il secondo va avanti
	await _frames(2)
	_check(c.index == 3, "clic: avanti (inquadratura 4, scena nel motore)")
	await _frames(5)
	var cam_cs: Camera3D = root.get_viewport().get_camera_3d()
	_check(cam_cs != cam_before and cam_cs.name == "CameraCutscene", "scena nel motore: telecamera della cutscene")
	for i in 400:
		await process_frame
		if c.index >= 4:
			break
	_check(p.global_position.distance_to(start_pos + Vector3(2, 0, 0)) < 0.3, "l'eroe si è mosso come scritto (+2 m) col gioco in pausa")
	_check(c.index == 4 and root.get_viewport().get_camera_3d() == cam_before, "inquadratura 5 (video mancante: segnaposto), telecamera del gioco ripristinata")
	for i in 400:
		await process_frame
		if done[0]:
			break
	await _frames(2)
	_check(done[0] and not CS.is_playing() and not paused and lvl.hud.visible, "fine: callback chiamata, gioco ripreso, HUD di nuovo visibile")

	print("\n== 3. Salta, trigger, coda")
	var skipped := [false]
	c = CS.play("prova")
	c.finished.connect(func(_id: String, sk: bool) -> void: skipped[0] = sk)
	await _frames(3)
	await _key("pause")
	await _frames(2)
	_check(skipped[0] and not CS.is_playing() and not paused and not lvl.pause_menu.root.visible, "Esc: salta tutto (senza aprire il menu di pausa)")
	_check(not CS.trigger("nessun_evento"), "evento senza cutscene: non parte niente")
	# trigger: una sola volta per eroe
	DB.CUTSCENES["_test_trigger"] = {"title": "t", "trigger": "enter:_test", "shots": [{"type": "title", "text": "T", "duration": 0.2}]}
	_check(CS.trigger("enter:_test"), "trigger \"enter:\": la cutscene parte")
	for i in 120:
		await process_frame
		if not CS.is_playing():
			break
	_check(not CS.trigger("enter:_test"), "lo stesso trigger non la fa ripartire (già vista)")
	# coda: due cutscene di fila
	DB.CUTSCENES["_test_a"] = {"title": "a", "trigger": "", "shots": [{"type": "title", "text": "A", "duration": 0.3}]}
	DB.CUTSCENES["_test_b"] = {"title": "b", "trigger": "", "shots": [{"type": "title", "text": "B", "duration": 0.3}]}
	var order: Array = []
	CS.play("_test_a", func() -> void: order.append("a"))
	CS.play("_test_b", func() -> void: order.append("b"))
	for i in 200:
		await process_frame
		if order.size() == 2:
			break
	_check(order == ["a", "b"], "una cutscene chiesta mentre ne gira un'altra va in coda (%s)" % str(order))
	# area nel livello
	DB.CUTSCENES["_test_area"] = {"title": "area", "trigger": "area:AreaProva", "shots": [{"type": "title", "text": "Area", "duration": 0.2}]}
	var area: Area3D = load("res://world/cutscene_trigger.gd").new()
	area.name = "AreaProva"
	lvl.add_child(area)
	area.global_position = p.global_position + Vector3(8, 0, 0)
	await _frames(3)
	p.global_position = area.global_position
	var started := false
	for i in 60:
		await physics_frame
		if CS.is_playing() and CS.current.cutscene_id == "_test_area":
			started = true
			break
	_check(started, "area CutsceneTrigger: entrando parte la cutscene \"area:<nome>\"")
	for i in 120:
		await process_frame
		if not CS.is_playing():
			break
	for k: String in ["_test_trigger", "_test_a", "_test_b", "_test_area"]:
		DB.CUTSCENES.erase(k)

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
