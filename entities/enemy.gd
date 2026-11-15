class_name Enemy
extends CharacterBody3D
## Nemico. Sta fermo/vaga nella sua zona finché il giocatore non si avvicina, poi insegue
## usando la navmesh (aggira gli ostacoli) con evitamento degli altri nemici (RVO).
## Se il giocatore scappa troppo lontano torna a casa e si rigenera (leash, come in Diablo).
## Gli "elite" (Campioni, nome blu) e gli "unici" (boss, nome arancione) sono più forti e lasciano più loot.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, RECOVER, RETURN, CHARGE }

const LEASH := 40.0
const ELITE_PREFIX := ["Furioso", "Implacabile", "Corrotto", "Feroce", "Antico", "Vorace"]

var type_id := "predone"
var data: Dictionary = {}
var level := 1
var elite := false
var unique := false
var max_life := 30.0
var life := 30.0
var damage := 5.0
var speed := 4.0
var dead := false
var state := State.IDLE
var state_timer := 0.0
var home := Vector3.ZERO
var zone: Node = null
var display_name := ""
var knockback := Vector3.ZERO
var slow_mult := 1.0
var slow_timer := 0.0
var special_cd := 5.0
var charge_dir := Vector3.ZERO
var _charge_hit := false
var _windup_kind := ""
var _safe_velocity := Vector3.ZERO
var _last_nav_target := Vector3.INF
var _wander_timer := 0.0
var _wander_target := Vector3.INF
var _sleep_check := 0.0
var _asleep := false

var model: Node3D
var nav: NavigationAgent3D
var bar_mesh: QuadMesh
var bar_fg: MeshInstance3D
var bar_bg: MeshInstance3D
var name_label: Label3D
const BAR_WIDTH := 1.3


static func create(p_type: String, p_level: int, p_elite: bool = false) -> Enemy:
	var e := Enemy.new()
	e.type_id = p_type
	e.level = maxi(1, p_level)
	e.elite = p_elite
	e._init_stats()
	return e


func _init_stats() -> void:
	data = EnemyDB.get_data(type_id)
	unique = bool(data.get("unique", false))
	if unique:
		elite = false
	max_life = float(data["hp"]) * (1.0 + 0.3 * (level - 1))
	damage = float(data["damage"]) * (1.0 + 0.2 * (level - 1))
	speed = float(data["speed"])
	display_name = data["name"]
	if elite:
		max_life *= 3.0
		damage *= 1.4
		speed *= 1.1
		display_name = "%s %s" % [data["name"], ELITE_PREFIX.pick_random()]
	life = max_life


func radius() -> float:
	return float(data["radius"]) * (1.25 if elite else 1.0)


func xp_value() -> int:
	var x := float(data["xp"]) * (1.0 + 0.25 * (level - 1))
	if elite:
		x *= 3.0
	return int(x)


func _ready() -> void:
	if data.is_empty():
		_init_stats()
	add_to_group("enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMY
	var r := radius()
	var h := float(data["height"]) * (1.25 if elite else 1.0)

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(h, r * 2.0)
	shape.shape = cap
	shape.position.y = cap.height * 0.5
	add_child(shape)

	nav = NavigationAgent3D.new()
	nav.radius = r + 0.1
	nav.height = h
	nav.max_speed = speed * 1.5
	nav.avoidance_enabled = true
	nav.neighbor_distance = 8.0
	nav.max_neighbors = 8
	nav.time_horizon_agents = 0.8
	nav.path_desired_distance = 0.7
	nav.target_desired_distance = 0.5
	nav.avoidance_layers = 1
	nav.avoidance_mask = 1
	add_child(nav)
	nav.velocity_computed.connect(func(v: Vector3) -> void: _safe_velocity = v)

	var scene := load(data["model"]) as PackedScene
	model = scene.instantiate() if scene else Node3D.new()
	if elite:
		model.scale = Vector3.ONE * 1.25
	add_child(model)

	_build_bar(h)
	if elite or unique:
		var aura := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r + 0.2
		tm.outer_radius = r + 0.45
		aura.mesh = tm
		var col := Color(0.35, 0.55, 1.0) if elite else Color(1.0, 0.5, 0.1)
		aura.material_override = Fx.mat(col, 3.0, false, true)
		aura.position.y = 0.05
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(aura)
	Fx.minimap_icon(self, Color(1.0, 0.5, 0.1) if unique else Color(0.95, 0.15, 0.15), 1.6 if unique else 1.0)
	home = global_position
	_wander_timer = randf_range(1.0, 4.0)


func _build_bar(h: float) -> void:
	var y := h + 0.6
	bar_bg = MeshInstance3D.new()
	var bgm := QuadMesh.new()
	bgm.size = Vector2(BAR_WIDTH + 0.08, 0.17)
	bar_bg.mesh = bgm
	bar_bg.material_override = _bar_mat(Color(0, 0, 0, 0.75), 0)
	bar_bg.position.y = y
	bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar_bg)
	bar_fg = MeshInstance3D.new()
	bar_mesh = QuadMesh.new()
	bar_mesh.size = Vector2(BAR_WIDTH, 0.11)
	bar_fg.mesh = bar_mesh
	bar_fg.material_override = _bar_mat(Color(0.85, 0.12, 0.12), 1)
	bar_fg.position.y = y
	bar_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar_fg)
	var always := elite or unique
	bar_bg.visible = always
	bar_fg.visible = always
	if always:
		name_label = Label3D.new()
		name_label.text = display_name
		name_label.modulate = Color(0.45, 0.65, 1.0) if elite else Color(1.0, 0.6, 0.15)
		name_label.font_size = 36
		name_label.outline_size = 8
		name_label.pixel_size = 0.01
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.no_depth_test = true
		name_label.position.y = y + 0.35
		add_child(name_label)


