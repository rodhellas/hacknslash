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
var rare := false                # capo di un gruppo raro (nome giallo); i suoi servitori sono normali
var affixes: Array = []          # affissi delle elite (EnemyDB.ELITE_AFFIXES)
var pack_name := ""              # nome scelto dal gruppo (prefisso dei Campioni o nome del capo raro)
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
var _summon_cd := 5.0
var stun_timer := 0.0
var _phase := 0                  # fasi del boss superate (EnemyDB.BOSSES)
var _boss_cd := 4.0
var _boss_attacks: Array = []
var _shield_adds: Array = []
var enraged := false
var dot_dps := 0.0               # danno al secondo delle fiamme (varianti delle abilità)
var dot_timer := 0.0
var _dot_tick := 0.0
var _dot_color := Color(1.0, 0.5, 0.15)

var model: Node3D
var nav: NavigationAgent3D
var bar_mesh: QuadMesh
var bar_fg: MeshInstance3D
var bar_bg: MeshInstance3D
var name_label: Label3D
const BAR_WIDTH := 1.3


static func create(p_type: String, p_level: int, p_elite: bool = false, p_affixes: Array = [], p_rare: bool = false, p_pack_name: String = "") -> Enemy:
	var e := Enemy.new()
	e.type_id = p_type
	e.level = maxi(1, p_level)
	e.elite = p_elite or p_rare
	e.rare = p_rare
	e.affixes = p_affixes.duplicate()
	e.pack_name = p_pack_name
	e._init_stats()
	return e


func has_affix(id: String) -> bool:
	return affixes.has(id)


func _init_stats() -> void:
	data = EnemyDB.get_data(type_id)
	unique = bool(data.get("unique", false))
	if unique:
		elite = false
		rare = false
	# Difficoltà / grado del labirinto: da Esperto in su i nemici hanno almeno il livello dell'eroe
	var sc: Dictionary = Game.enemy_scaling() if Game else {}
	level = maxi(level, int(sc.get("min_level", 0)))
	max_life = float(data["hp"]) * (1.0 + 0.3 * (level - 1)) * float(sc.get("hp", 1.0))
	damage = float(data["damage"]) * (1.0 + 0.2 * (level - 1)) * float(sc.get("dmg", 1.0))
	speed = float(data["speed"])
	display_name = data["name"]
	if elite:
		max_life *= 4.0 if rare else 3.0
		damage *= 1.4
		speed *= 1.1
		if rare:
			display_name = pack_name if pack_name != "" else "%s %s" % [EnemyDB.RARE_NAMES_A.pick_random(), EnemyDB.RARE_NAMES_B.pick_random()]
		else:
			display_name = "%s %s" % [data["name"], pack_name if pack_name != "" else ELITE_PREFIX.pick_random()]
	if has_affix("rapido"):
		speed *= 1.35
	if unique:
		_boss_attacks = (EnemyDB.BOSSES.get(type_id, {}).get("attacks", []) as Array).duplicate()
	life = max_life


func radius() -> float:
	return float(data["radius"]) * (1.25 if elite else 1.0)


func xp_value() -> int:
	var x := float(data["xp"]) * (1.0 + 0.25 * (level - 1))
	if elite:
		x *= 4.0 if rare else 3.0
	if Game:
		x *= float(Game.enemy_scaling().get("xp", 1.0))
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
	# "model_scale": riusa il modello di un altro nemico più grande (es. i boss dei dungeon)
	model.scale = Vector3.ONE * float(data.get("model_scale", 1.0)) * (1.25 if elite else 1.0)
	add_child(model)

	_build_bar(h)
	if elite or unique:
		var aura := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r + 0.2
		tm.outer_radius = r + 0.45
		aura.mesh = tm
		var col := name_color()
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
		if not affixes.is_empty():
			name_label.text += "\n" + affix_text()
		name_label.modulate = name_color()
		name_label.font_size = 36
		name_label.outline_size = 8
		name_label.pixel_size = 0.01
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.no_depth_test = true
		name_label.position.y = y + 0.35
		add_child(name_label)


## Colore del nome: blu i Campioni, giallo i capi rari, arancione i boss.
func name_color() -> Color:
	if unique:
		return Color(1.0, 0.6, 0.15)
	if rare:
		return Color(1.0, 0.9, 0.3)
	if elite:
		return Color(0.45, 0.65, 1.0)
	return Color.WHITE


