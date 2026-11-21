extends SceneTree
## TEST AUTOMATICO della grafica 2D (docs/GRAFICA_2D_AI.md): texture del terreno e delle strade nei livelli,
## pavimenti e muri dei dungeon, icone degli oggetti nello zaino e nel sacchetto delle gemme, barra delle abilità
## decorata e globi con la cornice, cornici dei pannelli, sfondo del menu, schermate di caricamento, icona dell'app.
## In headless le immagini non si vedono: si controlla che siano collegate. Vanno guardate anche a schermo.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_grafica.gd
## Non salva la partita (slot -1).

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


## Pezzi di terreno (sotto World/Terreno, tranne lo sfondo) con e senza la texture; strade con la texture.
func _terrain_stats(lvl: Node) -> Dictionary:
	var world: Node = lvl.get_node("World")
	var tex := 0
	var flat := 0
	for mi: MeshInstance3D in world.get_node("Terreno").find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Sfondo":
			continue
		if mi.material_override is ShaderMaterial:
			tex += 1
		else:
			flat += 1
	var roads := 0
	var road_surfaces := 0
	var strade: Node = world.get_node_or_null("Strade")
	if strade != null:
		for mi: MeshInstance3D in strade.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				road_surfaces += 1
				if mi.get_surface_override_material(i) is ShaderMaterial:
					roads += 1
	return {"tex": tex, "flat": flat, "roads": roads, "road_surfaces": road_surfaces}


