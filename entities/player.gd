class_name Player
extends CharacterBody3D
## Eroe controllato dal giocatore. Controlli stile Diablo 3:
##   Clic sinistro (tieni premuto): muovi / attacca il nemico sotto il cursore / raccogli / interagisci
##   Shift + clic sinistro: attacca sul posto        Clic destro, 1-4: abilità
##   Q: pozione    E: interagisci con l'oggetto più vicino    WASD: movimento diretto (opzionale)
##   T: portale cittadino (torna a Ostia Nova; in città compare il portale per tornare indietro)
## Il modello 3D viene caricato dalla scena indicata nella classe (sostituibile con un modello Tripo).
## Se il modello contiene un AnimationPlayer con animazioni "idle", "run", "attack", "cast", "hit",
## "death" vengono riprodotte automaticamente.

signal xp_changed(xp: int, xp_next: int, level: int)
signal inventory_changed
signal died

const POTION_CD := 30.0
const POTION_HEAL := 0.6
const INTERACT_RANGE := 2.4
const PORTAL_TIME := 1.5

var hero: HeroData
var cls: Dictionary
var stats: Dictionary = {}
var abilities: Dictionary = {}
var cooldowns: Dictionary = {}
var life := 100.0
var resource := 0.0
var dead := false
var buffs: Array = []
var potion_cd := 0.0
var attack_cd := 0.0
var cast_lock := 0.0
var combo_step := 0
var combo_timer := 0.0
var facing_yaw := 0.0
var powers: Dictionary = {}      # poteri dei leggendari indossati
var shield := 0.0                # scudo che assorbe danni (Scutum dell'Ultima Legione)
var _shield_t := 0.0
var _shield_cd := 0.0
var portal_t := 0.0              # > 0 mentre si apre il portale cittadino

var move_target := Vector3.INF
var attack_target: Enemy = null
var interact_target: Node3D = null
var lmb_held := false

var model: Node3D
var nav: NavigationAgent3D
var anim: AnimationPlayer
var buff_bubble: MeshInstance3D
var camera: Camera3D
var _dash: Dictionary = {}
var _last_nav_target := Vector3.INF
var _warn_cd := 0.0
var _bob_t := 0.0


func setup(p_hero: HeroData) -> void:
	hero = p_hero
	cls = HeroClasses.get_data(hero.class_id)
	for ab: Dictionary in cls["abilities"]:
		abilities[ab["slot"]] = ab
	refresh_stats()
	life = stats["max_life"]
	resource = stats["resource_max"] if cls.get("resource_starts_full", true) else 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 0.4
	nav.radius = 0.5
	nav.height = 1.8
	add_child(nav)

	var scene := load(cls["model"]) as PackedScene
	model = scene.instantiate() if scene else Node3D.new()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	buff_bubble = MeshInstance3D.new()
	var sb := SphereMesh.new()
	sb.radius = 1.3
	sb.height = 2.6
	buff_bubble.mesh = sb
	buff_bubble.material_override = Fx.mat(Color(1.0, 0.85, 0.4, 0.18), 1.5, true, true)
	buff_bubble.position.y = 1.0
	buff_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	buff_bubble.visible = false
	add_child(buff_bubble)

	var icon := Fx.minimap_icon(model, Color(1.0, 0.85, 0.2), 2.2, "arrow")
	icon.position.y = 32.0


# --- Statistiche ---------------------------------------------------------------

func refresh_stats() -> void:
	stats = hero.compute_stats()
	powers = hero.legendary_powers()
	life = minf(life, stats["max_life"])
	resource = minf(resource, stats["resource_max"])


func attack_speed() -> float:
	return float(stats["aps"]) * (1.0 + buff_sum("aspd"))


func buff_sum(key: String) -> float:
	var t := 0.0
	for b: Dictionary in buffs:
		t += float(b.get(key, 0.0))
	return t


func has_power(id: String) -> bool:
	return powers.has(id)


func potion_cooldown() -> float:
	return POTION_CD * (0.5 if has_power("achille") else 1.0)


func is_unlocked(ab: Dictionary) -> bool:
	return Game.debug_unlock_all or hero.level >= int(ab.get("unlock", 1))


func cooldown_left(ab: Dictionary) -> float:
	if ab.get("slot") == "lmb":
		return 0.0
	return float(cooldowns.get(ab["id"], 0.0))


