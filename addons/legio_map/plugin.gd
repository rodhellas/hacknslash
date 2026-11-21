@tool
extends EditorPlugin
## Plugin "Legio Map": aggiunge il pannello Mappa (a destra, accanto all'Inspector).

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/legio_map/map_dock.gd").new()
	dock.name = "Mappa"
	dock.plugin = self
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
