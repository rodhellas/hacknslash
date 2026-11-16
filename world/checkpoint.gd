class_name Checkpoint
extends StaticBody3D
## Altare-checkpoint: avvicinandoti si attiva, salva la partita e diventa il punto di rinascita.
## Cliccandolo si apre l'elenco degli altari attivati (viaggio rapido, anche tra livelli).
## Se il modello contiene un nodo "Flame", viene acceso all'attivazione.

@export var checkpoint_id := ""
@export var title := "Altare di Giano"

var active := false


func _ready() -> void:
	add_to_group("checkpoint")
	add_to_group("interactable")
	collision_layer = Layers.WORLD | Layers.INTERACT
	if Engine.is_editor_hint():
		return
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.5
	cs.shape = sph
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	active = Game.hero != null and Game.hero.flags.has("cp_" + checkpoint_id)
	_set_flame(active)
	Fx.minimap_icon(self, Color(0.3, 0.7, 1.0), 2.0, "square")


func interact_name() -> String:
	return "%s (viaggio rapido)" % title


func can_interact() -> bool:
	return true


func interact(p: Player) -> void:
	_activate(p)
	if Game.level:
		Game.level.hud.show_waypoints(checkpoint_id)


func spawn_point() -> Vector3:
	return global_position + global_basis.z * 3.0


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_activate(body as Player)


func _activate(p: Player) -> void:
	if Game.hero == null or p.dead:
		return
	p.heal(float(p.stats["max_life"]), false)
	var first := not Game.hero.waypoints.has(checkpoint_id)
	var lvl_id: String = Game.level.level_id if Game.level else Game.hero.level_id
	Game.hero.register_waypoint(checkpoint_id, lvl_id, title)
	Game.hero.checkpoint_id = checkpoint_id
	_set_flame(true)
	if first:
		Fx.ring(Game.world_root(), global_position, 4.5, Color(0.3, 0.7, 1.0), 0.6)
		Fx.pillar(Game.world_root(), global_position, Color(0.4, 0.7, 1.0), 8.0, 1.0)
		Sfx.play("checkpoint", global_position)
	elif p.life >= float(p.stats["max_life"]) - 0.5 and Game.hero.checkpoint_id == checkpoint_id and _recent():
		return
	var saved := Game.save_game()
	if Game.level:
		Game.level.hud.show_message("%s\n%s" % [title, "Partita salvata" if saved else "Checkpoint raggiunto"], 2.5)


var _last_msg := -100.0


## Evita di ripetere "Partita salvata" se l'eroe gironzola attorno all'altare.
func _recent() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var r := now - _last_msg < 20.0
	if not r:
		_last_msg = now
	return r


func _set_flame(on: bool) -> void:
	var flame := find_child("Flame", true, false) as Node3D
	if flame:
		flame.visible = on
