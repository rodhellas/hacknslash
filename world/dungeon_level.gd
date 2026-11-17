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


func _ready() -> void:
	var info: Dictionary = {}
	if Game.hero != null:
		info = Game.hero.flags.get("dungeon", {})
	dungeon_id = String(info.get("id", DungeonDB.DUNGEONS.keys()[0]))
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
	_mesh(body, st, cfg["floor"])


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
	_mesh(body, tall, col)
	_mesh(body, low, col.darkened(0.15))


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


func _mesh(body: Node3D, st: SurfaceTool, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := st.commit()
	mi.mesh = m
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
		# Oggetti lungo i bordi della stanza (il centro resta libero per combattere)
		for pr: Array in props:
			if rng.randf() < float(pr[1]):
				var n := rng.randi_range(1, 3)
				for k in n:
					var p := _room_edge_point(r, rng)
					_prop(deco, String(pr[0]), p, rng.randf_range(0, 360))
	# Forzieri: uno decorato nella stanza del boss, uno normale in un paio di altre stanze
	var boss_c := gen.room_center_world(gen.boss_room) + Vector3(0, 0, -gen.rooms[gen.boss_room].size.y * gen.tile * 0.35)
	_chest(deco, boss_c, true)
	for k in 2:
		var i := rng.randi_range(1, gen.rooms.size() - 1)
		if i != gen.boss_room:
			_chest(deco, _room_edge_point(gen.rooms[i], rng), false)


## Punto vicino al bordo di una stanza, lontano dagli sbocchi dei corridoi.
func _room_edge_point(r: Rect2i, rng: RandomNumberGenerator) -> Vector3:
	var inner := Vector2(r.size) - Vector2(1.6, 1.6)
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
		best = Vector2(r.position) + Vector2(0.3, 0.3) + p
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
	var ps := load("res://scenes/props/%s.tscn" % pname) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = rot
	parent.add_child(inst)
	return inst


func _chest(parent: Node3D, pos: Vector3, rich: bool) -> void:
	var ch := _prop(parent, "forziere", pos, 0.0)
	if ch != null:
		ch.set("item_level", area_level)
		ch.set("rich", rich)


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
	world.bake_navigation_mesh(false)


# --- Uscita e nemici ---------------------------------------------------------------------------

## Scala di risalita sul lato nord della stanza di partenza.
func _build_exit() -> void:
	var r := gen.rooms[gen.start_room]
	var c := gen.room_center_world(gen.start_room)
	var pos := c + Vector3(0, 0, -r.size.y * gen.tile * 0.5 + 1.5)
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
	for i in gen.rooms.size():
		if i == gen.start_room:
			continue
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
			z.count = 4
		elif rng.randf() < 0.25:
			z.elite = true
			z.enemy_types = PackedStringArray([elites[rng.randi_range(0, elites.size() - 1)]])
			z.count = 3
		else:
			z.enemy_types = PackedStringArray(enemies)
			z.count = clampi(r.get_area() / 10, 3, 8)
		zones.add_child(z)


## L'uscita riporta davanti all'entrata da cui si è scesi.
func on_exit_reached(exit: LevelExit) -> void:
	var info: Dictionary = Game.hero.flags.get("dungeon", {})
	var back := String(info.get("return_level", "level_01"))
	Game.hero.flags["completed_dungeon_" + dungeon_id] = true
	Sfx.play("portal")
	if info.has("x"):
		Game.travel(back, "", Vector3(float(info["x"]), 0.0, float(info["z"])))
	else:
		Game.travel(back)
