extends "res://tools/build_world.gd"
## GENERATORE della città di OSTIA NOVA (hub del primo atto). Riusa le funzioni di build_world.gd.
## Crea scenes/levels/level_02_ostia.tscn (+ navmesh) e, se mancano, i nuovi oggetti di scena e i
## modelli degli NPC (quelli che esistono già NON vengono toccati: le sostituzioni Tripo sono salve).
##
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_ostia.gd
##
## ATTENZIONE: SOVRASCRIVE level_02_ostia.tscn. Dopo averla ritoccata a mano nell'editor non rigenerarla.
##
## Pianta (nord = −Z):
##   porta sud (z 52, uscita verso la campagna) → cardo → FORO (fontana, altare, mercato a ovest,
##   fucina a est) → basilica del prefetto (nord) ; tempio di Vesta a nord-est ; porta del porto
##   (nord: il cancello si apre con la missione "Il porto sbarrato" e porta al livello 3).

const HALF_X := 48.0
const Z_N := -58.0
const Z_S := 52.0
const PAVE := Color(0.55, 0.52, 0.47)
const STREET := Color(0.66, 0.63, 0.58)
const FORUM := Color(0.78, 0.76, 0.71)


func _generate() -> void:
	rng.seed = SEED + 2
	_build_props(true)
	_build_models(true)
	_build_ostia()
	print("Generazione di Ostia Nova completata.")
	quit()


func _allowed(p: Vector2) -> bool:
	return absf(p.x) <= HALF_X + 2.0 and p.y >= Z_N - 12.0 and p.y <= Z_S + 10.0


func _build_ostia() -> void:
	level_root = Node3D.new()
	level_root.name = "OstiaNova"
	get_root().add_child(level_root)
	_build_environment()
	var region := NavigationRegion3D.new()
	region.name = "World"
	level_root.add_child(region)
	region.owner = level_root

	_city_ground(region)
	_city_walls(region)
	var places := _group(region, "Luoghi")
	_forum(places)
	_quarters(places)
	_temple(places)
	_city_npcs(_group(region, "Abitanti"))

	for m: Array in [["PlayerStart", Vector3(0, 0, 42)], ["DaLazio", Vector3(0, 0, 42)], ["PortaleArrivo", Vector3(-6, 0, 18)],
			["DalPorto", Vector3(0, 0, Z_N + 9)]]:
		var mk := Marker3D.new()
		mk.name = m[0]
		mk.position = m[1]
		level_root.add_child(mk)
		mk.owner = level_root

	var exit: Area3D = load("res://world/level_exit.gd").new()
	exit.name = "UscitaLazio"
	exit.position = Vector3(0, 0, 59)
	exit.set("title", "Campagna di Lazio Prime")
	exit.set("target_level", "level_01")
	exit.set("target_spawn", "DaOstia")
	var ecs := CollisionShape3D.new()
	var ebs := BoxShape3D.new()
	ebs.size = Vector3(12, 4, 3)
	ecs.shape = ebs
	ecs.position.y = 2
	exit.add_child(ecs)
	level_root.add_child(exit)
	exit.owner = level_root
	ecs.owner = level_root

	var exit2: Area3D = load("res://world/level_exit.gd").new()
	exit2.name = "UscitaPorto"
	exit2.position = Vector3(0, 0, Z_N - 6)
	exit2.set("title", "Porto di Ostia Nova")
	exit2.set("target_level", "level_03_porto")
	exit2.set("target_spawn", "DaOstia")
	var ecs2 := CollisionShape3D.new()
	var ebs2 := BoxShape3D.new()
	ebs2.size = Vector3(12, 4, 3)
	ecs2.shape = ebs2
	ecs2.position.y = 2
	exit2.add_child(ecs2)
	level_root.add_child(exit2)
	exit2.owner = level_root
	ecs2.owner = level_root

	# Cancello del porto: FUORI dal nodo World (la navmesh ci passa sotto; si apre con la missione)
	var gates := Node3D.new()
	gates.name = "Cancelli"
	level_root.add_child(gates)
	gates.owner = level_root
	var gate := _place("cancello", gates, Vector2(0, Z_N))
	gate.set_script(load("res://world/quest_gate.gd"))
	gate.set("flag", "porto_aperto")
	gate.set("locked_text", "Il cancello del porto è sbarrato. Solo il prefetto può farlo aprire.")

	print("Calcolo navmesh...")
	var nm := NavigationMesh.new()
	nm.cell_size = 0.4
	nm.cell_height = 0.25
	nm.agent_radius = 0.4
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.region_min_size = 30.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	region.navigation_mesh = nm
	region.bake_navigation_mesh(false)
	print("Navmesh: %d poligoni" % nm.get_polygon_count())
	ResourceSaver.save(nm, "res://scenes/levels/level_02_ostia_navmesh.res", ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH)

	get_root().remove_child(level_root)
	level_root.set_script(load("res://world/level.gd"))
	level_root.set("level_id", "ostia_nova")
	level_root.set("level_title", "Ostia Nova")
	level_root.set("area_level", 5)
	level_root.set("is_town", true)
	level_root.set("intro_text", "Le porte di Ostia Nova si aprono davanti a te: il porto dell'Impero sul Mare Nostrum, tra colonne di marmo e lampioni al plasma.\n\n[TRAMA: arrivo in città, primo incontro con il prefetto.]\n\n[color=#c8a050]In città puoi comprare e vendere dal mercante Tito, smontare e forgiare oggetti dal fabbro Decimo e viaggiare tra gli altari attivati cliccandoli.\nFuori dalla città, premi T per aprire un portale che ti riporta qui.[/color]")
	_save_scene(level_root, "res://scenes/levels/level_02_ostia.tscn")
	print("Ostia Nova salvata in res://scenes/levels/level_02_ostia.tscn")
	level_root.free()