## Ritorna [danno, critico]
func roll_damage(mult: float) -> Array:
	var dmg := randf_range(stats["weapon_min"], stats["weapon_max"])
	dmg *= (1.0 + float(stats["main_stat"]) / 100.0) * (1.0 + float(stats["damage_pct"]) / 100.0)
	dmg *= mult * (1.0 + buff_sum("damage"))
	var crit := randf() * 100.0 < minf(stats["crit_chance"], 75.0)
	if crit:
		dmg *= 1.0 + float(stats["crit_damage"]) / 100.0
	return [dmg, crit]


func on_damage_dealt(amount: float) -> void:
	var h := float(stats["life_on_hit"]) + amount * buff_sum("lifesteal")
	if h > 0.0:
		life = minf(life + h, stats["max_life"])


# --- Input -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if dead or Game.level == null:
		return
	var h: Dictionary = Game.level.hover
	if event.is_action_pressed("primary"):
		lmb_held = true
		_on_primary_click(h)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("secondary"):
		_try_cast("rmb", h["point"])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_1"):
		_try_cast("1", h["point"])
	elif event.is_action_pressed("skill_2"):
		_try_cast("2", h["point"])
	elif event.is_action_pressed("skill_3"):
		_try_cast("3", h["point"])
	elif event.is_action_pressed("skill_4"):
		_try_cast("4", h["point"])
	elif event.is_action_pressed("potion"):
		use_potion()
	elif event.is_action_pressed("interact"):
		_interact_nearest()
	elif event.is_action_pressed("town_portal"):
		start_town_portal()


func _input(event: InputEvent) -> void:
	if event.is_action_released("primary"):
		lmb_held = false


func _on_primary_click(h: Dictionary) -> void:
	interact_target = null
	attack_target = null
	if Input.is_action_pressed("force_stand"):
		_try_cast("lmb", h["point"])
		return
	match String(h["kind"]):
		"enemy":
			attack_target = h["node"]
			move_target = Vector3.INF
		"interact":
			interact_target = h["node"]
			move_target = Vector3.INF
		_:
			move_target = h["point"]


func _follow_mouse_hold() -> void:
	if not lmb_held or Game.level == null:
		return
	var h: Dictionary = Game.level.hover
	if Input.is_action_pressed("force_stand"):
		_try_cast("lmb", h["point"])
	elif h["kind"] == "enemy" and interact_target == null:
		attack_target = h["node"]
	elif h["kind"] == "ground" and attack_target == null and interact_target == null:
		move_target = h["point"]


# --- Fisica / movimento ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	camera = get_viewport().get_camera_3d()
	_tick(delta)
	if not _dash.is_empty():
		if not _dash.has("leap"):
			_process_dash(delta)
		return
	var wish := _input_direction()
	if portal_t > 0.0:
		if wish != Vector3.ZERO or move_target != Vector3.INF or attack_target != null or interact_target != null:
			cancel_town_portal()
		else:
			portal_t -= delta
			_animate(delta, Vector3.ZERO)
			if portal_t <= 0.0 and Game.level:
				Game.level.use_town_portal()
			return
	if wish != Vector3.ZERO:
		move_target = Vector3.INF
		attack_target = null
		interact_target = null
	else:
		_follow_mouse_hold()
		wish = _auto_actions()
	if cast_lock > 0.0:
		wish = Vector3.ZERO
	velocity = wish * float(stats["move_speed"])
	move_and_slide()
	if wish.length() > 0.1:
		_face_dir(wish, delta)
	_animate(delta, wish)


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.1 or camera == null:
		return Vector3.ZERO
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	return (right.normalized() * input.x - fwd.normalized() * input.y).limit_length(1.0)


func _auto_actions() -> Vector3:
	if attack_target != null:
		if not is_instance_valid(attack_target) or attack_target.dead:
			attack_target = null
			return Vector3.ZERO
		var ab: Dictionary = abilities["lmb"]
		var reach := _ability_reach(ab) + attack_target.radius()
		if _flat_dist(attack_target.global_position) > reach:
			return _nav_toward(attack_target.global_position)
		if _try_cast("lmb", attack_target.global_position) and not lmb_held:
			attack_target = null
		return Vector3.ZERO
	if interact_target != null:
		if not is_instance_valid(interact_target):
			interact_target = null
			return Vector3.ZERO
		if _flat_dist(interact_target.global_position) > INTERACT_RANGE:
			return _nav_toward(interact_target.global_position)
		_interact_with(interact_target)
		interact_target = null
		return Vector3.ZERO
	if move_target != Vector3.INF:
		if _flat_dist(move_target) < 0.35:
			move_target = Vector3.INF
			return Vector3.ZERO
		return _nav_toward(move_target)
	return Vector3.ZERO


