extends "res://tools/build_world.gd"
## GENERATORE del livello 3: PORTO DI OSTIA NOVA (atto 2). Riusa le funzioni di build_world.gd.
## Crea scenes/levels/level_03_porto.tscn (+ navmesh) e, se mancano, i nuovi props e modelli.
##
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_porto.gd
## ATTENZIONE: SOVRASCRIVE level_03_porto.tscn. Dopo averlo ritoccato a mano non rigenerarlo.
##
## Percorso sud → nord (circa 620 m), il mare è a est:
##   porta del porto (arrivo da Ostia Nova) → Via del Porto → Magazzini (deviazione a ovest:
##   magazzino del sale, missione "Merce rubata"; moli a est) → Cantieri navali (altare, deviazione
##   a ovest: cantiere) → Spazioporto (piattaforme, navetta corsara) → Faro (boss Vulso il Corsaro).

const PCELL := 8.0
const PX0 := -112.0
const PZ0 := 32.0
const PNX := 28
const PNZ := 81

const P_ROAD := [
	Vector2(0, 14), Vector2(0, -50), Vector2(-20, -110), Vector2(-22, -190), Vector2(8, -250),
	Vector2(12, -330), Vector2(-12, -400), Vector2(-8, -470), Vector2(18, -525),
]
const P_HW := [20, 24, 24, 24, 24, 24, 24, 24]
## Aree laterali (centro, raggio, zona)
const P_SIDE := [
	[Vector2(-64, -160), 24.0, "sale"],
	[Vector2(-60, -320), 26.0, "cantiere"],
	[Vector2(26, -445), 30.0, "spazioporto"],
	[Vector2(20, -550), 30.0, "faro"],
]
## Sentieri (da, a, mezza larghezza)
const P_PATHS := [
	[Vector2(-25, -160), Vector2(-48, -160), 9.0],
	[Vector2(-5, -318), Vector2(-40, -320), 9.0],
	[Vector2(10, -140), Vector2(46, -140), 5.0],
	[Vector2(15, -284), Vector2(46, -284), 6.0],
	[Vector2(5, -380), Vector2(46, -380), 5.0],
]
## Moli nel mare: [x inizio, x fine, z centro, mezza larghezza]
## (le z dei moli sono allineate alle celle di 8 m: z = 4 modulo 8)
const P_PIERS := [[32.0, 82.0, -140.0, 4.0], [32.0, 92.0, -284.0, 4.0], [32.0, 78.0, -380.0, 4.0]]

## Zone, colori e vegetazione: data/map_zones.gd
const WATER := Color(0.12, 0.32, 0.5)

var p_cum: Array = []
var p_total := 0.0


func _generate() -> void:
	rng.seed = SEED + 3
	_build_props(true)
	_build_models(true)
	_p_compute_road()
	_build_porto()
	print("Generazione del porto completata.")
	quit()


# --- Geometria ------------------------------------------------------------------------------------

func _p_compute_road() -> void:
	p_cum = [0.0]
	for i in range(1, P_ROAD.size()):
		p_total += (P_ROAD[i] as Vector2).distance_to(P_ROAD[i - 1])
		p_cum.append(p_total)


func _p_road_info(p: Vector2) -> Array:
	var best := [INF, 0.0]
	for i in P_ROAD.size() - 1:
		var r := _seg_dist(p, P_ROAD[i], P_ROAD[i + 1])
		if r[0] < best[0]:
			best = [r[0], float(p_cum[i]) + (P_ROAD[i + 1] as Vector2).distance_to(P_ROAD[i]) * float(r[1])]
	return best


func _p_road_point(s: float) -> Array:
	s = clampf(s, 0.0, p_total - 0.01)
	for i in P_ROAD.size() - 1:
		if s <= p_cum[i + 1]:
			var a: Vector2 = P_ROAD[i]
			var b: Vector2 = P_ROAD[i + 1]
			return [a.lerp(b, (s - float(p_cum[i])) / a.distance_to(b)), (b - a).normalized()]
	return [P_ROAD[-1], Vector2.UP]


func _shore_x(z: float) -> float:
	return 44.0 + 8.0 * sin(z * 0.015)


