class_name Checkpoint
extends StaticBody3D
## Altare-checkpoint: avvicinandoti si attiva, salva la partita e diventa il punto di rinascita.
## Se il modello contiene un nodo "Flame", viene acceso all'attivazione.

@export var checkpoint_id := ""
@export var title := "Altare di Giano"

var active := false


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = Layers.WORLD
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


func spawn_point() -> Vector3:
	return global_position + global_basis.z * 3.0


func _on_body_entered(body: Node) -> void:
	if not body is Player or Game.hero == null:
		return
	var p := body as Player
	p.heal(float(p.stats["max_life"]))
	var first := not Game.hero.flags.has("cp_" + checkpoint_id)
	Game.hero.flags["cp_" + checkpoint_id] = true
	Game.hero.checkpoint_id = checkpoint_id
	_set_flame(true)
	if first:
		Fx.ring(Game.world_root(), global_position, 4.5, Color(0.3, 0.7, 1.0), 0.6)
	var saved := Game.save_game()
	if Game.level:
		Game.level.hud.show_message("%s\n%s" % [title, "Partita salvata" if saved else "Checkpoint raggiunto"], 2.5)


func _set_flame(on: bool) -> void:
	var flame := find_child("Flame", true, false) as Node3D
	if flame:
		flame.visible = on
