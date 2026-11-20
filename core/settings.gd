class_name Settings
extends RefCounted
## Impostazioni del giocatore (video, audio, tasti), salvate in user://settings.cfg.
## Caricate all'avvio da Game._ready(); le opzioni grafiche dell'ambiente (ombre, SSAO, bagliore)
## vengono applicate a ogni livello da Level._ready().

const PATH := "user://settings.cfg"

const VIDEO_DEFAULTS := {
	"fullscreen": false, "vsync": true, "shadows": true, "ssao": true, "glow": true, "msaa": 2, "scale": 1.0,
}

## Azioni rimappabili, nell'ordine mostrato nelle opzioni.
const ACTIONS := [
	["move_up", "Muovi su"], ["move_down", "Muovi giù"], ["move_left", "Muovi a sinistra"], ["move_right", "Muovi a destra"],
	["primary", "Muovi / attacca"], ["secondary", "Abilità (clic destro)"], ["force_stand", "Attacca sul posto"],
	["skill_1", "Abilità 1"], ["skill_2", "Abilità 2"], ["skill_3", "Abilità 3"], ["skill_4", "Abilità 4"],
	["potion", "Pozione"], ["interact", "Interagisci"], ["town_portal", "Portale cittadino"],
	["inventory", "Inventario"], ["skills", "Abilità"], ["map", "Mappa"], ["quest_log", "Diario missioni"],
	["show_items", "Mostra oggetti a terra"], ["turbo", "Movimento veloce ×5 (prove)"],
]

static var video: Dictionary = VIDEO_DEFAULTS.duplicate()
## Filtro del loot: gli oggetti con rarità sotto questo valore non compaiono a terra (0 = tutti,
## 1 = niente comuni, 2 = niente comuni né magici). Diventano qualche sesterzio.
static var loot_filter := 0
## Nomi degli oggetti a terra sempre visibili (altrimenti solo tenendo premuto Alt, come in D3).
static var always_show_items := true
## Numeri di danno sopra i nemici.
static var damage_numbers := true
## Scala dell'interfaccia (1.0 = normale).
static var ui_scale := 1.0
## Daltonici: la rarità si legge anche da una lettera (C, M, R, L, S) oltre che dal colore.
static var colorblind := false
## Controlli a video per il touch (solo nella versione per telefoni/tablet): 0 = automatici
## (se lo schermo è touch), 1 = sempre, 2 = mai.
static var touch_controls := 0
## Solo per i test: attiva i controlli touch anche sul PC.
static var force_touch := false
## Effetti ridotti: niente distorsioni, segni a terra, immagini fantasma, micro-pause; meno particelle.
static var reduced_vfx := false


## I controlli touch sono attivi?
## Esistono solo nella versione Android (feature "mobile"): sul PC mai, anche con uno schermo touch.
static func touch_enabled() -> bool:
	if not (touch_build() or force_touch):
		return false
	match touch_controls:
		1:
			return true
		2:
			return false
	return DisplayServer.is_touchscreen_available()


## Versione per telefoni/tablet (esportazione Android).
static func touch_build() -> bool:
	return OS.has_feature("mobile")


## Valori iniziali della grafica: più leggeri su telefoni e tablet.
static func _video_defaults() -> Dictionary:
	var d: Dictionary = VIDEO_DEFAULTS.duplicate()
	if OS.has_feature("mobile"):
		d["fullscreen"] = true
		d["ssao"] = false
		d["msaa"] = 0
		d["scale"] = 0.8
	return d


