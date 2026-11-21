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
const STASH_PATH_HC := "user://stash_hardcore.json"   # gli eroi hardcore hanno un forziere a parte
const STASH_SIZE := 60   # caselle per scheda
## Schede del forziere: la prima è gratis, le altre si comprano (sesterzi della scheda 2, 3, 4, 5).
const STASH_TAB_PRICES := [5000, 25000, 75000, 200000]

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
var stash_tabs := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la schermata di caricamento lavora anche a gioco fermo
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Settings.load_and_apply()


## Tasto "indietro" di Android: come ESC (chiude il pannello in alto o apre la pausa).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := InputEventAction.new()
		up.action = "pause"
		up.pressed = false
		Input.parse_input_event(up)


func _process(delta: float) -> void:
	_poll_loading()
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
		"hardcore": bool(h.get("hardcore", false)), "dead": bool((h.get("flags", {}) as Dictionary).get("dead", false)),
		"difficulty": int(h.get("difficulty", 0)), "rift_max": int((h.get("flags", {}) as Dictionary).get("rift_max", 0)),
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


func new_game(slot: int, hero_name: String, class_id: String, sex: String = "m", hardcore: bool = false) -> void:
	hero = HeroData.create(hero_name, class_id, sex)
	hero.hardcore = hardcore
	_reset_stash()
	current_slot = slot
	save_game()
	go_to_level(hero.level_id)


func load_game(slot: int) -> bool:
	var data := _read_slot(slot)
	if data.is_empty():
		return false
	var h := HeroData.from_dict(data.get("hero", {}))
	if h.flags.get("dead", false):
		return false   # eroe hardcore caduto
	hero = h
	current_slot = slot
	_reset_stash()
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
## Tutte le caselle di tutte le schede (stash_tabs × STASH_SIZE); scheda n = caselle [n*60, n*60+60).
func stash() -> Array:
	if not _stash_loaded:
		_stash_loaded = true
		var items: Array = []
		if FileAccess.file_exists(_stash_path()):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_stash_path()))
			if parsed is Array:   # formato vecchio: una sola scheda
				items = parsed
			elif parsed is Dictionary:
				stash_tabs = clampi(int(parsed.get("tabs", 1)), 1, STASH_TAB_PRICES.size() + 1)
				items = parsed.get("items", [])
		_stash.resize(stash_tabs * STASH_SIZE)
		for i in mini(items.size(), _stash.size()):
			if items[i] is Dictionary:
				_stash[i] = Item.from_dict(items[i])
	return _stash


func _stash_path() -> String:
	return STASH_PATH_HC if hero != null and hero.hardcore else STASH_PATH


## Cambiando eroe (normale / hardcore) il forziere va ricaricato dal suo file.
func _reset_stash() -> void:
	_stash_loaded = false
	_stash = []
	stash_tabs = 1


## Prezzo della prossima scheda del forziere (-1 = già tutte).
func next_stash_tab_price() -> int:
	stash()
	return STASH_TAB_PRICES[stash_tabs - 1] if stash_tabs - 1 < STASH_TAB_PRICES.size() else -1


func buy_stash_tab() -> bool:
	var price := next_stash_tab_price()
	if price < 0 or hero == null or hero.gold < price:
		return false
	hero.gold -= price
	stash_tabs += 1
	_stash.resize(stash_tabs * STASH_SIZE)
	save_stash()
	return true


func save_stash() -> void:
	if not _stash_loaded:
		return
	var out: Array = []
	for it: Variant in _stash:
		out.append((it as Item).to_dict() if it != null else null)
	var f := FileAccess.open(_stash_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"tabs": stash_tabs, "items": out}))


func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))


## Moltiplicatori dei nemici adesso: difficoltà scelta, oppure grado del labirinto di Dedalo.
## {hp, dmg, xp, gold, leg, affixes, min_level, name}
func enemy_scaling() -> Dictionary:
	if hero == null:
		return DifficultyDB.get_data(0)
	var sc: Dictionary
	var grade := 0
	if level != null and is_instance_valid(level):
		grade = int(level.rift_grade)
	if grade > 0:
		sc = DifficultyDB.rift_scaling(grade).duplicate()
		sc["min_level"] = hero.level
	else:
		sc = DifficultyDB.get_data(hero.difficulty).duplicate()
		sc["min_level"] = hero.level if hero.difficulty >= 1 else 0
	return sc


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


