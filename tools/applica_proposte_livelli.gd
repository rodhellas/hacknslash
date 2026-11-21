extends SceneTree
## Applica ai livelli fatti a mano le proposte di docs/PROPOSTE_LIVELLI.md (20-11-2026):
## percorsi, arene, segreti e ritmo degli incontri di Campagna di Lazio Prime, Ostia Nova e Porto.
## Modifica i .tscn (non rigenera i livelli), poi "Ricostruisci terreno" + navmesh (tools/map_builder.gd),
## controlla che segreti e arene siano raggiungibili a piedi e solo allora salva.
## Si può rilanciare: ciò che esiste già non viene duplicato.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/applica_proposte_livelli.gd
##       (aggiungi "-- prova" per non salvare)

const LEVELS := [
	["res://scenes/levels/level_01.tscn", "_level_01"],
	["res://scenes/levels/level_02_ostia.tscn", "_ostia"],
	["res://scenes/levels/level_03_porto.tscn", "_porto"],
]

var _frame := 0
var _idx := 0
var level: Node3D
var script_backup: Script
var root_props := {}
var checks: Array = []   # [nome, da, a] percorsi da verificare
var save := true
var errors := 0


func _initialize() -> void:
	save = not OS.get_cmdline_user_args().has("prova")
	seed(20261120)   # cespugli degli imbocchi sempre uguali
	load("res://world/map_shape.gd").keep_in_game = true


func _process(_d: float) -> bool:
	_frame += 1
	if _idx >= LEVELS.size():
		print("\nFatto. Errori: %d%s" % [errors, "" if save else " (prova: niente salvato)"])
		quit(1 if errors > 0 else 0)
		return true
	if _frame == 1:
		_load_and_apply()
	elif _frame == 10:
		_verify_and_save()
		_idx += 1
		_frame = 0
	return false


# --- Caricamento, ricostruzione, verifica, salvataggio ---------------------------------------------

func _load_and_apply() -> void:
	var path: String = LEVELS[_idx][0]
	print("\n== %s" % path.get_file())
	level = (load(path) as PackedScene).instantiate()
	# Niente logica di gioco del livello mentre lo si modifica: si toglie lo script della radice
	# (ricordando le sue proprietà) e lo si rimette prima di salvare.
	script_backup = level.get_script()
	root_props = {}
	for p: Dictionary in level.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(p["usage"]) & PROPERTY_USAGE_STORAGE:
			root_props[p["name"]] = level.get(p["name"])
	level.set_script(null)
	root.add_child(level)
	NavigationServer3D.region_set_use_async_iterations((level.get_node("World") as NavigationRegion3D).get_rid(), false)
	NavigationServer3D.map_set_use_async_iterations(level.get_world_3d().navigation_map, false)
	checks = []
	reach_checks = []
	call(LEVELS[_idx][1])
	var rep: String = load("res://tools/map_builder.gd").new().build(level, true)
	for line: String in rep.split("\n"):
		if line.contains("ATTENZIONE") or line.contains("fuori") or line.begins_with("Terreno") or line.begins_with("Navmesh"):
			print("   ", line)


func _verify_and_save() -> void:
	var map := level.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(map)
	for c: Array in checks:
		var params := NavigationPathQueryParameters3D.new()
		params.map = map
		params.start_position = _v3(c[1])
		params.target_position = _v3(c[2])
		params.path_search_max_polygons = 0
		var res := NavigationPathQueryResult3D.new()
		NavigationServer3D.query_path(params, res)
		var pts := res.path
		var ok := pts.size() > 1 and Vector2(pts[-1].x, pts[-1].z).distance_to(c[2]) < 2.5
		if c.size() > 3:
			# Soglia: chi passa di lato deve fare il giro dal varco (percorso molto più lungo della linea d'aria)
			var length := 0.0
			for k in range(1, pts.size()):
				length += pts[k - 1].distance_to(pts[k])
			ok = ok and length > (c[1] as Vector2).distance_to(c[2]) + float(c[3])
			if not ok:
				var simple: Array = []
				for q in pts:
					simple.append(Vector2(q.x, q.z).round())
				print("      percorso: ", simple)
		print("   %s %s%s" % ["OK      " if ok else "NON RAGGIUNGIBILE", c[0], "" if ok else " (il percorso si ferma a %s)" % (str(Vector2(pts[-1].x, pts[-1].z).round()) if pts.size() > 0 else "-")])
		if not ok:
			errors += 1
	var unreachable := 0
	for c: Array in reach_checks:
		var params := NavigationPathQueryParameters3D.new()
		params.map = map
		params.start_position = _v3(c[1])
		params.target_position = _v3(c[2])
		params.path_search_max_polygons = 0
		var res := NavigationPathQueryResult3D.new()
		NavigationServer3D.query_path(params, res)
		var pts := res.path
		if pts.size() < 2 or Vector2(pts[-1].x, pts[-1].z).distance_to(c[2]) > 4.0:
			print("   NON RAGGIUNGIBILE %s (si ferma a %s)" % [c[0], str(Vector2(pts[-1].x, pts[-1].z).round()) if pts.size() > 0 else "-"])
			unreachable += 1
	if not reach_checks.is_empty():
		print("   raggiungibili dal punto di partenza: %d/%d (altari, uscite, forzieri, entrate, cartelli)" % [reach_checks.size() - unreachable, reach_checks.size()])
	errors += unreachable
	var path: String = LEVELS[_idx][0]
	root.remove_child(level)
	level.set_script(script_backup)
	for k: String in root_props:
		level.set(k, root_props[k])
	if save and errors == 0:
		var ps := PackedScene.new()
		if ps.pack(level) == OK and ResourceSaver.save(ps, path) == OK:
			print("   salvato")
		else:
			print("   ERRORE nel salvataggio")
			errors += 1
	level.free()


