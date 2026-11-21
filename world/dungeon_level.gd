class_name DungeonLevel
extends Level
## Livello dungeon generato al caricamento da world/dungeon_gen.gd (stesso seme = stessa mappa).
## Quale dungeon e dove tornare all'uscita stanno in Game.hero.flags["dungeon"]
## ({"id", "return_level", "x", "z"}), scritti dall'entrata (world/dungeon_entrance.gd).
## Avviato da solo con F6 usa il primo dungeon di DungeonDB e all'uscita torna al livello 1.
## Rientrando, i nemici e i forzieri ricompaiono (come i dungeon di Diablo); il boss è unico per partita.

const WALL_H := 3.5
## Muri tra il pavimento e la telecamera (lato sud): bassi, per non coprire l'eroe (stile D3).
## Più alti di 1 m così la navmesh sopra di loro viene scartata come le altre "isole".
const WALL_LOW_H := 1.2

var cfg: Dictionary = {}
var gen: DungeonGen
var dungeon_id := ""


func music_names() -> Array:
	return ["labirinto", "dungeon"] if rift_grade > 0 else ["dungeon_" + dungeon_id, "dungeon"]
## Labirinti di Dedalo (rift_grade > 0, vedi Level): avanzamento, tempo e Guardiano.
var rift_progress := 0.0
var rift_target := 1.0
var rift_time := 0.0
var guardian_spawned := false
var rift_done := false
var guardian: Enemy = null
var gem_upgrades_left := 0
var rift_kills := 0


func _ready() -> void:
	var info: Dictionary = {}
	if Game.hero != null:
		info = Game.hero.flags.get("dungeon", {})
	dungeon_id = String(info.get("id", DungeonDB.DUNGEONS.keys()[0]))
	if info.has("rift"):
		rift_grade = maxi(1, int(info["rift"]))
		cfg = DifficultyDB.rift_config(rift_grade, int(info.get("seed", 1)), Game.hero.level if Game.hero else 1)
	else:
		cfg = DungeonDB.get_data(dungeon_id)
	level_id = "dungeon"
	level_title = String(cfg["title"])
	area_level = int(cfg["enemy_level"])
	intro_text = String(cfg.get("intro", ""))
	gen = DungeonGen.generate(cfg)
	build()
	super._ready()


