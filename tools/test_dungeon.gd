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
	_check(zones.size() == lvl.gen.rooms.size() - 1, "una zona di nemici per stanza (%d)" % zones.size())
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

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)


func entrance_return() -> Vector3:
	var e: Variant = game.level.find_child("IngressoCatacombe", true, false)
	return e.return_point() if e != null else Vector3.ZERO