# --- Utilità --------------------------------------------------------------------------------------

func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _own(n: Node) -> void:
	n.owner = level


func _group(path: String) -> Node3D:
	var base := path.get_base_dir()
	var parent: Node = level.get_node_or_null(base)
	if parent == null:
		parent = _group(base)
	var n := parent.get_node_or_null(path.get_file()) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = path.get_file()
		parent.add_child(n)
		_own(n)
	return n


## Oggetto di scena (scenes/props/<nome>.tscn) sotto `parent` con un nome fisso (salta se esiste già).
func _prop(parent: Node, node_name: String, pname: String, p: Vector2, rot: float = 0.0, props: Dictionary = {}, scale: float = 1.0) -> Node3D:
	if parent.get_node_or_null(node_name) != null:
		return parent.get_node(node_name)
	var inst: Node3D = (load("res://scenes/props/%s.tscn" % pname) as PackedScene).instantiate()
	inst.name = node_name
	inst.position = _v3(p) - (parent as Node3D).global_position if parent is Node3D and (parent as Node3D).is_inside_tree() else _v3(p)
	inst.rotation_degrees.y = rot
	if scale != 1.0:
		inst.scale = Vector3.ONE * scale
	for k: String in props:
		inst.set(k, props[k])
	parent.add_child(inst)
	_own(inst)
	return inst


func _zone(zone_name: String) -> Node3D:
	return level.get_node_or_null("Incontri/" + zone_name) as Node3D


func _set_zone(zone_name: String, values: Dictionary) -> void:
	var z := _zone(zone_name)
	if z == null:
		print("   (zona %s non trovata)" % zone_name)
		return
	for k: String in values:
		if k == "pos":
			z.position = _v3(values[k])
		else:
			z.set(k, values[k])


func _remove_zone(zone_name: String) -> void:
	var z := _zone(zone_name)
	if z != null:
		z.get_parent().remove_child(z)
		z.free()


func _add_zone(zone_name: String, p: Vector2, types: Array, count: int, lvl: int, elite: bool, radius: float) -> void:
	if _zone(zone_name) != null:
		return
	var z: Node3D = load("res://world/encounter_zone.gd").new()
	z.name = zone_name
	z.position = _v3(p)
	z.set("enemy_types", PackedStringArray(types))
	z.set("count", count)
	z.set("enemy_level", lvl)
	z.set("elite", elite)
	z.set("radius", radius)
	level.get_node("Incontri").add_child(z)
	_own(z)


func _area(area_name: String, c: Vector2, radius: float, zone_name: String, scatter: bool) -> void:
	var forma := level.get_node("Forma")
	if forma.get_node_or_null(area_name) != null:
		return
	var a: Node3D = load("res://world/map_area.gd").new()
	a.name = area_name
	a.position = _v3(c)
	a.set("radius", radius)
	a.set("zone", zone_name)
	a.set("scatter", scatter)
	forma.add_child(a)
	_own(a)


func _road(road_name: String, pts: Array, half_width: float, paved: float, col: Color, zone_name: String = "") -> void:
	var forma := level.get_node("Forma")
	if forma.get_node_or_null(road_name) != null:
		return
	var r: Path3D = load("res://world/map_road.gd").new()
	r.name = road_name
	var cv := Curve3D.new()
	cv.bake_interval = 2.0
	for p: Vector2 in pts:
		cv.add_point(_v3(p))
	r.curve = cv
	r.set("half_width", half_width)
	r.set("widths", PackedFloat32Array([half_width, half_width]))
	r.set("paved_width", paved)
	r.set("paved_color", col)
	r.set("zone", zone_name)
	forma.add_child(r)
	_own(r)


## Toglie un nodo della Forma (per ricrearlo con parametri nuovi).
func _remove_forma(node_name: String) -> void:
	var n := level.get_node_or_null("Forma/" + node_name)
	if n != null:
		n.get_parent().remove_child(n)
		n.free()


