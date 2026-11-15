class_name Abilities
extends RefCounted
## Esegue le abilità definite in data/hero_classes.gd in base al loro "kind".


static func execute(p: Player, ab: Dictionary, point: Vector3) -> void:
	match String(ab["kind"]):
		"melee": _melee(p, ab)
		"projectile": _projectile(p, ab, point)
		"aoe_point": _aoe_point(p, ab, point)
		"aoe_self": _aoe_self(p, ab)
		"dash": _dash(p, ab, point)
		"buff": _buff(p, ab)
		_: push_warning("Tipo di abilità sconosciuto: %s" % ab["kind"])


static func enemies_in_radius(tree: SceneTree, center: Vector3, radius: float) -> Array:
	var out: Array = []
	for e: Enemy in tree.get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d := Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length()
		if d <= radius + e.radius():
			out.append(e)
	return out


static func hit_enemy(p: Player, e: Enemy, mult: float, knock: Vector3, ab: Dictionary) -> void:
	if e.dead:
		return
	var r := p.roll_damage(mult)
	e.take_damage(r[0], knock, r[1])
	p.on_damage_dealt(r[0])
	if ab.has("slow"):
		e.apply_slow(float(ab["slow"]), float(ab.get("slow_time", 2.0)))


## Danni ad area attorno a un punto (usato da esplosioni, atterraggi, onde d'urto).
static func damage_area(p: Player, center: Vector3, radius: float, mult: float, knock: float, ab: Dictionary) -> int:
	var n := 0
	for e: Enemy in enemies_in_radius(p.get_tree(), center, radius):
		var k := e.global_position - center
		k.y = 0.0
		hit_enemy(p, e, mult, k.normalized() * knock, ab)
		n += 1
	break_props(p, center, radius)
	return n


static func break_props(p: Player, center: Vector3, radius: float) -> void:
	for b: Node3D in p.get_tree().get_nodes_in_group("breakable"):
		var d := Vector2(b.global_position.x - center.x, b.global_position.z - center.z).length()
		if d <= radius + 0.5 and b.has_method("break_open"):
			b.break_open(p)


static func _melee(p: Player, ab: Dictionary) -> void:
	var yaw := p.facing_yaw
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var reach := float(ab.get("range", 2.6))
	var arc := float(ab.get("arc", 100.0))
	var mult := float(ab.get("dmg", 1.0))
	var knock := float(ab.get("knock", 3.0))
	var spin := false
	if ab.get("combo", false):
		if p.combo_step == 2:
			spin = true
			mult *= 1.8
			reach += 0.5
			knock = 9.0
		p.combo_step = (p.combo_step + 1) % 3
		p.combo_timer = 1.0
	var hits := int(ab.get("hits", 1))
	var count := 0
	for e: Enemy in enemies_in_radius(p.get_tree(), p.global_position, reach):
		var to := e.global_position - p.global_position
		to.y = 0.0
		if spin or to.length() < 1.0 or rad_to_deg(fwd.angle_to(to.normalized())) <= arc * 0.5:
			for i in hits:
				hit_enemy(p, e, mult, to.normalized() * knock, ab)
			count += 1
	break_props(p, p.global_position + fwd * reach * 0.5, reach * 0.6)
	var col: Color = ab.get("color", Color.WHITE)
	Fx.swing(p, yaw, 360.0 if spin else arc, reach, col, 0.25 if spin else 0.14)
	if spin:
		Fx.ring(Game.world_root(), p.global_position, reach, col, 0.3)
	if count > 0:
		p.shake(0.1 if spin else 0.04)


static func _projectile(p: Player, ab: Dictionary, point: Vector3) -> void:
	var to := point - p.global_position
	to.y = 0.0
	var base_dir := to.normalized() if to.length() > 0.2 else p.forward()
	var count := int(ab.get("count", 1))
	var spread := deg_to_rad(float(ab.get("spread", 0.0)))
	for i in count:
		var ang := 0.0
		if count > 1:
			ang = lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
		var d := base_dir.rotated(Vector3.UP, ang)
		Projectile.spawn_from_player(p, ab, p.global_position + Vector3(0, 1.2, 0) + d * 0.7, d)


