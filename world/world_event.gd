class_name WorldEvent
extends StaticBody3D
## Evento casuale (WorldDB.EVENTS): forziere maledetto, stendardo del clan, prigionieri.
## Piazzato da codice vicino a una zona di nemici (Level._place_world_extras): ne usa tipi e livello.
## Completato: forziere decorato di loot, esperienza, sesterzi e avanzamento delle taglie.

var event_id := "maledetto"
var enemy_types: PackedStringArray = PackedStringArray(["predone"])
var enemy_level := 1
var state := "idle"              # idle, running, done
var spawned: Array = []
var time_left := 0.0
var wave := 0
var freed := 0
var _spawn_t := 0.0
var _captives: Array = []


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("world_events")
	collision_layer = Layers.INTERACT
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.0, 1.6)
	shape.shape = bs
	shape.position.y = 1.0
	add_child(shape)
	match event_id:
		"maledetto":
			_box(Vector3(1.4, 0.8, 0.9), Vector3(0, 0.4, 0), Color(0.3, 0.15, 0.35))
			_box(Vector3(1.5, 0.15, 1.0), Vector3(0, 0.85, 0), Color(0.6, 0.2, 0.8), 2.0)
		"assedio":
			_box(Vector3(0.12, 3.2, 0.12), Vector3(0, 1.6, 0), Color(0.4, 0.3, 0.2))
			_box(Vector3(1.2, 1.4, 0.05), Vector3(0.6, 2.4, 0), Color(0.7, 0.15, 0.1), 0.6)
		"prigionieri":
			_box(Vector3(0.6, 1.4, 0.6), Vector3(0, 0.7, 0), Color(0.35, 0.25, 0.15))
			var n := int(WorldDB.EVENTS["prigionieri"]["captives"])
			for i in n:
				var c := EventCaptive.new()
				c.event = self
				var a := TAU * i / n
				c.position = Vector3(cos(a), 0, sin(a)) * 4.0
				add_child(c)
				_captives.append(c)
	Fx.minimap_icon(self, Color(1.0, 0.4, 0.9), 1.8, "square")


