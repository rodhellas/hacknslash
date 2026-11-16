extends SceneTree
## TEST AUTOMATICO di città, commercio, viaggi e poteri leggendari.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_ostia.gd
## Stampa OK/FALLITO per ogni controllo e termina con il riepilogo (codice di uscita 1 se qualcosa fallisce).
## Nota: usa lo slot di salvataggio 3 (indice 2) e lo cancella alla fine.

const SLOT := 2
var game: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  OK       ", what)
	else:
		fails += 1
		print("  FALLITO  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Aspetta che il livello indicato sia caricato e pronto.
func _wait_level(id: String, max_frames: int = 600) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			return true
	return false


## Fa camminare l'eroe verso un nodo interagibile finché non ci interagisce (o scade il tempo).
func _walk_interact(target: Node3D, max_frames: int = 900) -> void:
	var p: Variant = game.level.player
	p.interact_target = target
	for i in max_frames:
		await process_frame
		if p.interact_target == null:
			return


func _walk_to(pos: Vector3, max_frames: int = 1200) -> bool:
	var p: Variant = game.level.player
	p.move_target = pos
	for i in max_frames:
		await process_frame
		if p.move_target == Vector3.INF:
			return true
	return false


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	game = root.get_node("Game")
	var HeroDataS: GDScript = load("res://core/hero_data.gd")
	var ItemDBS: GDScript = load("res://data/item_db.gd")
	var hero: Variant = HeroDataS.create("Collaudatore", "legionario")
	hero.level = 6
	hero.gold = 100000
	game.hero = hero
	game.current_slot = SLOT

	print("\n== 1. Dal livello 1 alla città")
	game.travel("level_01", "DaOstia")
	_check(await _wait_level("level_01"), "livello 1 caricato")
	var p: Variant = game.level.player
	_check(_flat(p.global_position, Vector3(50, 0, -878)) < 1.0, "comparsa nel marker DaOstia (%s)" % p.global_position)
	p.move_target = Vector3(50, 0, -906)
	_check(await _wait_level("ostia_nova", 1500), "uscita del livello 1 -> Ostia Nova")
	p = game.level.player
	_check(_flat(p.global_position, Vector3(0, 0, 42)) < 1.0, "comparsa nel marker DaLazio (%s)" % p.global_position)
	_check(game.hero.flags.has("completed_level_01"), "livello 1 segnato come completato")
	_check(game.level.hud.lore_panel.visible, "testo di benvenuto alla prima visita")
	game.level.hud.lore_panel.visible = false

	print("\n== 2. Città: NPC, altare")
	var npcs := get_nodes_in_group("npcs")
	_check(npcs.size() == 11, "11 abitanti in città (%d)" % npcs.size())
	var by_id := {}
	for n: Variant in npcs:
		by_id[n.npc_id] = n
	var altar: Variant = null
	for cp: Variant in get_nodes_in_group("checkpoint"):
		altar = cp
	await _walk_interact(altar)
	_check(game.hero.waypoints.has("ostia_foro"), "altare del Foro attivato raggiungendolo a piedi")
	_check(game.level.hud.waypoint_panel.visible, "cliccando l'altare si apre il viaggio rapido")
	game.level.hud.waypoint_panel.visible = false

	print("\n== 3. Mercante")
	await _walk_interact(by_id["mercante"])
	var trade: Variant = game.level.trade_ui
	_check(trade.is_open and trade.mode == "vendor", "il negozio si apre parlando col mercante")
	_check(game.level.inventory_ui.is_open, "l'inventario si apre accanto al negozio")
	var stock: Array = trade._get_stock()
	_check(stock.size() == trade.STOCK_SIZE, "merce generata (%d oggetti)" % stock.size())
	var price: int = ItemDBS.buy_price(stock[0])
	var gold0: int = game.hero.gold
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	trade._on_item_input(ev, 0, false)
	await _frames(2)
	_check(game.hero.gold == gold0 - price, "acquisto: pagati %d sesterzi" % price)
	var idx: int = game.hero.inventory.find(null) - 1
	_check(idx >= 0 and game.hero.inventory[idx] != null, "oggetto comprato nello zaino")
	var sold: Variant = game.hero.inventory[idx]
	var value: int = ItemDBS.sell_value(sold)
	gold0 = game.hero.gold
	trade.on_bag_right_click(idx)
	await _frames(2)
	_check(game.hero.gold == gold0 + value and game.hero.inventory[idx] == null, "vendita: +%d sesterzi" % value)
	_check(game.buyback.size() == 1, "oggetto venduto nella lista di riacquisto")
	trade._tab = "riacquista"
	trade.refresh()
	trade._on_item_input(ev, 0, true)
	await _frames(2)
	_check(game.buyback.is_empty() and game.hero.gold == gold0, "riacquisto allo stesso prezzo")

	print("\n== 4. Fabbro")
	game.level.close_top_panel()
	await _walk_interact(by_id["fabbro"])
	# Il primo clic affida la missione "Ferri del mestiere" (vedi test_atto2.gd), il secondo apre la fucina
	_check(game.level.hud.lore_panel.visible, "il fabbro affida prima la sua missione")
	game.level.hud.lore_panel.visible = false
	await _walk_interact(by_id["fabbro"])
	_check(trade.is_open and trade.mode == "smith", "il pannello del fabbro si apre")
	var ItemS: GDScript = load("res://core/item.gd")
	for r in [0, 1, 2, 3]:
		game.hero.add_item(ItemDBS.generate(5, r, "legionario"))
	var salv_idx: int = -1
	for i in game.hero.inventory.size():
		if game.hero.inventory[i] != null and game.hero.inventory[i].rarity == 3:
			salv_idx = i
	trade.on_bag_right_click(salv_idx)
	_check(game.hero.material("frammento") == 1, "smontare un leggendario dà un frammento divino")
	trade._salvage_all(0)
	_check(game.hero.material("rottami") >= 2, "smonta tutti i comuni -> rottami (%d)" % game.hero.material("rottami"))
	game.hero.add_material("rottami", 20)
	game.hero.add_material("essenza", 20)
	game.hero.add_material("frammento", 5)
	for rid: String in ["magico", "raro", "leggendario"]:
		var before: int = game.hero.inventory.count(null)
		trade._slot_choice = "arma"
		trade._craft(rid)
		_check(game.hero.inventory.count(null) == before - 1, "forgia: %s" % rid)
	var crafted_weapon: Variant = null
	for it: Variant in game.hero.inventory:
		if it != null and it.slot == "arma" and it.rarity == 2:
			crafted_weapon = it
	_check(crafted_weapon != null and game.hero.can_equip(crafted_weapon), "l'arma forgiata è usabile dal legionario")

	print("\n== 5. Poteri leggendari")
	var leg: Variant = null
	for i in 400:
		var it: Variant = ItemDBS.generate(6, 3, "legionario", false)
		if it.power == "spartaco":
			leg = it
			break
	_check(leg != null, "generato il Gladio di Spartaco")
	game.hero.equipment["arma"] = leg
	p.refresh_stats()
	_check(p.has_power("spartaco"), "il potere è attivo indossandolo")
	_check(leg.tooltip_bbcode().contains("Ogni nemico ucciso"), "il potere compare nel tooltip")
	var EnemyS: GDScript = load("res://entities/enemy.gd")
	var e: Variant = EnemyS.create("predone", 1)
	e.position = p.global_position + Vector3(3, 0, 0)
	game.level.enemies_root.add_child(e)
	await _frames(2)
	e.take_damage(99999.0)
	await _frames(2)
	var has_buff := false
	for b: Dictionary in p.buffs:
		has_buff = has_buff or b["id"] == "spartaco"
	_check(has_buff, "uccidere un nemico attiva il bonus di Spartaco")
	var old: Variant = ItemS.from_dict({"name": "Anello di Cesare", "rarity": 3, "slot": "anello"})
	_check(old.power == "cesare", "i leggendari dei vecchi salvataggi ricevono il potere")

	print("\n== 6. Viaggio rapido verso il livello 1")
	game.hero.register_waypoint("acquedotto", "level_01", "Altare di Giano")
	game.level.travel_to_waypoint("acquedotto")
	_check(await _wait_level("level_01"), "viaggio verso un altare di un altro livello")
	p = game.level.player
	var cp_pos := Vector3.ZERO
	for cp: Variant in get_nodes_in_group("checkpoint"):
		if cp.checkpoint_id == "acquedotto":
			cp_pos = cp.global_position
	_check(_flat(p.global_position, cp_pos) < 5.0, "comparsa vicino all'Altare di Giano")

	print("\n== 7. Portale cittadino")
	var here: Vector3 = p.global_position
	p.start_town_portal()
	_check(p.portal_t > 0.0, "canalizzazione del portale iniziata")
	_check(await _wait_level("ostia_nova", 400), "il portale porta a Ostia Nova")
	var portal: Variant = null
	for n: Variant in get_nodes_in_group("interactable"):
		if n.get_script() == load("res://world/town_portal.gd"):
			portal = n
	_check(portal != null, "in città c'è il portale di ritorno")
	if portal != null:
		await _walk_interact(portal)
		_check(await _wait_level("level_01"), "il portale riporta al livello 1")
		_check(_flat(game.level.player.global_position, here) < 1.0, "...nel punto esatto da cui si era partiti")
		_check(not game.hero.flags.has("portal_return"), "il portale si chiude dopo l'uso")

	print("\n== 8. Salvataggio")
	_check(game.save_game(), "salvataggio scritto")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.slot_path(SLOT)))
	var h2: Variant = HeroDataS.from_dict(data["hero"])
	_check(h2.material("frammento") == game.hero.material("frammento"), "materiali salvati")
	_check(h2.waypoints.has("ostia_foro") and h2.waypoints.has("acquedotto"), "altari salvati")
	_check(h2.equipment["arma"].power == "spartaco", "potere del leggendario salvato")
	game.delete_slot(SLOT)

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