func _is_water(p: Vector2) -> bool:
	return p.x > _shore_x(p.y)


func _on_pier(p: Vector2) -> bool:
	for pr: Array in P_PIERS:
		if p.x >= float(pr[0]) - 2.0 and p.x <= float(pr[1]) and absf(p.y - float(pr[2])) <= float(pr[3]):
			return true
	return false


func _allowed(p: Vector2) -> bool:
	if _on_pier(p):
		return true
	if _is_water(p):
		return false
	for i in P_ROAD.size() - 1:
		if float(_seg_dist(p, P_ROAD[i], P_ROAD[i + 1])[0]) <= P_HW[i]:
			return true
	for sd: Array in P_SIDE:
		if p.distance_to(sd[0]) <= float(sd[1]):
			return true
	for c: Array in P_PATHS:
		if float(_seg_dist(p, c[0], c[1])[0]) <= float(c[2]):
			return true
	return false


# --- Livello --------------------------------------------------------------------------------------

func _build_porto() -> void:
	level_root = Node3D.new()
	level_root.name = "PortoOstia"
	get_root().add_child(level_root)
	_build_environment()
	var region := NavigationRegion3D.new()
	region.name = "World"
	level_root.add_child(region)
	region.owner = level_root

	var pois := _group(region, "Luoghi")
	_p_start(pois)
	_p_magazzini(pois)
	_p_moli(pois)
	_p_cantieri(pois)
	_p_spazioporto(pois)
	_p_faro(pois)
	_p_shape()
	_p_encounters()

	for m: Array in [["PlayerStart", Vector3(0, 0, 4)], ["DaOstia", Vector3(0, 0, 4)]]:
		var mk := Marker3D.new()
		mk.name = m[0]
		mk.position = m[1]
		level_root.add_child(mk)
		mk.owner = level_root
	var exit: Area3D = load("res://world/level_exit.gd").new()
	exit.name = "UscitaOstiaNova"
	exit.position = Vector3(0, 0, 15)
	exit.set("title", "Ostia Nova")
	exit.set("target_level", "ostia_nova")
	exit.set("target_spawn", "DalPorto")
	var ecs := CollisionShape3D.new()
	var ebs := BoxShape3D.new()
	ebs.size = Vector3(10, 4, 3)
	ecs.shape = ebs
	ecs.position.y = 2
	exit.add_child(ecs)
	level_root.add_child(exit)
	exit.owner = level_root
	ecs.owner = level_root

	# Terreno, confini, strade, mare, vegetazione, lampioni e navmesh dalla Forma
	print(load("res://tools/map_builder.gd").new().build(level_root, true))

	get_root().remove_child(level_root)
	level_root.set_script(load("res://world/level.gd"))
	level_root.set("level_id", "level_03_porto")
	level_root.set("level_title", "Porto di Ostia Nova")
	level_root.set("area_level", 8)
	level_root.set("intro_text", "Il porto di Ostia Nova: magazzini sventrati, gru ferme, navi in fiamme. Le vele rosse dei pirati cilici sventolano sui moli.\n\n[TRAMA: cosa trova l'eroe al porto.]")
	level_root.set("exit_text", "[TRAMA: fine dell'atto 2.]")
	_save_scene(level_root, "res://scenes/levels/level_03_porto.tscn")
	print("Porto salvato. Lunghezza del percorso: %d m" % roundi(p_total))
	level_root.free()


## Oggetto al lato della strada all'ascissa s (offset > 0 = a destra guardando verso nord).
func _beside(s: float, offset: float) -> Array:
	var rp := _p_road_point(s)
	var d: Vector2 = rp[1]
	return [(rp[0] as Vector2) + _perp(d) * offset, d]