# --- Terreno e mura ------------------------------------------------------------------------------

func _city_ground(region: Node3D) -> void:
	var ground := _group(region, "Terreno")
	var base := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	base.mesh = pm
	base.material_override = Fx.mat(Color(0.12, 0.14, 0.1))
	base.position = Vector3(0, -0.05, 0)
	base.name = "Base"
	ground.add_child(base)
	base.owner = level_root
	# Suolo calpestabile: dentro le mura + piazzale fuori dalla porta sud
	_ground_box(ground, "Suolo", Vector3(0, -0.5, (Z_N + Z_S) * 0.5), Vector3(HALF_X * 2.0 + 2.0, 1, Z_S - Z_N + 2.0), PAVE)
	_ground_box(ground, "Piazzale", Vector3(0, -0.5, Z_S + 6.0), Vector3(14, 1, 12), STREET.darkened(0.1))
	_ground_box(ground, "PiazzaleNord", Vector3(0, -0.5, Z_N - 6.0), Vector3(14, 1, 12), STREET.darkened(0.1))
	# Strade e foro (solo grafica)
	_strip(ground, Vector2(0, Z_S + 12.0), Vector2(0, -18), 8.0, 0.02, 0.04, STREET)
	_strip(ground, Vector2(0, -38), Vector2(0, Z_N - 12.0), 8.0, 0.02, 0.04, STREET)
	_strip(ground, Vector2(-HALF_X, -2), Vector2(HALF_X, -2), 6.0, 0.015, 0.03, STREET.darkened(0.05))
	_strip(ground, Vector2(-21, -2), Vector2(21, -2), 32.0, 0.03, 0.04, FORUM)
	# Bordi del piazzale esterno: niente "vuoto" ai lati della porta
	for x: float in [-7.5, 7.5]:
		_blocker(ground, Vector3(x, 1.5, Z_S + 6.0), Vector3(1.0, 3, 12))
		_place("muro_rovina", ground, Vector2(x, Z_S + 6.0), 90.0)
	_blocker(ground, Vector3(0, 1.5, Z_S + 12.5), Vector3(16, 3, 1))
	for x: float in [-7.5, 7.5]:
		_blocker(ground, Vector3(x, 1.5, Z_N - 6.0), Vector3(1.0, 3, 12))
		_place("muro_rovina", ground, Vector2(x, Z_N - 6.0), 90.0)
	_blocker(ground, Vector3(0, 1.5, Z_N - 12.5), Vector3(16, 3, 1))


