class_name LevelExit
extends Area3D
## Uscita del livello: quando l'eroe ci entra, il livello è completato.
## Se target_level è impostato (id in Game.LEVELS) porta a quel livello, nel Marker3D target_spawn;
## altrimenti mostra il pannello di fine livello.

@export var target_level := ""
@export var target_spawn := ""
@export var title := "Ostia Nova"

var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	Fx.minimap_icon(self, Color(0.3, 1.0, 0.4), 3.0, "square")


func _on_body_entered(body: Node) -> void:
	if _done or not body is Player or Game.level == null:
		return
	_done = true
	Game.level.on_exit_reached(self)
