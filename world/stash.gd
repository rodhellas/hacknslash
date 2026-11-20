class_name Stash
extends StaticBody3D
## Forziere personale (stash) della città: cliccandolo si apre il pannello per depositare e
## riprendere oggetti. Il contenuto è condiviso da tutti gli eroi (Game.stash(), file user://stash.json).


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.WORLD | Layers.INTERACT
	if Engine.is_editor_hint():
		return
	Fx.minimap_icon(self, Color(0.4, 0.75, 1.0), 1.4, "square")


func interact_name() -> String:
	return "Forziere personale"


func can_interact() -> bool:
	return true


func interact(_p: Player) -> void:
	if Game.level == null:
		return
	Sfx.play("forziere", global_position)
	var lid := find_child("Lid", true, false) as Node3D
	if lid:
		var tw := create_tween()
		tw.tween_property(lid, "rotation_degrees:x", -70.0, 0.25)
		tw.tween_interval(0.8)
		tw.tween_property(lid, "rotation_degrees:x", 0.0, 0.3)
	Game.level.open_stash(self)