## Imbocco di un segreto: 2 cespugli per lato (solo decorazione, senza collisioni: la navmesh non cambia),
## così da lontano si legge come un varco tra la vegetazione. `a` = imbocco, `b` = punto successivo del sentiero.
func _mask_entrance(group: Node, a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var k := 0
	for along: float in [0.0, 3.5]:
		for side: float in [-1.0, 1.0]:
			var c := _prop(group, "CespuglioImbocco%d" % k, "cespuglio", a + dir * along + perp * side * 4.0, randf() * 360.0)
			if c is CollisionObject3D:
				(c as CollisionObject3D).collision_layer = 0
			k += 1


## Punto fisso per santuari ("santuario") o eventi ("evento"): World/Luoghi/PuntiExtra (Level._place_world_extras).
func _extra_point(kind: String, i: int, p: Vector2) -> void:
	var g := _group("World/Luoghi/PuntiExtra")
	var n := "%s_%d" % [kind.capitalize(), i]
	if g.get_node_or_null(n) != null:
		return
	var m := Marker3D.new()
	m.name = n
	m.position = _v3(p)
	m.set_meta("tipo", kind)
	g.add_child(m)
	_own(m)


func _move(path: String, p: Vector2) -> void:
	var n := level.get_node_or_null(path) as Node3D
	if n == null:
		print("   (nodo %s non trovato)" % path)
		return
	var parent := n.get_parent() as Node3D
	n.global_position = _v3(p) if parent == null else Vector3(p.x, n.global_position.y, p.y)


func _find_prop(parent_path: String, pname: String, near: Vector2) -> Node3D:
	for n: Node in level.get_node(parent_path).get_children():
		if n is Node3D and String(n.scene_file_path).ends_with(pname + ".tscn"):
			var gp := (n as Node3D).global_position
			if Vector2(gp.x, gp.z).distance_to(near) < 1.0:
				return n
	return null


func _check_path(what: String, from: Vector2, to: Vector2) -> void:
	checks.append([what, from, to])


## La barricata obbliga a fare il giro dal varco: percorso più lungo della linea d'aria di almeno `extra` m.
func _check_detour(what: String, from: Vector2, to: Vector2, extra: float) -> void:
	checks.append([what, from, to, extra])


# ==================================================================================================
#  Livello 1 – Campagna di Lazio Prime
# ==================================================================================================

func _level_01() -> void:
	var sentiero := Color(0.5, 0.4, 0.28)
	# --- Ritmo degli incontri (L1-R1..R4, L1-A2, L1-A3) ---
	_set_zone("Banditi_bosco", {"elite": true, "enemy_types": PackedStringArray(["predone", "lupo"]), "count": 3, "radius": 5.0})
	_set_zone("Barbari_strada", {"elite": true, "enemy_types": PackedStringArray(["barbaro", "frombolier"]), "count": 3, "radius": 5.0})
	_remove_zone("Imboscata_nord")
	_set_zone("Barbari_avanguardia", {"count": 7, "enemy_types": PackedStringArray(["barbaro", "predone", "drone"])})
	_set_zone("Lupi_margine", {"count": 3})
	_set_zone("Lupi_bosco", {"enemy_types": PackedStringArray(["lupo"]), "count": 7, "radius": 9.0})
	_set_zone("Rinnegati_porta", {"count": 4, "pos": Vector2(96, -800), "radius": 5.0})
	_set_zone("Predoni_ponte", {"pos": Vector2(88, -318), "enemy_types": PackedStringArray(["predone", "drone"]), "count": 5, "radius": 7.0})
	_set_zone("Campo_barbaro", {"pos": Vector2(-100, -546), "count": 6})
	_add_zone("Campo_frombolieri", Vector2(-104, -536), ["frombolier"], 3, 4, false, 4.0)
	_add_zone("Lemuri_tomba", Vector2(-30, -662), ["lemure"], 2, 5, true, 4.0)

	# --- Posto di blocco al ponte (L1-A2): barricata bassa che lascia libero il ponte ---
	var ponte := level.get_node("World/Luoghi/Ponte")
	_prop(ponte, "BloccoCassa1", "cassa", Vector2(78, -316), 15.0)
	_prop(ponte, "BloccoCassa2", "cassa", Vector2(96, -320), -10.0)
	_prop(ponte, "BloccoBarile", "barile", Vector2(94, -317))

	# --- Percorsi (L1-P1, L1-P2) ---
	_road("Sentiero_TempioColline", [Vector2(-100, -428), Vector2(-74, -444), Vector2(-48, -456)], 8.0, 3.5, sentiero)
	var mau := level.get_node("World/Luoghi/Mausoleo")
	_prop(mau, "StendardoBivio1", "stendardo", Vector2(92, -688), 90.0)
	_prop(mau, "StendardoBivio2", "stendardo", Vector2(96, -698), 90.0)
	_prop(mau, "CartelloBivio", "cartello", Vector2(100, -690), 90.0, {"title": "Mausoleo dei Vetranii", "text": "[TRAMA] Qui riposa la famiglia dei Vetranii. Sotto il mausoleo si aprono le catacombe."})

	# --- Arena di Brenno (L1-A1): imbuto con varco di 12 m (x 62-74) e piazzale libero ---
	_area("ArenaBrenno", Vector2(58, -858), 24.0, "citta", false)
	var bar := _group("World/Luoghi/OstiaNova/Barricate")
	var k := 0
	for x: float in [38.0, 42.0, 46.0, 54.0, 58.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0]:
		_prop(bar, "Palizzata%d" % k, "palizzata", Vector2(x, -826))
		k += 1
	# sotto l'arco dell'acquedotto (50, -824) si passerebbe: palizzata subito dietro; a est fino al bordo
	_prop(bar, "PalizzataArco", "palizzata", Vector2(50, -826))
	for x: float in [102.0, 106.0, 110.0, 114.0, 118.0, 122.0]:
		_prop(bar, "PalizzataBordoE%d" % int(x), "palizzata", Vector2(x, -826))
	for x: float in [34.0, 30.0, 26.0, 22.0, 18.0]:
		_prop(bar, "PalizzataBordoO%d" % int(x), "palizzata", Vector2(x, -826))
	_prop(bar, "CassaVarcoO", "cassa", Vector2(61, -827), 20.0)
	_prop(bar, "CassaVarcoE", "cassa", Vector2(75, -827), -15.0)
	_prop(bar, "FaloArenaO", "falo", Vector2(52, -844))
	(bar.get_node("FaloArenaO") as Node3D).global_position = _v3(Vector2(52, -844))   # lontano dagli archi: spazio per schivare
	_prop(bar, "FaloArenaE", "falo", Vector2(72, -866))
	_check_path("arena di Brenno (dal varco)", Vector2(68, -800), Vector2(62, -852))
	_check_detour("le barricate obbligano a passare dal varco (ovest)", Vector2(44, -816), Vector2(44, -836), 20.0)
	_check_detour("le barricate obbligano a passare dal varco (est)", Vector2(94, -816), Vector2(94, -836), 20.0)

	# --- Segreti (L1-S1..S4): radura + sentiero stretto senza lastricato ---
	var seg := _group("World/Luoghi/Segreti")
	# Capanno del traghettatore (sponda sud del fiume, dietro la tenda del ponte)
	_area("Segreto_Traghetto", Vector2(150, -320), 9.0, "fiume", false)
	_road("SentieroSegreto_Traghetto", [Vector2(114, -308), Vector2(130, -312), Vector2(144, -318)], 4.5, 0.0, sentiero, "fiume")
	var g := _group("World/Luoghi/Segreti/Traghetto")
	_prop(g, "Forziere", "forziere", Vector2(152, -324), 180.0, {"flag_id": "chest_segreto_traghetto", "item_level": 2, "rich": true})
	_prop(g, "Cartello", "cartello", Vector2(146, -326), 0.0, {"title": "Il traghettatore", "text": "[TRAMA] Un capanno abbandonato. Il traghettatore se n'è andato in fretta."})
	for i in 3:
		_prop(g, "Anfora%d" % i, "anfora", Vector2(155 + i, -318))
	_check_path("segreto del traghettatore", Vector2(100, -300), Vector2(150, -320))
	# Radura del pastore (bosco)
	_area("Segreto_Pastore", Vector2(60, -178), 9.0, "bosco", false)
	_road("SentieroSegreto_Pastore", [Vector2(80, -150), Vector2(72, -162), Vector2(64, -172)], 4.5, 0.0, sentiero, "bosco")
	g = _group("World/Luoghi/Segreti/Pastore")
	_prop(g, "Forziere", "forziere", Vector2(58, -182), 0.0, {"flag_id": "chest_segreto_bosco", "item_level": 2})
	_prop(g, "Cartello", "cartello", Vector2(64, -184), 0.0, {"title": "La radura del pastore", "text": "[TRAMA] Un recinto vuoto e un fuoco spento da giorni."})
	_check_path("radura del pastore", Vector2(85, -140), Vector2(60, -178))
	# Tomba aperta (necropoli, lato ovest)
	_area("Segreto_TombaAperta", Vector2(-30, -662), 10.0, "necropoli", false)
	_remove_forma("SentieroSegreto_Tomba")   # versione allungata: l'attacco alla radura copre più celle
	_road("SentieroSegreto_Tomba", [Vector2(-12, -640), Vector2(-20, -650), Vector2(-27, -657), Vector2(-30, -662)], 4.5, 0.0, sentiero, "necropoli")
	g = _group("World/Luoghi/Segreti/TombaAperta")
	_prop(g, "Tomba", "tomba", Vector2(-34, -670), 0.0, {}, 1.5)
	_prop(g, "Sarcofago", "sarcofago", Vector2(-26, -668), 35.0)
	_prop(g, "Forziere", "forziere", Vector2(-30, -664), 0.0, {"flag_id": "chest_segreto_tomba", "item_level": 5, "rich": true})
	_prop(g, "Cartello", "cartello", Vector2(-22, -660), 0.0, {"title": "La tomba aperta", "text": "[TRAMA] La lastra è stata spostata dall'interno."})
	_check_path("tomba aperta", Vector2(0, -630), Vector2(-30, -662))
	# Deposito dei rinnegati (dietro l'acquedotto: si passa sotto un arco)
	_area("Segreto_Deposito", Vector2(60, -762), 9.0, "citta", false)
	_road("SentieroSegreto_Deposito", [Vector2(90, -755), Vector2(80, -757), Vector2(68, -760)], 4.5, 0.0, sentiero, "citta")
	g = _group("World/Luoghi/Segreti/Deposito")
	_prop(g, "Forziere", "forziere", Vector2(56, -766), 90.0, {"flag_id": "chest_segreto_deposito", "item_level": 5})
	_prop(g, "Cartello", "cartello", Vector2(62, -768), 0.0, {"title": "Ordini di Brenno", "text": "[TRAMA] \"Nessuno passi la porta. Chi viene da Lazio Prime va fermato.\" – B."})
	_prop(g, "Cassa1", "cassa", Vector2(52, -758), 10.0)
	_prop(g, "Cassa2", "cassa", Vector2(54, -756), -20.0)
	_prop(g, "Barile", "barile", Vector2(64, -768))
	_check_path("deposito dei rinnegati", Vector2(100, -752), Vector2(60, -762))

	# Imbocchi dei segreti mascherati dalla vegetazione
	_mask_entrance(level.get_node("World/Luoghi/Segreti/Traghetto"), Vector2(114, -308), Vector2(130, -312))
	_mask_entrance(level.get_node("World/Luoghi/Segreti/Pastore"), Vector2(80, -150), Vector2(72, -162))
	_mask_entrance(level.get_node("World/Luoghi/Segreti/TombaAperta"), Vector2(-12, -640), Vector2(-20, -650))
	_mask_entrance(level.get_node("World/Luoghi/Segreti/Deposito"), Vector2(90, -755), Vector2(80, -757))

	# --- Cartelli di storia nelle deviazioni (L1-S5) ---
	_prop(level.get_node("World/Luoghi/FattoriaRazziata"), "CartelloDiario", "cartello", Vector2(-48, -90), 0.0, {"title": "Diario del fattore", "text": "[TRAMA]"})
	_prop(level.get_node("World/Luoghi/RelittoNavetta"), "CartelloRegistro", "cartello", Vector2(195, -240), 0.0, {"title": "Registro di volo", "text": "[TRAMA]"})
	_prop(level.get_node("World/Luoghi/AccampamentoBarbaro"), "CartelloTotem", "cartello", Vector2(-108, -556), 0.0, {"title": "Totem del clan", "text": "[TRAMA]"})
	_prop(level.get_node("World/Luoghi/Mausoleo"), "CartelloEpigrafe", "cartello", Vector2(140, -670), 0.0, {"title": "Epigrafe", "text": "[TRAMA]"})

	# --- Punti fissi per santuari ed eventi (L1-R5) ---
	var i := 0
	for p: Vector2 in [Vector2(10, -70), Vector2(-20, -440), Vector2(20, -640), Vector2(60, -178)]:
		_extra_point("santuario", i, p)
		i += 1
	i = 0
	for p: Vector2 in [Vector2(175, -235), Vector2(-60, -520), Vector2(110, -760)]:
		_extra_point("evento", i, p)
		i += 1
	_check_path("anello tempio → colline", Vector2(-110, -415), Vector2(-48, -456))
	_vignettes(45, 3001)


# ==================================================================================================
#  Ostia Nova
# ==================================================================================================

func _ostia() -> void:
	var q := level.get_node("World/Luoghi/Quartieri")
	# O-P1: scia di luci dal foro alla porta del porto, attorno alla basilica
	var k := 0
	for p: Vector2 in [Vector2(12, -22), Vector2(14, -32), Vector2(12, -42), Vector2(8, -52)]:
		_prop(q, "LampioneVersoPorto%d" % k, "lampione_plasma", p)
		k += 1
	_prop(q, "StendardoPorta", "stendardo", Vector2(-6, -54))
	# O-P2: oltre il cancello chiuso si vedono le gru del porto (solo decorazione, fuori da World)
	var deco := level.get_node_or_null("OltreCancello") as Node3D
	if deco == null:
		deco = Node3D.new()
		deco.name = "OltreCancello"
		level.add_child(deco)
		_own(deco)
	_prop(deco, "Gru", "gru", Vector2(-10, -78), 30.0)
	_prop(deco, "Nave", "nave", Vector2(14, -82), 80.0, {}, 0.5)
	for n: Node in deco.get_children():
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = 0   # niente navmesh né ostacoli
	# O-S1: il ricordo di famiglia nel quartiere nord-ovest
	_prop(q, "ForziereEredita", "forziere", Vector2(-43, -40), 90.0, {"flag_id": "chest_ostia_eredita", "item_level": 3})
	_prop(q, "CartelloEredita", "cartello", Vector2(-43, -35), 90.0, {"title": "Un ricordo di famiglia", "text": "[TRAMA]"})
	for i in 3:
		_prop(q, "AnforaEredita%d" % i, "anfora", Vector2(-44 + i, -44))
	_check_path("ricordo di famiglia (quartiere NO)", Vector2(0, 30), Vector2(-41, -40))
	_check_path("dal porto ai servizi", Vector2(0, -49), Vector2(0, 0))


# ==================================================================================================
#  Porto di Ostia Nova
# ==================================================================================================

func _porto() -> void:
	var sentiero := Color(0.58, 0.55, 0.5)
	# --- Ritmo (P-R1, P-R2, P-A2, P-P2) ---
	_remove_zone("Granchi_strada")
	_set_zone("Pirati_ingresso", {"count": 3})
	_set_zone("Pirati_strada", {"count": 6, "enemy_types": PackedStringArray(["pirata", "pirata", "granchio"])})
	_remove_zone("Gru_pirati")
	_remove_zone("Strada_faro")
	_set_zone("Magazzini_1", {"elite": true, "enemy_types": PackedStringArray(["pirata", "arpionatore"]), "count": 3, "radius": 5.0})
	_set_zone("Automa_magazzini", {"enemy_types": PackedStringArray(["automa", "granchio", "granchio", "granchio", "granchio"]), "count": 5, "radius": 7.0})
	_set_zone("Pirati_curva", {"enemy_types": PackedStringArray(["pirata", "pirata", "arpionatore"])})
	_set_zone("Strada_spazioporto", {"count": 4})
	_set_zone("Spazioporto_ciurma", {"count": 5})
	_set_zone("Molo_3", {"count": 5})

	# --- Percorsi (P-P1): anello del cantiere ---
	_road("Sentiero_CantiereNord", [Vector2(-50, -298), Vector2(-36, -280), Vector2(-22, -262)], 6.0, 8.0, sentiero)
	_check_path("anello del cantiere", Vector2(-56, -310), Vector2(-20, -262))

	# --- Moli (P-P2) ---
	var moli := level.get_node("World/Luoghi/Moli")
	_prop(moli, "ForziereMolo3", "forziere", Vector2(78, -382), -90.0, {"flag_id": "chest_porto_molo3", "item_level": 8})
	_prop(moli, "CartelloBolla", "cartello", Vector2(84, -141), -90.0, {"title": "Bolla di carico", "text": "[TRAMA] Merce di Tito: trenta anfore di garum, sequestrate."})
	for i in 4:
		_prop(moli, "AnforaMolo1_%d" % i, "anfora", Vector2(82 + i, -145 + (i % 2)))
	_check_path("forziere del molo 3", Vector2(20, -380), Vector2(76, -380))

	# --- Soglia del faro e altare prima del boss (P-A1) ---
	_move("World/Luoghi/Spazioporto/Altare", Vector2(-2, -500))
	var faro := level.get_node("World/Luoghi/Faro")
	_prop(faro, "SogliaMuroO0", "muro", Vector2(-12, -515))
	_prop(faro, "SogliaMuroO1", "muro", Vector2(-4, -515))
	_prop(faro, "SogliaMuroO2", "muro", Vector2(4, -515))
	_prop(faro, "SogliaCassaO", "cassa", Vector2(9, -515), 10.0)
	_prop(faro, "SogliaMuroE1", "muro", Vector2(27, -515))
	_prop(faro, "SogliaMuroE2", "muro", Vector2(35, -515))
	_prop(faro, "SogliaCassaE", "cassa", Vector2(23, -515), -10.0)
	_prop(faro, "StendardoSoglia1", "stendardo", Vector2(11, -513))
	_prop(faro, "StendardoSoglia2", "stendardo", Vector2(21, -513))
	var t1 := _find_prop("World/Luoghi/Faro", "tenda", Vector2(6, -558))
	if t1:
		t1.global_position = _v3(Vector2(-2, -562))
	var t2 := _find_prop("World/Luoghi/Faro", "tenda", Vector2(34, -542))
	if t2:
		t2.global_position = _v3(Vector2(42, -548))
	_check_path("arena di Vulso (dall'altare, dal varco)", Vector2(-2, -496), Vector2(20, -548))
	_check_detour("la soglia del faro obbliga a passare dal varco", Vector2(-5, -508), Vector2(-5, -524), 12.0)

	# --- Segreti (P-S1, P-S2) ---
	_area("Segreto_Contrabbandieri", Vector2(-58, -236), 9.0, "magazzini", false)
	_road("SentieroSegreto_Contrabbandieri", [Vector2(-30, -228), Vector2(-42, -231), Vector2(-52, -234)], 4.5, 0.0, sentiero, "magazzini")
	var g := _group("World/Luoghi/Segreti/Contrabbandieri")
	_prop(g, "Forziere", "forziere", Vector2(-62, -240), 90.0, {"flag_id": "chest_segreto_contrabbando", "item_level": 7, "rich": true})
	_prop(g, "PilaCasse", "pila_casse", Vector2(-64, -232))
	_prop(g, "Barile", "barile", Vector2(-56, -242))
	_prop(g, "Cartello", "cartello", Vector2(-54, -240), 0.0, {"title": "Il tunnel", "text": "[TRAMA] Una botola sotto le casse: porta alle vecchie cisterne."})
	_check_path("nascondiglio dei contrabbandieri", Vector2(-10, -228), Vector2(-58, -236))
	_mask_entrance(g, Vector2(-30, -228), Vector2(-42, -231))
	g = _group("World/Luoghi/Segreti/Lanterna")
	_prop(g, "Cartello", "cartello", Vector2(6, -576), 0.0, {"title": "La lanterna del faro", "text": "[TRAMA: atto 3]"})
	for i in 4:
		_prop(g, "Anfora%d" % i, "anfora", Vector2(3 + i, -579))
	_check_path("dietro il faro", Vector2(20, -540), Vector2(6, -574))

	# --- Punti fissi per santuari ed eventi (P-R3) ---
	var i := 0
	for p: Vector2 in [Vector2(-10, -100), Vector2(-20, -330), Vector2(20, -480)]:
		_extra_point("santuario", i, p)
		i += 1
	i = 0
	for p: Vector2 in [Vector2(-40, -200), Vector2(0, -370)]:
		_extra_point("evento", i, p)
		i += 1
	# Il molo 1 cominciava a x 10 e tra lui e la strada restava una cella chiusa (isolato di confine):
	# raccordo lastricato, così il molo (e la bolla di carico) si raggiunge a piedi
	_road("Raccordo_Molo1", [Vector2(-12, -140), Vector2(16, -140)], 5.0, 6.0, sentiero, "strada")
	_check_path("molo 1 collegato alla strada", Vector2(-20, -100), Vector2(60, -140))
	_vignettes(18, 3003)
	_print_pirates()


## "Ripulire i moli" chiede 30 pirati: quanti ce ne sono (i tipi si alternano nell'ordine della lista).
func _print_pirates() -> void:
	var n := 0
	for z: Node in level.get_node("Incontri").get_children():
		var types: PackedStringArray = z.get("enemy_types")
		for k in int(z.get("count")):
			if types.size() > 0 and types[k % types.size()] == "pirata":
				n += 1
	print("   pirati nel porto (senza rinforzi di Vulso ed elite in più): %d (la missione ne chiede 30)" % n)


# ==================================================================================================
#  Scene sul percorso (stile Diablo 3): gruppi di oggetti che bloccano, ai lati del cammino
# ==================================================================================================

## Gruppi di oggetti di scena: [prop, x, z, rotazione, scala] attorno al centro (ruotati tutti insieme).
const VIGNETTES := {
	"carro_rotto": [["carro", 0, 0, 25, 1.0], ["cassa", 2.4, 1.2, 10, 1.0], ["barile", 2.6, -0.8, 0, 1.0], ["covone", -2.6, 1.0, 0, 1.0]],
	"recinto": [["staccionata", -2.0, 0, 0, 1.0], ["staccionata", 2.0, 0, 0, 1.0], ["staccionata", 4.1, 2.0, 90, 1.0],
		["covone", 0.5, 2.2, 0, 1.0], ["covone", 2.4, 2.8, 0, 0.8]],
	"pozzo": [["pozzo", 0, 0, 0, 1.0], ["anfora", 1.7, 0.4, 0, 1.0], ["anfora", 1.5, 1.3, 0, 1.0], ["barile", -1.8, 0.6, 0, 1.0]],
	"rovina": [["muro_rovina", 0, 0, 0, 1.0], ["colonna_rotta", 3.2, 1.2, 0, 1.0], ["colonna_rotta", -3.0, 1.8, 0, 0.8],
		["roccia_piccola", 1.0, 2.2, 0, 1.0]],
	"tempietto": [["colonna_rotta", -2.5, -1.5, 0, 1.0], ["colonna_rotta", 2.5, -1.5, 0, 1.1], ["statua", 0, -2.2, 0, 1.0],
		["colonna_rotta", -2.5, 1.5, 0, 0.7]],
	"bivacco": [["falo", 0, 0, 0, 1.0], ["tenda", 3.4, -1.8, 200, 1.0], ["tronco", -2.4, 0.2, 90, 1.0], ["barile", 1.8, 2.6, 0, 1.0]],
	"tombe": [["sarcofago", 0, 0, 10, 1.0], ["sarcofago", 0.3, 2.0, -5, 1.0], ["colonna_rotta", -2.6, 1.0, 0, 0.8], ["cipresso", 3.2, 0.8, 0, 1.0]],
	"frana": [["roccia_grande", 0, 0, 0, 1.0], ["roccia_grande", 2.8, 1.4, 70, 0.7], ["tronco", -2.4, 1.8, 30, 1.0], ["roccia_piccola", 1.2, -1.6, 0, 1.0]],
	"tronchi": [["tronco", 0, 0, 10, 1.0], ["tronco", 0.4, 1.0, 15, 1.0], ["roccia_piccola", -2.0, 0.6, 0, 1.0], ["cespuglio", 2.4, -0.6, 0, 1.0]],
	"carico": [["pila_casse", 0, 0, 0, 1.0], ["cassa", 1.8, 0.4, 15, 1.0], ["barile", -1.6, 0.8, 0, 1.0], ["barile", -1.2, -1.0, 0, 1.0],
		["anfora", 1.0, -1.6, 0, 1.0]],
	"carretto_porto": [["carro", 0, 0, 80, 1.0], ["pila_casse", 0.6, 2.4, 0, 1.0], ["barile", -2.0, 2.0, 0, 1.0]],
	"barili": [["barile", 0, 0, 0, 1.0], ["barile", 1.0, 0.3, 0, 1.0], ["barile", 0.4, 1.0, 0, 1.0], ["cassa", -1.5, 0.4, 20, 1.0], ["bitta", 2.4, -0.8, 0, 1.0]],
}
## Zona -> scene possibili.
const ZONE_VIGNETTES := {
	"fattoria": ["carro_rotto", "recinto", "pozzo", "recinto"], "fiume": ["tronchi", "carro_rotto", "frana"],
	"bosco": ["tronchi", "bivacco", "frana", "tronchi"], "boschetto": ["rovina", "tronchi", "tempietto"],
	"tempio": ["tempietto", "rovina", "rovina"], "relitto": ["frana", "carico", "bivacco"], "campo": ["bivacco", "frana", "carro_rotto"],
	"necropoli": ["tombe", "rovina", "tombe"], "citta": ["carro_rotto", "pozzo", "rovina"],
	"strada": ["carico", "carretto_porto", "barili"], "magazzini": ["carico", "barili"], "cantieri": ["tronchi", "carico"],
	"cantiere": ["tronchi", "carico"], "spazioporto": ["carico", "barili"], "faro": ["frana", "rovina"], "sale": ["barili", "carico"],
}
const VIGNETTE_SPACING := 30.0
const VIGNETTE_RADIUS := 5.0

var reach_checks: Array = []   # [nome, da, a]: punti che devono restare raggiungibili (tolleranza 4 m)


## Mette le scene: ai lati del cammino (mai sul tracciato di strade e sentieri), fuori da arene/segreti/radure
## (aree senza vegetazione), lontano da incontri, punti fissi, oggetti piazzati e da altre scene.
func _vignettes(max_count: int, seed_value: int) -> void:
	var g := _group("World/Luoghi/Scene")
	if g.get_child_count() > 0:
		print("   scene già presenti: %d" % g.get_child_count())
		_reach_all()
		return
	var mb: Variant = load("res://tools/map_builder.gd").new()
	mb.rasterize(level)
	mb._collect_obstacles(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var avoid: Array = []   # [centro, raggio]
	for z: Node in level.get_node("Incontri").get_children():
		avoid.append([Vector2((z as Node3D).global_position.x, (z as Node3D).global_position.z), float(z.get("radius")) + 6.0])
	for m: Node in level.find_children("*", "Marker3D", true, false):
		avoid.append([Vector2((m as Node3D).global_position.x, (m as Node3D).global_position.z), 7.0])
	var cells: Array = []
	for k in mb.state.size():
		if mb.state[k] == 1 and mb.no_scatter[k] == 0 and ZONE_VIGNETTES.has(String(mb.zone_of[k])):
			cells.append(k)
	# ordine casuale ma fisso
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var placed: Array = []
	for k: int in cells:
		if placed.size() >= max_count:
			break
		var c: Vector2 = mb._center(k) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		if not _vignette_spot_ok(mb, c, avoid, placed):
			continue
		var zone: String = mb.zone_of[k]
		var kinds: Array = ZONE_VIGNETTES[zone]
		var kind: String = kinds[rng.randi() % kinds.size()]
		var yaw := deg_to_rad(15.0 * rng.randi_range(0, 23))
		var vg := Node3D.new()
		vg.name = "%s_%d" % [kind.capitalize().replace(" ", ""), placed.size()]
		vg.position = _v3(c)
		g.add_child(vg)
		_own(vg)
		var i := 0
		for part: Array in VIGNETTES[kind]:
			var off := Vector2(float(part[1]), float(part[2])).rotated(-yaw)
			_prop(vg, "%s%d" % [String(part[0]).capitalize().replace(" ", ""), i], part[0], c + off, rad_to_deg(yaw) + float(part[3]), {}, float(part[4]))
			i += 1
		placed.append(c)
	print("   scene sul percorso: %d" % placed.size())
	_reach_all()


func _vignette_spot_ok(mb: Variant, c: Vector2, avoid: Array, placed: Array) -> bool:
	# tutto il gruppo sul calpestabile, non vicino all'acqua né in arene/radure
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k: int = mb._cell_of(c + Vector2(dx, dz) * VIGNETTE_RADIUS)
			if k < 0 or mb.state[k] != 1 or mb.no_scatter[k] == 1 or mb._near_water(k):
				return false
	# lontano dal lastricato delle strade (la carreggiata resta libera) e fuori dai sentieri senza lastricato
	# (segreti, sentieri stretti: non vanno mai ostruiti)
	for rd: Array in mb.roads_data:
		var road: Node = rd[0]
		var pts: PackedVector2Array = rd[1]
		var ws: PackedFloat32Array = rd[2]
		var paved_hw := float(road.get("paved_width")) * 0.5
		for i in range(1, pts.size()):
			var sd: Vector2 = mb._seg_dist(c, pts[i - 1], pts[i])
			var need := paved_hw + VIGNETTE_RADIUS + 2.0 if paved_hw > 0.0 else lerpf(ws[i - 1], ws[i], sd.y) + VIGNETTE_RADIUS + 1.0
			if sd.x < need:
				return false
	# ma non in mezzo al nulla: accanto a un bordo (entro 16 m), come le scene di D3 ai lati del cammino
	var edge := false
	for a in 8:
		var k: int = mb._cell_of(c + Vector2.from_angle(TAU * a / 8.0) * 16.0)
		if k < 0 or mb.state[k] != 1:
			edge = true
	if not edge:
		return false
	if not mb._free(c, VIGNETTE_RADIUS + 1.0):
		return false
	for av: Array in avoid:
		if c.distance_to(av[0]) < float(av[1]) + VIGNETTE_RADIUS:
			return false
	for p: Vector2 in placed:
		if c.distance_to(p) < VIGNETTE_SPACING:
			return false
	return true


## Dopo le scene: altari, uscite, forzieri, entrate dei dungeon e cartelli devono restare raggiungibili
## dal primo altare (o dal punto di partenza).
func _reach_all() -> void:
	var start := Vector2.INF
	var targets: Array = []
	for n: Node in level.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s == null or not (n is Node3D):
			continue
		var f := s.resource_path.get_file()
		if f in ["checkpoint.gd", "level_exit.gd", "chest.gd", "dungeon_entrance.gd", "lore_sign.gd"]:
			var p := Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
			targets.append(["%s %s" % [f.get_basename(), n.name], p])
			if f == "checkpoint.gd" and start == Vector2.INF:
				start = p
	var ps := level.get_node_or_null("PlayerStart") as Node3D
	if ps != null:
		start = Vector2(ps.global_position.x, ps.global_position.z)
	for t: Array in targets:
		reach_checks.append(["raggiungibile: " + String(t[0]), start, t[1]])