func affix_text() -> String:
	var names: Array = []
	for a: String in affixes:
		names.append(String((EnemyDB.ELITE_AFFIXES.get(a, {"name": a}) as Dictionary)["name"]))
	return " · ".join(names)


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
	_tick_dot(delta)
	_update_status_fx()
	if dead:
		return
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = knockback
		velocity.y = 0.0
		move_and_slide()
		return
	slow_timer -= delta
	if slow_timer <= 0.0:
		slow_mult = 1.0
	state_timer -= delta
	special_cd -= delta
	_summon_cd -= delta
	_boss_cd -= delta
	if not _shield_adds.is_empty():
		_check_shield_adds()
	if not affixes.is_empty() and state != State.IDLE and state != State.RETURN and not p.dead:
		_tick_affixes(delta, p, dist)
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
			elif not _boss_attacks.is_empty() and _boss_cd <= 0.0 and dist < 22.0:
				_boss_attack(p)
			elif data.has("summon") and _summon_cd <= 0.0:
				_summon()
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
				_hit_player(p, damage * 1.3)
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
	if not bool(data.get("ranged", false)):
		Sfx.play(SoundDB.enemy_family(type_id) + "_attacco", global_position, 0.0, 0.2)


## Il boss chiama rinforzi attorno a sé.
func _summon() -> void:
	_summon_cd = float(data.get("summon_cd", 15.0))
	var container: Node = Game.level.enemies_root if Game.level else get_parent()
	var n := int(data.get("summon_count", 2))
	Fx.popup_speech(self, "A me, ciurma!", float(data["height"]) + 1.2, 2.0)
	Fx.ring(Game.world_root(), global_position, 6.0, Color(1.0, 0.5, 0.1), 0.5)
	for i in n:
		var a := TAU * i / n + randf() * 0.5
		var e := Enemy.create(String(data["summon"]), level)
		e.position = global_position + Vector3(cos(a), 0, sin(a)) * 4.0
		container.add_child(e)
		Fx.burst(Game.world_root(), e.position + Vector3(0, 1, 0), Color(0.3, 0.8, 1.0), 12, 4.0, 0.12, 0.5, 0.0)
		e.aggro()


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
		Sfx.play("proiettile_nemico", global_position, 0.0, 0.15)
		return
	if special == "slam" or special == "charge":
		var center := global_position + dir * radius()
		var rad := float(data.get("slam_radius", 3.0))
		Fx.ring(Game.world_root(), center, rad, Color(1.0, 0.5, 0.1), 0.3)
		Fx.burst(Game.world_root(), center + Vector3(0, 0.2, 0), Color(0.5, 0.42, 0.32), 16, 6.0, 0.18, 0.5, -10.0, 70.0)
		Sfx.play("esplosione_fisico", center, -2.0, 0.15)
		var d := Vector2(p.global_position.x - center.x, p.global_position.z - center.z).length()
		if d <= rad + 0.4:
			_hit_player(p, damage)
			p.shake(0.15)
		return
	if dist <= attack_range() + 0.6:
		_hit_player(p, damage)


func _hit_player(p: Player, amount: float) -> void:
	var before := p.life
	p.take_damage(amount, level)
	if has_affix("vampirico") and p.life < before:
		life = minf(max_life, life + (before - p.life) * 0.3)
		_update_bar()


# --- Boss: fasi e attacchi speciali --------------------------------------------------------------

func _check_phase() -> void:
	var phases: Array = EnemyDB.BOSSES.get(type_id, {}).get("phases", [])
	while _phase < phases.size() and life / max_life <= float(phases[_phase]["at"]):
		_enter_phase(phases[_phase])
		_phase += 1


func _enter_phase(ph: Dictionary) -> void:
	Sfx.play("boss_ruggito", global_position)
	if ph.has("say"):
		Fx.popup_speech(self, String(ph["say"]), float(data["height"]) + 1.2, 2.5)
	for act: String in ph.get("do", []):
		if act == "enrage":
			enraged = true
			speed *= 1.3
			damage *= 1.25
			Fx.ring(Game.world_root(), global_position, 5.0, Color(1.0, 0.15, 0.1), 0.6)
			Vfx.fire(self, global_position, radius() * 2.0, 1.2)
			Fx.burst(Game.world_root(), global_position + Vector3(0, 1.5, 0), Color(1.0, 0.2, 0.1), 30, 6.0, 0.15, 0.6, 2.0)
		elif act == "summon" or act == "shield":
			var adds := _spawn_adds(String(ph.get("type", data.get("summon", "predone"))), int(ph.get("n", 3)))
			if act == "shield":
				_shield_adds = adds
				_shield_t = 9999.0
				_show_shield(true)
				if Game.level:
					Game.level.hud.show_message("%s è protetto: uccidi i rinforzi!" % display_name, 3.0)
		elif act.begins_with("attack:"):
			_boss_attacks.append(act.substr(7))
	_boss_cd = minf(_boss_cd, 2.0)


