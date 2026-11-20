class_name Cutscene
extends CanvasLayer
## RIPRODUTTORE DELLE CUTSCENE (catalogo: data/cutscene_db.gd, guida: docs/CUTSCENE.md).
## Inquadrature: titolo, immagine animata (fumetto animato con zoom/panoramica e livelli in parallasse), video,
## scena nel motore (telecamera e attori nel livello). Sottotitoli che si scrivono, voce, musica, particelle.
## Il gioco è in pausa mentre gira (si muovono solo gli attori delle scene). Clic / Spazio / Invio / A = avanti
## (se il testo si sta ancora scrivendo lo completa), Esc / Start / B = salta tutto (se "skippable").
## Uso: Cutscene.play("id") oppure Cutscene.trigger("enter:level_01") (una volta per eroe: flag "cs_<id>").

signal finished(cutscene_id: String, skipped: bool)

const LAYER := 40
const IMG_DIR := "res://textures/cutscene/"
const VOICE_DIR := "res://audio/voci/"
const OVERSCAN := 1.2          # le immagini sono più grandi dello schermo: spazio per zoom e panoramiche
const PAN := 0.07              # spostamento per x/y = 1 (frazione dello schermo)
const BAR := 0.09              # bande nere sopra e sotto (frazione dell'altezza)
const DEFAULT_FADE := 0.45
const MIN_SHOT_INPUT := 0.25   # dopo un cambio di inquadratura l'input "avanti" è ignorato per un attimo

static var current: Cutscene = null
static var _queue: Array = []   # [id, Callable]

var cutscene_id := ""
var on_done: Callable
var data: Dictionary = {}
var shots: Array = []
var index := -1
var skippable := true
var skipped := false

var _root: Control
var _black: ColorRect
var _stage: Control
var _bars: Array[ColorRect] = []
var _sub_box: VBoxContainer
var _speaker: Label
var _text: RichTextLabel
var _skip_label: Label
var _hint: Label
var _fade: ColorRect
var _fx: CPUParticles2D
var _voice: AudioStreamPlayer
var _video: VideoStreamPlayer
var _layers: Array = []        # [Control, profondità]
var _move_from: Array = [1.0, 0.0, 0.0]
var _move_to: Array = [1.0, 0.0, 0.0]
var _shot_time := 0.0
var _shot_len := 0.0
var _shot_tw: Tween
var _reveal_tw: Tween
var _cam: Camera3D
var _prev_cam: Camera3D
var _anchor := Vector3.ZERO
var _spawned: Dictionary = {}
var _anim_modes: Dictionary = {}   # AnimationPlayer -> process_mode originale
var _hidden_ui: Array = []
var _was_paused := false
var _done := false


# --- API ----------------------------------------------------------------------------------------------

## Riproduce una cutscene. Se un'altra è in corso, va in coda. `done` è chiamata alla fine (anche se saltata).
static func play(id: String, done: Callable = Callable()) -> Cutscene:
	if CutsceneDB.get_data(id).is_empty():
		push_warning("Cutscene sconosciuta: " + id)
		if done.is_valid():
			done.call()
		return null
	if is_playing():
		_queue.append([id, done])
		return null
	var tree := Engine.get_main_loop() as SceneTree
	var c := Cutscene.new()
	c.cutscene_id = id
	c.on_done = done
	tree.root.add_child(c)
	return c


static func is_playing() -> bool:
	return current != null and is_instance_valid(current) and not current._done


## Già vista da questo eroe?
static func seen(id: String) -> bool:
	return Game.hero != null and Game.hero.flags.has("cs_" + id)


## Evento di gioco: fa partire le cutscene con questo "trigger" non ancora viste. Ritorna true se ne parte almeno una.
static func trigger(event: String) -> bool:
	if Game.hero == null:
		return false
	var any := false
	for id: String in CutsceneDB.with_trigger(event):
		if seen(id) or (is_playing() and current.cutscene_id == id) or _queue.any(func(q: Array) -> bool: return q[0] == id):
			continue
		play(id)
		any = true
	return any


## Avanti: completa il testo che si sta scrivendo, altrimenti passa all'inquadratura successiva.
func advance() -> void:
	if _done or _shot_time < MIN_SHOT_INPUT:
		return
	if _reveal_tw != null and _reveal_tw.is_running():
		_reveal_tw.kill()
		_text.visible_ratio = 1.0
		return
	_next_shot()


