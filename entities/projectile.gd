class_name Projectile
extends Area3D
## Proiettile: del giocatore (danno calcolato dall'abilità) o dei nemici (danno fisso).

var dir := Vector3.FORWARD
var speed := 20.0
var life := 1.0
var owner_player: Player = null
var ability: Dictionary = {}
var fixed_damage := 0.0
var attacker_level := 1
var pierce := false
var chain := 0
var explode_radius := 0.0
var color := Color.WHITE
var element := "fisico"
var _hit: Array = []


static func spawn_from_player(p: Player, ab: Dictionary, origin: Vector3, d: Vector3) -> Projectile:
	var pr := Projectile.new()
	pr.owner_player = p
	pr.ability = ab
	pr.dir = d.normalized()
	pr.speed = float(ab.get("speed", 24.0))
	pr.life = float(ab.get("max_range", 22.0)) / pr.speed
	pr.pierce = bool(ab.get("pierce", false)) or p.has_power("diana")
	pr.chain = int(ab.get("chain", 0))
	pr.explode_radius = float(ab.get("explode_radius", 0.0))
	pr.color = ab.get("color", Color.WHITE)
	pr.element = String(ab.get("element", "fisico"))
	pr.collision_mask = Layers.WORLD | Layers.ENEMY
	pr._build(float(ab.get("length", 0.8)), float(ab.get("thickness", 0.14)))
	pr.position = origin
	Game.world_root().add_child(pr)
	if String(ab.get("visual", "")) == "lancia_energia":
		# La lancia si forma in mano: lampo che si stringe e scintille che convergono
		Vfx.glow(Game.world_root(), origin, pr._energy_color(), 1.8, 0.16, 0.35)
	return pr


static func spawn_from_enemy(origin: Vector3, d: Vector3, damage: float, level: int, col: Color, spd: float) -> Projectile:
	var pr := Projectile.new()
	pr.dir = d.normalized()
	pr.speed = spd
	pr.life = 18.0 / spd
	pr.fixed_damage = damage
	pr.attacker_level = level
	pr.color = col
	pr.element = ""
	pr.collision_mask = Layers.WORLD | Layers.PLAYER
	pr._build(0.5, 0.25)
	pr.position = origin
	Game.world_root().add_child(pr)
	return pr


func _build(length: float, thickness: float) -> void:
	collision_layer = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(0.3, thickness * 0.6)
	shape.shape = sphere
	add_child(shape)
	_build_visual(length, thickness)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)
	Fx.trail(self, color, clampf(thickness * 0.8, 0.08, 0.3))
	body_entered.connect(_on_body_entered)


## Aspetto per elemento (il proiettile vola lungo −Z locale).
func _build_visual(length: float, thickness: float) -> void:
	match String(ability.get("visual", "")):
		"lancia_energia", "dardo_energia":
			_build_energy_spear(length, thickness)
			return
		"rete_energia":
			_build_energy_net(thickness)
			return
		"bolas_energia":
			_build_energy_bolas(thickness)
			return
		"scure_energia":
			_build_energy_axe(length, thickness)
			return
	match element:
		"fuoco":
			var core := _part(SphereMesh.new(), Vector3.ZERO, Color(1.0, 0.8, 0.4))
			(core.mesh as SphereMesh).radius = thickness * 0.6 + 0.1
			(core.mesh as SphereMesh).height = (thickness * 0.6 + 0.1) * 2.0
			var f := Vfx.fire(self, Vector3.ZERO, maxf(thickness * 2.4, 0.6), 0.0)
			if f:
				f.position = Vector3.ZERO
			var g := Vfx.glow(self, Vector3.ZERO, color, maxf(thickness * 3.0, 0.8), 0.0)
			if g:
				g.position = Vector3.ZERO
		"freddo":
			var pm := PrismMesh.new()
			pm.size = Vector3(thickness * 1.2 + 0.1, length, thickness + 0.1)
			var c := _part(pm, Vector3.ZERO, Color(0.75, 0.95, 1.0))
			c.rotation_degrees.x = -90.0
			var g := Vfx.glow(self, Vector3.ZERO, color, maxf(thickness * 3.0, 0.7), 0.0)
			if g:
				g.position = Vector3.ZERO
		"fulmine":
			var g := Vfx.glow(self, Vector3.ZERO, color, maxf(thickness * 4.0, 0.9), 0.0)
			if g:
				g.position = Vector3.ZERO
			var box := BoxMesh.new()
			box.size = Vector3(thickness * 0.5, thickness * 0.5, length)
			_part(box, Vector3.ZERO, color.lightened(0.5))
		"":
			# nemici: nucleo luminoso
			var g := Vfx.glow(self, Vector3.ZERO, color, 0.9, 0.0)
			if g:
				g.position = Vector3.ZERO
			var sm := SphereMesh.new()
			sm.radius = thickness * 0.5
			sm.height = thickness
			_part(sm, Vector3.ZERO, color)
		_:
			# fisico: asta + punta (pilum, freccia, scure lanciata)
			var shaft := BoxMesh.new()
			shaft.size = Vector3(thickness * 0.5, thickness * 0.5, length)
			_part(shaft, Vector3.ZERO, Color(0.75, 0.7, 0.6))
			var tip := PrismMesh.new()
			tip.size = Vector3(thickness * 1.4, length * 0.25, thickness * 0.6)
			var t := _part(tip, Vector3(0, 0, -length * 0.55), color)
			t.rotation_degrees.x = -90.0
			var g := Vfx.glow(self, Vector3.ZERO, color, 0.6, 0.0)
			if g:
				g.position = Vector3(0, 0, -length * 0.5)