static func _aoe_point(p: Player, ab: Dictionary, point: Vector3) -> void:
	var max_range := float(ab.get("max_range", 18.0))
	var to := point - p.global_position
	to.y = 0.0
	if to.length() > max_range:
		point = p.global_position + to.normalized() * max_range
	point.y = 0.0
	var radius := float(ab.get("radius", 4.0))
	var delay := float(ab.get("delay", 0.0))
	var ticks := int(ab.get("ticks", 1))
	var interval := float(ab.get("interval", 0.5))
	var col: Color = ab.get("color", Color.WHITE)
	var root := Game.world_root()
	Fx.telegraph(root, point, radius, col, delay + interval * (ticks - 1) + 0.1)
	if ab.get("strike", false):
		Fx.strike(root, point, delay, col, 0.9)
	for i in ticks:
		var t := delay + interval * i
		p.get_tree().create_timer(maxf(t, 0.01)).timeout.connect(func() -> void:
			if not is_instance_valid(p):
				return
			damage_area(p, point, radius, float(ab.get("dmg", 1.0)), float(ab.get("knock", 4.0)), ab)
			Fx.ring(root, point, radius, col, 0.3)
			if ticks == 1:
				p.shake(0.15))


static func _aoe_self(p: Player, ab: Dictionary) -> void:
	var ticks := int(ab.get("ticks", 1))
	var interval := float(ab.get("interval", 0.3))
	var radius := float(ab.get("radius", 4.0))
	var col: Color = ab.get("color", Color.WHITE)
	for i in ticks:
		p.get_tree().create_timer(maxf(interval * i, 0.01)).timeout.connect(func() -> void:
			if not is_instance_valid(p) or p.dead:
				return
			damage_area(p, p.global_position, radius, float(ab.get("dmg", 1.0)), float(ab.get("knock", 6.0)), ab)
			if ab.get("spin", false):
				Fx.swing(p, p.facing_yaw, 360.0, radius, col, interval)
			else:
				Fx.ring(Game.world_root(), p.global_position, radius, col, 0.35)
				p.shake(0.12))


static func _dash(p: Player, ab: Dictionary, point: Vector3) -> void:
	var mode := String(ab.get("mode", "forward"))
	var dist := float(ab.get("distance", 10.0))
	var to := point - p.global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.2 else p.forward()
	match mode:
		"forward":
			p.start_dash(dir, dist, 24.0, ab)
		"leap":
			var target := p.snap_to_nav(p.global_position + dir * minf(to.length(), dist))
			p.start_leap(target, ab)
		"teleport":
			var target := p.snap_to_nav(p.global_position + dir * minf(to.length(), dist))
			var col: Color = ab.get("color", Color.WHITE)
			Fx.ring(Game.world_root(), p.global_position, 2.0, col, 0.3)
			p.global_position = target
			Fx.ring(Game.world_root(), target, 2.5, col, 0.4)


## Atterraggio del balzo.
static func land(p: Player, ab: Dictionary) -> void:
	var col: Color = ab.get("color", Color.WHITE)
	damage_area(p, p.global_position, float(ab.get("radius", 4.0)), float(ab.get("dmg", 1.0)), float(ab.get("knock", 8.0)), ab)
	Fx.ring(Game.world_root(), p.global_position, float(ab.get("radius", 4.0)), col, 0.35)
	p.shake(0.15)


static func _buff(p: Player, ab: Dictionary) -> void:
	p.add_buff(ab)
	var col: Color = ab.get("color", Color.WHITE)
	if ab.has("heal_pct"):
		p.heal(float(p.stats["max_life"]) * float(ab["heal_pct"]))
	if ab.has("shockwave"):
		damage_area(p, p.global_position, float(ab["shockwave"]), float(ab.get("dmg", 1.0)), float(ab.get("knock", 10.0)), ab)
		Fx.ring(Game.world_root(), p.global_position, float(ab["shockwave"]), col, 0.4)
		p.shake(0.15)
	else:
		Fx.ring(Game.world_root(), p.global_position, 2.5, col, 0.5)
