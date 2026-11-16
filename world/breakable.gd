class_name Breakable
extends StaticBody3D
## Anfora/vaso distruttibile: si rompe con un clic o colpendola. A volte contiene sesterzi.

@export var gold_chance := 0.35
var broken := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("breakable")
	collision_layer = Layers.INTERACT
	collision_mask = 0


func interact_name() -> String:
	return "Anfora"


func can_interact() -> bool:
	return not broken


func interact(p: Player) -> void:
	break_open(p)


func break_open(_p: Player) -> void:
	if broken:
		return
	broken = true
	remove_from_group("interactable")
	remove_from_group("breakable")
	Fx.ring(Game.world_root(), global_position, 1.2, Color(0.8, 0.6, 0.4), 0.25)
	Fx.burst(Game.world_root(), global_position + Vector3(0, 0.5, 0), Color(0.7, 0.38, 0.22), 10, 4.0, 0.15, 0.6, -12.0, 80.0)
	Sfx.play("break", global_position)
	if randf() < gold_chance:
		var lvl := Game.level.area_level if Game.level else 1
		var d := LootDrop.make_gold(randi_range(2, 6) * lvl)
		d.position = global_position
		Game.world_root().add_child.call_deferred(d)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.12)
	tw.tween_callback(queue_free)