func _ground_box(parent: Node, n: String, pos: Vector3, size: Vector3, col: Color) -> void:
	var sb := StaticBody3D.new()
	sb.name = n
	sb.collision_layer = Layers.WORLD
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Fx.mat(col)
	sb.add_child(mi)
	parent.add_child(sb)
	sb.owner = level_root
	cs.owner = level_root
	mi.owner = level_root


## Ostacolo invisibile (blocca il movimento e buca la navmesh).
func _blocker(parent: Node, pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Blocco_%d" % parent.get_child_count()
	sb.collision_layer = Layers.WORLD
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	sb.owner = level_root
	cs.owner = level_root


func _city_walls(region: Node3D) -> void:
	var g := _group(region, "Mura")
	for z: float in [Z_S, Z_N]:
		for x: float in [-44.0, -36.0, -28.0, -20.0, -14.0, 14.0, 20.0, 28.0, 36.0, 44.0]:
			_place("muro", g, Vector2(x, z))
	var z := Z_N + 4.0
	while z <= Z_S + 2.0:
		_place("muro", g, Vector2(-HALF_X, z), 90.0)
		_place("muro", g, Vector2(HALF_X, z), 90.0)
		z += 8.0
	_place("porta_citta", g, Vector2(0, Z_S))
	_place("porta_citta", g, Vector2(0, Z_N))
	_place("stendardo", g, Vector2(-9, Z_S - 5))
	_place("stendardo", g, Vector2(9, Z_S - 5))
	_place("cartello", g, Vector2(7, Z_N + 6), 0.0, 1.0, {"title": "Porto di Ostia Nova",
		"text": "Oltre questo cancello c'è il porto di Ostia Nova. Si apre solo per ordine del prefetto.\n\n[TRAMA: atto 2 — il porto, le navette per Nova Roma.]"})


# --- Foro ------------------------------------------------------------------------------------------

func _forum(parent: Node) -> void:
	var g := _group(parent, "Foro")
	_place("fontana", g, Vector2(0, -2))
	var z := -16.0
	while z <= 12.5:
		_place("colonna", g, Vector2(-21, z))
		_place("colonna", g, Vector2(21, z))
		z += 4.4
	for p: Vector2 in [Vector2(-18, -16), Vector2(18, -16), Vector2(-18, 12), Vector2(18, 12)]:
		_place("lampione_plasma", g, p)
	_place("stendardo", g, Vector2(-5, 13))
	_place("stendardo", g, Vector2(5, 13))
	_place("statua", g, Vector2(-9, -16), 180.0)
	_place("statua", g, Vector2(9, -16), 180.0)
	_place("altare", g, Vector2(8, 8), 0.0, 1.0, {"checkpoint_id": "ostia_foro", "title": "Altare del Foro"})
	_place("scrigno", g, Vector2(-8, 9))

	# Mercato (lato ovest)
	var m := _group(parent, "Mercato")
	for zz: float in [-9.0, -2.0, 5.0]:
		_place("bancarella", m, Vector2(-15.5, zz), -90.0)
	_place("cassa", m, Vector2(-18.5, -12), 20.0)
	_place("cassa", m, Vector2(-18.8, -10.6), 50.0)
	_place("barile", m, Vector2(-18.5, 8.5))
	_place("barile", m, Vector2(-17.6, 9.3))
	for i in 3:
		_place("anfora", m, Vector2(-18.5 + i * 0.9, 1.6))

	# Fucina (lato est)
	var f := _group(parent, "Fucina")
	_place("fucina", f, Vector2(16, -5))
	_place("cassa", f, Vector2(19, 2), 10.0)
	_place("barile", f, Vector2(13.5, -9.5))

	# Basilica del prefetto (nord del foro, facciata verso sud)
	var b := _group(parent, "Basilica")
	_place("basilica", b, Vector2(0, -30), 180.0)
	for p: Vector2 in [Vector2(-16, -24), Vector2(16, -24)]:
		_place("cipresso", b, p)


# --- Quartieri ---------------------------------------------------------------------------------------

func _quarters(parent: Node) -> void:
	var g := _group(parent, "Quartieri")
	# Sud (tra la porta e il foro)
	for side: float in [-1.0, 1.0]:
		_place("insula", g, Vector2(30 * side, 40))
		_place("insula", g, Vector2(30 * side, 23))
		_place("casa", g, Vector2(16 * side, 31), 90.0)
		_place("cipresso", g, Vector2(40 * side, 8))
		_place("cipresso", g, Vector2(40 * side, 1))
	_place("pozzo", g, Vector2(-22, 13))
	_place("carro", g, Vector2(22, 46), 80.0)
	_place("cassa", g, Vector2(-21, 46), 15.0)
	_place("covone", g, Vector2(-24, 47))
	for zz: float in [46.0, 36.0, 26.0, 16.0]:
		_place("lampione_plasma", g, Vector2(5.5 if int(zz) % 20 == 6 else -5.5, zz))
	# Ovest e est del foro
	_place("casa", g, Vector2(-35, -3), 90.0)
	_place("insula", g, Vector2(36, -3), 90.0)
	_place("pino_marittimo", g, Vector2(-40, -16))
	# Nord-ovest
	_place("insula", g, Vector2(-31, -31))
	_place("insula", g, Vector2(-31, -47))
	_place("casa", g, Vector2(-15, -48))
	_place("albero_quercia", g, Vector2(-19, -38))
	_place("lampione_plasma", g, Vector2(-5.5, -44))
	_place("lampione_plasma", g, Vector2(5.5, -50))
	for i in 4:
		_place("anfora", g, Vector2(-24 + i * 0.9, -40))


func _temple(parent: Node) -> void:
	var g := _group(parent, "TempioDiVesta")
	var c := Vector2(32, -40)
	_place("pavimento_tempio", g, c)
	var z := -51.0
	while z <= -28.0:
		_place("colonna", g, Vector2(c.x - 6.5, z))
		_place("colonna", g, Vector2(c.x + 6.5, z))
		z += 4.4
	_place("statua", g, Vector2(c.x, -50), 0.0, 1.1)
	_place("falo", g, Vector2(c.x, -43))
	_place("cipresso", g, Vector2(20, -30))
	_place("cipresso", g, Vector2(20, -46))


# --- Abitanti -----------------------------------------------------------------------------------------

func _city_npcs(parent: Node) -> void:
	# [id, posizione, rotazione (gradi: 0 = guarda a nord)]
	var list := [
		["mercante", Vector2(-12.8, -2), -90.0],
		["fabbro", Vector2(12.8, -1.5), 90.0],
		["prefetto", Vector2(0, -19.5), 180.0],
		["vestale", Vector2(32, -26), 180.0],
		["guardia", Vector2(-7, 45), 180.0],
		["guardia", Vector2(7, 45), 180.0],
		["guardia", Vector2(-5, Z_N + 6), 180.0],
		["cittadino", Vector2(-8, 22), 90.0],
		["cittadino", Vector2(9, -12), -60.0],
		["cittadino", Vector2(24, 15), 200.0],
		["cittadino", Vector2(-26, 5), 30.0],
	]
	var i := 0
	for e: Array in list:
		var n := StaticBody3D.new()
		n.name = "Npc_%s_%d" % [e[0], i]
		n.set_script(load("res://entities/npc.gd"))
		n.set("npc_id", e[0])
		n.position = _v3(e[1])
		n.rotation_degrees.y = e[2]
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5
		cyl.height = 1.9
		cs.shape = cyl
		cs.position.y = 0.95
		n.add_child(cs)
		parent.add_child(n)
		n.owner = level_root
		cs.owner = level_root
		i += 1