func skip() -> void:
	if skippable and not _done:
		skipped = true
		_finish()


# --- Ciclo di vita ------------------------------------------------------------------------------------

func _ready() -> void:
	current = self
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = CutsceneDB.get_data(cutscene_id)
	shots = data.get("shots", [])
	skippable = bool(data.get("skippable", true))
	if Game.hero != null:
		Game.hero.flags["cs_" + cutscene_id] = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_hide_game_ui()
	_build_ui()
	var music := String(data.get("music", ""))
	if music != "":
		var path := Music.find("music", [music])
		if path != "":
			Music.play(path)
	_next_shot()


func _process(delta: float) -> void:
	if _done:
		return
	_shot_time += delta
	if _shot_len > 0.0 and _shot_time >= _shot_len:
		_next_shot()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var mb := event as InputEventMouseButton
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		skip()
	elif mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if skippable and _skip_label.get_global_rect().grow(14.0).has_point(_skip_label.get_global_mouse_position()):
			skip()
		else:
			advance()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("pad_primary"):
		advance()
	elif not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
			or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseMotion):
		return
	get_viewport().set_input_as_handled()   # niente arriva al gioco durante la cutscene


func _finish() -> void:
	if _done:
		return
	_done = true
	_clear_shot()
	_end_scene_camera()
	for n: Node in _spawned.values():
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	for ap: Variant in _anim_modes:
		if is_instance_valid(ap):
			(ap as AnimationPlayer).process_mode = _anim_modes[ap]
	_anim_modes.clear()
	for ui: Variant in _hidden_ui:
		if is_instance_valid(ui):
			(ui as CanvasLayer).visible = true
	_hidden_ui.clear()
	if not _was_paused:
		get_tree().paused = false
	if String(data.get("music", "")) != "" and Game.level != null and is_instance_valid(Game.level):
		Music.play_level(Game.level.music_names(), Game.level.music)
	if current == self:
		current = null
	finished.emit(cutscene_id, skipped)
	if on_done.is_valid():
		on_done.call()
	queue_free()
	if not _queue.is_empty():
		var nxt: Array = _queue.pop_front()
		Cutscene.play.call_deferred(String(nxt[0]), nxt[1])


func _hide_game_ui() -> void:
	var lvl: Node = Game.level if Game.level != null and is_instance_valid(Game.level) else null
	if lvl == null:
		return
	for key: String in ["hud", "touch"]:
		var ui: Variant = lvl.get(key)
		if ui is CanvasLayer and (ui as CanvasLayer).visible:
			(ui as CanvasLayer).visible = false
			_hidden_ui.append(ui)


# --- Interfaccia --------------------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = BAR
		else:
			bar.anchor_top = 1.0 - BAR
			bar.anchor_bottom = 1.0
		_root.add_child(bar)
		_bars.append(bar)
	# Sottotitoli: chi parla + testo che si scrive
	_sub_box = VBoxContainer.new()
	_sub_box.anchor_left = 0.15
	_sub_box.anchor_right = 0.85
	_sub_box.anchor_top = 1.0 - BAR - 0.13
	_sub_box.anchor_bottom = 1.0 - 0.015
	_sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sub_box)
	_speaker = Label.new()
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36))
	_speaker.add_theme_constant_override("outline_size", 6)
	_speaker.add_theme_color_override("font_outline_color", Color.BLACK)
	_sub_box.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_constant_override("outline_size", 6)
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_sub_box.add_child(_text)
	_skip_label = Label.new()
	_skip_label.text = "Salta  ▸▸" if Settings.touch_enabled() else "Salta  ▸▸  (Esc)"
	_skip_label.visible = skippable
	_skip_label.anchor_left = 1.0
	_skip_label.anchor_right = 1.0
	_skip_label.offset_left = -220
	_skip_label.offset_right = -24
	_skip_label.offset_top = 18
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75, 0.75))
	_root.add_child(_skip_label)
	_hint = Label.new()
	_hint.text = "Tocca: avanti" if Settings.touch_enabled() else "Clic / Spazio: avanti"
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -260
	_hint.offset_right = -24
	_hint.offset_top = -34
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62, 0.6))
	_root.add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)


# --- Inquadrature -------------------------------------------------------------------------------------