func _bar_mat(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = priority
	return m


func _player() -> Player:
	if Game.level == null or Game.level.player == null:
		return null
	return Game.level.player


func aggro_range() -> float:
	return float(data.get("aggro", 11.0)) * (1.2 if elite or unique else 1.0)


func attack_range() -> float:
	return float(data["range"]) + (radius() if not data.get("ranged", false) else 0.0)


# --- IA -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	var p := _player()
	if p == null:
		return
	var to_p := p.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var dir_p := to_p.normalized() if dist > 0.01 else Vector3.ZERO

	# Nemici lontani e tranquilli "dormono" per risparmiare CPU
	_sleep_check -= delta
	if _sleep_check <= 0.0:
		_sleep_check = 0.5
		_asleep = state == State.IDLE and dist > 70.0
	if _asleep:
		return

	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	slow_timer -= delta
	if slow_timer <= 0.0:
		slow_mult = 1.0
	state_timer -= delta
	special_cd -= delta
	var spd := speed * slow_mult
	var desired := Vector3.ZERO

	match state:
		State.IDLE:
			if dist < aggro_range() and not p.dead:
				aggro()
			else:
				desired = _wander(delta) * spd * 0.35
		State.CHASE:
			if p.dead or (global_position.distance_to(home) > LEASH and dist > 10.0):
				_go_home()
			elif _can_charge(dist):
				_start_windup("charge")
			elif dist <= attack_range() * 0.95:
				_start_windup("attack")
			else:
				desired = _nav_dir(p.global_position) * spd
		State.WINDUP:
			_face(dir_p)
			if state_timer <= 0.0:
				Fx.set_base_overlay(model, null)
				if _windup_kind == "charge":
					state = State.CHARGE
					state_timer = 0.7
					charge_dir = dir_p
					_charge_hit = false
				else:
					_attack(p, dist, dir_p)
					state = State.RECOVER
					state_timer = float(data["cooldown"])
		State.RECOVER:
			if bool(data.get("ranged", false)) and dist < 5.0:
				desired = -dir_p * spd * 0.7
			if state_timer <= 0.0:
				state = State.CHASE
		State.RETURN:
			desired = _nav_dir(home) * spd * 1.4
			life = minf(max_life, life + max_life * 0.25 * delta)
			_update_bar()
			if global_position.distance_to(home) < 2.0:
				state = State.IDLE
				life = max_life
				_update_bar()
		State.CHARGE:
			velocity = charge_dir * 17.0
			move_and_slide()
			if not _charge_hit and dist < radius() + 1.2:
				_charge_hit = true
				p.take_damage(damage * 1.3, level)
				p.shake(0.2)
			if state_timer <= 0.0 or (get_slide_collision_count() > 0 and get_real_velocity().length() < 4.0):
				state = State.RECOVER
				state_timer = 1.0
			return

	nav.velocity = desired
	velocity = (_safe_velocity if desired.length() > 0.01 else Vector3.ZERO) + knockback
	velocity.y = 0.0
	move_and_slide()
	if desired.length() > 0.1 and state != State.WINDUP:
		_face(desired.normalized())


func _wander(delta: float) -> Vector3:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 7.0)
		var a := randf() * TAU
		_wander_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 4.0)
	if _wander_target == Vector3.INF:
		return Vector3.ZERO
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 0.5:
		_wander_target = Vector3.INF
		return Vector3.ZERO
	return to.normalized()


