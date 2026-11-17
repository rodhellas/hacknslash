extends SceneTree
## TEST AUTOMATICO degli effetti visivi (core/vfx.gd): ogni shader del kit si costruisce, ogni effetto
## crea i suoi nodi e poi li toglie, proiettili diversi per elemento, stati sui nemici, dissolvenza.
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