func _box(size: Vector3, pos: Vector3, col: Color, glow: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Fx.mat(col, glow)
	mi.position = pos
	add_child(mi)


func title() -> String:
	return String(WorldDB.EVENTS[event_id]["name"])


func interact_name() -> String:
	match state:
		"idle": return "%s – %s" % [title(), WorldDB.EVENTS[event_id]["desc"]]
		"running": return title() + " (in corso)"
	return title() + " (completato)"


func can_interact() -> bool:
	return state == "idle" and event_id != "prigionieri"


func interact(_p: Player) -> void:
	if state != "idle" or event_id == "prigionieri":
		return
	start()


func start() -> void:
	state = "running"
	Sfx.play("evento_inizio", global_position)
	if Game.level:
		Game.level.hud.show_banner(title())
	match event_id:
		"maledetto":
			time_left = float(WorldDB.EVENTS["maledetto"]["time"])
			_spawn_t = 0.0
		"assedio":
			_next_wave()
		"prigionieri":
			_spawn_group(6, true)


func on_captive_freed() -> void:
	freed += 1
	if state == "idle":
		start()
	Sfx.play("raccogli", global_position)


func _physics_process(delta: float) -> void:
	if state != "running" or Game.level == null:
		return
	_clean()
	match event_id:
		"maledetto":
			time_left -= delta
			_spawn_t -= delta
			if time_left > 0.0 and _spawn_t <= 0.0:
				_spawn_t = 7.0
				_spawn_group(4, false)
			if time_left <= 0.0 and spawned.is_empty():
				_complete()
		"assedio":
			if spawned.is_empty():
				if wave >= (WorldDB.EVENTS["assedio"]["waves"] as Array).size():
					_complete()
				else:
					_next_wave()
		"prigionieri":
			if freed >= _captives.size() and spawned.is_empty():
				_complete()
	if state == "running":
		Game.level.hud.set_event(title(), objective())


## Testo dell'obiettivo (HUD).
func objective() -> String:
	match event_id:
		"maledetto":
			return "Sopravvivi: %d s" % ceili(maxf(time_left, 0.0)) if time_left > 0.0 else "Sconfiggi gli ultimi nemici (%d)" % spawned.size()
		"assedio":
			return "Ondata %d di %d – nemici: %d" % [wave, (WorldDB.EVENTS["assedio"]["waves"] as Array).size(), spawned.size()]
		"prigionieri":
			return "Prigionieri liberati: %d / %d – guardie: %d" % [freed, _captives.size(), spawned.size()]
	return ""


func _next_wave() -> void:
	var waves: Array = WorldDB.EVENTS["assedio"]["waves"]
	var n := int(waves[wave])
	wave += 1
	_spawn_group(n, wave == waves.size())


func _spawn_group(n: int, with_elite: bool) -> void:
	var map := get_world_3d().navigation_map
	for i in n:
		var a := randf() * TAU
		var pos := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(5.0, 9.0)
		var s := NavigationServer3D.map_get_closest_point(map, pos)
		if s != Vector3.ZERO and s.y < 1.0:
			pos = Vector3(s.x, 0.0, s.z)
		var e := Enemy.create(enemy_types[i % enemy_types.size()], enemy_level, with_elite and i == 0,
			EncounterZone.roll_affixes(int(Game.enemy_scaling().get("affixes", 1))) if with_elite and i == 0 else [])
		e.position = pos
		Game.level.enemies_root.add_child(e)
		e.aggro()
		Fx.burst(Game.world_root(), pos + Vector3(0, 1, 0), Color(1.0, 0.4, 0.9), 12, 4.0, 0.1, 0.5, 0.0)
		spawned.append(e)


func _clean() -> void:
	for i in range(spawned.size() - 1, -1, -1):
		if not is_instance_valid(spawned[i]) or (spawned[i] as Enemy).dead:
			spawned.remove_at(i)


func _complete() -> void:
	state = "done"
	if Game.level == null:
		return
	Game.level.hud.clear_event()
	Game.level.hud.show_banner("Evento completato!")
	Fx.pillar(Game.world_root(), global_position, Color(1.0, 0.85, 0.3), 10.0, 1.2)
	Sfx.play("evento_fine", global_position)
	Loot.drop("chest_rich", global_position + Vector3(0, 0, 1.5), enemy_level)
	var p: Player = Game.level.player
	if p:
		p.add_xp(int(50 * enemy_level * float(Game.enemy_scaling().get("xp", 1.0))))
	Bounties.notify("event", Bounties.level_key())


## Prigioniero dell'evento: si clicca per liberarlo.
class EventCaptive extends StaticBody3D:
	var event: WorldEvent
	var free_ := false

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = Layers.INTERACT
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.7
		cs.height = 2.0
		shape.shape = cs
		shape.position.y = 1.0
		add_child(shape)
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.5
		body.mesh = cm
		body.material_override = Fx.mat(Color(0.8, 0.7, 0.55))
		body.position.y = 0.75
		add_child(body)
		var cage := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 2.0, 1.1)
		cage.mesh = bm
		cage.name = "Gabbia"
		cage.material_override = Fx.mat(Color(0.3, 0.3, 0.32, 0.45), 0.0, true)
		cage.position.y = 1.0
		add_child(cage)

	func interact_name() -> String:
		return "Prigioniero (libera)" if not free_ else "Prigioniero liberato"

	func can_interact() -> bool:
		return not free_

	func interact(_p: Player) -> void:
		if free_:
			return
		free_ = true
		var cage := get_node_or_null("Gabbia")
		if cage:
			cage.queue_free()
		Fx.burst(Game.world_root(), global_position + Vector3(0, 1, 0), Color(1.0, 0.9, 0.5), 14, 4.0, 0.1, 0.5, 2.0)
		event.on_captive_freed()
