extends SceneTree
## TEST AUTOMATICO dei dungeon generati: stesso seme = stessa mappa, entrata nel livello 1,
## navmesh percorribile dalla partenza al boss, nemici, uscita e ritorno davanti all'entrata.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_dungeon.gd
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


func _wait_level(id: String, max_frames: int = 900) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			return true
	return false


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	game = root.get_node("Game")
	var Gen: GDScript = load("res://world/dungeon_gen.gd")
	var DB: GDScript = load("res://data/dungeon_db.gd")
	var cfg: Dictionary = DB.get_data("catacombe")

	print("\n== 1. Generazione")
	var a: Variant = Gen.generate(cfg)
	var b: Variant = Gen.generate(cfg)
	var c: Variant = Gen.generate(cfg, int(cfg["seed"]) + 1)
	_check(a.fingerprint() == b.fingerprint(), "stesso seme = stessa mappa")
	_check(a.boss_room == b.boss_room and a.rooms == b.rooms, "stesse stanze e stessa stanza del boss")
	_check(a.fingerprint() != c.fingerprint(), "seme diverso = mappa diversa")
	_check(a.rooms.size() >= 6, "%d stanze" % a.rooms.size())
	_check(a.all_connected(), "tutto il pavimento è raggiungibile dalla partenza")
	_check(a.boss_room != a.start_room, "il boss non è nella stanza di partenza")
	var all_ok := true
	for s in 30:
		var g: Variant = Gen.generate(cfg, 100 + s)
		if not g.all_connected() or g.rooms.size() < 5:
			all_ok = false
			print("    seme %d: %d stanze, collegato %s" % [100 + s, g.rooms.size(), g.all_connected()])
	_check(all_ok, "30 semi diversi: sempre collegati e con almeno 5 stanze")
	for id: String in DB.DUNGEONS:
		if id == "catacombe":
			continue
		var cf: Dictionary = DB.DUNGEONS[id]
		var g1: Variant = Gen.generate(cf)
		var ok: bool = g1.fingerprint() == Gen.generate(cf).fingerprint() and g1.all_connected() and g1.boss_room != g1.start_room
		for sd in 30:
			var gs: Variant = Gen.generate(cf, 500 + sd)
			ok = ok and gs.all_connected() and gs.rooms.size() >= 5
		_check(ok, "%s (stile %s): stesso seme = stessa mappa, 30 semi sempre collegati" % [id, cf.get("style", "stanze")])

	print("\n== 2. Entrata nel livello 1")
	var hero: Variant = load("res://core/hero_data.gd").create("Collaudatore", "legionario")
	hero.level = 8
	game.hero = hero
	game.current_slot = -1
	game.travel("level_01", "", Vector3(138, 0, -652))
	_check(await _wait_level("level_01"), "livello 1 caricato")
	var entrance: Variant = game.level.find_child("IngressoCatacombe", true, false)
	_check(entrance != null, "entrata delle catacombe presente accanto al Mausoleo")
	var p: Variant = game.level.player
	p.interact_target = entrance
	_check(await _wait_level("dungeon"), "cliccando l'entrata si scende nel dungeon")
	var lvl: Variant = game.level
	p = lvl.player
	_check(lvl.level_title == "Catacombe del Mausoleo", "titolo: %s" % lvl.level_title)
	_check(lvl.gen.fingerprint() == a.fingerprint(), "la mappa in gioco è quella del seme")
	_check(_flat(p.global_position, lvl.gen.room_center_world(lvl.gen.start_room)) < 1.5, "l'eroe compare nella stanza di partenza")

	print("\n== 3. Navmesh e nemici")
	var map: RID = lvl.get_world_3d().navigation_map
	for i in 120:
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break
		await process_frame
	var nm: NavigationMesh = (lvl.get_node("World") as NavigationRegion3D).navigation_mesh
	_check(nm.get_polygon_count() > 50, "navmesh calcolata (%d poligoni)" % nm.get_polygon_count())
	var qp := NavigationPathQueryParameters3D.new()
	qp.map = map
	qp.start_position = p.global_position
	var boss_pos: Vector3 = lvl.gen.room_center_world(lvl.gen.boss_room)
	qp.target_position = boss_pos
	qp.path_search_max_polygons = 0
	var res := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(qp, res)
	var end := res.path[res.path.size() - 1] if res.path.size() > 0 else Vector3.ZERO
	_check(res.path.size() > 2 and _flat(end, boss_pos) < 3.0, "si arriva a piedi alla stanza del boss (%d punti)" % res.path.size())
	var zones: Array = lvl.get_node("Incontri").get_children()
	var rest: int = Array(lvl.gen.kinds).count("sacello")
	_check(zones.size() == lvl.gen.rooms.size() - 1 - rest, "una zona di nemici per stanza, tranne partenza e sacelli (%d)" % zones.size())
	var boss_zone: Variant = null
	for z: Variant in zones:
		if z.unique_id == "custode":
			boss_zone = z
	_check(boss_zone != null, "il Custode delle Ossa aspetta nella stanza del boss")
	lvl.teleport_player(boss_pos + Vector3(0, 0, 6))
	for i in 60:
		await process_frame
		if boss_zone.spawned:
			break
	var boss_found := false
	for e: Variant in get_nodes_in_group("enemies"):
		if e.type_id == "custode":
			boss_found = true
	_check(boss_found, "avvicinandosi il boss compare")
	var chests := 0
	var chest_script: Script = load("res://world/chest.gd")
	for n: Variant in get_nodes_in_group("interactable"):
		if n.get_script() == chest_script:
			chests += 1
	_check(chests >= 2, "forzieri nelle stanze (%d)" % chests)
	# Proposte dei livelli (docs/PROPOSTE_LIVELLI.md, D2-D6)
	var sac: int = Array(lvl.gen.kinds).find("sacello")
	var shrine_in_sac := false
	if sac >= 0:
		var sr: Rect2i = lvl.gen.rooms[sac]
		for sh: Node in lvl.get_node("Extra").get_children():
			if sr.has_point(lvl.gen.world_to_cell((sh as Node3D).global_position)):
				shrine_in_sac = true
	_check(sac >= 0 and lvl.get_node("Incontri").get_node_or_null("Stanza%d" % sac) == null and shrine_in_sac,
		"c'è un sacello: stanza senza nemici con un santuario")
	_check(boss_zone.count == 2, "pochi servitori accanto al boss (%d): i rinforzi li chiamano le sue fasi" % boss_zone.count)
	var ante: int = lvl.antechamber()
	var az: Variant = lvl.get_node("Incontri").get_node_or_null("Stanza%d" % ante)
	_check(ante >= 0 and az != null and az.elite, "l'anticamera del boss ha un gruppo elite (stanza %d)" % ante)
	var dead_ends := 0
	var dead_with_chest := 0
	for i in lvl.gen.rooms.size():
		if i == lvl.gen.start_room or i == lvl.gen.boss_room or lvl.gen.kinds[i] == "tesoro" or lvl.room_exits(i) != 1:
			continue
		dead_ends += 1
		var rr: Rect2i = lvl.gen.rooms[i]
		for n: Variant in get_nodes_in_group("interactable"):
			if n.get_script() == chest_script and rr.grow(1).has_point(lvl.gen.world_to_cell(n.global_position)):
				dead_with_chest += 1
				break
	_check(dead_with_chest >= mini(dead_ends, 3), "forzieri nei vicoli ciechi (%d stanze con un solo sbocco, %d con il forziere)" % [dead_ends, dead_with_chest])
	# (l'eroe si allontana: l'uscita compare dove stava, e ci entrerebbe subito)
	lvl.teleport_player(lvl.gen.room_center_world(lvl.gen.start_room))
	await _frames(2)
	for e: Variant in get_nodes_in_group("enemies"):
		if e.type_id == "custode":
			e.take_damage(e.life * 100.0, Vector3.ZERO, false)
	await _frames(5)
	_check(lvl.get_node_or_null("UscitaBoss") != null, "sconfitto il boss, compare un'uscita nella sua stanza")

	print("\n== 4. Uscita")
	for e: Variant in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	var exit: Variant = lvl.find_child("Uscita", true, false)
	lvl.teleport_player(exit.global_position + Vector3(0, 0, 4))
	await _frames(2)
	p.move_target = exit.global_position + Vector3(0, 0, -1.5)
	_check(await _wait_level("level_01"), "la scala riporta al livello 1")
	p = game.level.player
	_check(_flat(p.global_position, entrance_return()) < 1.5, "si ricompare davanti all'entrata (%s)" % p.global_position)

	print("\n== 5. Salvataggio dentro il dungeon")
	game.hero.flags["dungeon"] = {"id": "catacombe", "return_level": "level_01", "x": 138.0, "z": -656.0}
	var saved_pos: Vector3 = a.room_center_world(a.start_room) + Vector3(3, 0, 2)
	game.travel("dungeon", "", saved_pos)
	_check(await _wait_level("dungeon"), "ricaricando il dungeon (come da un salvataggio)...")
	_check(game.level.gen.fingerprint() == a.fingerprint() and _flat(game.level.player.global_position, saved_pos) < 1.0,
		"...la mappa è la stessa e l'eroe è dove era")

	print("\n== 6. Gli altri dungeon: entrata nel loro livello, percorso fino al boss")
	for id: String in DB.DUNGEONS:
		if id == "catacombe":
			continue
		var cf: Dictionary = DB.DUNGEONS[id]
		var where: Array = cf["entrance"]
		game.travel(String(where[0]))
		await _wait_level(String(where[0]))
		var ent: Variant = game.level.get_node_or_null(String(where[1]))
		_check(ent != null and ent.dungeon_id == id, "%s: entrata in %s" % [id, where[0]])
		if ent == null:
			continue
		game.level.teleport_player(ent.return_point())
		await _frames(2)
		game.level.player.interact_target = ent
		_check(await _wait_level("dungeon"), "%s: cliccando si scende" % id)
		var dl: Variant = game.level
		_check(dl.dungeon_id == id and dl.level_title == String(cf["title"]), "%s: titolo %s" % [id, dl.level_title])
		_check(dl.get_node("World/Arredi").get_child_count() > dl.gen.rooms.size() * 2, "%s: stanze arredate (%d nodi tra oggetti e luci)" % [id, dl.get_node("World/Arredi").get_child_count()])
		var m: RID = dl.get_world_3d().navigation_map
		for i in 120:
			if NavigationServer3D.map_get_iteration_id(m) > 0:
				break
			await process_frame
		var q := NavigationPathQueryParameters3D.new()
		q.map = m
		q.start_position = dl.player.global_position
		var bp: Vector3 = dl.gen.room_center_world(dl.gen.boss_room)
		q.target_position = bp
		q.path_search_max_polygons = 0
		var rs := NavigationPathQueryResult3D.new()
		NavigationServer3D.query_path(q, rs)
		var fin := rs.path[rs.path.size() - 1] if rs.path.size() > 0 else Vector3.ZERO
		_check(rs.path.size() > 2 and _flat(fin, bp) < 3.0, "%s: si arriva a piedi al boss" % id)
		var ex: Variant = dl.find_child("Uscita", true, false)
		var ex_q := NavigationPathQueryParameters3D.new()
		ex_q.map = m
		ex_q.start_position = dl.player.global_position
		ex_q.target_position = ex.global_position + Vector3(0, 0, -1.5)
		ex_q.path_search_max_polygons = 0
		var ex_r := NavigationPathQueryResult3D.new()
		NavigationServer3D.query_path(ex_q, ex_r)
		var ex_end := ex_r.path[ex_r.path.size() - 1] if ex_r.path.size() > 0 else Vector3(1e6, 0, 0)
		_check(_flat(ex_end, ex.global_position + Vector3(0, 0, -1.5)) < 2.0, "%s: la scala di uscita è raggiungibile" % id)
		var boss_id := String(cf["boss"])
		var bz: Variant = null
		for z: Variant in dl.get_node("Incontri").get_children():
			if z.unique_id == boss_id:
				bz = z
		dl.teleport_player(bp + Vector3(0, 0, 5))
		for i in 60:
			await process_frame
			if bz != null and bz.spawned:
				break
		var found := false
		for e: Variant in get_nodes_in_group("enemies"):
			if e.type_id == boss_id:
				found = true
		_check(found, "%s: compare il boss (%s)" % [id, boss_id])

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)


func entrance_return() -> Vector3:
	var e: Variant = game.level.find_child("IngressoCatacombe", true, false)
	return e.return_point() if e != null else Vector3.ZERO
