extends SceneTree
## TEST AUTOMATICO: slot nuovi e doppia arma, tipi di danno, gemme leggendarie, santuari e piloni,
## eventi casuali, taglie, boss a fasi, hardcore, mappa grande, oggetti "nuovi", confronto, daltonici,
## controller nei pannelli e sulla barra, riepilogo alla morte.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_avventura.gd
## Non salva la partita (slot -1); usa e cancella un file di prova "slot_7".

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


func _kill_all(list: Array) -> void:
	for e: Variant in list:
		if is_instance_valid(e) and not e.dead:
			e._shield_t = 0.0   # anche le elite Scudate
			e.take_damage(1e9)
	await _frames(3)


func _run() -> void:
	game = root.get_node("Game")
	var HD: GDScript = load("res://core/hero_data.gd")
	var IDB: GDScript = load("res://data/item_db.gd")
	var App: GDScript = load("res://core/appearance.gd")
	var Abil: GDScript = load("res://core/abilities.gd")
	var Bnt: GDScript = load("res://core/bounties.gd")
	var WDB: GDScript = load("res://data/world_db.gd")
	var E: GDScript = load("res://entities/enemy.gd")

	print("\n== 1. Slot nuovi e doppia arma")
	var h: Variant = HD.create("Collaudatore", "gladiatore")
	h.level = 30
	_check(HD.EQUIP_SLOTS.size() == 13, "13 caselle di equipaggiamento")
	for b: String in ["humeralia", "cingulum", "armillae"]:
		h.inventory[0] = IDB.make_basic(b, 10)
		h.equip_from_inventory(0)
	_check(h.equipment.has("spalle") and h.equipment.has("cintura") and h.equipment.has("bracciali"), "spallacci, cintura e bracciali si indossano")
	var r1: Variant = IDB.make_basic("anello_ferro", 10)
	var r2: Variant = IDB.make_basic("anello_sigillo", 10)
	h.inventory[0] = r1
	h.equip_from_inventory(0)
	h.inventory[0] = r2
	h.equip_from_inventory(0)
	_check(h.equipment.get("anello") == r1 and h.equipment.get("anello2") == r2, "il secondo anello va nella seconda casella")
	var s0: Dictionary = h.compute_stats()
	var off: Variant = IDB.make_basic("scure", 10)
	h.inventory[0] = off
	_check(h.equip_from_inventory(0, true) and h.equipment.get("secondaria") == off, "Gladiatore: Ctrl+clic mette la scure nella mano sinistra")
	var s1: Dictionary = h.compute_stats()
	_check(float(s1["aps"]) > float(s0["aps"]) and float(s1["weapon_max"]) > float(s0["weapon_max"]), "doppia arma: più danni e +15% velocità")
	var lg: Variant = HD.create("Legio", "legionario")
	lg.inventory[0] = IDB.make_basic("gladio_plasma", 5)
	lg.equip_from_inventory(0, true)
	_check(lg.equipment.get("secondaria").base_id == "scutum", "il Legionario non può usare due armi")
	var model: Node3D = (load("res://scenes/characters/gladiatore.tscn") as PackedScene).instantiate()
	root.add_child(model)
	App.apply(model, h.equipment)
	var socks: Array = []
	for n: Node in App.pieces(model, "secondaria"):
		socks.append(String(n.get_parent().name))
	_check(socks.has("Presa_ManoSx") and not socks.has("Presa_ManoDx"), "l'arma della mano sinistra si vede nella mano sinistra")
	_check(App.pieces(model, "spalle").size() == 2 and App.pieces(model, "cintura").size() > 0, "spallacci e cintura si vedono addosso")
	model.queue_free()

	print("\n== 2. Tipi di danno")
	var SDB: GDScript = load("res://data/skill_db.gd")
	_check(SDB.resolve("augure", "rmb", "sfera_vulcano", "", {})["element"] == "fuoco" and SDB.resolve("legionario", "lmb", "colpo_gladio", "ardente", {})["element"] == "fuoco"
		and SDB.resolve("augure", "3", "ira_nettuno", "", {})["element"] == "freddo", "ogni abilità ha il suo tipo di danno (anche dalle varianti)")
	_check(IDB.AFFIXES.has("fuoco_pct") and "bracciali" in IDB.AFFIXES["fuoco_pct"]["slots"], "affissi +% danni per tipo (su bracciali, amuleti, mano secondaria)")
	var hero: Variant = HD.create("Collaudatrice", "augure", "f")
	hero.level = 30
	game.hero = hero
	game.current_slot = -1
	game.travel("ostia_nova")
	_check(await _wait_level("ostia_nova"), "Ostia Nova caricata")
	var lvl: Variant = game.level
	var p: Variant = lvl.player
	var e: Variant = E.create("bruto", 30)
	e.position = p.global_position + Vector3(0, 0, -4)
	lvl.enemies_root.add_child(e)
	await _frames(2)
	e.max_life = 1e9
	e.life = 1e9
	p.stats["crit_chance"] = -100.0
	p.stats["weapon_min"] = 100.0
	p.stats["weapon_max"] = 100.0
	var l0: float = e.life
	Abil.hit_enemy(p, e, 1.0, Vector3.ZERO, {"id": "x", "element": "fuoco"})
	var d_plain: float = l0 - e.life
	p.stats["fuoco_pct"] = 50.0
	l0 = e.life
	Abil.hit_enemy(p, e, 1.0, Vector3.ZERO, {"id": "x", "element": "fuoco"})
	_check(absf((l0 - e.life) / d_plain - 1.5) < 0.01, "+50% danni da fuoco: colpo ×1,5")
	Abil.hit_enemy(p, e, 1.0, Vector3.ZERO, {"id": "x", "element": "freddo"})
	_check(e.slow_mult < 1.0, "il freddo rallenta")

	print("\n== 3. Gemme leggendarie")
	var amu: Variant = IDB.make_basic("bulla", 30)
	amu.gems = [""]
	hero.equipment["amuleto"] = amu
	var helm: Variant = IDB.make_basic("galea", 30)
	helm.gems = [""]
	hero.equipment["elmo"] = helm
	var key: String = IDB.leg_gem_key("cuore_marte", 5)
	hero.add_gem(key)
	_check(not lvl.trade_ui.socket_gem(helm, 0, key), "una gemma leggendaria non va nell'elmo")
	var st0: float = float(hero.compute_stats()["damage_pct"])
	_check(lvl.trade_ui.socket_gem(amu, 0, key), "va nell'amuleto")
	_check(absf(float(hero.compute_stats()["damage_pct"]) - st0 - 15.0) < 0.01, "Cuore di Marte grado 5: +15% danni")
	var bulla2: Variant = IDB.make_basic("anello_ferro", 30)
	bulla2.gems = [IDB.leg_gem_key("dente_cerbero", 10)]
	hero.equipment["anello"] = bulla2
	p.refresh_stats()
	var champ: Variant = E.create("predone", 30, true)
	_check(absf(p.special_damage_mult(champ) - 1.3) < 0.001, "Dente di Cerbero grado 10: +30% contro le elite")
	champ.free()
	_check(IDB.leg_gem_upgrade_chance(5, 20) == 1.0 and IDB.leg_gem_upgrade_chance(20, 20) == 0.6 and IDB.leg_gem_upgrade_chance(30, 20) < 0.1,
		"probabilità di potenziamento secondo il grado del labirinto")
	var owned: Array = hero.owned_legendary_gems()
	var ent: Dictionary = {}
	for g: Dictionary in owned:
		if String(g["key"]).contains("cuore_marte"):
			ent = g
	_check(hero.upgrade_legendary_gem(ent, 20, 0.0) and amu.gems[0] == IDB.leg_gem_key("cuore_marte", 6), "potenziamento riuscito: grado 6 nell'amuleto")
	var back: Variant = HD.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	_check(back.equipment["amuleto"].gems[0] == IDB.leg_gem_key("cuore_marte", 6), "la gemma resta nel salvataggio")

	print("\n== 4. Boss a fasi")
	await _kill_all([e])
	var boss: Variant = E.create("custode", 30)
	boss.position = p.global_position + Vector3(0, 0, -10)
	lvl.enemies_root.add_child(boss)
	await _frames(2)
	boss.take_damage(boss.max_life * 0.4)
	_check(boss._shield_t > 0.0 and boss._shield_adds.size() == 4, "sotto il 66%: il Custode si protegge e chiama 4 lemuri")
	var lb: float = boss.life
	boss.take_damage(1000.0)
	_check(boss.life == lb, "protetto: non subisce danni")
	await _kill_all(boss._shield_adds.duplicate())
	await _frames(2)
	_check(boss._shield_t <= 0.0, "uccisi i lemuri lo scudo cade")
	boss.take_damage(boss.max_life * 0.35)
	_check(boss.enraged and boss._boss_attacks.has("nova"), "sotto il 33%: furia e nuovo attacco (nova)")
	var n_before: int = lvl.dynamic_root.get_child_count()
	boss._boss_attacks = ["pioggia"]
	boss._boss_attack(p)
	await _frames(1)
	_check(lvl.dynamic_root.get_child_count() >= n_before + 6, "attacco speciale: pioggia di fuoco attorno all'eroe")
	await _kill_all([boss])
	_check(game.hero.flags.has("unique_custode"), "boss sconfitto")

	print("\n== 5. Taglie")
	var board: Variant = lvl.find_child("TabulaTaglie", true, false)
	_check(board != null, "Tabula delle taglie nel foro")
	board.interact(p)
	_check(lvl.hud.choice_panel.visible and hero.bounties.has("1") and hero.bounties.has("2"), "la tabula mostra le taglie dei due atti")
	lvl.hud.hide_choice()
	var act1: Array = Bnt.act_list(1)
	_check(act1.size() == 4 and String(act1[0]["type"]) == "boss", "4 taglie per atto, la prima un boss")
	act1[0] = {"type": "boss", "target": "custode", "place": "dungeon:catacombe", "count": 1, "progress": 0, "done": false}
	_check(Bnt.wants_boss("custode"), "il Custode ricompare per la taglia anche se già ucciso")
	var kb: Dictionary = {"type": "kill", "target": "", "place": "level_01", "count": 2, "progress": 0, "done": false}
	act1[1] = kb
	var g0: int = hero.gold
	Bnt.notify("kill", "level_01")
	Bnt.notify("kill", "level_01")
	_check(bool(kb["done"]) and hero.gold > g0, "taglia di uccisioni completata: sesterzi ed esperienza")
	for b: Dictionary in act1:
		b["done"] = true
	var drops0: int = lvl.dynamic_root.get_child_count()
	_check(Bnt.claim_cache(1, p.global_position) and not Bnt.act_done(1), "Cassa del Prefetto ritirata, taglie nuove")
	await _frames(2)
	_check(lvl.dynamic_root.get_child_count() > drops0 + 3, "la cassa lascia loot a terra")

	print("\n== 6. Santuari, eventi, piloni (livello 1)")
	game.travel("level_01")
	_check(await _wait_level("level_01"), "livello 1 caricato")
	lvl = game.level
	p = lvl.player
	var extra: Node = null
	for i in 200:
		extra = lvl.get_node_or_null("Extra")
		if extra != null and extra.get_child_count() > 0:
			break
		await process_frame
	var shrines: Array = []
	var events: Array = []
	for c: Node in extra.get_children():
		if c.get_script() == load("res://world/shrine.gd"):
			shrines.append(c)
		elif c.get_script() == load("res://world/world_event.gd"):
			events.append(c)
	_check(shrines.size() == WDB.SHRINES_PER_MAP and events.size() == WDB.EVENTS_PER_MAP, "%d santuari e %d eventi piazzati vicino alle zone" % [shrines.size(), events.size()])
	var sh: Variant = shrines[0]
	sh.shrine_id = "furia"
	sh.interact(p)
	await _frames(2)
	_check(p.buff_sum("damage") >= 0.25 and not sh.can_interact(), "Santuario di Marte: +25% danni, poi esaurito")
	_check(String(lvl.hud.buff_label.text).contains("Santuario di Marte"), "il potenziamento si vede sopra la barra")
	var ev: Variant = events[0]
	ev.event_id = "assedio"
	lvl.teleport_player(ev.global_position + Vector3(0, 0, 3))
	await _frames(2)
	ev.start()
	await _frames(2)
	_check(ev.state == "running" and ev.spawned.size() == 4 and lvl.hud.event_box.visible, "l'evento parte: prima ondata e riquadro in alto")
	for w in 6:
		await _kill_all(ev.spawned.duplicate())
		await _frames(3)
		if ev.state == "done":
			break
	await _frames(5)
	_check(ev.state == "done" and not lvl.hud.event_box.visible, "tre ondate sconfitte: evento completato")
	p.buffs.clear()
	p.add_buff({"id": "santuario_canalizzazione", "duration": 30.0, "channel": 1.0})
	p.resource = 0.0
	p.cooldowns.clear()
	p.cast_lock = 0.0
	_check(p._try_cast("rmb", p.global_position + Vector3(0, 0, -5)), "Pilone del Flusso: abilità senza costo")

	print("\n== 7. Interfaccia")
	var mm: Variant = lvl.hud.minimap
	hero.register_waypoint("prova", "ostia_nova", "Altare di prova")
	mm.toggle_big()
	await _frames(1)
	var labels: Array = []
	var buttons := 0
	for c: Node in mm.side.find_children("*", "", true, false):
		if c is Label:
			labels.append((c as Label).text)
		elif c is Button:
			buttons += 1
	_check(labels.any(func(t: String) -> bool: return t.contains("Nemici")) and buttons >= 1, "mappa grande: legenda e altari per il viaggio rapido")
	_check(labels.any(func(t: String) -> bool: return t.contains("Catacombe")), "mappa grande: dungeon della zona")
	mm.toggle_big()
	var drop: Variant = load("res://entities/loot_drop.gd").make_item(IDB.make_basic("galea", 5))
	drop.position = p.global_position
	lvl.dynamic_root.add_child(drop)
	await _frames(2)
	var picked: Variant = drop.item
	drop.interact(p)
	var idx: int = hero.inventory.find(picked)
	_check(idx >= 0 and picked.is_new, "oggetto raccolto segnato come nuovo")
	lvl.inventory_ui.open()
	await _frames(1)
	_check(String(lvl.inventory_ui.bag_buttons[idx].text).begins_with("✦"), "nello zaino ha la stellina")
	lvl.inventory_ui._on_hover_bag(idx)
	_check(not picked.is_new and String(lvl.inventory_ui.tooltip_text.text).contains("Shift"), "passandoci sopra non è più nuovo; il tooltip ricorda Shift")
	var S: GDScript = load("res://core/settings.gd")
	S.colorblind = true
	lvl.inventory_ui.refresh()
	_check(String(lvl.inventory_ui.bag_buttons[idx].text).begins_with("[C]"), "daltonici: lettera della rarità")
	S.colorblind = false
	lvl.inventory_ui.close()
	p.using_pad = true
	await _frames(2)
	_check(lvl.hud.slots["rmb"].key_text == "X" and lvl.hud.potion_slot.key_text == "RT", "col controller la barra mostra i pulsanti (X, RT...)")
	p.using_pad = false
	await _frames(2)
	_check(lvl.hud.slots["rmb"].key_text == "Clic dx", "col mouse tornano i tasti")

	print("\n== 8. Morte e hardcore")
	p.kills_since_death = 7
	p.take_damage(1e9, 1)
	await _frames(2)
	var body: String = (lvl.hud.death_panel.find_child("Body", true, false) as Label).text
	_check(lvl.hud.death_panel.visible and body.contains("Uccisioni: 7"), "riepilogo alla morte")
	lvl.respawn_player()
	hero.hardcore = true
	_check(game._stash_path().ends_with("stash_hardcore.json"), "gli eroi hardcore hanno un forziere separato")
	p.take_damage(1e9, 1)
	await _frames(2)
	_check(hero.flags.get("dead", false) and lvl.hud.choice_panel.visible and not lvl.hud.death_panel.visible, "hardcore: caduto per sempre, niente rinascita")
	var f := FileAccess.open(game.slot_path(7), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "saved_at": "oggi", "hero": hero.to_dict()}))
	f.close()
	var info: Dictionary = game.slot_info(7)
	_check(info["hardcore"] and info["dead"], "lo slot mostra eroe hardcore caduto")
	_check(not game.load_game(7), "un eroe hardcore caduto non si può più caricare")
	DirAccess.remove_absolute(game.slot_path(7))

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