func _next_shot() -> void:
	_clear_shot()
	index += 1
	if index >= shots.size():
		_finish()
		return
	var s: Dictionary = shots[index]
	var kind := String(s.get("type", "image"))
	if kind != "scene":
		_end_scene_camera()
	_black.visible = kind != "scene"
	for bar: ColorRect in _bars:
		bar.visible = kind != "title"
	var voice := _voice_stream(s)
	_shot_len = _duration(s, voice)
	_shot_time = 0.0
	match kind:
		"title": _shot_title(s)
		"video": _shot_video(s)
		"scene": _shot_scene(s)
		_: _shot_image(s)
	_set_fx(String(s.get("fx", "")))
	_set_subtitle(s)
	if voice != null and DisplayServer.get_name() != "headless":
		_voice.stream = voice
		_voice.volume_db = Sfx.volume_db + 4.0
		_voice.play()
	var fade := float(s.get("fade", DEFAULT_FADE))
	_fade.color.a = 1.0 if fade > 0.0 else 0.0
	if fade > 0.0:
		create_tween().tween_property(_fade, "color:a", 0.0, fade)


## Durata: "duration", altrimenti la voce, altrimenti la lunghezza del testo (o delle azioni della scena).
func _duration(s: Dictionary, voice: AudioStream) -> float:
	if s.has("duration"):
		return float(s["duration"])
	if voice != null:
		return voice.get_length() + 0.6
	var kind := String(s.get("type", "image"))
	if kind == "video":
		return -1.0   # finisce col video
	var t := maxf(2.5, 1.4 + String(s.get("text", "")).length() * 0.055)
	if kind == "title":
		t = 3.0
	elif kind == "scene":
		for a: Dictionary in s.get("actions", []):
			t = maxf(t, float(a.get("at", 0.0)) + float(a.get("time", 0.0)) + 1.2)
	elif String(s.get("text", "")) == "":
		t = 4.0
	return t


func _clear_shot() -> void:
	if _shot_tw != null:
		_shot_tw.kill()
	if _reveal_tw != null:
		_reveal_tw.kill()
	for c: Node in _stage.get_children() if _stage != null else []:
		c.queue_free()
	_layers.clear()
	_video = null
	if _voice != null:
		_voice.stop()
	_set_fx("")


func _shot_title(s: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(box)
	var big := Label.new()
	big.text = String(s.get("text", ""))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 72)
	big.add_theme_color_override("font_color", Color(0.95, 0.8, 0.42))
	box.add_child(big)
	var small := Label.new()
	small.text = String(s.get("subtitle", ""))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.add_theme_font_size_override("font_size", 28)
	small.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	box.add_child(small)
	box.modulate.a = 0.0
	_shot_tw = create_tween()
	_shot_tw.tween_property(box, "modulate:a", 1.0, minf(1.0, _shot_len * 0.3))


func _shot_image(s: Dictionary) -> void:
	var layers: Array = s.get("layers", [])
	if layers.is_empty():
		layers = [[String(s.get("image", "")), 0.0]]
	var first := true
	for l: Array in layers:
		var c := _image_layer(String(l[0]), first)
		_stage.add_child(c)
		_layers.append([c, float(l[1])])
		first = false
	var mv: Dictionary = s.get("move", {})
	_move_from = mv.get("from", [1.0, 0.0, 0.0])
	_move_to = mv.get("to", _move_from)
	_apply_move(0.0)
	if _shot_len > 0.0:
		_shot_tw = create_tween()
		_shot_tw.tween_method(_apply_move, 0.0, 1.0, _shot_len).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Un livello dell'immagine; se il file manca, un segnaposto con il nome (fondo scuro solo per il primo livello).
func _image_layer(img: String, opaque: bool) -> Control:
	var path := image_path(img)
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var ph := ColorRect.new()
	ph.color = Color(0.12, 0.1, 0.09) if opaque else Color(0, 0, 0, 0)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := Label.new()
	lb.text = "[immagine mancante: %s]" % img
	lb.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.8))
	lb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lb.position.y += 40.0 * _layers.size()
	ph.add_child(lb)
	return ph


## Percorso di un'immagine: "nome" o "cartella/nome" sotto textures/cutscene/ (.png predefinito) oppure res://...
static func image_path(img: String) -> String:
	if img == "":
		return ""
	if img.begins_with("res://"):
		return img
	return IMG_DIR + img + ("" if img.get_extension() != "" else ".png")


