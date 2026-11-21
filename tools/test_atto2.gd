extends SceneTree
## TEST AUTOMATICO di missioni, forziere personale, opzioni e livello 3 (porto, atto 2).
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_atto2.gd
## L'eroe è reso invulnerabile per percorrere tutto il porto a piedi (verifica la navmesh).
## Usa lo slot 3 (indice 2) e lo cancella alla fine; non tocca il forziere personale vero (lo salva e lo ripristina).

const SLOT := 2
## Tappe a piedi nel porto (seguono la strada) fino al faro.
const ROUTE := [
	Vector3(0, 0, -50), Vector3(-20, 0, -110), Vector3(-22, 0, -190), Vector3(8, 0, -250),
	Vector3(-6, 0, -300), Vector3(12, 0, -330), Vector3(-12, 0, -400), Vector3(-8, 0, -470), Vector3(18, 0, -525),
]
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


func _wait_level(id: String, max_frames: int = 600) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			_invuln()
			return true
	return false


func _invuln() -> void:
	game.level.player.add_buff({"id": "test", "duration": 99999.0, "invuln": 1.0})


func _walk_interact(target: Node3D, max_frames: int = 1200) -> void:
	var p: Variant = game.level.player
	p.interact_target = target
	for i in max_frames:
		await process_frame
		if p.interact_target == null:
			return


## Cammina fino a pos. fight = elimina i nemici normali vicini (come farebbe un giocatore).
func _walk_to(pos: Vector3, max_frames: int = 2400, fight: bool = false) -> bool:
	var p: Variant = game.level.player
	for i in max_frames:
		if fight and i % 20 == 0:
			for e: Variant in get_nodes_in_group("enemies"):
				if not e.unique and e.global_position.distance_to(p.global_position) < 9.0:
					e.take_damage(999999.0)
		if p.move_target == Vector3.INF:
			if Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length() < 1.5:
				return true
			p.move_target = pos
		await process_frame
	return false


func _npc(id: String) -> Variant:
	for n: Variant in get_nodes_in_group("npcs"):
		if n.npc_id == id:
			return n
	return null


func _quest_state(id: String) -> String:
	return String((game.hero.quests.get(id, {}) as Dictionary).get("state", ""))


