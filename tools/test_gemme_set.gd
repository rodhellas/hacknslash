extends SceneTree
## TEST AUTOMATICO di gemme (orbite, gioielliere) e set (bonus a 2/3/4 pezzi).
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_gemme_set.gd
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_level(id: String, max_frames: int = 600) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			return true
	return false


func _run() -> void:
	game = root.get_node("Game")
	var HeroDataS: GDScript = load("res://core/hero_data.gd")
	var ItemDBS: GDScript = load("res://data/item_db.gd")
	var ItemS: GDScript = load("res://core/item.gd")
	var hero: Variant = HeroDataS.create("Collaudatore", "legionario")
	hero.level = 10
	hero.gold = 100000
	game.hero = hero
	game.current_slot = -1
	game.travel("ostia_nova")
	_check(await _wait_level("ostia_nova"), "Ostia Nova caricata")
	var p: Variant = game.level.player

	print("\n== 1. Set")
	var base_stats: Dictionary = p.stats.duplicate()
	var pieces: Array = []
	for i in 4:
		var it: Variant = ItemDBS.make_set_piece(10, "legionario", true, "primo_pilo", i)
		pieces.append(it)
	_check(pieces[0].rarity == ItemS.Rarity.SET and pieces[0].set_id == "primo_pilo", "pezzo di set verde con set_id")
	_check(pieces[0].affixes.size() == 4, "statistiche fisse + 2 casuali (%d affissi)" % pieces[0].affixes.size())
	hero.equipment[pieces[0].slot] = pieces[0]
	p.refresh_stats()
	_check(ItemDBS.set_counts(hero.equipment).get("primo_pilo", 0) == 1, "1 pezzo indossato")
	var armor1: float = p.stats["armor"]
	hero.equipment[pieces[1].slot] = pieces[1]
	p.refresh_stats()
	var bonus2: Dictionary = ItemDBS.set_bonuses(hero.equipment, hero.level)
	_check(bonus2["stats"].size() == 2, "con 2 pezzi: bonus da 2 attivo")
	_check(float(p.stats["armor"]) > armor1 + 60.0, "il bonus aggiunge armatura (%d → %d)" % [armor1, p.stats["armor"]])
	_check(p.skill_bonus.is_empty(), "bonus da 4 non ancora attivo")
	hero.equipment[pieces[2].slot] = pieces[2]
	hero.equipment[pieces[3].slot] = pieces[3]
	p.refresh_stats()
	_check(float(p.skill_bonus.get("pilum", 0.0)) == 200.0, "con 4 pezzi: +200% danni di Pilum")
	_check(float(p.stats["dps"]) > float(base_stats["dps"]), "DPS cresciuto (%.1f → %.1f)" % [base_stats["dps"], p.stats["dps"]])
	var tip: String = pieces[0].tooltip_bbcode()
	_check(tip.contains("Panoplia del Primo Pilo") and tip.contains("(4)"), "tooltip con nome del set e bonus")
	var saved: Variant = ItemS.from_dict(JSON.parse_string(JSON.stringify(pieces[0].to_dict())))
	_check(saved.set_id == "primo_pilo" and saved.rarity == ItemS.Rarity.SET, "set_id e rarità salvati")
	var seen_set := false
	for i in 200:
		var lg: Variant = ItemDBS.generate(10, ItemS.Rarity.LEGGENDARIO, "legionario")
		if lg.set_id != "":
			seen_set = true
			break
	_check(seen_set, "a volte un leggendario esce come pezzo di set")
	var seen_socket := false
	for i in 300:
		var r: Variant = ItemDBS.generate(10, ItemS.Rarity.RARO, "legionario")
		if not r.gems.is_empty():
			seen_socket = r.gems.size() <= int(ItemDBS.MAX_SOCKETS.get(r.slot, 0))
			break
	_check(seen_socket, "gli oggetti possono avere orbite (entro il massimo per tipo)")

	print("\n== 2. Gemme e gioielliere")
	var smith: Variant = null
	for n: Variant in get_nodes_in_group("npcs"):
		if n.npc_id == "fabbro":
			smith = n
	p.global_position = smith.global_position + Vector3(2, 0, 0)
	game.level.open_trade(smith)
	var trade: Variant = game.level.trade_ui
	trade._tab = "gemme"
	trade.refresh()
	await _frames(2)
	_check(trade.is_open and trade.mode == "smith", "pannello del fabbro aperto sulla scheda Gioielliere")
	hero.add_gem("rubino:1", 7)
	var gold0: int = hero.gold
	_check(trade.combine_gem("rubino:1"), "combina 3 rubini scheggiati")
	_check(hero.gem_count("rubino:1") == 4 and hero.gem_count("rubino:2") == 1, "restano 4 scheggiati, 1 grezzo")
	_check(hero.gold == gold0 - ItemDBS.GEM_COMBINE_GOLD, "costo della combinazione pagato")
	var weapon: Variant = hero.equipment["arma"]
	weapon.gems = [""]
	p.refresh_stats()
	var dmg0: float = p.stats["damage_pct"]
	_check(trade.socket_gem(weapon, 0, "rubino:2"), "rubino grezzo incastonato nell'arma")
	_check(hero.gem_count("rubino:2") == 0, "gemma tolta dal sacchetto")
	_check(absf(float(p.stats["damage_pct"]) - dmg0 - 8.0) < 0.01, "arma: +8%% danni (%.0f → %.0f)" % [dmg0, p.stats["damage_pct"]])
	var helm: Variant = hero.equipment["elmo"]
	helm.gems = [""]
	var life0: float = p.stats["max_life"]
	trade.socket_gem(helm, 0, "rubino:1")
	_check(float(p.stats["max_life"]) > life0, "elmo: il rubino dà vita (%d → %d)" % [life0, p.stats["max_life"]])
	_check(not trade.socket_gem(helm, 0, "rubino:1"), "orbita piena: non si incastona due volte")
	_check(trade.unsocket_gem(weapon, 0) and hero.gem_count("rubino:2") == 1, "gemma tolta e tornata nel sacchetto")
	_check(absf(float(p.stats["damage_pct"]) - dmg0) < 0.01, "statistiche tornate come prima")
	var restored: Variant = HeroDataS.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	_check(restored.gem_count("rubino:1") == 3 and restored.equipment["elmo"].gems == ["rubino:1"], "gemme e orbite salvate")

	print("\n== 3. Gemme a terra")
	var LootDropS: GDScript = load("res://entities/loot_drop.gd")
	var d: Variant = LootDropS.make_gem("smeraldo:3")
	d.position = p.global_position + Vector3(4, 0, 0)
	game.level.dynamic_root.add_child(d)
	await _frames(2)
	p.move_target = d.position
	for i in 120:
		await process_frame
		if not is_instance_valid(d):
			break
	_check(hero.gem_count("smeraldo:3") == 1, "gemma raccolta passandoci sopra")

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