## FORMA del porto (modificabile poi nell'editor): strada principale con le zone, aree laterali,
## sentieri, moli sopra il mare, il mare a est della costa e le radure da tenere libere.
func _p_shape() -> void:
	var forma: Node3D = load("res://world/map_shape.gd").new()
	forma.name = "Forma"
	forma.set("seed", SEED + 3)
	forma.set("default_zone", "strada")
	forma.set("background_color", WATER)
	forma.set("background_y", -0.35)
	forma.set("water_color", WATER)
	level_root.add_child(forma)
	forma.owner = level_root
	var widths := PackedFloat32Array()
	for i in P_ROAD.size():
		widths.append(float(maxi(P_HW[maxi(i - 1, 0)], P_HW[mini(i, P_HW.size() - 1)])))
	_shape_road(forma, "ViaDelPorto", P_ROAD, widths, {"paved_width": 7.0, "paved_color": Color(0.64, 0.61, 0.56),
		"zone_breaks": PackedStringArray(["0=strada", "0.16=magazzini", "0.42=cantieri", "0.64=spazioporto", "0.86=faro"]),
		"lamp_spacing": 34.0})
	var i := 0
	for sd: Array in P_SIDE:
		_shape_area(forma, "Area_%s" % sd[2], sd[0], float(sd[1]), {"zone": sd[2]})
	for c: Array in P_PATHS:
		var w := float(c[2])
		_shape_road(forma, "Sentiero_%d" % i, [c[0], c[1]], PackedFloat32Array([w, w]), {"paved_width": w * 1.4, "paved_color": Color(0.58, 0.55, 0.5)})
		i += 1
	i = 0
	for pr: Array in P_PIERS:
		var hw := float(pr[3])
		_shape_road(forma, "Molo_%d" % i, [Vector2(float(pr[0]) - 6.0, float(pr[2])), Vector2(float(pr[1]), float(pr[2]))],
			PackedFloat32Array([hw, hw]), {"paved_width": hw * 2.0, "paved_color": Color(0.45, 0.32, 0.2), "over_water": true, "zone": "molo"})
		i += 1
	# Mare: tutto ciò che sta a est della costa
	var sea := PackedVector2Array()
	var z := PZ0 + 40.0
	while z >= -700.0:
		sea.append(Vector2(_shore_x(z), z))
		z -= 8.0
	sea.append(Vector2(400.0, -700.0))
	sea.append(Vector2(400.0, PZ0 + 40.0))
	_shape_polygon(forma, "Mare", sea, {"mode": "acqua"})
	i = 0
	for c: Array in _clear:
		if float(c[1]) >= 8.0:
			_shape_area(forma, "Radura_%d" % i, c[0], float(c[1]), {"walkable": false, "scatter": false})
			i += 1


# --- Luoghi ---------------------------------------------------------------------------------------

func _p_start(parent: Node) -> void:
	var g := _group(parent, "PortaDelPorto")
	_place("porta_citta", g, Vector2(0, 20))
	for x: float in [-14.0, -20.0, 14.0, 20.0]:
		_place("muro", g, Vector2(x, 20))
	_clear.append([Vector2(0, 8), 12.0])
	_place("altare", g, Vector2(-9, -6), 0.0, 1.0, {"checkpoint_id": "porto_ingresso", "title": "Altare di Nettuno"})
	_place("cartello", g, Vector2(8, -4), 0.0, 1.0, {"title": "Via del Porto",
		"text": "La strada scende verso i moli. Dai magazzini sale fumo nero.\n\n[TRAMA]"})
	_place("stendardo", g, Vector2(-6, 14))
	_place("stendardo", g, Vector2(6, 14))


func _p_magazzini(parent: Node) -> void:
	var g := _group(parent, "Magazzini")
	var s := float(p_cum[1]) + 10.0
	var side := -1.0
	while s < float(p_cum[3]) + 20.0:
		var b := _beside(s, 18.0 * side)
		var p: Vector2 = b[0]
		var d: Vector2 = b[1]
		if _is_clear(p) and _allowed(p) and not _is_water(p + _perp(d) * 8.0 * side):
			_place("magazzino", g, p, rad_to_deg(atan2(-d.y, d.x)) + (90.0 if side > 0 else -90.0))
			_clear.append([p, 10.0])
		side = -side
		s += 24.0
	# Magazzino del sale (ovest): missione "Merce rubata"
	var c := Vector2(-64, -160)
	_clear.append([c, 12.0])
	_place("magazzino", g, c + Vector2(-8, -14), 0.0)
	_place("magazzino", g, c + Vector2(-14, 8), 90.0)
	_place("forziere", g, c + Vector2(2, -2), 90.0, 1.0, {"flag_id": "chest_porto_sale", "item_level": 7, "rich": true})
	for i in 4:
		_place("pila_casse", g, c + Vector2(8 + (i % 2) * 3.2, -8 + i * 4.0), rng.randf() * 30.0)
	_place("cartello", g, Vector2(-30, -152), 90.0, 1.0, {"title": "Magazzino del sale",
		"text": "Proprietà di Tito Mercatore. Vietato l'ingresso ai non autorizzati.\n\nQualcuno ha forzato la porta."})