func _spawn_adds(t: String, n: int) -> Array:
	var out: Array = []
	var container: Node = Game.level.enemies_root if Game.level else get_parent()
	for i in n:
		var a := TAU * i / n
		var e := Enemy.create(t, level)
		e.position = global_position + Vector3(cos(a), 0, sin(a)) * 4.5
		container.add_child(e)
		Fx.burst(Game.world_root(), e.position + Vector3(0, 1, 0), Color(0.3, 0.8, 1.0), 12, 4.0, 0.12, 0.5, 0.0)
		e.aggro()
		out.append(e)
	return out


func _check_shield_adds() -> void:
	for i in range(_shield_adds.size() - 1, -1, -1):
		if not is_instance_valid(_shield_adds[i]) or (_shield_adds[i] as Enemy).dead:
			_shield_adds.remove_at(i)
	if _shield_adds.is_empty():
		_shield_t = 0.0
		_show_shield(false)
		Fx.ring(Game.world_root(), global_position, 4.0, Color(0.6, 0.8, 1.0), 0.4)


func _show_shield(on: bool) -> void:
	if _shield_mesh == null:
		_shield_mesh = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = radius() + 0.6
		sm.height = (radius() + 0.6) * 2.0
		_shield_mesh.mesh = sm
		Vfx.make_bubble(_shield_mesh, Color(0.6, 0.8, 1.0, 0.8))
		_shield_mesh.position.y = float(data["height"]) * 0.5
		_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_shield_mesh)
	_shield_mesh.visible = on


func _boss_attack(p: Player) -> void:
	_boss_cd = EnemyDB.BOSS_ATTACK_CD * (0.7 if enraged else 1.0)
	var kind: String = _boss_attacks.pick_random()
	Sfx.play("boss_attacco", global_position)
	match kind:
		"nova":
			Fx.ring(Game.world_root(), global_position, 3.0, Color(1.0, 0.4, 0.9), 0.4)
			Vfx.glow(Game.world_root(), global_position + Vector3(0, 1.5, 0), Color(1.0, 0.4, 0.9), 4.0, 0.3)
			for i in 16:
				var a := TAU * i / 16.0
				Projectile.spawn_from_enemy(global_position + Vector3(0, 1.2, 0), Vector3(cos(a), 0, sin(a)), damage * 0.6, level,
					Color(1.0, 0.4, 0.9), 9.0)
		"pioggia":
			for i in 6:
				var a := randf() * TAU
				Hazard.spawn(p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 5.0), 2.2, 1.2, 0.0,
					damage * 0.9, Color(1.0, 0.45, 0.1), level)
		"onda":
			Hazard.spawn(global_position, 7.0, 1.3, 0.0, damage * 1.3, Color(1.0, 0.6, 0.2), level)
		"salto":
			var dest := p.global_position
			Hazard.spawn(dest, 3.5, 1.0, 0.0, damage * 1.2, Color(1.0, 0.3, 0.1), level)
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(func() -> void: Vfx.afterimage(model, Color(1.0, 0.4, 0.2), 0.4))
			tw.tween_property(self, "global_position", Vector3(dest.x, 0.0, dest.z), 0.35)


# --- Affissi delle elite --------------------------------------------------------------------

var _aff_cd: Dictionary = {}
var _shield_t := 0.0
var _shield_mesh: MeshInstance3D


func _aff_ready(id: String, delta: float, every: float, first: float) -> bool:
	var t := float(_aff_cd.get(id, first)) - delta
	if t <= 0.0:
		_aff_cd[id] = every * randf_range(0.85, 1.15)
		return true
	_aff_cd[id] = t
	return false


