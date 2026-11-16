extends SceneTree
## Esporta la pianta dall'alto di tutti i livelli in docs/mappe/*.png (vedi tools/map_preview.gd).
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/export_maps.gd
## (dall'editor si fa con il pannello Mappa > "Esporta pianta").

const LEVELS := ["res://scenes/levels/level_01.tscn", "res://scenes/levels/level_02_ostia.tscn", "res://scenes/levels/level_03_porto.tscn"]


func _initialize() -> void:
	var preview: GDScript = load("res://tools/map_preview.gd")
	for path: String in LEVELS:
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		# Istanza fuori dall'albero di scena: gli script del gioco non partono
		var level := scene.instantiate()
		var out: String = preview.export(level, path)
		print("%s -> %s" % [path, out if out != "" else "(nessuna Forma)"])
		level.free()
	quit()