func _p_moli(parent: Node) -> void:
	var g := _group(parent, "Moli")
	for pr: Array in P_PIERS:
		var z := float(pr[2])
		var x1 := float(pr[1])
		var hw := float(pr[3])
		var x := float(pr[0]) + 4.0
		while x < x1 - 2.0:
			_place("bitta", g, Vector2(x, z - hw + 0.6))
			x += 9.0
		_place("nave", g, Vector2((float(pr[0]) + x1) * 0.5 + 4.0, z - hw - 5.5), 90.0)
		_place("lampione_plasma", g, Vector2(x1 - 2.0, z + hw - 1.0))
		_place("pila_casse", g, Vector2(x1 - 6.0, z + 1.0), 20.0)
	_place("forziere", g, Vector2(88, -284), -90.0, 1.0, {"flag_id": "chest_porto_molo", "item_level": 7})
	_place("nave", g, Vector2(70, -215), 10.0)


func _p_cantieri(parent: Node) -> void:
	var g := _group(parent, "Cantieri")
	# Gru lungo la riva
	var s := float(p_cum[4]) + 5.0
	while s < float(p_cum[5]) + 10.0:
		var b := _beside(s, 20.0)
		var p: Vector2 = b[0]
		if _allowed(p) and _is_clear(p):
			_place("gru", g, p, 180.0)
			_clear.append([p, 4.0])
		s += 26.0
	var cp := Vector2(-6, -304)
	_place("altare", g, cp, 0.0, 1.0, {"checkpoint_id": "porto_cantiere", "title": "Altare di Minerva"})
	_clear.append([cp, 4.0])
	# Cantiere navale (ovest): nave in costruzione
	var c := Vector2(-60, -320)
	_clear.append([c, 15.0])
	_place("nave", g, c + Vector2(-4, 0), 0.0, 1.0)
	_place("gru", g, c + Vector2(10, -12), 90.0)
	_place("gru", g, c + Vector2(-16, 14), -90.0)
	for i in 5:
		_place("tronco", g, c + Vector2(8 + rng.randf_range(-2, 2), 4 + i * 1.2), rng.randf_range(-10, 10))
	_place("forziere", g, c + Vector2(6, 12), 180.0, 1.0, {"flag_id": "chest_porto_cantiere", "item_level": 8, "rich": true})
	_place("cartello", g, Vector2(4, -296), 0.0, 1.0, {"title": "Cantieri navali",
		"text": "Qui si costruivano le triremi stellari della flotta di Ostia.\n\n[TRAMA]"})


func _p_spazioporto(parent: Node) -> void:
	var g := _group(parent, "Spazioporto")
	var c := Vector2(26, -445)
	_clear.append([c, 20.0])
	_place("piattaforma", g, c + Vector2(-8, 10))
	_place("piattaforma", g, c + Vector2(10, -10))
	_place("relitto_navetta", g, c + Vector2(10, -10), 30.0)
	_place("torre_guardia", g, c + Vector2(-18, -12))
	_place("torre_guardia", g, c + Vector2(8, 22))
	for p: Vector2 in [c + Vector2(-16, 4), c + Vector2(0, -22), c + Vector2(10, 4)]:
		_place("lampione_plasma", g, p)
	_place("stendardo", g, c + Vector2(-4, -2))
	var cp := Vector2(-4, -418)
	_place("altare", g, cp, 0.0, 1.0, {"checkpoint_id": "porto_spazioporto", "title": "Altare di Mercurio"})
	_clear.append([cp, 4.0])
	_place("forziere", g, c + Vector2(-10, 20), 0.0, 1.0, {"flag_id": "chest_porto_spazioporto", "item_level": 8})