## Colore dell'energia: quello dell'abilità, spostato verso l'elemento (una variante di fuoco la fa arancio).
func _energy_color() -> Color:
	return color.lerp(Vfx.element_color(element), 0.5) if element != "fisico" else color


## Pilum di pura energia (direzione artistica: nel 3000 le armi sono energia, vedi docs/GAME_DESIGN.md):
## nucleo bianco, guscio di energia che scorre, punta luminosa; compare allungandosi dalla mano.
func _build_energy_spear(length: float, thickness: float) -> void:
	var col := _energy_color()
	var spear := Node3D.new()
	spear.name = "Lancia"
	add_child(spear)
	var core := BoxMesh.new()
	core.size = Vector3(thickness * 0.35, thickness * 0.35, length)
	var c := _part(core, Vector3.ZERO, col.lightened(0.7))
	c.reparent(spear, false)
	var shell := CapsuleMesh.new()
	shell.radius = thickness * 1.1
	shell.height = length * 1.1
	var sh := MeshInstance3D.new()
	sh.mesh = shell
	sh.rotation_degrees.x = 90.0
	Vfx.make_energy(sh, col)
	spear.add_child(sh)
	var tip := PrismMesh.new()
	tip.size = Vector3(thickness * 1.6, length * 0.28, thickness * 0.7)
	var t := _part(tip, Vector3(0, 0, -length * 0.6), col.lightened(0.5))
	t.rotation_degrees.x = -90.0
	t.reparent(spear, false)
	var g := Vfx.glow(spear, Vector3.ZERO, col, 1.0, 0.0)
	if g:
		g.position = Vector3(0, 0, -length * 0.6)
	var g2 := Vfx.glow(spear, Vector3.ZERO, col, length * 1.2, 0.0)
	if g2:
		g2.set_instance_shader_parameter("intensity", 0.8)
	spear.scale = Vector3(1, 1, 0.2)
	spear.create_tween().tween_property(spear, "scale", Vector3.ONE, 0.09).set_ease(Tween.EASE_OUT)


## Fa girare un nodo su sé stesso (rete, bolas, scure) finché il proiettile esiste.
func _spin(n: Node3D, axis: String, period: float) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "rotation:" + axis, TAU, period).from(0.0)


## Rete di filamenti di energia che ruota (Rete del reziario).
func _build_energy_net(thickness: float) -> void:
	var col := _energy_color()
	var net := Node3D.new()
	net.name = "Rete"
	add_child(net)
	var r := maxf(thickness, 0.5)
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.92
	ring.outer_radius = r
	Vfx.energy_part(net, ring, Vector3.ZERO, col, Vector3(90, 0, 0))
	for i in 4:
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 2.0, 0.03, 0.03)
		Vfx.energy_part(net, bm, Vector3.ZERO, col, Vector3(0, 0, 45.0 * i))
	var g := Vfx.glow(net, Vector3.ZERO, col, r * 2.5, 0.0)
	if g:
		g.position = Vector3.ZERO
		g.set_instance_shader_parameter("intensity", 0.8)
	_spin(net, "z", 0.5)