func _run() -> void:
	game = root.get_node("Game")
	var stash_backup: Variant = null
	if FileAccess.file_exists(game.STASH_PATH):
		stash_backup = FileAccess.get_file_as_string(game.STASH_PATH)
	var HeroDataS: GDScript = load("res://core/hero_data.gd")
	var hero: Variant = HeroDataS.create("Collaudatore", "legionario")
	hero.level = 9
	game.hero = hero
	game.current_slot = SLOT

	print("\n== 1. Missione automatica dell'atto 1")
	game.travel("level_01", "DaOstia")
	_check(await _wait_level("level_01"), "livello 1 caricato")
	_check(_quest_state("verso_ostia") == "active", "'Verso Ostia Nova' parte da sola")
	_check(game.level.hud.quest_tracker.text.contains("Verso Ostia Nova"), "la missione compare nell'HUD")
	var brenno: Variant = null
	for i in 240:
		await process_frame
		for e: Variant in get_nodes_in_group("enemies"):
			if e.type_id == "brenno":
				brenno = e
		if brenno != null:
			break
	_check(brenno != null, "Brenno compare vicino alla porta")
	if brenno != null:
		brenno.take_damage(999999.0)
		await _frames(2)
	_check(int(game.hero.quests["verso_ostia"]["step"]) == 1, "uccidere Brenno completa il primo obiettivo")
	game.level.player.move_target = Vector3(50, 0, -906)
	_check(await _wait_level("ostia_nova", 1500), "arrivo a Ostia Nova")
	game.level.hud.lore_panel.visible = false
	_check(int(game.hero.quests["verso_ostia"]["step"]) == 2, "entrare in città completa il secondo obiettivo")

	print("\n== 2. Dialoghi delle missioni")
	var pref: Variant = _npc("prefetto")
	_check(pref._marker.text == "?", "il prefetto ha il segno '?'")
	_check(_npc("fabbro")._marker.text == "!", "il fabbro ha una missione da affidare ('!')")
	var gold0: int = game.hero.gold
	await _walk_interact(pref)
	_check(_quest_state("verso_ostia") == "done", "parlando col prefetto la missione è completata")
	_check(game.hero.gold == gold0 + 300, "ricompensa in sesterzi ricevuta")
	_check(pref._marker.text == "!", "ora il prefetto ha una nuova missione ('!')")
	game.level.hud.lore_panel.visible = false
	var gate: Variant = game.level.find_child("Cancelli", true, false).get_child(0)
	_check(gate.collision_layer != 0, "il cancello del porto è chiuso")
	await _walk_interact(pref)
	_check(_quest_state("porto_sbarrato") == "active", "il prefetto affida 'Il porto sbarrato'")
	_check(game.level.hud.lore_panel.visible, "il testo della missione viene mostrato")
	game.level.hud.lore_panel.visible = false
	await _frames(2)
	_check(gate.opened and gate.collision_layer == 0, "il cancello del porto si apre")
	await _walk_interact(_npc("mercante"))
	_check(_quest_state("casse_rubate") == "active", "il mercante affida 'Merce rubata' invece di aprire il negozio")
	_check(not game.level.trade_ui.is_open, "...e il negozio resta chiuso")
	game.level.hud.lore_panel.visible = false
	await _walk_interact(_npc("mercante"))
	_check(game.level.trade_ui.is_open, "al secondo clic si apre il negozio")
	game.level.close_top_panel()

	print("\n== 3. Missione del fabbro")
	await _walk_interact(_npc("fabbro"))
	_check(_quest_state("ferri_del_mestiere") == "active", "il fabbro affida 'Ferri del mestiere'")
	game.level.hud.lore_panel.visible = false
	await _walk_interact(_npc("fabbro"))
	var trade: Variant = game.level.trade_ui
	_check(trade.is_open and trade.mode == "smith", "poi apre la fucina")
	var ItemDBS: GDScript = load("res://data/item_db.gd")
	for i in 3:
		game.hero.add_item(ItemDBS.generate(5, 0, "legionario"))
	trade._salvage_all(0)
	_check(int(game.hero.quests["ferri_del_mestiere"]["step"]) == 1, "smontare 3 oggetti completa l'obiettivo")
	game.level.close_top_panel()
	await _walk_interact(_npc("fabbro"))
	_check(_quest_state("ferri_del_mestiere") == "done", "la missione del fabbro è completata")
	game.level.hud.lore_panel.visible = false

	print("\n== 4. Forziere personale")
	var stash_node: Variant = null
	for n: Variant in get_nodes_in_group("interactable"):
		if n.get_script() == load("res://world/stash.gd"):
			stash_node = n
	_check(stash_node != null, "c'è il forziere personale in città")
	await _walk_interact(stash_node)
	_check(trade.is_open and trade.mode == "stash", "cliccandolo si apre il pannello del forziere")
	var it: Variant = ItemDBS.generate(5, 2, "legionario")
	game.hero.add_item(it)
	var idx: int = game.hero.inventory.find(it)
	trade.on_bag_right_click(idx)
	_check(game.stash().has(it) and game.hero.inventory[idx] == null, "deposito nel forziere")
	var sidx: int = game.stash().find(it)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	trade._on_stash_input(ev, sidx)
	_check(not game.stash().has(it) and game.hero.inventory.has(it), "ripresa dal forziere")
	game.stash()[0] = it
	game.save_stash()
	_check(FileAccess.get_file_as_string(game.STASH_PATH).contains(it.item_name), "forziere salvato su file")
	game.stash()[0] = null
	game.level.close_top_panel()

	print("\n== 5. Il porto (atto 2)")
	_check(await _walk_to(Vector3(0, 0, -50)), "a piedi fino al cancello nord")
	game.level.player.move_target = Vector3(0, 0, -65)
	_check(await _wait_level("level_03_porto", 900), "il cancello nord porta al porto")
	game.level.hud.lore_panel.visible = false
	_check(int(game.hero.quests["porto_sbarrato"]["step"]) == 1, "obiettivo 'entra nel porto' completato")
	var n_enemies := 0
	for i in ROUTE.size():
		var ok: bool = await _walk_to(ROUTE[i], 3000, true)
		if not ok:
			var pl: Variant = game.level.player
			print("    posizione %s  morto %s  move_target %s  attacco %s  interazione %s  livello %s" % [pl.global_position, pl.dead, pl.move_target, pl.attack_target, pl.interact_target, game.level.level_id])
		_check(ok, "tappa %d raggiunta a piedi %s" % [i + 1, ROUTE[i]])
		n_enemies = maxi(n_enemies, get_nodes_in_group("enemies").size())
	_check(game.hero.waypoints.has("porto_cantiere"), "altare dei cantieri attivato lungo la strada")
	_check(int(game.hero.quests["porto_sbarrato"]["step"]) == 2, "obiettivo 'raggiungi i cantieri' completato")
	_check(n_enemies > 5, "i pirati compaiono lungo il percorso (%d)" % n_enemies)
	var vulso: Variant = null
	for i in 600:
		await process_frame
		for e: Variant in get_nodes_in_group("enemies"):
			if e.type_id == "vulso":
				vulso = e
		if vulso != null:
			break
	_check(vulso != null, "Vulso il Corsaro compare al faro")
	if vulso != null:
		var before := get_nodes_in_group("enemies").size()
		vulso.aggro()
		vulso._summon_cd = 0.0
		await _frames(30)
		_check(get_nodes_in_group("enemies").size() > before, "Vulso chiama rinforzi")
		vulso.take_damage(9999999.0)
		await _frames(3)
	_check(int(game.hero.quests["porto_sbarrato"]["step"]) == 3, "sconfiggere Vulso completa l'obiettivo")

	print("\n== 6. Ritorno e consegna")
	game.level.player.start_town_portal()
	_check(await _wait_level("ostia_nova", 400), "portale per Ostia Nova")
	await _walk_interact(_npc("prefetto"))
	_check(_quest_state("porto_sbarrato") == "done", "'Il porto sbarrato' completata")
	game.level.hud.lore_panel.visible = false
	game.level.hud.toggle_quest_log()
	var log_text: String = game.level.hud.quest_log_text.text
	_check(log_text.contains("Il porto sbarrato") and log_text.contains("Merce rubata"), "il diario elenca missioni in corso e completate")

	print("\n== 7. Opzioni e tasti")
	var OptS: GDScript = load("res://ui/options_menu.gd")
	var opt: Variant = OptS.new()
	game.level.add_child(opt)
	await _frames(1)
	opt.open()
	opt._waiting_action = "potion"
	var k := InputEventKey.new()
	k.physical_keycode = KEY_G
	k.pressed = true
	opt._input(k)
	var SettingsS: GDScript = load("res://core/settings.gd")
	_check(SettingsS.event_text("potion") == "G", "rimappatura: Pozione su G (%s)" % SettingsS.event_text("potion"))
	SettingsS.reset_controls()
	_check(SettingsS.event_text("potion") == "Q", "ripristino dei tasti predefiniti")
	opt._waiting_action = ""
	opt.root.visible = false

	print("\n== 8. Salvataggio")
	_check(game.save_game(), "salvataggio scritto")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.slot_path(SLOT)))
	var h2: Variant = HeroDataS.from_dict(data["hero"])
	_check(String(h2.quests["porto_sbarrato"]["state"]) == "done" and String(h2.quests["casse_rubate"]["state"]) == "active", "missioni salvate")
	game.delete_slot(SLOT)
	if stash_backup != null:
		var f := FileAccess.open(game.STASH_PATH, FileAccess.WRITE)
		f.store_string(stash_backup)
	else:
		DirAccess.remove_absolute(game.STASH_PATH)

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