## Consigli mostrati nella schermata di caricamento.
const TIPS := [
	"K apre la finestra delle abilità: ogni tasto ha abilità alternative e varianti da sbloccare.",
	"Dal livello 10 si sbloccano le passive: tre caselle, ai livelli 10, 20 e 30.",
	"I Campioni (blu) arrivano in gruppo; i capi rari (gialli) hanno dei servitori. Leggi i loro affissi!",
	"Più è alta la difficoltà (menu di pausa), più leggendari trovi.",
	"L'Obelisco di Dedalo nel foro di Ostia Nova apre i Labirinti: battili in tempo per salire di grado.",
	"Tieni premuto Alt per vedere i nomi di tutti gli oggetti a terra.",
	"Il fabbro, nella scheda Aspetto, cambia l'aspetto dell'equipaggiamento senza toccarne le statistiche.",
	"I leggendari con un potere arancione possono cambiare del tutto un'abilità.",
	"Sesterzi in più? Il forziere personale ha altre schede da comprare.",
	"Le gemme si combinano dal gioielliere: tre uguali ne fanno una di grado superiore.",
]

var _loading: CanvasLayer
var _loading_path := ""
var _loading_frames := 0


func go_to_level(level_id: String) -> void:
	get_tree().paused = false
	var path: String = LEVELS.get(level_id, LEVELS["level_01"])
	_show_loading(level_id)
	# Il caricamento in un altro thread si blocca in alcuni casi (es. headless): si carica normalmente,
	# ma dopo due frame, così la schermata di caricamento fa in tempo a comparire.
	_loading_path = path
	_loading_frames = 2
	get_tree().paused = true   # il vecchio livello si ferma mentre si carica il nuovo


## Schermata di caricamento (nome del luogo + consiglio) mentre si carica la scena.
func _show_loading(level_id: String) -> void:
	if _loading == null:
		_loading = CanvasLayer.new()
		_loading.layer = 50
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.025, 0.02)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_loading.add_child(bg)
		var art := TextureRect.new()
		art.name = "Art"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_loading.add_child(art)
		# Nome del luogo e consiglio nella zona scura in basso del dipinto
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		v.offset_left = -500
		v.offset_right = 500
		v.offset_top = -190
		v.offset_bottom = -40
		v.add_theme_constant_override("separation", 18)
		_loading.add_child(v)
		for n: String in ["Title", "Tip"]:
			var l := Label.new()
			l.name = n
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 40 if n == "Title" else 18)
			l.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35) if n == "Title" else Color(0.8, 0.75, 0.65))
			l.add_theme_constant_override("outline_size", 8)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			v.add_child(l)
		add_child(_loading)
	var title := level_title(level_id)
	if level_id == "dungeon" and hero != null:
		var info: Dictionary = hero.flags.get("dungeon", {})
		title = "Labirinto di Dedalo" if info.has("rift") else String(DungeonDB.get_data(String(info.get("id", ""))).get("title", "Dungeon"))
	(_loading.find_child("Title", true, false) as Label).text = title
	# Dipinto del luogo: textures/ui/caricamento_<livello>.png (dungeon e labirinti: caricamento_dungeon)
	var art_path := "res://textures/ui/caricamento_%s.png" % level_id
	(_loading.find_child("Art", true, false) as TextureRect).texture = load(art_path) if ResourceLoader.exists(art_path) else null
	(_loading.find_child("Tip", true, false) as Label).text = TIPS.pick_random()
	_loading.visible = true


func _poll_loading() -> void:
	if _loading_path == "":
		return
	_loading_frames -= 1
	if _loading_frames > 0:
		return
	var p := _loading_path
	_loading_path = ""
	get_tree().paused = false
	get_tree().change_scene_to_file(p)


## Chiamato dal livello quando è pronto.
func hide_loading() -> void:
	if _loading != null:
		_loading.visible = false


func quit_to_menu(save: bool = true) -> void:
	if save:
		save_game()
	get_tree().paused = false
	level = null
	hide_loading()
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