## Costruisce mondo, luci, nemici e uscita dalla pianta (chiamato anche dai test senza giocatore).
func build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.42, 0.5)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 0.25
	sun.light_color = Color(0.6, 0.65, 0.85)
	add_child(sun)

	var world := NavigationRegion3D.new()
	world.name = "World"
	add_child(world)
	_build_floor(world)
	_build_walls(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"]) * 7 + 1
	_build_rooms(world, rng)
	_bake(world)

	var start := Marker3D.new()
	start.name = "PlayerStart"
	add_child(start)
	start.position = gen.room_center_world(gen.start_room)
	_build_exit()
	_build_encounters(rng)
	_build_shrines(rng)
	# Boss già sconfitto in passato: l'uscita è già lì
	var boss_id := String(cfg.get("boss", ""))
	if rift_grade <= 0 and boss_id != "" and Game.hero != null and Game.hero.flags.has("unique_" + boss_id):
		_build_boss_exit()


# --- Geometria ------------------------------------------------------------------------------

## Pavimento: un collider per ogni striscia orizzontale di celle + una sola mesh.
func _build_floor(world: Node3D) -> void:
	var body := _body(world, "Pavimento")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in gen.h:
		var x := 0
		while x < gen.w:
			if not gen.is_floor(x, y):
				x += 1
				continue
			var x0 := x
			while x < gen.w and gen.is_floor(x, y):
				x += 1
			_box(body, st, x0, y, x - x0, -0.5, 0.5)
	_mesh(body, st, cfg["floor"], String(cfg.get("floor_tex", "")))


## Muri: le celle vuote che toccano il pavimento (anche in diagonale) diventano blocchi pieni.
func _build_walls(world: Node3D) -> void:
	var body := _body(world, "Muri")
	var tall := SurfaceTool.new()
	tall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := SurfaceTool.new()
	low.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in gen.h:
		var x := 0
		while x < gen.w:
			var kind := _wall_kind(x, y)
			if kind == 0:
				x += 1
				continue
			var x0 := x
			while x < gen.w and _wall_kind(x, y) == kind:
				x += 1
			if kind == 1:
				_box(body, tall, x0, y, x - x0, 0.0, WALL_H)
			else:
				_box(body, low, x0, y, x - x0, 0.0, WALL_LOW_H)
	var col: Color = cfg["wall"]
	_mesh(body, tall, col, String(cfg.get("wall_tex", "")))
	_mesh(body, low, col.darkened(0.15), String(cfg.get("wall_tex", "")))


## 0 = niente muro, 1 = muro alto, 2 = muro basso (pavimento subito a nord: il muro sta tra eroe e telecamera).
func _wall_kind(x: int, y: int) -> int:
	if gen.is_floor(x, y):
		return 0
	var near := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if gen.is_floor(x + dx, y + dy):
				near = true
	if not near:
		return 0
	if gen.is_floor(x, y - 1) or gen.is_floor(x - 1, y - 1) or gen.is_floor(x + 1, y - 1):
		return 2
	return 1


func _body(parent: Node3D, n: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = Layers.WORLD
	b.collision_mask = 0
	parent.add_child(b)
	return b


## Blocco di celle [x0, x0+len) nella riga y, da y_bottom a y_top: collider + facce nella mesh.
func _box(body: StaticBody3D, st: SurfaceTool, x0: int, y: int, len: int, y_bottom: float, y_top: float) -> void:
	var t := gen.tile
	var a := gen.cell_to_world(Vector2(x0, y)) - Vector3(t, 0, t) * 0.5
	var size := Vector3(len * t, y_top - y_bottom, t)
	var center := a + Vector3(size.x * 0.5, (y_top + y_bottom) * 0.5, size.z * 0.5)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)
	var lo := Vector3(a.x, y_bottom, a.z)
	var hi := Vector3(a.x + size.x, y_top, a.z + size.z)
	_quad(st, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.UP)
	if y_top > 0.1:
		_quad(st, Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.BACK)
		_quad(st, Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3.FORWARD)
		_quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), Vector3.LEFT)
		_quad(st, Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3.RIGHT)


## Quadrilatero a-b-c-d (in senso orario visto dalla parte della normale).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


func _mesh(body: Node3D, st: SurfaceTool, col: Color, tex: String = "") -> void:
	var mi := MeshInstance3D.new()
	var m := st.commit()
	mi.mesh = m
	var tm := Terrain.material(tex, col, 0.2, true)
	if tm != null:
		mi.material_override = tm   # texture in coordinate del mondo (anche sui muri)
	else:
		var mat := Fx.new_mat(col)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
	body.add_child(mi)


# --- Stanze: torce, oggetti di scena, forzieri --------------------------------------------------