## Zoom e panoramica (p = 0..1); i livelli in primo piano si muovono di più (parallasse).
func _apply_move(p: float) -> void:
	var vs := _root.size
	var zoom := lerpf(float(_move_from[0]), float(_move_to[0]), p)
	var off := Vector2(lerpf(float(_move_from[1]), float(_move_to[1]), p), lerpf(float(_move_from[2]), float(_move_to[2]), p))
	for l: Array in _layers:
		var c: Control = l[0]
		var f := 0.6 + float(l[1]) * 0.8
		c.size = vs * OVERSCAN
		c.pivot_offset = c.size * 0.5
		c.position = (vs - c.size) * 0.5 + off * vs * PAN * f
		var z := 1.0 + (zoom - 1.0) * f
		c.scale = Vector2(z, z)


func _shot_video(s: Dictionary) -> void:
	var path := String(s.get("video", ""))
	if path != "" and ResourceLoader.exists(path) and DisplayServer.get_name() != "headless":
		_video = VideoStreamPlayer.new()
		_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_video.expand = true
		_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_video.stream = load(path)
		_video.volume_db = Sfx.volume_db
		_stage.add_child(_video)
		_video.finished.connect(func() -> void:
			if not _done and _video != null:
				_next_shot())
		_video.play()
		return
	_stage.add_child(_image_layer("video: " + path.get_file(), true))
	_layers.append([_stage.get_child(_stage.get_child_count() - 1), 0.0])
	_move_from = [1.0, 0.0, 0.0]
	_move_to = _move_from
	_apply_move(0.0)
	if _shot_len < 0.0:
		_shot_len = 3.0


# --- Scene nel motore ---------------------------------------------------------------------------------

