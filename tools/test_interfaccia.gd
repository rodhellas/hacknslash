extends SceneTree
## TEST AUTOMATICO dell'interfaccia nuova: finestra Abilità, zaino (ordina, dettagli, anteprima 3D),
## forziere a schede, vendita in blocco, Aspetto (trasmogrificazione), filtro del loot, nomi a terra (Alt),
## nebbia di guerra e segnalini delle missioni, schermata di caricamento, controller, numeri di danno.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_interfaccia.gd
## Non salva la partita (slot -1). Il forziere personale vero viene salvato e ripristinato.

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


func _wait_level(id: String, max_frames: int = 900) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			return true
	return false


func _pad(button: int, pressed := true) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button as JoyButton
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _run() -> void:
	game = root.get_node("Game")
	var HD: GDScript = load("res://core/hero_data.gd")
	var IDB: GDScript = load("res://data/item_db.gd")
	var App: GDScript = load("res://core/appearance.gd")
	# Forziere personale vero: da ripristinare alla fine
	var stash_path := "user://stash.json"
	var stash_backup: Variant = FileAccess.get_file_as_string(stash_path) if FileAccess.file_exists(stash_path) else null

	var hero: Variant = HD.create("Collaudatrice", "gladiatore", "f")
	hero.level = 35
	hero.gold = 100000
	game.hero = hero
	game.current_slot = -1

	print("\n== 1. Schermata di caricamento")
	game.travel("ostia_nova")
	await _frames(1)
	var ld: Variant = game._loading
	_check(ld != null and ld.visible and String(ld.find_child("Title", true, false).text) == "Ostia Nova", "compare con il nome del luogo")
	_check(await _wait_level("ostia_nova"), "Ostia Nova caricata")
	await _frames(2)
	_check(not ld.visible, "sparisce quando il livello è pronto")
	var lvl: Variant = game.level
	var p: Variant = lvl.player

	print("\n== 2. Finestra Abilità (K)")
	var ev := InputEventAction.new()
	ev.action = "skills"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var sui: Variant = lvl.skills_ui
	_check(sui.is_open, "K apre la finestra")
	sui._select("rmb")
	await _frames(1)
	var names: Array = []
	for c: Node in sui.chooser.get_children():
		if c is Button:
			names.append((c as Button).text)
	_check(names.any(func(t: String) -> bool: return t.begins_with("Scure rotante")), "per il clic destro propone anche Scure rotante")
	sui._pick("rmb", "scure_rotante", "")
	sui._pick("rmb", "scure_rotante", "due")
	_check(p.abilities["rmb"]["id"] == "scure_rotante" and int(p.abilities["rmb"]["count"]) == 2, "scelta abilità e variante: Scure rotante, Due scuri")
	_check(lvl.hud.slots["rmb"].ability["id"] == "scure_rotante", "la barra in basso mostra la nuova abilità")
	sui._select("passiva:0")
	sui._pick_passive(0, "brutalita")
	_check(hero.passives[0] == "brutalita" and (sui.passive_buttons[0] as Button).text == "Brutalità", "passiva scelta e mostrata")
	_check(lvl.close_top_panel() and not sui.is_open, "ESC chiude la finestra")

	print("\n== 3. Zaino")
	for b: String in ["galea", "scure", "anello_ferro", "lorica", "scure"]:
		var it: Variant = IDB.make_basic(b, 10)
		hero.inventory[randi_range(5, 30)] = it
	var lg: Variant = IDB.generate(20, 3, "gladiatore")
	hero.inventory[39] = lg
	lvl.inventory_ui.open()
	await _frames(2)
	lvl.inventory_ui.sort_bag()
	var first_ok: bool = hero.inventory[0] != null and hero.inventory[0].slot == "arma"
	var no_gaps := true
	var seen_null := false
	for it: Variant in hero.inventory:
		if it == null:
			seen_null = true
		elif seen_null:
			no_gaps = false
	_check(first_ok and no_gaps, "Ordina: armi prima, nessun buco")
	lvl.inventory_ui.details = true
	lvl.inventory_ui._refresh_stats()
	_check(String(lvl.inventory_ui.stats_label.text).contains("Riduzione ricariche"), "statistiche dettagliate")
	var pv: Variant = lvl.inventory_ui.preview
	_check(pv.visible and pv.model != null and String(pv.model.scene_file_path).ends_with("gladiatore_f.tscn"), "anteprima 3D con il corpo dell'eroina")
	_check(App.pieces(pv.model, "arma").size() > 0, "l'anteprima mostra l'equipaggiamento")
	lvl.inventory_ui.close()

	print("\n== 4. Fabbro: Aspetto")
	var smith: Variant = null
	for n: Node in get_nodes_in_group("npcs"):
		if String(n.get("npc_id")) == "fabbro":
			smith = n
	lvl.teleport_player(smith.global_position + Vector3(0, 0, 2))
	await _frames(2)
	lvl.open_trade(smith)
	var tr: Variant = lvl.trade_ui
	tr._tab = "aspetto"
	tr._look_slot = "arma"
	tr.refresh()
	hero.unlock_look("spatha")
	var gold0: int = hero.gold
	_check(tr.set_look("arma", "spatha") and hero.look_for("arma") == "spatha" and hero.gold < gold0, "l'arma prende l'aspetto della spatha (a pagamento)")
	var blade := false
	for m: Variant in App.pieces(p.model, "arma"):
		if (m as MeshInstance3D).mesh is BoxMesh and ((m as MeshInstance3D).mesh as BoxMesh).size.z > 0.9:
			blade = true
	_check(blade, "addosso si vede la lama lunga della spatha")
	_check(not tr.set_look("arma", "arco_plasma"), "aspetti non sbloccati o non adatti rifiutati")
	tr.set_dye("arma", "oro")
	_check(hero.dyes.get("arma", "") == "oro", "tinta scelta")
	var back: Variant = HD.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	_check(back.transmog.get("arma", "") == "spatha" and back.dyes.get("arma", "") == "oro" and back.looks.has("spatha"), "aspetto e tinte restano nel salvataggio")
	tr.set_look("arma", "")
	tr.close()

	print("\n== 5. Mercante e forziere")
	var vendor: Variant = null
	for n: Node in get_nodes_in_group("npcs"):
		if String(n.get("npc_id")) == "mercante":
			vendor = n
	lvl.teleport_player(vendor.global_position + Vector3(0, 0, 2))
	await _frames(2)
	lvl.open_trade(vendor)
	var n_items := 0
	for it: Variant in hero.inventory:
		if it != null and it.rarity <= 1:
			n_items += 1
	var g1: int = hero.gold
	var sold: int = tr.sell_all_up_to(1)
	var leg_left := false
	for it: Variant in hero.inventory:
		if it == lg:
			leg_left = true
	_check(sold == n_items and hero.gold > g1 and leg_left, "Vendi comuni e magici: %d venduti, il leggendario resta" % sold)
	tr.close()
	var stash_node: Variant = lvl.find_child("Scrigno", true, false)
	lvl.teleport_player(stash_node.global_position + Vector3(0, 0, 2))
	await _frames(2)
	var tabs0: int = game.stash_tabs if game._stash_loaded else (game.stash().size() / game.STASH_SIZE)
	game.stash()
	tabs0 = game.stash_tabs
	lvl.open_stash(stash_node)
	if tabs0 < 5:
		var price: int = game.next_stash_tab_price()
		var g2: int = hero.gold
		_check(game.buy_stash_tab() and game.stash_tabs == tabs0 + 1 and hero.gold == g2 - price and game.stash().size() == game.stash_tabs * 60,
			"comprata la scheda %d del forziere (%d sesterzi)" % [game.stash_tabs, price])
		tr._stash_tab = game.stash_tabs - 1
		var idx: int = hero.inventory.find(lg)
		tr._deposit(idx)
		_check(game.stash()[(game.stash_tabs - 1) * 60] == lg, "si deposita nella scheda aperta")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(stash_path))
		_check(parsed is Dictionary and int(parsed["tabs"]) == game.stash_tabs, "le schede si salvano nel file del forziere")
	tr.close()

	print("\n== 6. Filtro del loot e nomi a terra")
	var S: GDScript = load("res://core/settings.gd")
	S.loot_filter = 2
	var LootS: GDScript = load("res://core/loot.gd")
	var before_gold := 0
	var before_items := 0
	await _frames(1)
	for c: Node in lvl.dynamic_root.get_children():
		if c.get_script() == load("res://entities/loot_drop.gd"):
			c.queue_free()
	await _frames(2)
	LootS.spawn_item(IDB.make_basic("galea", 5), p.global_position + Vector3(4, 0, 0))
	var rare: Variant = IDB.generate(5, 2, "gladiatore")
	LootS.spawn_item(rare, p.global_position + Vector3(4, 0, 0))
	await _frames(2)
	for c: Node in lvl.dynamic_root.get_children():
		if c.get_script() == load("res://entities/loot_drop.gd"):
			if c.item != null:
				before_items += 1
			elif c.gold > 0:
				before_gold += 1
	_check(before_items == 1 and before_gold == 1, "filtro: il comune diventa sesterzi, il raro cade a terra")
	S.loot_filter = 0
	S.always_show_items = false
	var common_drop: Variant = load("res://entities/loot_drop.gd").make_item(IDB.make_basic("galea", 5))
	common_drop.position = p.global_position + Vector3(-4, 0, 0)
	lvl.dynamic_root.add_child(common_drop)
	await _frames(2)
	_check(not common_drop._label.visible, "senza 'sempre visibili' il nome di un comune è nascosto")
	Input.action_press("show_items")
	await _frames(2)
	_check(common_drop._label.visible, "tenendo Alt si vede")
	Input.action_release("show_items")
	S.always_show_items = true

	print("\n== 7. Nebbia di guerra e segnalini")
	game.travel("level_01")
	_check(await _wait_level("level_01"), "livello 1 caricato")
	lvl = game.level
	p = lvl.player
	var ov: Variant = lvl.hud.minimap.overlay
	await _frames(20)
	var n0: int = ov.explored_count()
	_check(n0 > 10 and ov.is_explored(p.global_position), "intorno all'eroe è esplorato (%d celle)" % n0)
	var far: Vector3 = p.global_position + Vector3(0, 0, -200)
	_check(not ov.is_explored(far), "200 m più avanti è ancora nebbia")
	lvl.teleport_player(Vector3(far.x, 0, far.z))
	await _frames(20)
	_check(ov.is_explored(far) and ov.explored_count() > n0, "camminando la nebbia si dirada")
	var saved: Array = hero.flags["fog"]["level_01"]
	_check(saved.size() == ov.explored_count(), "l'esplorato finisce nel salvataggio (%d celle)" % saved.size())
	hero.quests.clear()
	load("res://core/quests.gd").start("verso_ostia", false)
	ov._marks = ov.quest_marks()
	_check(not ov._marks.is_empty(), "segnalino della missione sulla mappa (boss della porta)")

	print("\n== 8. Controller")
	var E: GDScript = load("res://entities/enemy.gd")
	var e: Variant = E.create("predone", 1)
	e.position = p.global_position + Vector3(0, 0, -3)
	lvl.enemies_root.add_child(e)
	await _frames(3)
	e.max_life = 1e6
	e.life = 1e6
	var aim: Vector3 = p.pad_aim(p.abilities["lmb"])
	_check(aim.distance_to(e.global_position) < 0.5, "la mira automatica sceglie il nemico vicino")
	p.attack_cd = 0.0
	p.cast_lock = 0.0
	_pad(JOY_BUTTON_A)
	await _frames(2)
	_pad(JOY_BUTTON_A, false)
	await _frames(2)
	_check(e.life < e.max_life and p.using_pad, "A attacca il nemico")
	var ex := InputEventJoypadMotion.new()
	ex.axis = JOY_AXIS_LEFT_X
	ex.axis_value = 1.0
	Input.parse_input_event(ex)
	await _frames(1)
	_check(p._input_direction().length() > 0.5, "lo stick sinistro muove l'eroe")
	ex.axis_value = 0.0
	Input.parse_input_event(ex)
	_check(InputMap.action_get_events("skill_3").any(func(x: InputEvent) -> bool: return x is InputEventJoypadButton), "le abilità hanno un pulsante del controller")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	S.rebind("skill_3", key)
	var evs: Array = InputMap.action_get_events("skill_3")
	_check(evs[0] is InputEventKey and evs.any(func(x: InputEvent) -> bool: return x is InputEventJoypadButton), "rimappare un tasto non toglie il pulsante del controller")
	S.load_and_apply()

	print("\n== 9. Numeri di danno")
	_check(E._fmt(1234567.0) == "1.23 M" and E._fmt(45678.0) == "45.678" and E._fmt(999.0) == "999", "numeri grandi leggibili")

	# Ripristino del forziere personale vero
	if stash_backup == null:
		DirAccess.remove_absolute(stash_path)
	else:
		var f := FileAccess.open(stash_path, FileAccess.WRITE)
		f.store_string(String(stash_backup))
	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