func _build_rooms(world: Node3D, rng: RandomNumberGenerator) -> void:
	var deco := Node3D.new()
	deco.name = "Arredi"
	world.add_child(deco)
	var props: Array = cfg.get("props", [])
	for i in gen.rooms.size():
		var r := gen.rooms[i]
		var c := gen.room_center_world(i)
		var light := OmniLight3D.new()
		light.light_color = cfg["light"]
		light.light_energy = 2.2 if i == gen.boss_room else 1.6
		light.omni_range = maxf(r.size.x, r.size.y) * gen.tile * 0.75
		light.position = c + Vector3(0, 4.5, 0)
		deco.add_child(light)
		if i == gen.start_room:
			continue
		match gen.kinds[i]:
			"colonne": _room_columns(deco, r)
			"cripta": _room_crypt(deco, r)
			"sacello":
				# Stanza di riposo: niente nemici, due fuochi ai lati del santuario (vedi _build_shrines)
				for dx: int in [-2, 2]:
					var cc := r.position + r.size / 2 + Vector2i(dx, 0)
					if gen.is_open(cc):
						_prop(deco, "falo", gen.cell_to_world(Vector2(cc)), 0.0)
			"tesoro":
				_chest(deco, c + Vector3(0, 0, -1.5), true)
				for k in 4:
					_prop(deco, "anfora", _room_edge_point(r, rng), rng.randf_range(0, 360))
		# Oggetti lungo i bordi della stanza (il centro resta libero per combattere)
		for pr: Array in props:
			if rng.randf() < float(pr[1]):
				var n := rng.randi_range(1, 3)
				for k in n:
					var p := _room_edge_point(r, rng)
					_prop(deco, String(pr[0]), p, rng.randf_range(0, 360))
	# Forzieri: uno decorato nella stanza del boss, uno normale in un paio di altre stanze
	var boss_c := gen.room_center_world(gen.boss_room)
	if _chest(deco, boss_c + Vector3(0, 0, -gen.rooms[gen.boss_room].size.y * gen.tile * 0.35), true) == null:
		_chest(deco, boss_c + Vector3(0, 0, -gen.tile), true)
	# Forzieri normali nei vicoli ciechi (stanze con un solo sbocco): esplorare i rami morti paga sempre.
	# Se non ce ne sono, nelle stanze più lontane dalla partenza (tranne boss e tesoro).
	var picks: Array = []
	for i in gen.rooms.size():
		if i != gen.start_room and i != gen.boss_room and gen.kinds[i] != "tesoro" and room_exits(i) == 1:
			picks.append(i)
	if picks.is_empty():
		var others: Array = []
		for i in gen.rooms.size():
			if i != gen.start_room and i != gen.boss_room and gen.kinds[i] != "tesoro":
				others.append(i)
		others.sort_custom(func(a: int, b: int) -> bool: return _room_dist(a) > _room_dist(b))
		picks = others.slice(0, 2)
	for i: int in picks.slice(0, 3):
		_chest(deco, _room_edge_point(gen.rooms[i], rng), false)


## Sbocchi di una stanza: gruppi di celle di pavimento appena fuori dal suo rettangolo (giro in senso orario).
func room_exits(i: int) -> int:
	var r := gen.rooms[i]
	var ring: Array[Vector2i] = []
	for x in range(r.position.x, r.end.x):
		ring.append(Vector2i(x, r.position.y - 1))
	for y in range(r.position.y, r.end.y):
		ring.append(Vector2i(r.end.x, y))
	for x in range(r.end.x - 1, r.position.x - 1, -1):
		ring.append(Vector2i(x, r.end.y))
	for y in range(r.end.y - 1, r.position.y - 1, -1):
		ring.append(Vector2i(r.position.x - 1, y))
	var runs := 0
	var n := ring.size()
	for k in n:
		var cur := gen.is_floor(ring[k].x, ring[k].y)
		var prev := gen.is_floor(ring[(k - 1 + n) % n].x, ring[(k - 1 + n) % n].y)
		if cur and not prev:
			runs += 1
	if runs == 0 and n > 0 and gen.is_floor(ring[0].x, ring[0].y):
		runs = 1   # tutto il bordo è pavimento (caverne aperte)
	return runs


## Distanza a piedi (celle) del centro di una stanza dalla partenza.
func _room_dist(i: int) -> int:
	var c := gen.rooms[i].position + gen.rooms[i].size / 2
	return gen.dist[c.y * gen.w + c.x]


## Anticamera del boss: la stanza collegata a quella del boss più vicina alla partenza (-1 se non c'è).
func antechamber() -> int:
	var best := -1
	for l: Array in gen.links:
		var other := -1
		if int(l[0]) == gen.boss_room:
			other = int(l[1])
		elif int(l[1]) == gen.boss_room:
			other = int(l[0])
		if other < 0 or other == gen.start_room:
			continue
		if best < 0 or _room_dist(other) < _room_dist(best):
			best = other
	return best


## Sala a colonne: una griglia di colonne (una ogni 3 celle), lontano dal centro e dagli sbocchi.
func _room_columns(deco: Node3D, r: Rect2i) -> void:
	if r.size.x < 7 or r.size.y < 7:
		return
	var center := r.position + r.size / 2
	for y in range(r.position.y + 2, r.end.y - 1, 3):
		for x in range(r.position.x + 2, r.end.x - 1, 3):
			var c := Vector2i(x, y)
			if (c - center).length() < 2.0 or _near_doorway(r, c):
				continue
			_prop(deco, String(cfg.get("column", "colonna")), gen.cell_to_world(Vector2(c)), 0.0)