func _p_faro(parent: Node) -> void:
	var g := _group(parent, "Faro")
	var c := Vector2(20, -550)
	_clear.append([c, 18.0])
	_place("faro", g, c + Vector2(0, -20))
	_clear.append([c + Vector2(0, -20), 6.0])
	_place("falo", g, c + Vector2(-8, 4))
	_place("falo", g, c + Vector2(9, -3))
	_place("tenda", g, c + Vector2(-14, -8), 30.0)
	_place("tenda", g, c + Vector2(14, 8), -40.0)
	_place("stendardo", g, c + Vector2(-5, -12))
	_place("stendardo", g, c + Vector2(5, -12))
	_place("forziere", g, c + Vector2(-10, -18), 0.0, 1.0, {"flag_id": "chest_porto_faro", "item_level": 9, "rich": true})
	_place("cartello", g, c + Vector2(8, 16), 0.0, 1.0, {"title": "Il faro di Ostia Nova",
		"text": "La luce del faro guida le navi fino a Nova Roma. Ora è il covo di Vulso il Corsaro.\n\n[TRAMA: atto 3]"})


func _p_encounters() -> void:
	var g := Node3D.new()
	g.name = "Incontri"
	level_root.add_child(g)
	g.owner = level_root
	# [nome, posizione, tipi, numero, livello, elite, boss]
	var list := [
		["Pirati_ingresso", Vector2(0, -42), ["pirata"], 4, 6, false, ""],
		["Granchi_strada", Vector2(-12, -82), ["granchio"], 6, 6, false, ""],
		["Pirati_strada", Vector2(-20, -120), ["pirata", "arpionatore"], 5, 6, false, ""],
		["Magazzini_1", Vector2(-22, -170), ["pirata", "pirata", "arpionatore"], 6, 6, false, ""],
		["Sale_campioni", Vector2(-64, -162), ["pirata"], 3, 7, true, ""],
		["Sale_ciurma", Vector2(-50, -150), ["pirata", "arpionatore"], 4, 7, false, ""],
		["Molo_1", Vector2(62, -140), ["pirata", "granchio"], 5, 7, false, ""],
		["Automa_magazzini", Vector2(-12, -215), ["automa", "granchio", "granchio"], 3, 7, false, ""],
		["Pirati_curva", Vector2(8, -255), ["pirata", "arpionatore"], 6, 7, false, ""],
		["Molo_2", Vector2(66, -284), ["arpionatore", "pirata"], 5, 7, false, ""],
		["Cantiere_operai", Vector2(-56, -318), ["automa", "pirata", "pirata"], 4, 8, false, ""],
		["Cantiere_campioni", Vector2(-48, -334), ["arpionatore"], 3, 8, true, ""],
		["Gru_pirati", Vector2(12, -335), ["pirata", "granchio"], 6, 8, false, ""],
		["Molo_3", Vector2(60, -380), ["granchio"], 7, 8, false, ""],
		["Strada_spazioporto", Vector2(-12, -398), ["pirata", "arpionatore"], 6, 8, false, ""],
		["Droni_spazioporto", Vector2(22, -432), ["drone"], 5, 8, false, ""],
		["Spazioporto_ciurma", Vector2(34, -458), ["pirata", "arpionatore", "automa"], 6, 9, false, ""],
		["Spazioporto_campioni", Vector2(14, -455), ["automa"], 2, 9, true, ""],
		["Strada_faro", Vector2(-8, -485), ["pirata", "granchio"], 6, 9, false, ""],
		["Boss_Vulso", Vector2(20, -548), ["pirata", "arpionatore"], 4, 9, false, "vulso"],
	]
	for e: Array in list:
		var z: Node3D = load("res://world/encounter_zone.gd").new()
		z.name = e[0]
		z.position = _v3(e[1])
		z.set("enemy_types", PackedStringArray(e[2]))
		z.set("count", e[3])
		z.set("enemy_level", e[4])
		z.set("elite", e[5])
		z.set("unique_id", e[6])
		z.set("radius", 7.0 if e[3] > 4 else 5.0)
		g.add_child(z)
		z.owner = level_root
		if not _allowed(e[1]):
			push_warning("Incontro %s fuori dall'area giocabile" % e[0])
	print("Incontri: %d" % list.size())
