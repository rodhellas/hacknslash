class_name LoreSign
extends StaticBody3D
## Cartello/iscrizione leggibile: mostra un testo di storia. Usalo per la trama.

@export var title := "Cartello"
@export_multiline var text := ""


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.WORLD | Layers.INTERACT


func interact_name() -> String:
	return title


func can_interact() -> bool:
	return true


func interact(_p: Player) -> void:
	if Game.level:
		Game.level.hud.show_lore(title, text)