func _run() -> void:
	game = root.get_node("Game")
	root.size = Vector2i(1600, 900)
	var HD: GDScript = load("res://core/hero_data.gd")
	var IDB: GDScript = load("res://data/item_db.gd")
	var Sett: GDScript = load("res://core/settings.gd")
	var old_touch: int = Sett.touch_controls
	Sett.touch_controls = 2   # barra completa (mouse)

	var hero: Variant = HD.create("Pittrice", "legionario", "f")
	hero.level = 20
	game.hero = hero
	game.current_slot = -1

	print("\n== 1. Terreno e strade dei livelli")
	var DR: GDScript = load("res://core/dressing.gd")
	var bad: Array = []
	for id: String in ["erba", "erba_alta", "erba_secca", "erbacce", "felce", "fiori_gialli", "foglie", "sassolini", "sasso", "masso",
			"masso_grande", "parete", "cespuglietto", "cespuglio", "funghi", "ramo", "tronco_caduto", "ossa", "lastra", "detriti", "assi",
			"corde", "pino", "quercia", "cipresso", "olivo", "pino_marittimo", "casa", "insula", "rovina", "torre", "statua"]:
		var m: Mesh = DR.mesh(id)
		if m == null or m.get_surface_count() != 1 or (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 9:
			bad.append(id)
	_check(bad.is_empty(), "forme dell'arredo tutte costruite %s" % str(bad))
	for pair: Array in [["level_01", "level_01"], ["ostia_nova", "ostia_nova"], ["level_03_porto", "level_03_porto"]]:
		game.travel(pair[0])
		var ok: bool = await _wait_level(pair[1])
		var art: TextureRect = game._loading.find_child("Art", true, false)
		_check(ok and art != null and art.texture != null and art.texture.resource_path.ends_with("caricamento_%s.png" % pair[0]),
			"%s: schermata di caricamento con il suo dipinto" % pair[0])
		var st := _terrain_stats(game.level)
		_check(st["tex"] > 10 and st["flat"] == 0, "%s: tutto il terreno ha le texture (%d pezzi, %d senza)" % [pair[0], st["tex"], st["flat"]])
		_check(st["road_surfaces"] == 0 or st["roads"] == st["road_surfaces"], "%s: strade con la texture (%d/%d)" % [pair[0], st["roads"], st["road_surfaces"]])
		if pair[0] != "ostia_nova":
			var arr: Node = game.level.get_node_or_null("Arredo")
			var kinds := {}
			if arr != null:
				for mi: Node in arr.get_children():
					kinds[String(mi.name).rsplit("_", true, 2)[0]] = true
			var want: Array = ["erba", "pino", "felce", "parete"] if pair[0] == "level_01" else ["detriti", "casa", "insula"]
			_check(arr != null and want.all(func(k: String) -> bool: return kinds.has(k)),
				"%s: arredo stile D3 (copertura del suolo e massa oltre i confini: %s)" % [pair[0], ", ".join(PackedStringArray(kinds.keys()))])

	# Le curve strette delle strade hanno triangoli ripiegati al contrario: vanno nascosti (cull_back), se no "spicchi"
	# (e tutti gli altri devono essere girati verso l'alto, se no col culling la strada sparisce)
	var cull_ok := true
	var front := 0
	var back := 0
	for mi: MeshInstance3D in game.level.get_node("World/Strade").find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null or not m.shader.code.contains("cull_back"):
				cull_ok = false
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for k in range(0, v.size() - 2, 3):
				if (v[k + 1] - v[k]).cross(v[k + 2] - v[k]).y < 0.0:
					front += 1
				else:
					back += 1
	_check(cull_ok and front > 100 and back == 0, "strade visibili dall'alto (%d triangoli) e senza triangoli ripiegati nelle curve (%d)" % [front, back])

	print("\n== 2. Dungeon")
	for id: String in ["catacombe", "caverne_clan", "cisterne"]:
		game.hero.flags["dungeon"] = {"id": id, "return_level": "level_01", "x": 0.0, "z": 0.0}
		game.travel("dungeon")
		await _wait_level("dungeon")
		await _frames(5)
		var floor_ok := false
		var wall_ok := false
		for body_name: String in ["Pavimento", "Muri"]:
			var body: Node = game.level.find_child(body_name, true, false)
			if body == null:
				continue
			for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
				if mi.material_override is ShaderMaterial:
					if body_name == "Pavimento":
						floor_ok = true
					else:
						wall_ok = true
		var art: TextureRect = game._loading.find_child("Art", true, false)
		var walls: Node = game.level.find_child("Muri", true, false)
		var two_sided := walls != null and ((walls.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override as ShaderMaterial).shader.code.contains("cull_disabled")
		_check(floor_ok and wall_ok and two_sided and art.texture != null, "%s: pavimento e muri con le texture (muri a due facce), dipinto di caricamento" % id)

	print("\n== 3. Icone degli oggetti, gemme, materiali")
	game.travel("ostia_nova")
	await _wait_level("ostia_nova")
	var lvl: Variant = game.level
	var p: Variant = lvl.player
	var missing: Array = []
	var IC: GDScript = load("res://core/icons.gd")
	for base_id: String in IDB.BASES:
		if IC.item(IDB.make_basic(base_id, 5)) == null:
			missing.append(base_id)
	for t: String in IDB.GEMS:
		if IC.gem(t + ":1") == null:
			missing.append(t)
	for g: String in IDB.LEGENDARY_GEMS:
		if IC.gem("leg:%s:1" % g) == null:
			missing.append(g)
	for m: String in IDB.MATERIALS:
		if IC.material(m) == null:
			missing.append(m)
	_check(missing.is_empty() and IC.material("sesterzi") != null, "ogni base, gemma, gemma leggendaria e materiale ha l'icona %s" % str(missing))
	hero.inventory.fill(null)
	hero.add_item(IDB.make_basic("gladio_plasma", 5))
	hero.gems["rubino:2"] = 3
	lvl.inventory_ui.toggle()
	await _frames(3)
	var bag0: Button = lvl.inventory_ui.bag_buttons[0]
	var bag1: Button = lvl.inventory_ui.bag_buttons[1]
	_check(bag0.icon != null and bag0.text == "" and bag1.icon == null, "zaino: l'oggetto mostra l'icona (senza sigla), la casella vuota no")
	var arma: Button = lvl.inventory_ui.equip_buttons["arma"]
	_check(arma.icon != null and arma.text != "", "equipaggiamento: icona e nome dell'arma indossata")
	_check(String(lvl.inventory_ui.mats_label.text).contains("[img"), "materiali con le loro icone")
	_check(lvl.inventory_ui.panel.get_theme_stylebox("panel") is StyleBoxTexture, "lo zaino ha la cornice di bronzo")
	lvl.inventory_ui.toggle()
	await _frames(2)

	print("\n== 4. Barra delle abilità e globi")
	var hud: Variant = lvl.hud
	var bar: Control = hud.find_child("BarraAbilita", true, false)
	_check(bar != null and hud.skill_row.visible, "barra delle abilità decorata visibile (mouse)")
	var inside := 0
	if bar != null:
		for s: String in hud.slots:
			var sl: Control = hud.slots[s]
			if sl.get_parent() == bar and Rect2(Vector2.ZERO, bar.size).encloses(Rect2(sl.position, sl.size)):
				inside += 1
	_check(inside == 6, "le 6 abilità stanno nei fori della barra (%d)" % inside)
	var lg: Rect2 = hud.life_globe.get_global_rect()
	var rg: Rect2 = hud.res_globe.get_global_rect()
	var bar_rect: Rect2 = bar.get_global_rect() if bar != null else Rect2()
	_check(not lg.grow(12).intersects(bar_rect) and not rg.grow(12).intersects(bar_rect), "i globi (con la cornice) non coprono la barra")
	_check(load("res://ui/globe.gd")._frame != null, "i globi hanno la cornice di bronzo")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(lg.grow(14)) and screen.encloses(rg.grow(14)), "barra in basso tutta dentro lo schermo")

	print("\n== 5. Menu principale e icona dell'app")
	game.level.queue_free()
	await _frames(2)
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	var bg_ok := false
	for tr: TextureRect in menu.find_children("*", "TextureRect", true, false):
		if tr.texture != null and tr.texture.resource_path.ends_with("sfondo_menu.png"):
			bg_ok = true
	_check(bg_ok, "il menu principale ha lo sfondo dipinto")
	menu.queue_free()
	var icon_path := String(ProjectSettings.get_setting("application/config/icon", ""))
	_check(icon_path.ends_with("icona_app.png") and ResourceLoader.exists(icon_path), "icona dell'app impostata nel progetto")
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var fg := String(cfg.get_value("preset.0.options", "launcher_icons/adaptive_foreground_432x432", ""))
	var bgi := String(cfg.get_value("preset.0.options", "launcher_icons/adaptive_background_432x432", ""))
	_check(ResourceLoader.exists(fg) and ResourceLoader.exists(bgi), "icona Android adattiva (primo piano e sfondo) nel preset")

	Sett.touch_controls = old_touch
	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
