class_name QuestGate
extends StaticBody3D
## Cancello che si apre quando l'eroe ha un certo flag (es. "porto_aperto", messo dalla missione
## "Il porto sbarrato" quando parte). Va messo FUORI dal nodo World, così la navmesh passa
## comunque e il percorso funziona appena il cancello si apre.

@export var flag := "porto_aperto"
@export var locked_text := "Il cancello è sbarrato."

var opened := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.WORLD | Layers.INTERACT
	if Engine.is_editor_hint():
		return
	if Game.hero != null and Game.hero.flags.has(flag):
		_open(false)
	else:
		Game.quests_changed.connect(_check)


func interact_name() -> String:
	return "Cancello sbarrato"


func can_interact() -> bool:
	return not opened


func interact(_p: Player) -> void:
	if Game.level:
		Game.level.hud.show_warning(locked_text)


func _check() -> void:
	if not opened and Game.hero != null and Game.hero.flags.has(flag):
		_open(true)


func _open(animated: bool) -> void:
	opened = true
	remove_from_group("interactable")
	collision_layer = 0
	if animated:
		Sfx.play("cancello", global_position)
		create_tween().tween_property(self, "position:y", -7.5, 2.0).set_trans(Tween.TRANS_SINE)
	else:
		position.y = -7.5