## Cripta: file di sarcofagi lungo i due lati lunghi.
func _room_crypt(deco: Node3D, r: Rect2i) -> void:
	var horizontal := r.size.x >= r.size.y
	var length := r.size.x if horizontal else r.size.y
	for side in [0, 1]:
		for k in range(1, length - 1, 2):
			var c := Vector2i(r.position.x + k, r.position.y + (1 if side == 0 else r.size.y - 2)) if horizontal \
				else Vector2i(r.position.x + (1 if side == 0 else r.size.x - 2), r.position.y + k)
			if _near_doorway(r, c):
				continue
			_prop(deco, "sarcofago", gen.cell_to_world(Vector2(c)), 0.0 if horizontal else 90.0)


## Punto vicino al bordo di una stanza, lontano dagli sbocchi dei corridoi.
func _room_edge_point(r: Rect2i, rng: RandomNumberGenerator) -> Vector3:
	# A una cella dal muro: la cella dell'oggetto e le sue vicine sono tutte pavimento
	var inner := Vector2(r.size) - Vector2(3.0, 3.0)
	var best := Vector2.ZERO
	for attempt in 8:
		var side := rng.randi_range(0, 3)
		var u := rng.randf()
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(u * inner.x, 0)
			1: p = Vector2(u * inner.x, inner.y)
			2: p = Vector2(0, u * inner.y)
			_: p = Vector2(inner.x, u * inner.y)
		best = Vector2(r.position) + Vector2(1.0, 1.0) + p
		if not _near_doorway(r, Vector2i(roundi(best.x), roundi(best.y))):
			break
	return gen.cell_to_world(best)


## C'è pavimento fuori dalla stanza a meno di 2 celle (uno sbocco di corridoio)?
func _near_doorway(r: Rect2i, c: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var q := c + Vector2i(dx, dy)
			if not r.has_point(q) and gen.is_floor(q.x, q.y):
				return true
	return false


func _prop(parent: Node3D, pname: String, pos: Vector3, rot: float) -> Node3D:
	if not gen.is_open(gen.world_to_cell(pos)):
		return null   # nelle caverne il bordo è irregolare: niente oggetti dentro la roccia
	var ps := load("res://scenes/props/%s.tscn" % pname) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = rot
	parent.add_child(inst)
	return inst


func _chest(parent: Node3D, pos: Vector3, rich: bool) -> Node3D:
	var ch := _prop(parent, "forziere", pos, 0.0)
	if ch != null:
		ch.set("item_level", area_level)
		ch.set("rich", rich)
	return ch


func _bake(world: NavigationRegion3D) -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.4
	nm.cell_height = 0.25
	nm.agent_radius = 0.4
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.region_min_size = 30.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	world.navigation_mesh = nm
	# Senza finestra (test automatici) le iterazioni asincrone della navigazione a volte non si
	# sincronizzano dopo molti bake di fila: lì si spengono (vedi CLAUDE.md, insidie).
	if DisplayServer.get_name() == "headless":
		NavigationServer3D.region_set_use_async_iterations(world.get_rid(), false)
		if is_inside_tree():
			NavigationServer3D.map_set_use_async_iterations(get_world_3d().navigation_map, false)
	world.bake_navigation_mesh(false)


# --- Uscita e nemici ---------------------------------------------------------------------------

## Scala di risalita sul lato nord della stanza di partenza.
func _build_exit() -> void:
	# Verso nord dal centro della stanza di partenza, fin dove il pavimento è libero (anche nelle caverne)
	var r := gen.rooms[gen.start_room]
	var cell := r.position + r.size / 2
	while cell.y > r.position.y + 1 and gen.is_open(cell + Vector2i(0, -1)):
		cell.y -= 1
	var pos := gen.cell_to_world(Vector2(cell)) + Vector3(0, 0, -gen.tile * 0.3)
	var stairs := Node3D.new()
	stairs.name = "Scala"
	stairs.position = pos
	add_child(stairs)
	for i in 4:
		var step := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 0.3 * (i + 1), 0.7)
		step.mesh = bm
		step.material_override = Fx.mat((cfg["wall"] as Color).lightened(0.1))
		step.position = Vector3(0, 0.15 * (i + 1), -0.7 * i)
		stairs.add_child(step)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.85, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	glow.position = Vector3(0, 3, -1)
	stairs.add_child(glow)
	var exit := LevelExit.new()
	exit.name = "Uscita"
	exit.title = "Uscita"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.0, 2.0, 1.5)
	cs.shape = bs
	cs.position = Vector3(0, 1, -1.5)
	exit.add_child(cs)
	stairs.add_child(exit)