func _ability_reach(ab: Dictionary) -> float:
	if ab["kind"] == "melee":
		return float(ab.get("range", 2.5)) * 0.85
	return minf(float(ab.get("max_range", 16.0)) * 0.8, 16.0)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _nav_toward(target: Vector3) -> Vector3:
	if _last_nav_target == Vector3.INF or _last_nav_target.distance_to(target) > 0.5:
		nav.target_position = target
		_last_nav_target = target
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	if nav.is_navigation_finished() or d.length() < 0.05:
		d = target - global_position
		d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO


func snap_to_nav(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	var s := NavigationServer3D.map_get_closest_point(map, p)
	# Scarta i punti vuoti o sulle "isole" della navmesh sopra gli oggetti alti (il suolo è a y 0.5, le isole da 2 m in su)
	if (s == Vector3.ZERO and p.length() > 1.0) or s.y > 1.0:
		return Vector3(p.x, 0.0, p.z)
	return Vector3(s.x, 0.0, s.z)


func forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func _face_dir(dir: Vector3, delta: float) -> void:
	var target := atan2(-dir.x, -dir.z)
	facing_yaw = lerp_angle(facing_yaw, target, 1.0 - exp(-14.0 * delta))
	model.rotation.y = facing_yaw


func _face_point(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() > 0.1:
		facing_yaw = atan2(-to.x, -to.z)
		model.rotation.y = facing_yaw


func _tick(delta: float) -> void:
	attack_cd -= delta
	cast_lock -= delta
	potion_cd -= delta
	_warn_cd -= delta
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_step = 0
	for k: String in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	for i in range(buffs.size() - 1, -1, -1):
		buffs[i]["time"] = float(buffs[i]["time"]) - delta
		if buffs[i]["time"] <= 0.0:
			buffs.remove_at(i)
	_shield_cd -= delta
	if shield > 0.0:
		_shield_t -= delta
		if _shield_t <= 0.0:
			shield = 0.0
	buff_bubble.visible = buff_sum("dr") > 0.0 or shield > 0.0 or buff_sum("invuln") > 0.0
	life = minf(life + float(stats["life_regen"]) * delta, stats["max_life"])
	resource = clampf(resource + float(stats["resource_regen"]) * delta, 0.0, stats["resource_max"])


func _animate(delta: float, wish: Vector3) -> void:
	if anim != null:
		if cast_lock <= 0.0:
			_play_anim("run" if wish.length() > 0.1 else "idle")
		return
	# Modelli grayboxing: piccolo saltello quando cammina
	if wish.length() > 0.1:
		_bob_t += delta * 11.0
		model.position.y = absf(sin(_bob_t)) * 0.12
	else:
		model.position.y = move_toward(model.position.y, 0.0, delta)


func _play_anim(anim_name: String) -> void:
	if anim != null and anim.has_animation(anim_name) and anim.current_animation != anim_name:
		anim.play(anim_name)


# --- Abilità ------------------------------------------------------------------------

func _try_cast(slot: String, point: Vector3) -> bool:
	var ab: Dictionary = abilities.get(slot, {})
	if ab.is_empty() or dead or not _dash.is_empty():
		return false
	if not is_unlocked(ab):
		_warn("%s si sblocca al livello %d" % [ab["name"], int(ab["unlock"])])
		return false
	if cast_lock > 0.0:
		return false
	cancel_town_portal()
	if slot == "lmb":
		if attack_cd > 0.0:
			return false
	elif cooldown_left(ab) > 0.0:
		return false
	var cost := float(ab.get("cost", 0.0))
	if resource < cost:
		_warn("%s insufficiente" % cls["resource"])
		return false
	if cost > 0.0 and has_power("pontefice") and randf() < 0.25:
		cost = 0.0
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, 2.6, 0), "Gratis!", Color(0.6, 0.7, 1.0), 30)
	resource = clampf(resource - cost + float(ab.get("gain", 0.0)), 0.0, stats["resource_max"])
	var aps := attack_speed() * float(ab.get("speed", 1.0))
	if slot == "lmb":
		attack_cd = 1.0 / aps
		cast_lock = minf(0.75 / aps, 0.4)
	else:
		cooldowns[ab["id"]] = float(ab.get("cooldown", 0.0)) * (1.0 - minf(stats["cdr_pct"], 40.0) / 100.0)
		cast_lock = 0.25
	_face_point(point)
	move_target = Vector3.INF
	Abilities.execute(self, ab, point)
	_play_anim("attack" if ab["kind"] == "melee" else "cast")
	if ab["kind"] == "dash" and has_power("mercurio"):
		add_buff({"id": "mercurio", "duration": 4.0, "aspd": 0.3})
	return true


