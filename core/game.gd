extends Node
## Autoload "Game": partita corrente, salvataggi su file e cambio di scena.
## I salvataggi sono file JSON in user://saves/ (su Windows: %APPDATA%/Godot/app_userdata/Legio 3000/saves).

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const SAVE_VERSION := 1
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVELS := {
	"level_01": "res://scenes/levels/level_01.tscn",
}

var hero: HeroData
var current_slot := -1
var level: Level = null
## true = tutte le abilità sbloccate da subito (comodo per provare le classi).
var debug_unlock_all := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(delta: float) -> void:
	if hero != null and level != null and not get_tree().paused:
		hero.play_time += delta


## Nodo in cui creare effetti, proiettili e loot.
func world_root() -> Node:
	if level != null and is_instance_valid(level):
		return level.dynamic_root
	return get_tree().current_scene


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


## Riepilogo di uno slot per il menu ({} se vuoto).
func slot_info(slot: int) -> Dictionary:
	var data := _read_slot(slot)
	if data.is_empty():
		return {}
	var h: Dictionary = data.get("hero", {})
	return {
		"name": h.get("name", "?"), "class_id": h.get("class_id", "legionario"), "level": int(h.get("level", 1)),
		"play_time": float(h.get("play_time", 0.0)), "saved_at": data.get("saved_at", ""),
	}


func latest_slot() -> int:
	var best := -1
	var best_time := 0
	for i in SLOT_COUNT:
		var p := slot_path(i)
		if FileAccess.file_exists(p):
			var t := FileAccess.get_modified_time(p)
			if t >= best_time:
				best_time = t
				best = i
	return best


func new_game(slot: int, hero_name: String, class_id: String) -> void:
	hero = HeroData.create(hero_name, class_id)
	current_slot = slot
	save_game()
	go_to_level(hero.level_id)


func load_game(slot: int) -> bool:
	var data := _read_slot(slot)
	if data.is_empty():
		return false
	hero = HeroData.from_dict(data.get("hero", {}))
	current_slot = slot
	go_to_level(hero.level_id)
	return true


func save_game() -> bool:
	if hero == null or current_slot < 0:
		return false
	if level != null and is_instance_valid(level):
		level.store_state()
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"hero": hero.to_dict(),
	}
	var f := FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if f == null:
		push_error("Impossibile salvare: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))


func go_to_level(level_id: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS.get(level_id, LEVELS["level_01"]))


func quit_to_menu(save: bool = true) -> void:
	if save:
		save_game()
	get_tree().paused = false
	level = null
	get_tree().change_scene_to_file(MENU_SCENE)


## Se avvii un livello direttamente dall'editor (F6) crea un eroe di prova (senza salvataggi).
func ensure_debug_hero() -> void:
	if hero == null:
		hero = HeroData.create("Collaudatore", "legionario")
		current_slot = -1


func _read_slot(slot: int) -> Dictionary:
	var p := slot_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}