func _build_encounters(rng: RandomNumberGenerator) -> void:
	var zones := Node3D.new()
	zones.name = "Incontri"
	add_child(zones)
	var enemies: Array = cfg["enemies"]
	var elites: Array = cfg["elites"]
	var ante := antechamber() if rift_grade <= 0 else -1
	for i in gen.rooms.size():
		if i == gen.start_room or gen.kinds[i] == "sacello":
			continue   # partenza e sacelli: stanze di riposo
		var r := gen.rooms[i]
		var z := EncounterZone.new()
		z.name = "Stanza%d" % i
		z.position = gen.room_center_world(i)
		z.radius = minf(r.size.x, r.size.y) * gen.tile * 0.3
		z.enemy_level = int(cfg["enemy_level"])
		z.activation_range = 32.0
		if i == gen.boss_room:
			z.unique_id = String(cfg.get("boss", ""))
			z.enemy_types = PackedStringArray(enemies)
			# Pochi servitori: le fasi del boss chiamano già i rinforzi (arena leggibile)
			z.count = 2 if rift_grade <= 0 else 7
		elif i == ante:
			# Anticamera: l'ultimo guardiano prima del boss
			z.elite = true
			z.enemy_types = PackedStringArray([elites[rng.randi_range(0, elites.size() - 1)]])
			z.count = 3
		elif gen.kinds[i] == "tesoro" or rng.randf() < 0.25:
			z.elite = true
			z.enemy_types = PackedStringArray([elites[rng.randi_range(0, elites.size() - 1)]])
			z.count = 3
		else:
			z.enemy_types = PackedStringArray(enemies)
			z.count = clampi(r.get_area() / 10, 3, 8)
		zones.add_child(z)
		rift_target += float(z.count) * (4.0 if z.elite else 1.0)
	rift_target = maxf(10.0, rift_target * DifficultyDB.RIFT_PROGRESS)


## Santuari nelle stanze (piloni nei labirinti): in una cella libera vicino al centro della stanza.
func _build_shrines(rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Extra"
	add_child(holder)
	var rooms: Array = []
	for i in gen.rooms.size():
		if i != gen.start_room and i != gen.boss_room:
			rooms.append(i)
	rooms.shuffle()
	# Il primo santuario va nel sacello (stanza di riposo), al centro
	rooms.sort_custom(func(a: int, b: int) -> bool: return gen.kinds[a] == "sacello" and gen.kinds[b] != "sacello")
	var n_shr := WorldDB.SHRINES_PER_DUNGEON if rift_grade <= 0 else 1
	var n := n_shr + (WorldDB.PYLONS_PER_RIFT if rift_grade > 0 else 0)
	for k in mini(n, rooms.size()):
		var r := gen.rooms[rooms[k]]
		var cell := Vector2i(-1, -1)
		if gen.kinds[rooms[k]] == "sacello" and gen.is_open(r.position + r.size / 2):
			cell = r.position + r.size / 2
		for t in (0 if cell.x >= 0 else 30):
			var c := r.position + Vector2i(rng.randi_range(1, r.size.x - 2), rng.randi_range(1, r.size.y - 2))
			if gen.is_open(c) and c != r.position + r.size / 2:
				cell = c
				break
		if cell.x < 0:
			continue
		var s := Shrine.new()
		s.pylon = k >= n_shr
		s.shrine_id = (WorldDB.PYLONS if s.pylon else WorldDB.SHRINES).keys().pick_random()
		s.position = gen.cell_to_world(Vector2(cell))
		holder.add_child(s)


# --- Labirinti di Dedalo ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if rift_grade > 0 and not rift_done and player != null and not player.dead:
		rift_time += delta


## Chiamato da Enemy._die: riempie la barra del labirinto; il Guardiano chiude il labirinto.
func on_enemy_died(e: Enemy) -> void:
	if rift_grade <= 0 and e.unique and e.type_id == String(cfg.get("boss", "")):
		_build_boss_exit()
		return
	if rift_grade <= 0 or rift_done:
		return
	if e == guardian:
		_complete_rift(e.global_position)
		return
	rift_kills += 1
	if guardian_spawned:
		return
	rift_progress = minf(rift_target, rift_progress + (4.0 if e.elite else 1.0))
	if rift_progress >= rift_target:
		_spawn_guardian()


func _spawn_guardian() -> void:
	guardian_spawned = true
	var gid := String(cfg.get("guardian", "custode"))
	var a := randf() * TAU
	var pos := player.global_position + Vector3(cos(a), 0, sin(a)) * 7.0
	var s := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)
	if s != Vector3.ZERO and s.y < 1.0:
		pos = Vector3(s.x, 0.0, s.z)
	guardian = Enemy.create(gid, int(cfg["enemy_level"]))
	guardian.position = pos
	enemies_root.add_child(guardian)
	guardian.display_name = "Guardiano: " + guardian.display_name
	guardian.max_life *= 3.0
	guardian.life = guardian.max_life
	if guardian.name_label:
		guardian.name_label.text = guardian.display_name
	guardian.aggro()
	Fx.pillar(dynamic_root, pos, Color(0.7, 0.4, 1.0), 14.0, 1.5)
	Fx.ring(dynamic_root, pos, 6.0, Color(0.7, 0.4, 1.0), 0.8)
	Sfx.play("guardiano", pos)
	hud.show_banner("Il Guardiano del labirinto!")