func _tick_affixes(delta: float, p: Player, dist: float) -> void:
	if _shield_t > 0.0:
		_shield_t -= delta
		if _shield_t <= 0.0 and _shield_mesh:
			_shield_mesh.visible = false
	if has_affix("scudato") and _aff_ready("scudato", delta, 10.0, 3.0):
		_shield_t = 3.0
		_show_shield(true)
	if has_affix("incendiario") and dist < 25.0 and _aff_ready("incendiario", delta, 5.0, 2.0):
		Hazard.spawn(p.global_position, 2.5, 0.9, 4.0, damage * 0.6, Color(1.0, 0.4, 0.1), level)
	if has_affix("gelido") and dist < 25.0 and _aff_ready("gelido", delta, 6.0, 3.0):
		for i in 3:
			var a := randf() * TAU
			Hazard.spawn(p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 3.0), 2.0, 1.4, 0.0,
				damage * 1.1, Color(0.55, 0.85, 1.0), level, 0.5)
	if has_affix("teletrasporto") and dist > 6.0 and dist < 35.0 and _aff_ready("teletrasporto", delta, 6.0, 2.0):
		var a := randf() * TAU
		Fx.burst(Game.world_root(), global_position + Vector3(0, 1, 0), Color(0.7, 0.4, 1.0), 14, 4.0, 0.1, 0.4, 0.0)
		var dest := p.global_position + Vector3(cos(a), 0, sin(a)) * 2.5
		var snapped := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, dest)
		if snapped != Vector3.ZERO and snapped.y < 1.0:
			global_position = Vector3(snapped.x, 0.0, snapped.z)
		Fx.burst(Game.world_root(), global_position + Vector3(0, 1, 0), Color(0.7, 0.4, 1.0), 14, 4.0, 0.1, 0.4, 0.0)
	if has_affix("elettrico") and dist < 20.0 and _aff_ready("elettrico", delta, 4.0, 1.5):
		for i in 6:
			var a := TAU * i / 6.0 + randf() * 0.3
			Projectile.spawn_from_enemy(global_position + Vector3(0, 1.0, 0), Vector3(cos(a), 0, sin(a)), damage * 0.5, level,
				Color(0.6, 0.8, 1.0), 10.0)


## Stordimento (varianti delle abilità): niente movimento né attacchi. Elite e boss la metà.
func apply_stun(time: float) -> void:
	if dead or _shield_t > 0.0:
		return
	var t := time * (0.5 if (elite or unique) else 1.0)
	if stun_timer <= 0.0:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, float(data["height"]) + 0.9, 0), "Stordito", Color(1.0, 0.95, 0.4), 26)
	stun_timer = maxf(stun_timer, t)
	if state == State.WINDUP:
		Fx.set_base_overlay(model, null)
		state = State.RECOVER
		state_timer = 0.2
	elif state == State.CHARGE:
		state = State.RECOVER
		state_timer = 0.2


## Fiamme / veleno: dps danni al secondo per time secondi (la nuova applicazione sostituisce se è più forte).
func apply_dot(dps: float, time: float, col: Color = Color(1.0, 0.5, 0.15)) -> void:
	if dead or dps <= 0.0 or _shield_t > 0.0:
		return
	if dps >= dot_dps or dot_timer <= 0.0:
		dot_dps = dps
		_dot_color = col
	dot_timer = maxf(dot_timer, time)


# --- Stati visibili (fiamme, stordimento, gelo) ------------------------------------------------------

var _fx_fire: MeshInstance3D
var _fx_stun: Node3D
var _fx_frost: MeshInstance3D


func _update_status_fx() -> void:
	var h := float(data["height"]) * (1.25 if elite else 1.0) * float(data.get("model_scale", 1.0))
	var burning := dot_timer > 0.0
	if burning and _fx_fire == null:
		_fx_fire = Vfx.fire(self, global_position, maxf(radius() * 2.2, 1.0), 0.0)
		if _fx_fire:
			_fx_fire.position = Vector3(0, h * 0.45, 0)
	elif not burning and _fx_fire != null:
		_fx_fire.queue_free()
		_fx_fire = null
	var stunned := stun_timer > 0.0
	if stunned and _fx_stun == null:
		_fx_stun = Node3D.new()
		add_child(_fx_stun)
		_fx_stun.position = Vector3(0, h + 0.3, 0)
		for i in 3:
			var g := Vfx.glow(_fx_stun, global_position, Color(1.0, 0.95, 0.4), 0.35, 0.0)
			if g:
				g.position = Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0)) * 0.5
	elif not stunned and _fx_stun != null:
		_fx_stun.queue_free()
		_fx_stun = null
	if _fx_stun != null:
		_fx_stun.rotation.y += 0.12
	var frozen := slow_timer > 0.0 and slow_mult < 0.95
	if frozen and _fx_frost == null:
		_fx_frost = Vfx.pool(self, radius() + 0.6, Color(0.55, 0.85, 1.0, 0.7))
	elif not frozen and _fx_frost != null:
		_fx_frost.queue_free()
		_fx_frost = null


func _clear_status_fx() -> void:
	for n: Variant in [_fx_fire, _fx_stun, _fx_frost]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_fx_fire = null
	_fx_stun = null
	_fx_frost = null