func start_dash(dir: Vector3, distance: float, speed: float, ab: Dictionary) -> void:
	_face_point(global_position + dir)
	_dash = {"dir": dir, "remaining": distance, "speed": speed, "ab": ab, "hit": []}
	collision_mask = Layers.WORLD
	move_target = Vector3.INF
	attack_target = null


func _process_dash(delta: float) -> void:
	var spd := float(_dash["speed"])
	velocity = (_dash["dir"] as Vector3) * spd
	move_and_slide()
	_dash["remaining"] = float(_dash["remaining"]) - spd * delta
	var ab: Dictionary = _dash["ab"]
	if float(ab.get("dmg", 0.0)) > 0.0:
		for e: Enemy in Abilities.enemies_in_radius(get_tree(), global_position, 1.6):
			if not e in _dash["hit"]:
				_dash["hit"].append(e)
				Abilities.hit_enemy(self, e, float(ab["dmg"]), (_dash["dir"] as Vector3) * float(ab.get("knock", 8.0)), ab)
	var blocked := get_slide_collision_count() > 0 and get_real_velocity().length() < spd * 0.3
	if float(_dash["remaining"]) <= 0.0 or blocked:
		_end_dash()


func start_leap(target: Vector3, ab: Dictionary) -> void:
	_face_point(target)
	_dash = {"leap": true}
	move_target = Vector3.INF
	attack_target = null
	var t := 0.45
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", Vector3(target.x, 0.0, target.z), t)
	tw.tween_property(model, "position:y", 3.0, t * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(model, "position:y", 0.0, t * 0.5).set_delay(t * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(func() -> void:
		Abilities.land(self, ab)
		_end_dash())


func _end_dash() -> void:
	_dash = {}
	collision_mask = Layers.WORLD | Layers.ENEMY
	velocity = Vector3.ZERO


func add_buff(ab: Dictionary) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		if buffs[i]["id"] == ab["id"]:
			buffs.remove_at(i)
	buffs.append({
		"id": ab["id"], "time": float(ab.get("duration", 5.0)), "dr": float(ab.get("dr", 0.0)),
		"damage": float(ab.get("damage", 0.0)), "aspd": float(ab.get("aspd", 0.0)),
		"lifesteal": float(ab.get("lifesteal", 0.0)), "invuln": float(ab.get("invuln", 0.0)),
	})


func use_potion() -> void:
	if potion_cd > 0.0:
		_warn("Pozione in ricarica (%d s)" % ceili(potion_cd))
		return
	potion_cd = potion_cooldown()
	heal(float(stats["max_life"]) * POTION_HEAL)
	Fx.ring(Game.world_root(), global_position, 2.0, Color(1, 0.2, 0.3), 0.4)
	Fx.burst(Game.world_root(), global_position + Vector3(0, 1.0, 0), Color(1, 0.25, 0.35), 14, 3.0, 0.12, 0.6, 3.0)
	Sfx.play("potion")
	if has_power("achille"):
		add_buff({"id": "achille", "duration": 2.0, "invuln": 1.0})


# --- Portale cittadino ---------------------------------------------------------------

func start_town_portal() -> void:
	if dead or Game.level == null or portal_t > 0.0:
		return
	if Game.level.is_town:
		_warn("Sei già in città")
		return
	if not Game.hero.flags.has("visited_" + Game.HUB):
		_warn("Non conosci ancora la strada per %s" % Game.level_title(Game.HUB))
		return
	portal_t = PORTAL_TIME
	move_target = Vector3.INF
	attack_target = null
	interact_target = null
	lmb_held = false
	_play_anim("cast")
	Sfx.play("cast", null, -4.0)
	Fx.ring(Game.world_root(), global_position, 1.6, Color(0.35, 0.65, 1.0), PORTAL_TIME)


func cancel_town_portal() -> void:
	portal_t = 0.0


# --- Interazione --------------------------------------------------------------------

func _interact_nearest() -> void:
	var best: Node3D = null
	var best_d := 3.5
	for n: Node3D in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("can_interact") and not n.can_interact():
			continue
		var d := _flat_dist(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best != null:
		_interact_with(best)


func _interact_with(n: Node3D) -> void:
	if n.has_method("can_interact") and not n.can_interact():
		return
	_face_point(n.global_position)
	n.interact(self)


# --- Vita, morte, esperienza ------------------------------------------------------------

func take_damage(raw: float, attacker_level: int = 1) -> void:
	if dead or not _dash.is_empty():
		return
	if buff_sum("invuln") > 0.0:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, 2.3, 0), "Immune", Color(0.8, 0.8, 1.0), 30)
		return
	if portal_t > 0.0:
		cancel_town_portal()
		_warn("Portale interrotto")
	var armor := float(stats["armor"])
	var armor_dr := clampf(armor / (armor + 50.0 * attacker_level), 0.0, 0.75)
	var amount := raw * (1.0 - armor_dr) * (1.0 - clampf(buff_sum("dr"), 0.0, 0.85))
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	life -= amount
	Fx.popup_text(Game.world_root(), global_position + Vector3(0, 2.3, 0), str(roundi(amount)), Color(1, 0.25, 0.25), 38)
	Fx.flash(model, Color(1, 0.15, 0.15, 0.6))
	Sfx.play("player_hurt", null, -3.0)
	shake(0.08)
	if life <= 0.0:
		_die()
		return
	if has_power("ultima_legione") and _shield_cd <= 0.0 and life < float(stats["max_life"]) * 0.3:
		shield = float(stats["max_life"]) * 0.3
		_shield_t = 8.0
		_shield_cd = 60.0
		Fx.ring(Game.world_root(), global_position, 3.0, Color(1.0, 0.8, 0.3), 0.5)
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, 2.8, 0), "Ultima Legione!", Color(1.0, 0.6, 0.15), 40)