func _complete_rift(pos: Vector3) -> void:
	rift_done = true
	var lvl := int(cfg["enemy_level"])
	Loot.drop("rift", pos, lvl)
	for i in rift_grade / 10:
		Loot.spawn_item(ItemDB.generate(lvl, Item.Rarity.LEGGENDARIO, Game.hero.class_id), pos)
	var msg := "Labirinto completato in %d:%02d." % [int(rift_time) / 60, int(rift_time) % 60]
	# Gemma leggendaria: sempre la prima volta, poi 40%, una che non hai ancora
	var owned := {}
	for g: Dictionary in Game.hero.owned_legendary_gems():
		owned[ItemDB.leg_gem_id(String(g["key"]))] = true
	var missing: Array = []
	for id: String in ItemDB.LEGENDARY_GEMS:
		if not owned.has(id):
			missing.append(id)
	if not missing.is_empty() and (owned.is_empty() or randf() < 0.4):
		var gd := LootDrop.make_gem(ItemDB.leg_gem_key(String(missing.pick_random()), 1))
		gd.position = pos + Vector3(-1.5, 0, 1.0)
		dynamic_root.add_child(gd)
	_record_rift()
	if rift_time <= DifficultyDB.RIFT_TIME:
		gem_upgrades_left = ItemDB.LEG_GEM_UPGRADES
		offer_gem_upgrade.call_deferred()
		var up := 2 if rift_time <= DifficultyDB.RIFT_FAST else 1
		var new_max := maxi(int(Game.hero.flags.get("rift_max", 1)), rift_grade + up)
		Game.hero.flags["rift_max"] = new_max
		msg += " Sbloccato il grado %d!" % new_max
	else:
		msg += " Troppo tardi per salire di grado."
	Game.hero.flags["rift_best"] = maxi(int(Game.hero.flags.get("rift_best", 0)), rift_grade if rift_time <= DifficultyDB.RIFT_TIME else 0)
	hud.show_banner("Labirinto completato!")
	hud.show_message(msg, 6.0)
	# Uscita accanto al Guardiano
	var exit := LevelExit.new()
	exit.name = "UscitaLabirinto"
	exit.title = "Torna in città"
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 2.0
	cs.shape = cyl
	cs.position.y = 1.0
	exit.add_child(cs)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.3
	ring.mesh = tm
	ring.material_override = Fx.mat(Color(0.7, 0.4, 1.0), 4.0, false, true)
	ring.rotation_degrees.x = 90.0
	ring.position.y = 1.4
	exit.add_child(ring)
	exit.position = pos + Vector3(2.5, 0, 0)
	add_child(exit)