func _tick_dot(delta: float) -> void:
	if dot_timer <= 0.0:
		return
	dot_timer -= delta
	_dot_tick -= delta
	if _dot_tick <= 0.0:
		_dot_tick = 0.5
		Fx.burst(Game.world_root(), global_position + Vector3(0, float(data["height"]) * 0.6, 0), _dot_color, 4, 2.0, 0.08, 0.35, 3.0)
		take_damage(dot_dps * 0.5, Vector3.ZERO, false, true)
	if dot_timer <= 0.0:
		dot_dps = 0.0


func apply_slow(amount: float, time: float) -> void:
	slow_mult = minf(slow_mult, 1.0 - amount)
	slow_timer = maxf(slow_timer, time)


func take_damage(amount: float, knock: Vector3 = Vector3.ZERO, crit: bool = false, quiet: bool = false, element: String = "fisico") -> void:
	if dead:
		return
	if _shield_t > 0.0:
		if not quiet:
			Fx.popup_text(Game.world_root(), global_position + Vector3(0, float(data["height"]) + 0.6, 0), "Immune", Color(0.6, 0.8, 1.0), 30)
		return
	if has_affix("corazzato"):
		amount *= 0.65
		knock = Vector3.ZERO
	life -= amount
	knockback += knock * float(data.get("knock_resist", 1.0)) * (0.4 if elite else 1.0)
	if unique and life > 0.0:
		_check_phase()
	var h := float(data["height"]) * (1.25 if elite else 1.0)
	if quiet:
		if Settings.damage_numbers:
			Fx.popup_text(Game.world_root(), global_position + Vector3(0, h + 0.2, 0), str(roundi(amount)), _dot_color.lightened(0.2), 30)
		_update_bar()
		if life <= 0.0:
			_die()
		return
	# Numeri di danno: più grandi i critici e i colpi che tolgono tanta vita
	var big := clampf(amount / maxf(max_life, 1.0), 0.0, 1.0)
	var ecol: Color = (ItemDB.ELEMENTS.get(element, ItemDB.ELEMENTS["fisico"]) as Dictionary)["color"]
	if not Settings.damage_numbers:
		pass
	elif crit:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, h + 0.4, 0), "%s!" % _fmt(amount), Color(1.0, 0.75, 0.1).lerp(ecol, 0.35), 64 + roundi(big * 30.0))
	else:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, h + 0.4, 0), _fmt(amount), ecol, 40 + roundi(big * 24.0))
	Fx.flash(model, Color(1, 1, 1, 0.7))
	Vfx.hit(Game.world_root(), global_position + Vector3(0, h * 0.6, 0), element, crit)
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


## 12345 -> "12.345", 1234567 -> "1,23 M" (i danni crescono molto nei Tormenti).
static func _fmt(v: float) -> String:
	var n := roundi(v)
	if n >= 1000000:
		return "%.2f M" % (n / 1000000.0)
	if n >= 10000:
		return "%d.%03d" % [n / 1000, n % 1000]
	return str(n)


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
	var h := float(data["height"]) * (1.25 if elite else 1.0)
	Fx.burst(Game.world_root(), global_position + Vector3(0, h * 0.5, 0), Color(0.45, 0.4, 0.35), 14 if not unique else 40,
		4.0, 0.18 if not unique else 0.3, 0.7, -6.0)
	Sfx.play(SoundDB.enemy_family(type_id) + "_morte", global_position, 3.0 if (elite or unique) else 0.0)
	if unique:
		Fx.explosion(Game.world_root(), global_position, 6.0, Color(1.0, 0.5, 0.1))
		Sfx.play("esplosione_fuoco", global_position)
	var p := _player()
	if p:
		p.add_xp(xp_value())
		p.on_enemy_killed(self)
	var in_rift := Game.level != null and int(Game.level.rift_grade) > 0
	if unique and Game.hero and not in_rift:
		Game.hero.flags["unique_" + type_id] = true
		Cutscene.trigger.call_deferred("boss:" + type_id)
	if has_affix("esplosivo"):
		Hazard.spawn(global_position, 3.5, 1.0, 0.0, damage * 1.5, Color(1.0, 0.6, 0.2), level)
	if Game.level and Game.level.has_method("on_enemy_died"):
		Game.level.on_enemy_died(self)
	if not in_rift:
		Bounties.on_kill(self)
		Quests.notify("kill", type_id)
		if unique:
			Quests.notify("kill_unique", type_id)
	Loot.on_enemy_killed(self)
	_clear_status_fx()
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", deg_to_rad(-90.0), 0.25)
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void: Vfx.dissolve(model, 0.9, Color(1.0, 0.6, 0.2) if not unique else Color(1.0, 0.3, 0.1)))
	tw.tween_interval(1.0)
	tw.tween_callback(queue_free)