## Chiamato dal nemico quando muore (poteri leggendari "all'uccisione").
func on_enemy_killed(_e: Enemy) -> void:
	if has_power("spartaco"):
		heal(float(stats["max_life"]) * 0.03, false)
		var stacks := 1
		for b: Dictionary in buffs:
			if b["id"] == "spartaco":
				stacks = mini(int(b.get("stacks", 1)) + 1, 5)
		add_buff({"id": "spartaco", "duration": 5.0, "damage": 0.05 * stacks})
		buffs[-1]["stacks"] = stacks
	if has_power("romolo"):
		for k: String in cooldowns.keys():
			cooldowns[k] = maxf(0.0, float(cooldowns[k]) - 1.0)


func heal(amount: float, show: bool = true) -> void:
	if dead or amount <= 0.0:
		return
	life = minf(life + amount, stats["max_life"])
	if show:
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, 2.3, 0), "+%d" % roundi(amount), Color(0.3, 1, 0.4), 38)


func add_xp(amount: int) -> void:
	if hero.level >= HeroData.MAX_LEVEL:
		return
	hero.xp += amount
	var leveled := false
	while hero.xp >= HeroData.xp_to_next(hero.level) and hero.level < HeroData.MAX_LEVEL:
		hero.xp -= HeroData.xp_to_next(hero.level)
		hero.level += 1
		leveled = true
		for ab: Dictionary in cls["abilities"]:
			if int(ab["unlock"]) == hero.level and Game.level:
				Game.level.hud.show_message("Nuova abilità: %s  [%s]" % [ab["name"], HeroClasses.SLOT_KEYS[ab["slot"]]], 4.0)
	if leveled:
		refresh_stats()
		life = stats["max_life"]
		resource = maxf(resource, stats["resource_max"] * 0.5)
		Fx.popup_text(Game.world_root(), global_position + Vector3(0, 3.0, 0), "LIVELLO %d!" % hero.level, Color(1, 0.85, 0.3), 80)
		Fx.ring(Game.world_root(), global_position, 4.0, Color(1, 0.85, 0.3), 0.7)
		Fx.pillar(Game.world_root(), global_position, Color(1, 0.85, 0.3), 12.0, 1.4)
		Sfx.play("levelup")
	xp_changed.emit(hero.xp, HeroData.xp_to_next(hero.level), hero.level)


func _die() -> void:
	dead = true
	life = 0.0
	velocity = Vector3.ZERO
	lmb_held = false
	portal_t = 0.0
	shield = 0.0
	_play_anim("death")
	if anim == null:
		create_tween().tween_property(model, "rotation:x", deg_to_rad(-90.0), 0.5)
	died.emit()


func revive(pos: Vector3) -> void:
	dead = false
	global_position = pos
	life = stats["max_life"]
	resource = stats["resource_max"] if cls.get("resource_starts_full", true) else 0.0
	buffs.clear()
	model.rotation.x = 0.0
	move_target = Vector3.INF
	attack_target = null
	interact_target = null
	_end_dash()


func shake(amount: float) -> void:
	if camera is IsoCamera:
		(camera as IsoCamera).shake(amount)


func _warn(text: String) -> void:
	if _warn_cd > 0.0 or Game.level == null:
		return
	_warn_cd = 0.8
	Game.level.hud.show_warning(text)