## Bolas di energia: due sfere legate da un raggio, che girano.
func _build_energy_bolas(thickness: float) -> void:
	var col := _energy_color()
	var b := Node3D.new()
	b.name = "Bolas"
	add_child(b)
	var half := maxf(thickness, 0.4) * 0.8
	for sx: float in [-1.0, 1.0]:
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		Vfx.energy_part(b, sm, Vector3(sx * half, 0, 0), col)
		var g := Vfx.glow(b, Vector3.ZERO, col, 0.7, 0.0)
		if g:
			g.position = Vector3(sx * half, 0, 0)
	var cord := BoxMesh.new()
	cord.size = Vector3(half * 2.0, 0.025, 0.025)
	_part(cord, Vector3.ZERO, col.lightened(0.6)).reparent(b, false)
	_spin(b, "y", 0.25)


## Scure rotante: la scure vera (metallo) avvolta dall'energia, che gira su sé stessa.
func _build_energy_axe(length: float, thickness: float) -> void:
	var col := _energy_color()
	var axe := Node3D.new()
	axe.name = "Scure"
	add_child(axe)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.06, maxf(length, 0.6) * 1.2, 0.06)
	var hm := MeshInstance3D.new()
	hm.mesh = handle
	hm.material_override = Fx.mat(VisualDB.MATERIALS["legno"])
	axe.add_child(hm)
	var head := BoxMesh.new()
	head.size = Vector3(0.05, 0.25, maxf(thickness, 0.4) * 0.7)
	var am := MeshInstance3D.new()
	am.mesh = head
	am.position = Vector3(0, maxf(length, 0.6) * 0.45, -0.1)
	am.material_override = Fx.mat(VisualDB.MATERIALS["acciaio"])
	axe.add_child(am)
	var shell := BoxMesh.new()
	shell.size = head.size + Vector3(0.07, 0.07, 0.07)
	Vfx.energy_part(axe, shell, am.position, col)
	_spin(axe, "x", 0.22)


func _part(mesh: Mesh, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Fx.mat(col, 4.0, false, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi


func _ready() -> void:
	_orient()


func _orient() -> void:
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		if explode_radius > 0.0 and owner_player != null:
			_explode()
		queue_free()


func _on_body_entered(body: Node) -> void:
	if owner_player != null:
		if body is Enemy:
			var e := body as Enemy
			if e.dead or e in _hit:
				return
			_hit.append(e)
			if not is_instance_valid(owner_player):
				queue_free()
				return
			if explode_radius > 0.0:
				_explode()
				queue_free()
				return
			Abilities.hit_enemy(owner_player, e, float(ability.get("dmg", 1.0)), dir * float(ability.get("knock", 3.0)), ability)
			if chain > 0 and _chain_to_next(e):
				return
			if not pierce:
				queue_free()
		elif body is CollisionObject3D and (body as CollisionObject3D).collision_layer & Layers.WORLD:
			if explode_radius > 0.0:
				_explode()
			queue_free()
	else:
		if body is Player:
			(body as Player).take_damage(fixed_damage, attacker_level)
			Fx.burst(Game.world_root(), global_position, color, 8, 4.0, 0.08, 0.3)
			Vfx.glow(Game.world_root(), global_position, color, 1.2, 0.18)
			queue_free()
		elif body is CollisionObject3D and (body as CollisionObject3D).collision_layer & Layers.WORLD:
			queue_free()


func _explode() -> void:
	Abilities.damage_area(owner_player, global_position, explode_radius, float(ability.get("dmg", 1.0)), float(ability.get("knock", 6.0)), ability)
	Fx.explosion(Game.world_root(), Vector3(global_position.x, 0.0, global_position.z), explode_radius, color, element)
	Sfx.play(SoundDB.explosion_sound(element), global_position, 0.0, 0.15)
	owner_player.shake(0.08)


## Fulmine a catena: cerca il nemico più vicino non ancora colpito.
func _chain_to_next(from: Enemy) -> bool:
	var best: Enemy = null
	var best_d := 9.0
	for e: Enemy in Abilities.enemies_in_radius(get_tree(), from.global_position, 9.0):
		if e in _hit:
			continue
		var d := e.global_position.distance_to(from.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	chain -= 1
	var target := best.global_position + Vector3(0, 1.0, 0)
	if element == "fulmine":
		Vfx.lightning(Game.world_root(), global_position, target, color, 0.2)
	dir = (target - global_position).normalized()
	life = 1.0
	_orient()
	return true