static func load_and_apply() -> void:
	var defaults := _video_defaults()
	video = defaults.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		apply_video()
		return
	for k: String in defaults:
		video[k] = cfg.get_value("video", k, defaults[k])
	loot_filter = int(cfg.get_value("gameplay", "loot_filter", 0))
	always_show_items = bool(cfg.get_value("gameplay", "always_show_items", true))
	damage_numbers = bool(cfg.get_value("gameplay", "damage_numbers", true))
	ui_scale = float(cfg.get_value("gameplay", "ui_scale", 1.0))
	colorblind = bool(cfg.get_value("gameplay", "colorblind", false))
	touch_controls = int(cfg.get_value("gameplay", "touch_controls", 0))
	reduced_vfx = bool(cfg.get_value("video", "reduced_vfx", false))
	Sfx.volume_db = float(cfg.get_value("audio", "sfx_db", Sfx.volume_db))
	Music.volume_db = float(cfg.get_value("audio", "music_db", Music.volume_db))
	if cfg.has_section("controls"):
		for a: Array in ACTIONS:
			if cfg.has_section_key("controls", a[0]):
				var ev := deserialize(String(cfg.get_value("controls", a[0])))
				if ev != null:
					rebind(a[0], ev)
	apply_video()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for k: String in video:
		cfg.set_value("video", k, video[k])
	cfg.set_value("gameplay", "loot_filter", loot_filter)
	cfg.set_value("gameplay", "always_show_items", always_show_items)
	cfg.set_value("gameplay", "damage_numbers", damage_numbers)
	cfg.set_value("gameplay", "ui_scale", ui_scale)
	cfg.set_value("gameplay", "colorblind", colorblind)
	cfg.set_value("gameplay", "touch_controls", touch_controls)
	cfg.set_value("video", "reduced_vfx", reduced_vfx)
	cfg.set_value("audio", "sfx_db", Sfx.volume_db)
	cfg.set_value("audio", "music_db", Music.volume_db)
	if cfg.has_section("controls"):
		cfg.erase_section("controls")
	for a: Array in ACTIONS:
		var evs := InputMap.action_get_events(a[0])
		if not evs.is_empty() and _differs_from_default(a[0]):
			cfg.set_value("controls", a[0], serialize(evs[0]))
	cfg.save(PATH)


static func apply_video() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if video["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if video["vsync"] else DisplayServer.VSYNC_DISABLED)
	var vp := tree.root
	match int(video["msaa"]):
		0: vp.msaa_3d = Viewport.MSAA_DISABLED
		4: vp.msaa_3d = Viewport.MSAA_4X
		_: vp.msaa_3d = Viewport.MSAA_2X
	vp.scaling_3d_scale = clampf(float(video["scale"]), 0.5, 1.0)
	vp.content_scale_factor = clampf(ui_scale, 0.75, 1.5)
	if Game.level != null and is_instance_valid(Game.level):
		apply_to_level(Game.level)


## Ombre, SSAO e bagliore dell'ambiente del livello.
static func apply_to_level(level: Node) -> void:
	for we: WorldEnvironment in level.find_children("*", "WorldEnvironment", false, false):
		if we.environment:
			we.environment.ssao_enabled = bool(video["ssao"])
			we.environment.glow_enabled = bool(video["glow"])
	for l: DirectionalLight3D in level.find_children("*", "DirectionalLight3D", false, false):
		l.shadow_enabled = bool(video["shadows"])


static func reset_controls() -> void:
	InputMap.load_from_project_settings()


## Testo del tasto assegnato a un'azione (es. "W", "Mouse sinistro").
static func event_text(action: String) -> String:
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return "—"
	return describe(evs[0])


static func describe(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse sinistro"
			MOUSE_BUTTON_RIGHT: return "Mouse destro"
			MOUSE_BUTTON_MIDDLE: return "Mouse centrale"
			MOUSE_BUTTON_WHEEL_UP: return "Rotellina su"
			MOUSE_BUTTON_WHEEL_DOWN: return "Rotellina giù"
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return ev.as_text()


## Sostituisce tasto/mouse di un'azione tenendo i pulsanti del controller (il tasto resta il primo evento).
static func rebind(action: String, ev: InputEvent) -> void:
	var pads: Array = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			pads.append(e)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for e: InputEvent in pads:
		InputMap.action_add_event(action, e)


static func serialize(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "k:%d" % (ev as InputEventKey).physical_keycode
	if ev is InputEventMouseButton:
		return "m:%d" % (ev as InputEventMouseButton).button_index
	return ""


static func deserialize(s: String) -> InputEvent:
	var parts := s.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "k":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts[0] == "m":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	return null


static func _differs_from_default(action: String) -> bool:
	var def: Dictionary = ProjectSettings.get_setting("input/" + action, {})
	var def_events: Array = def.get("events", [])
	var cur := InputMap.action_get_events(action)
	# Conta solo tastiera e mouse (i pulsanti del controller non si rimappano)
	var a: Array = []
	var b: Array = []
	for e: InputEvent in cur:
		if serialize(e) != "":
			a.append(serialize(e))
	for e: Variant in def_events:
		if e is InputEvent and serialize(e) != "":
			b.append(serialize(e))
	return a != b
