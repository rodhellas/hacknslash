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
	Sfx.play("explosion", global_position, -4.0, 0.15)
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
