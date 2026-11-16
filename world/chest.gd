class_name Chest
extends StaticBody3D
## Forziere: si apre con un clic e lascia oggetti e sesterzi. Resta aperto nei salvataggi.
## Se il modello contiene un nodo "Lid" (coperchio), viene animato all'apertura.

@export var flag_id := ""
@export var item_level := 1
## Forziere decorato: più oggetti e di rarità migliore.
@export var rich := false

var opened := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.WORLD | Layers.INTERACT
	if Engine.is_editor_hint():
		return
	if Game.hero and flag_id != "" and Game.hero.flags.has(flag_id):
		opened = true
		_open_visual(false)


func interact_name() -> String:
	return "Forziere decorato" if rich else "Forziere"


func can_interact() -> bool:
	return not opened


func interact(_p: Player) -> void:
	if opened:
		return
	opened = true
	if Game.hero and flag_id != "":
		Game.hero.flags[flag_id] = true
	_open_visual(true)
	Sfx.play("chest", global_position)
	Fx.burst(Game.world_root(), global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.35), 20 if rich else 10, 5.0, 0.1, 0.6, -4.0, 40.0)
	Loot.drop("chest_rich" if rich else "chest", global_position + global_basis.z * -1.2, item_level)


func _open_visual(animated: bool) -> void:
	var lid := find_child("Lid", true, false) as Node3D
	if lid == null:
		return
	if animated:
		create_tween().tween_property(lid, "rotation_degrees:x", -100.0, 0.4).set_trans(Tween.TRANS_BACK)
	else:
		lid.rotation_degrees.x = -100.0
