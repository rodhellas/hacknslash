extends Node

## Emesso quando cambia lo stato di una missione (HUD, segni sopra gli NPC, cancelli).
signal quests_changed
## Autoload "Game": partita corrente, salvataggi su file e cambio di scena.
## I salvataggi sono file JSON in user://saves/ (su Windows: %APPDATA%/Godot/app_userdata/Legio 3000/saves).

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const SAVE_VERSION := 2
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVELS := {
	"level_01": "res://scenes/levels/level_01.tscn",
	"ostia_nova": "res://scenes/levels/level_02_ostia.tscn",
	"level_03_porto": "res://scenes/levels/level_03_porto.tscn",
	## Dungeon generati (quale dungeon: Game.hero.flags["dungeon"], vedi world/dungeon_level.gd)
	"dungeon": "res://scenes/levels/dungeon.tscn",
}
## Nomi dei livelli (elenco degli altari, portale) nell'ordine della campagna.
const LEVEL_TITLES := {
	"level_01": "Campagna di Lazio Prime",
	"ostia_nova": "Ostia Nova",
	"level_03_porto": "Porto di Ostia Nova",
}
## Città-hub raggiungibile con il portale cittadino (tasto T).
const HUB := "ostia_nova"
## Forziere personale: condiviso da tutti gli eroi (come in Diablo), salvato a parte.
const STASH_PATH := "user://stash.json"
const STASH_SIZE := 60

var hero: HeroData
var current_slot := -1
var level: Level = null
## true = tutte le abilità sbloccate da subito (comodo per provare le classi).
var debug_unlock_all := false
## Dove far comparire l'eroe nel prossimo livello: nome di un Marker3D o id di un altare.
var pending_spawn := ""
## Oggetti venduti al mercante in questa sessione (si possono ricomprare allo stesso prezzo).
var buyback: Array = []
var _stash: Array = []
var _stash_loaded := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Settings.load_and_apply()


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
	save_stash()
	return true


## Oggetti del forziere personale (Item o null), caricati dal disco la prima volta.
func stash() -> Array:
	if not _stash_loaded:
		_stash_loaded = true
		_stash.resize(STASH_SIZE)
		if FileAccess.file_exists(STASH_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STASH_PATH))
			if parsed is Array:
				for i in mini((parsed as Array).size(), STASH_SIZE):
					if parsed[i] is Dictionary:
						_stash[i] = Item.from_dict(parsed[i])
	return _stash


func save_stash() -> void:
	if not _stash_loaded:
		return
	var out: Array = []
	for it: Variant in _stash:
		out.append((it as Item).to_dict() if it != null else null)
	var f := FileAccess.open(STASH_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))


func level_title(level_id: String) -> String:
	return String(LEVEL_TITLES.get(level_id, level_id))


## Viaggio verso un altro livello. spawn = nome di un Marker3D o id di un altare;
## pos = posizione esatta (ritorno dal portale). Senza nessuno dei due: PlayerStart / ultimo altare.
func travel(level_id: String, spawn: String = "", pos: Variant = null) -> void:
	if hero == null:
		return
	if level != null and is_instance_valid(level):
		level.store_state()
	hero.level_id = level_id
	hero.has_position = pos is Vector3
	if pos is Vector3:
		hero.position = pos
	pending_spawn = spawn
	go_to_level.call_deferred(level_id)


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