func _nav_dir(target: Vector3) -> Vector3:
	if _last_nav_target == Vector3.INF or _last_nav_target.distance_to(target) > 0.8:
		nav.target_position = target
		_last_nav_target = target
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	if nav.is_navigation_finished() or d.length() < 0.05:
		d = target - global_position
		d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 0.3)


func _can_charge(dist: float) -> bool:
	return data.get("special", "") == "charge" and special_cd <= 0.0 and dist > 6.0 and dist < 16.0


func _start_windup(kind: String) -> void:
	_windup_kind = kind
	state = State.WINDUP
	state_timer = float(data["windup"]) * (1.4 if kind == "charge" else 1.0)
	if kind == "charge":
		special_cd = 7.0
	Fx.set_base_overlay(model, Color(1.0, 0.45, 0.0, 0.45))


func aggro() -> void:
	if dead or state != State.IDLE:
		return
	state = State.CHASE
	if zone != null and zone.has_method("alert"):
		zone.alert()


func _go_home() -> void:
	state = State.RETURN
	Fx.set_base_overlay(model, null)


func _attack(p: Player, dist: float, dir: Vector3) -> void:
	var special := String(data.get("special", ""))
	if bool(data.get("ranged", false)):
		Projectile.spawn_from_enemy(global_position + Vector3(0, 1.3, 0) + dir * 0.6, dir, damage, level,
			data.get("proj_color", Color.RED), float(data.get("proj_speed", 12.0)))
		return
	if special == "slam" or special == "charge":
		var center := global_position + dir * radius()
		var rad := float(data.get("slam_radius", 3.0))
		Fx.ring(Game.world_root(), center, rad, Color(1.0, 0.5, 0.1), 0.3)
		var d := Vector2(p.global_position.x - center.x, p.global_position.z - center.z).length()
		if d <= rad + 0.4:
			p.take_damage(damage, level)
			p.shake(0.15)
		return
	if dist <= attack_range() + 0.6:
		p.take_damage(damage, level)


func apply_slow(amount: float, time: float) -> void:
	slow_mult = minf(slow_mult, 1.0 - amount)
	slow_timer = maxf(slow_timer, time)


func take_damage(amount: float, knock: Vector3 = Vector3.ZERO, crit: bool = false) -> void:
	if dead:
		return
	life -= amount
	knockback += knock * float(data.get("knock_resist", 1.0)) * (0.4 if elite else 1.0)
	var h := float(data["height"]) * (1.25 if elite else 1.0)
	if crit:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, h + 0.4, 0), "%d!" % roundi(amount), Color(1.0, 0.6, 0.1), 60)
	else:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, h + 0.4, 0), str(roundi(amount)), Color(1, 0.95, 0.7))
	Fx.flash(model, Color(1, 1, 1, 0.7))
	_update_bar()
	if state == State.WINDUP and data.get("interruptible", true) and not elite and _windup_kind == "attack":
		Fx.set_base_overlay(model, null)
		state = State.RECOVER
		state_timer = 0.4
	if state == State.IDLE or state == State.RETURN:
		state = State.IDLE
		aggro()
	if Game.level:
		Game.level.on_enemy_hit(self)
	if life <= 0.0:
		_die()


func _update_bar() -> void:
	var ratio := clampf(life / max_life, 0.0, 1.0)
	bar_fg.visible = true
	bar_bg.visible = true
	bar_mesh.size.x = maxf(BAR_WIDTH * ratio, 0.001)
	bar_mesh.center_offset.x = -(BAR_WIDTH - bar_mesh.size.x) * 0.5


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	nav.avoidance_enabled = false
	Fx.set_base_overlay(model, null)
	bar_fg.visible = false
	bar_bg.visible = false
	if name_label:
		name_label.visible = false
	died.emit(self)
	var p := _player()
	if p:
		p.add_xp(xp_value())
	if unique and Game.hero:
		Game.hero.flags["unique_" + type_id] = true
	Loot.on_enemy_killed(self)
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", deg_to_rad(-90.0), 0.25)
	tw.tween_interval(1.2)
	tw.tween_property(model, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)
