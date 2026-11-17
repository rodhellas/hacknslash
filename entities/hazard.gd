class_name Hazard
extends Node3D
## Pericolo a terra creato dalle elite: pozza di fuoco (danno continuo), sfera di ghiaccio
## (esplode dopo un ritardo e rallenta), esplosione alla morte. Prima compare il segnale a terra.

var radius := 2.5
var delay := 1.0          # secondi di avviso prima che faccia male
var duration := 0.0       # 0 = un colpo solo all'esplosione; > 0 = danno continuo per tot secondi
var damage := 10.0        # danno del colpo, o danno al secondo se continuo
var slow := 0.0
var color := Color(1.0, 0.4, 0.1)
var attacker_level := 1
var _t := 0.0
var _tick := 0.0
var _armed := false


static func spawn(pos: Vector3, p_radius: float, p_delay: float, p_duration: float, p_damage: float, col: Color, lvl: int, p_slow: float = 0.0) -> Hazard:
	var h := Hazard.new()
	h.radius = p_radius
	h.delay = p_delay
	h.duration = p_duration
	h.damage = p_damage
	h.color = col
	h.attacker_level = lvl
	h.slow = p_slow
	h.position = Vector3(pos.x, 0.0, pos.z)
	Game.world_root().add_child(h)
	return h


func _ready() -> void:
	Fx.telegraph(self.get_parent(), global_position, radius, color, delay)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _armed:
		if _t < delay:
			return
		_armed = true
		_t = 0.0
		if duration <= 0.0:
			_burst()
			queue_free()
			return
		_make_pool()
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		var p := _player()
		if p != null and _inside(p):
			p.take_damage(damage * 0.5, attacker_level)
	if _t >= duration:
		queue_free()


func _burst() -> void:
	Fx.explosion(get_parent(), global_position, radius, color)
	Sfx.play("explosion", global_position, -6.0, 0.15)
	var p := _player()
	if p != null and _inside(p):
		p.take_damage(damage, attacker_level)
		if slow > 0.0:
			p.add_buff({"id": "gelo", "duration": 2.0, "move": -slow})


func _make_pool() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	mi.mesh = cm
	var c := color
	c.a = 0.55
	mi.material_override = Fx.mat(c, 2.0, true, true)
	mi.position.y = 0.06
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = radius * 1.5
	l.light_energy = 1.2
	l.position.y = 0.8
	add_child(l)


func _inside(p: Player) -> bool:
	return Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() <= radius + 0.3


func _player() -> Player:
	if Game.level == null or Game.level.player == null or Game.level.player.dead:
		return null
	return Game.level.player
