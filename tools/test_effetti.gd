extends SceneTree
## TEST AUTOMATICO degli effetti visivi (core/vfx.gd): ogni shader del kit si costruisce, ogni effetto
## usa la sua texture di textures/vfx, crea i suoi nodi e poi li toglie, proiettili diversi per elemento, stati sui nemici, dissolvenza.
## In headless gli shader non vengono compilati dalla scheda video: va guardato anche a schermo.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_effetti.gd

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


## Quante mesh con lo shader "energy" ci sono sotto `n`.
func _energy_count(n: Node) -> int:
	var V: GDScript = load("res://core/vfx.gd")
	var count := 0
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override == V.material("energy"):
			count += 1
	return count


func _run() -> void:
	game = root.get_node("Game")
	var V: GDScript = load("res://core/vfx.gd")
	var all_ok := true
	for k: String in V.SHADER_CODE:
		var m: ShaderMaterial = V.material(k)
		var code: String = m.shader.code
		if code.contains("%s") or not code.begins_with("shader_type spatial;"):
			all_ok = false
			print("    shader non pronto: ", k)
	_check(all_ok, "%d shader del kit costruiti (senza segnaposto)" % V.SHADER_CODE.size())
	var tex_ok := true
	for k: String in V.TEXTURES:
		var m: ShaderMaterial = V.material(k)
		var t: Variant = m.get_shader_parameter("mask")
		if not t is Texture2D or (t as Texture2D).get_width() < 256:
			tex_ok = false
			print("    texture mancante: ", k, " -> ", V.TEXTURES[k])
	for k: String in ["fire", "scorch:crepa", "pool", "dissolve", "slash"]:
		if not V.material(k).get_shader_parameter("noise_tex") is Texture2D:
			tex_ok = false
			print("    rumore mancante: ", k)
	_check(tex_ok, "%d materiali con la loro texture di textures/vfx (e il rumore dove serve)" % V.TEXTURES.size())
	var hero: Variant = load("res://core/hero_data.gd").create("Prova", "augure")
	hero.level = 30
	game.hero = hero
	game.current_slot = -1
	game.travel("ostia_nova")
	for i in 600:
		await process_frame
		if game.level != null and game.level.level_id == "ostia_nova" and game.level.player != null:
			break
	await _frames(5)
	var lvl: Variant = game.level
	var p: Variant = lvl.player
	var dyn: Node = lvl.dynamic_root
	var pos: Vector3 = p.global_position + Vector3(0, 0, -6)
	var n0: int = dyn.get_child_count()
	for el: String in ["fisico", "fuoco", "freddo", "fulmine"]:
		V.hit(dyn, pos + Vector3(0, 1, 0), el, true)
		V.explosion(dyn, pos, 4.0, el)
	V.lightning(dyn, pos, pos + Vector3(3, 1, 0), Color.WHITE)
	V.strike(dyn, pos, 0.3, "fuoco")
	V.strike(dyn, pos, 0.3, "fulmine")
	V.telegraph(dyn, pos, 3.0, Color.RED, 0.3)
	V.slash(p, 0.0, 120.0, 3.0, Color.CYAN, 0.15)
	await _frames(2)
	_check(dyn.get_child_count() > n0 + 20, "colpi, esplosioni, fulmini, meteore e avvisi creano i loro effetti (%d nodi)" % (dyn.get_child_count() - n0))
	await _frames(500)
	_check(dyn.get_child_count() <= n0 + 2, "dopo qualche secondo gli effetti si tolgono da soli (restano %d nodi)" % (dyn.get_child_count() - n0))

	var kinds := {}
	for el: String in ["fisico", "fuoco", "freddo", "fulmine"]:
		var pr: Variant = load("res://entities/projectile.gd").spawn_from_player(p, {"id": "x", "element": el, "speed": 0.01, "max_range": 1.0}, pos, Vector3.FORWARD)
		var sig := []
		for c: Node in pr.get_children():
			if c is MeshInstance3D:
				var m: Material = (c as MeshInstance3D).material_override
				sig.append(m.shader.resource_path + str(m.get_instance_id()) if m is ShaderMaterial else (c as MeshInstance3D).mesh.get_class())
		kinds[el] = str(sig)
		pr.queue_free()
	_check(kinds.values().size() == 4 and kinds["fuoco"] != kinds["freddo"] and kinds["freddo"] != kinds["fisico"] and kinds["fulmine"] != kinds["fisico"],
		"i proiettili hanno un aspetto diverso per elemento")

	# Direzione artistica "energia": pilum di pura energia, lame di metallo avvolte dall'energia
	var HC: GDScript = load("res://data/hero_classes.gd")
	var pil: Dictionary = {}
	for ab: Dictionary in HC.DATA["legionario"]["abilities"]:
		if ab["id"] == "pilum":
			pil = ab.duplicate()
	pil["speed"] = 0.01
	pil["element"] = "fulmine"
	var ppr: Variant = load("res://entities/projectile.gd").spawn_from_player(p, pil, pos, Vector3.FORWARD)
	var spear: Node = ppr.get_node_or_null("Lancia")
	var has_energy := false
	if spear != null:
		for c: Node in spear.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override == V.material("energy"):
				has_energy = true
	_check(spear != null and has_energy, "il pilum è una lancia di energia (nucleo, guscio che scorre, punta)")
	ppr.queue_free()
	var IDB: GDScript = load("res://data/item_db.gd")
	var App: GDScript = load("res://core/appearance.gd")
	var model: Node3D = load(HC.DATA["legionario"]["model"]).instantiate()
	dyn.add_child(model)
	App.apply(model, {"arma": IDB.make_basic("gladio_plasma", 10)})
	var metal := false
	var shell := false
	# Pezzi graybox (Equip_* = MeshInstance3D) o modello vero (Equip_* = scena con le mesh dentro)
	for piece: Node in App.pieces(model, "arma"):
		var list: Array = piece.find_children("*", "MeshInstance3D", true, false)
		if piece is MeshInstance3D:
			list.append(piece)
		for mi: MeshInstance3D in list:
			if mi.material_override == V.material("energy"):
				shell = true
			elif mi.material_override is StandardMaterial3D or (mi.material_override == null and mi.mesh != null
					and mi.mesh.get_surface_count() > 0 and mi.mesh.surface_get_material(0) is StandardMaterial3D):
				metal = true
	_check(metal and shell, "il gladio indossato ha la lama di metallo avvolta dal guscio di energia")
	model.queue_free()

	# Tutte le abilità con un aspetto "energia" (campo "visual"): creano pezzi di energia e poi li tolgono
	var SKD: GDScript = load("res://data/skill_db.gd")
	var AB: GDScript = load("res://core/abilities.gd")
	var with_visual: Array = []
	for c: String in HC.DATA:
		for ab: Dictionary in HC.DATA[c]["abilities"]:
			if ab.has("visual"):
				with_visual.append(ab)
	for k: String in SKD.EXTRA:
		for ab: Dictionary in SKD.EXTRA[k]:
			if ab.has("visual"):
				with_visual.append(ab)
	var bad: Array = []
	var nb: int = dyn.get_child_count()
	for ab0: Dictionary in with_visual:
		var ab: Dictionary = ab0.duplicate()
		ab["element"] = SKD.ELEMENTS.get(ab["id"], "fisico")
		var before := _energy_count(dyn)
		var made: Node = null
		if ab["kind"] == "projectile":
			ab["speed"] = 0.01
			made = load("res://entities/projectile.gd").spawn_from_player(p, ab, pos + Vector3(0, 30, 0), Vector3.FORWARD)
			if _energy_count(made) == 0:
				bad.append(ab["id"])
			made.queue_free()
			await _frames(1)
		else:
			AB._aoe_point(p, ab, pos)
			var seen := 0
			for i in 90:
				await process_frame
				seen = maxi(seen, _energy_count(dyn) - before)
			if seen == 0:
				bad.append(ab["id"])
	_check(with_visual.size() >= 13 and bad.is_empty(), "%d abilità di energia mostrano i loro pezzi di energia %s" % [with_visual.size(), str(bad)])
	await _frames(400)
	_check(dyn.get_child_count() <= nb + 2, "e poi li tolgono (restano %d nodi)" % (dyn.get_child_count() - nb))

	var E: GDScript = load("res://entities/enemy.gd")
	var e: Variant = E.create("bruto", 30)
	e.position = pos
	lvl.enemies_root.add_child(e)
	await _frames(2)
	e.max_life = 1e9
	e.life = 1e9
	e.apply_dot(10.0, 2.0)
	e.apply_stun(2.0)
	e.apply_slow(0.5, 2.0)
	await _frames(2)
	_check(e._fx_fire != null and e._fx_stun != null and e._fx_frost != null, "stati visibili sul nemico: fiamme, stelline, gelo")
	await _frames(320)   # il rallentamento non scorre mentre è stordito
	_check(e._fx_fire == null and e._fx_stun == null and e._fx_frost == null, "finiti gli stati, gli effetti spariscono")
	e._shield_t = 0.0
	e.take_damage(2e9)
	await _frames(60)
	var dissolving := false
	for mi: Node in e.model.find_children("*", "MeshInstance3D", true, false):
		var m: Material = (mi as MeshInstance3D).material_override
		if m == V.material("dissolve"):
			dissolving = true
	_check(dissolving, "il nemico morto si dissolve")
	p._dash = {"dir": Vector3.FORWARD, "remaining": 5.0, "speed": 20.0, "ab": {"color": Color.CYAN}, "hit": []}
	var n1: int = dyn.get_child_count()
	await _frames(10)
	_check(dyn.get_child_count() > n1, "lo scatto lascia immagini fantasma")
	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