func _shot_scene(s: Dictionary) -> void:
	var lvl: Node = Game.level if Game.level != null and is_instance_valid(Game.level) else null
	if lvl == null:
		_shot_len = 0.01   # fuori da un livello le scene si saltano
		return
	_anchor = _resolve_anchor(lvl, s.get("anchor", "player"))
	var cam_d: Dictionary = s.get("camera", {})
	var from := _anchor + _v3(cam_d.get("from", [6, 5, 8]))
	var to := _anchor + _v3(cam_d.get("to", cam_d.get("from", [6, 5, 8])))
	var look := _anchor + _v3(cam_d.get("look", [0, 1, 0]))
	if _cam == null:
		_prev_cam = get_viewport().get_camera_3d()
		_cam = Camera3D.new()
		_cam.name = "CameraCutscene"
		lvl.add_child(_cam)
		_cam.make_current()
	_cam.fov = float(cam_d.get("fov", 50.0))
	var move_cam := func(p: float) -> void:
		if _cam != null and is_instance_valid(_cam):
			_cam.global_position = from.lerp(to, p)
			_cam.look_at(look, Vector3.UP)
	move_cam.call(0.0)
	_shot_tw = create_tween()
	_shot_tw.tween_method(move_cam, 0.0, 1.0, maxf(_shot_len, 0.1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for a: Dictionary in s.get("actions", []):
		var at := float(a.get("at", 0.0))
		if at <= 0.0:
			_do_action(lvl, a)
		else:
			_shot_tw.parallel().tween_callback(_do_action.bind(lvl, a)).set_delay(at)


func _do_action(lvl: Node, a: Dictionary) -> void:
	if _done:
		return
	var actor: Node3D = null
	var name_key := String(a.get("name", a.get("actor", "")))
	if a.has("spawn"):
		var ps := load(String(a["spawn"])) as PackedScene
		if ps != null:
			actor = ps.instantiate() as Node3D
			if actor != null:
				lvl.add_child(actor)
				actor.global_position = _anchor + _v3(a.get("at_pos", a.get("move", [0, 0, 0])))
				_spawned[name_key] = actor
		if not a.has("anim") and not a.has("face"):
			return
	if actor == null:
		actor = _resolve_actor(lvl, String(a.get("actor", "")))
	if actor == null:
		return
	if a.has("move") and not a.has("spawn"):
		var target := _anchor + _v3(a["move"])
		target.y = actor.global_position.y
		_face(actor, target)
		var tw := create_tween()
		tw.tween_property(actor, "global_position", target, maxf(float(a.get("time", 1.0)), 0.05))
		_play(actor, "run")
		tw.tween_callback(_play.bind(actor, "idle"))
	if a.has("face"):
		_face(actor, _anchor + _v3(a["face"]))
	if a.has("anim"):
		_play(actor, String(a["anim"]))


func _resolve_anchor(lvl: Node, a: Variant) -> Vector3:
	if a is Array:
		return _v3(a)
	var n := _resolve_actor(lvl, String(a))
	return n.global_position if n != null else (lvl.get("player") as Node3D).global_position


func _resolve_actor(lvl: Node, key: String) -> Node3D:
	if key == "player" or key == "":
		return lvl.get("player") as Node3D
	if _spawned.has(key) and is_instance_valid(_spawned[key]):
		return _spawned[key]
	return lvl.get_node_or_null(key) as Node3D


func _face(actor: Node3D, target: Vector3) -> void:
	if actor.has_method("_face_point"):
		actor.call("_face_point", target)
		return
	var to := target - actor.global_position
	to.y = 0.0
	if to.length() > 0.1:
		actor.rotation.y = atan2(-to.x, -to.z)


## Animazione dell'attore (gira anche col gioco in pausa).
func _play(actor: Node3D, anim_name: String) -> void:
	for ap: Node in actor.find_children("*", "AnimationPlayer", true, false):
		var p := ap as AnimationPlayer
		if not _anim_modes.has(p):
			_anim_modes[p] = p.process_mode
			p.process_mode = Node.PROCESS_MODE_ALWAYS
		if p.has_animation(anim_name):
			p.play(anim_name)
			return


func _end_scene_camera() -> void:
	if _cam == null:
		return
	if is_instance_valid(_cam):
		_cam.queue_free()
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_cam = null
	_prev_cam = null


static func _v3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	var arr: Array = v
	return Vector3(float(arr[0]), float(arr[1]) if arr.size() > 1 else 0.0, float(arr[2]) if arr.size() > 2 else 0.0)


# --- Testo, voce, particelle --------------------------------------------------------------------------

func _set_subtitle(s: Dictionary) -> void:
	var t := String(s.get("text", "")) if String(s.get("type", "")) != "title" else ""
	_speaker.text = String(s.get("speaker", ""))
	_speaker.visible = _speaker.text != "" and t != ""
	_text.text = "[center]%s[/center]" % t
	_text.visible_ratio = 0.0
	_sub_box.visible = t != ""
	if t != "":
		var reveal := minf(t.length() * 0.028, maxf(_shot_len * 0.6, 0.3) if _shot_len > 0.0 else 2.0)
		_reveal_tw = create_tween()
		_reveal_tw.tween_property(_text, "visible_ratio", 1.0, reveal)


## Voce dell'inquadratura: "voice" oppure audio/voci/<id>_<n>.ogg|wav|mp3 se esiste.
func _voice_stream(s: Dictionary) -> AudioStream:
	var paths: Array = []
	if s.has("voice"):
		paths.append(String(s["voice"]))
	for ext: String in ["ogg", "wav", "mp3"]:
		paths.append("%s%s_%d.%s" % [VOICE_DIR, cutscene_id, index + 1, ext])
	for p: String in paths:
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null


## Particelle sopra l'immagine: braci, cenere, pioggia, energia, neve ("" = nessuna).
func _set_fx(kind: String) -> void:
	if _fx != null:
		_fx.queue_free()
		_fx = null
	if kind == "" or _root == null or Settings.reduced_vfx:
		return
	var vs := _root.size
	var p := CPUParticles2D.new()
	p.amount = 70
	p.lifetime = 5.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vs.x * 0.55, 10.0)
	p.spread = 25.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var up := true
	match kind:
		"braci":
			p.color = Color(1.0, 0.55, 0.15, 0.9)
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 110.0
		"energia":
			p.color = Color(0.45, 0.85, 1.0, 0.85)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 80.0
		"cenere":
			up = false
			p.color = Color(0.55, 0.52, 0.5, 0.7)
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 60.0
		"neve":
			up = false
			p.color = Color(0.95, 0.95, 1.0, 0.85)
			p.initial_velocity_min = 25.0
			p.initial_velocity_max = 55.0
		"pioggia":
			up = false
			p.amount = 300
			p.lifetime = 1.4
			p.spread = 4.0
			p.color = Color(0.7, 0.78, 0.9, 0.5)
			p.initial_velocity_min = 700.0
			p.initial_velocity_max = 900.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
		_:
			p.queue_free()
			return
	p.direction = Vector2(0.15, -1.0) if up else Vector2(0.1, 1.0)
	p.gravity = Vector2(0, -15.0 if up else 25.0)
	p.position = Vector2(vs.x * 0.5, vs.y + 10.0 if up else -10.0)
	_root.add_child(p)
	_root.move_child(p, _stage.get_index() + 1)
	_fx = p
