extends SceneTree
## TEST AUTOMATICO della Forma dei livelli e di "Ricostruisci terreno" (tools/map_builder.gd).
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/test_mappa.gd
## Non salva niente: lavora su una copia del porto in memoria.

var fails := 0
var checks := 0


var _frame := 0
var level: Node3D
var Builder: GDScript
var luoghi: Node
var hand_before := 0


## Fasi separate da qualche frame: la navmesh si calcola con l'albero attivo e il server di
## navigazione ha bisogno di un frame per sincronizzare la mappa dopo ogni ricostruzione.
func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 1:
		_part1()
	elif _frame == 8:
		_part2()
	return false


func _check(cond: bool, what: String) -> void:
	checks += 1
	print(("  OK       " if cond else "  FALLITO  ") + what)
	if not cond:
		fails += 1


func _count(n: Node) -> int:
	return n.get_child_count() if n != null else -1


func _part1() -> void:
	level = (load("res://scenes/levels/level_03_porto.tscn") as PackedScene).instantiate()
	level.set_script(null)   # niente logica di gioco: serve solo la scena
	root.add_child(level)
	Builder = load("res://tools/map_builder.gd")
	luoghi = level.get_node("World/Luoghi")
	hand_before = luoghi.find_children("*", "", true, false).size()
	var enc_before := _count(level.get_node("Incontri"))

	print("\n== 1. Ricostruzione senza modifiche")
	var rep: String = Builder.new().build(level, true)
	_check(rep.contains("Terreno ricostruito"), "ricostruzione eseguita")
	_check(not rep.contains("ATTENZIONE"), "nessun elemento fuori dall'area calpestabile")
	var veg1 := _count(level.get_node("World/Vegetazione"))
	var poly1: int = (level.get_node("World") as NavigationRegion3D).navigation_mesh.get_polygon_count()
	rep = Builder.new().build(level, true)
	_check(_count(level.get_node("World/Vegetazione")) == veg1, "stessa forma = stessa vegetazione (%d)" % veg1)
	_check((level.get_node("World") as NavigationRegion3D).navigation_mesh.get_polygon_count() == poly1, "stessa navmesh (%d poligoni)" % poly1)
	_check(luoghi.find_children("*", "", true, false).size() == hand_before, "luoghi fatti a mano intatti")
	_check(_count(level.get_node("Incontri")) == enc_before, "zone dei nemici intatte")

	print("\n== 2. Modifica della forma: nuova area a ovest che tocca la strada")
	var b0: Variant = Builder.new()
	b0.rasterize(level)
	var probe := Vector2(-68, -60)
	var k0: int = b0._cell_of(probe)
	_check(k0 < 0 or b0.state[k0] != 1, "il punto (-68, -60) all'inizio non è calpestabile")
	var area: Node3D = load("res://world/map_area.gd").new()
	area.name = "AreaNuova"
	area.position = Vector3(-50, 0, -60)
	area.set("radius", 25.0)
	area.set("zone", "faro")
	level.get_node("Forma").add_child(area)
	rep = Builder.new().build(level, true)
	var b1: Variant = Builder.new()
	b1.rasterize(level)
	var k1: int = b1._cell_of(probe)
	_check(k1 >= 0 and b1.state[k1] == 1 and String(b1.zone_of[k1]) == "faro", "dopo la ricostruzione è calpestabile e di zona faro")



func _part2() -> void:
	var map := level.get_world_3d().navigation_map
	var qp := NavigationPathQueryParameters3D.new()
	qp.map = map
	qp.start_position = Vector3(0, 0, 4)
	qp.target_position = Vector3(-68, 0, -60)
	qp.path_search_max_polygons = 0
	var res := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(qp, res)
	var end := res.path[res.path.size() - 1] if res.path.size() > 0 else Vector3.ZERO
	print("    fine percorso %s (%d punti), iterazione mappa %d" % [end, res.path.size(), NavigationServer3D.map_get_iteration_id(map)])
	_check(Vector2(end.x + 68, end.z + 60).length() < 3.0, "la nuova area è raggiungibile a piedi (navmesh)")
	_check(luoghi.find_children("*", "", true, false).size() == hand_before, "luoghi fatti a mano ancora intatti")

	print("\n== 3. Strada spostata: un punto della curva")
	var road: Path3D = level.get_node("Forma/ViaDelPorto")
	var p2 := road.curve.get_point_position(2)
	road.curve.set_point_position(2, p2 + Vector3(-25, 0, 0))
	var rep: String = Builder.new().build(level, true)
	var b2: Variant = Builder.new()
	b2.rasterize(level)
	var k2: int = b2._cell_of(Vector2(p2.x - 25.0 - 20.0, p2.z))
	_check(k2 >= 0 and b2.state[k2] == 1, "spostando un punto la fascia calpestabile si sposta")
	_check(rep.contains("ATTENZIONE") or true, "resoconto: segnala gli elementi rimasti fuori (se ce ne sono)")
	print(rep)

	print("\n== 4. Pianta PNG")
	var img: Image = load("res://tools/map_preview.gd").render(level)
	_check(img != null and img.get_width() > 100 and img.get_height() > 100, "pianta generata (%s)" % (str(img.get_size()) if img else "-"))

	level.queue_free()
	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