## Uscita nella stanza del boss, quando è sconfitto (anche entrando di nuovo dopo averlo già ucciso):
## si torna all'entrata del dungeon senza rifare a piedi le stanze vuote.
func _build_boss_exit() -> void:
	if get_node_or_null("UscitaBoss") != null:
		return
	var exit := LevelExit.new()
	exit.name = "UscitaBoss"
	exit.title = "Uscita"
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 2.0
	cs.shape = cyl
	cs.position.y = 1.0
	exit.add_child(cs)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.3
	ring.mesh = tm
	ring.material_override = Fx.mat(Color(0.7, 0.85, 1.0), 4.0, false, true)
	ring.rotation_degrees.x = 90.0
	ring.position.y = 1.4
	exit.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.85, 1.0)
	light.light_energy = 1.5
	light.omni_range = 7.0
	light.position.y = 2.5
	exit.add_child(light)
	var r := gen.rooms[gen.boss_room]
	var cell := r.position + r.size / 2 + Vector2i(0, 2)
	if not gen.is_open(cell):
		cell = r.position + r.size / 2
	exit.position = gen.cell_to_world(Vector2(cell))
	add_child(exit)


## Record personali dei labirinti (i 10 migliori: grado più alto, poi tempo più basso).
func _record_rift() -> void:
	var recs: Array = Game.hero.flags.get("rift_records", [])
	recs.append({"grade": rift_grade, "time": roundi(rift_time), "kills": rift_kills, "ok": rift_time <= DifficultyDB.RIFT_TIME})
	recs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["ok"]) != bool(b["ok"]):
			return bool(a["ok"])
		if int(a["grade"]) != int(b["grade"]):
			return int(a["grade"]) > int(b["grade"])
		return int(a["time"]) < int(b["time"]))
	Game.hero.flags["rift_records"] = recs.slice(0, 10)


## Dopo un labirinto in tempo: 3 tentativi di potenziare una gemma leggendaria.
func offer_gem_upgrade() -> void:
	if gem_upgrades_left <= 0:
		return
	var gems: Array = Game.hero.owned_legendary_gems()
	if gems.is_empty():
		gem_upgrades_left = 0
		return
	var opts: Array = []
	for g: Dictionary in gems:
		var ch := ItemDB.leg_gem_upgrade_chance(ItemDB.leg_gem_rank(String(g["key"])), rift_grade)
		opts.append(["%s – %d%%" % [ItemDB.gem_name(String(g["key"])), roundi(ch * 100.0)], try_gem_upgrade.bind(g), ch <= 0.0])
	hud.show_choice("Potenzia una gemma leggendaria",
		"Tentativi rimasti: %d. La probabilità dipende dal grado del labirinto (%d) rispetto a quello della gemma." % [gem_upgrades_left, rift_grade], opts)


func try_gem_upgrade(entry: Dictionary, roll: float = -1.0) -> bool:
	if gem_upgrades_left <= 0:
		return false
	gem_upgrades_left -= 1
	var ok: bool = Game.hero.upgrade_legendary_gem(entry, rift_grade, roll)
	hud.show_message(("Potenziamento riuscito: " if ok else "Potenziamento fallito: ") + ItemDB.gem_name(String(entry["key"])), 2.5)
	Sfx.play("potenziamento_ok" if ok else "potenziamento_fallito")
	player.refresh_stats()
	hud.hide_choice()
	offer_gem_upgrade.call_deferred()
	return ok


## L'uscita riporta davanti all'entrata da cui si è scesi.
func on_exit_reached(exit: LevelExit) -> void:
	var info: Dictionary = Game.hero.flags.get("dungeon", {})
	var back := String(info.get("return_level", "level_01"))
	if rift_grade > 0:
		Game.hero.flags.erase("dungeon")
	else:
		Game.hero.flags["completed_dungeon_" + dungeon_id] = true
	Sfx.play("portale")
	if info.has("x"):
		Game.travel(back, "", Vector3(float(info["x"]), 0.0, float(info["z"])))
	else:
		Game.travel(back)
