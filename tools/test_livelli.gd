extends SceneTree
## TEST AUTOMATICO delle modifiche di level design (docs/PROPOSTE_LIVELLI.md, tools/applica_proposte_livelli.gd):
## ritmo degli incontri (elite sul percorso, tratti di riposo), arene (Brenno, soglia del faro con l'altare prima
## di Vulso), segreti (radure, forzieri unici), cartelli, punti fissi per santuari ed eventi, missioni ancora fattibili.
## La raggiungibilità a piedi la controlla già applica_proposte_livelli.gd prima di salvare.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_livelli.gd

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


func _xz(n: Node) -> Vector2:
	var t := (n as Node3D).transform
	var p := n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return Vector2(t.origin.x, t.origin.z)


func _zones(lvl: Node) -> Dictionary:
	var out := {}
	for z: Node in lvl.get_node("Incontri").get_children():
		out[String(z.name)] = z
	return out


func _chest_flags(lvl: Node) -> Array:
	var out: Array = []
	for n: Node in lvl.find_children("*", "", true, false):
		if n.get("flag_id") != null and String(n.get("flag_id")) != "":
			out.append(String(n.get("flag_id")))
	return out


func _run() -> void:
	game = root.get_node("Game")
	load("res://world/map_shape.gd").keep_in_game = true

	print("\n== 1. Campagna di Lazio Prime")
	var l1: Node = load("res://scenes/levels/level_01.tscn").instantiate()
	var z := _zones(l1)
	_check(z["Banditi_bosco"].elite and z["Barbari_strada"].elite, "due elite sul percorso principale (bosco e strada delle colline)")
	_check(not z.has("Imboscata_nord"), "nessuna imboscata accanto all'Altare di Portuno (riposo dopo l'altare)")
	_check(z.has("Lemuri_tomba") and z["Lemuri_tomba"].elite and z.has("Campo_frombolieri"), "nuovi gruppi: lemuri della tomba, frombolieri del campo")
	_check(_xz(z["Rinnegati_porta"]).distance_to(Vector2(68, -826)) > 28.0, "calma prima di Brenno: l'ultimo gruppo è lontano dal varco")
	var flags := _chest_flags(l1)
	var secret_ok := true
	for f: String in ["chest_segreto_traghetto", "chest_segreto_bosco", "chest_segreto_tomba", "chest_segreto_deposito"]:
		if not flags.has(f):
			secret_ok = false
	_check(secret_ok, "quattro segreti con il loro forziere")
	var dup := {}
	for f: String in flags:
		dup[f] = int(dup.get(f, 0)) + 1
	_check(dup.values().all(func(v: int) -> bool: return v == 1), "ogni forziere ha un flag_id unico (%d forzieri)" % flags.size())
	_check(l1.get_node_or_null("Forma/ArenaBrenno") != null and l1.get_node("World/Luoghi/OstiaNova/Barricate").get_child_count() >= 20,
		"arena di Brenno: piazzale libero e barricate con il varco")
	_check(l1.get_node_or_null("Forma/Sentiero_TempioColline") != null, "anello tempio → colline")
	var pe: Node = l1.get_node_or_null("World/Luoghi/PuntiExtra")
	var n_s := 0
	var n_e := 0
	if pe != null:
		for m: Node in pe.get_children():
			if String(m.get_meta("tipo", "")) == "santuario":
				n_s += 1
			elif String(m.get_meta("tipo", "")) == "evento":
				n_e += 1
	_check(n_s == 4 and n_e == 3, "punti fissi: 4 per i santuari, 3 per gli eventi")
	var lemures := 0
	for zz: Node in z.values():
		var types: PackedStringArray = zz.get("enemy_types")
		for k in int(zz.get("count")):
			if types[k % types.size()] == "lemure":
				lemures += 1
	var sc: Node = l1.get_node_or_null("World/Luoghi/Scene")
	_check(sc != null and sc.get_child_count() >= 30, "scene sul percorso stile D3 (carri, recinti, rovine, bivacchi...): %d" % (sc.get_child_count() if sc else 0))
	_check(lemures >= 12, "\"Il fuoco tremante\" resta fattibile: %d lemuri (ne servono 12)" % lemures)
	l1.free()

	print("\n== 2. Porto di Ostia Nova")
	var po: Node = load("res://scenes/levels/level_03_porto.tscn").instantiate()
	z = _zones(po)
	_check(not z.has("Granchi_strada") and not z.has("Gru_pirati") and not z.has("Strada_faro"), "tre tratti di riposo (tolti 3 gruppi)")
	_check(z["Magazzini_1"].elite, "prima elite del porto ai magazzini")
	var altar: Node = po.get_node("World/Luoghi/Spazioporto/Altare")
	_check(String(altar.get("checkpoint_id")) == "porto_spazioporto" and _xz(altar).distance_to(Vector2(20, -548)) < 55.0,
		"Altare di Mercurio subito prima di Vulso (stesso id, salvataggi intatti)")
	_check(po.get_node("World/Luoghi/Faro").get_node_or_null("SogliaMuroO1") != null, "soglia del faro con il varco")
	var pirates := 0
	for zz: Node in z.values():
		var types: PackedStringArray = zz.get("enemy_types")
		for k in int(zz.get("count")):
			if types[k % types.size()] == "pirata":
				pirates += 1
	_check(pirates >= 30, "\"Ripulire\" resta fattibile: %d pirati (ne servono 30, più i rinforzi di Vulso)" % pirates)
	flags = _chest_flags(po)
	_check(flags.has("chest_porto_molo3") and flags.has("chest_segreto_contrabbando"), "forziere del molo 3 e dei contrabbandieri")
	var scp: Node = po.get_node_or_null("World/Luoghi/Scene")
	_check(scp != null and scp.get_child_count() >= 10 and po.get_node_or_null("Forma/Raccordo_Molo1") != null,
		"porto: scene sul percorso (%d) e molo 1 collegato alla strada" % (scp.get_child_count() if scp else 0))
	po.free()

	print("\n== 3. Ostia Nova")
	var os: Node = load("res://scenes/levels/level_02_ostia.tscn").instantiate()
	_check(_chest_flags(os).has("chest_ostia_eredita"), "il ricordo di famiglia nel quartiere nord-ovest")
	_check(os.get_node("World/Luoghi/Quartieri").get_node_or_null("LampioneVersoPorto0") != null, "scia di luci verso la porta del porto")
	var oc: Node = os.get_node_or_null("OltreCancello")
	var no_collide := oc != null
	if oc != null:
		for n: Node in oc.get_children():
			if n is CollisionObject3D and (n as CollisionObject3D).collision_layer != 0:
				no_collide = false
	_check(no_collide, "gru e nave oltre il cancello: solo decorazione (nessuna collisione)")
	os.free()

	print("\n== 4. Santuari ed eventi ai punti fissi (in gioco)")
	var hero: Variant = load("res://core/hero_data.gd").create("Esploratrice", "sagittario", "f")
	hero.level = 5
	game.hero = hero
	game.current_slot = -1
	game.travel("level_01")
	var lvl: Variant = null
	for i in 900:
		await process_frame
		lvl = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == "level_01" and lvl.is_node_ready() and lvl.get_node_or_null("Extra") != null and lvl.get_node("Extra").get_child_count() > 0:
			break
	await _frames(5)
	var markers: Array = []
	for m: Node in lvl.get_node("World/Luoghi/PuntiExtra").get_children():
		markers.append(_xz(m))
	var placed := 0
	var near := 0
	for x: Node in lvl.get_node("Extra").get_children():
		placed += 1
		for mp: Vector2 in markers:
			if _xz(x).distance_to(mp) < 3.5:
				near += 1
				break
	_check(placed == 5 and near == placed, "3 santuari e 2 eventi, tutti sui punti fissi (%d/%d)" % [near, placed])

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
