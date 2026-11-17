class_name OptionsMenu
extends CanvasLayer
## Opzioni: Video (schermo intero, vsync, ombre, SSAO, bagliore, antialiasing, risoluzione 3D),
## Audio (effetti, musica) e Comandi (rimappatura dei tasti). Aperto dal menu principale e dalla pausa.
## Le impostazioni sono in core/settings.gd e vengono salvate in user://settings.cfg.

signal closed

var root: Control
var pages: Dictionary = {}
var _waiting_action := ""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud._panel_style())
	panel.custom_minimum_size = Vector2(720, 600)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Label.new()
	t.text = "OPZIONI"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Hud.GOLD)
	v.add_child(t)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var holder := ScrollContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(holder)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(stack)
	pages["video"] = _build_video()
	pages["audio"] = _build_audio()
	pages["comandi"] = _build_controls()
	pages["gioco"] = _build_gameplay()
	for id: String in ["video", "audio", "gioco", "comandi"]:
		stack.add_child(pages[id])
		var b := Button.new()
		b.text = id.capitalize()
		b.custom_minimum_size = Vector2(150, 36)
		b.pressed.connect(_show.bind(id))
		tabs.add_child(b)
	var close_btn := Button.new()
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	v.add_child(close_btn)
	_show("video")
	root.visible = false


func open() -> void:
	root.visible = true
	_refresh_binds()


func close() -> void:
	_waiting_action = ""
	root.visible = false
	Settings.save()
	closed.emit()


func is_open() -> bool:
	return root.visible


func _show(id: String) -> void:
	for k: String in pages:
		(pages[k] as Control).visible = k == id


# --- Video ------------------------------------------------------------------------------------------

func _build_video() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	for pair: Array in [["fullscreen", "Schermo intero"], ["vsync", "Sincronia verticale (V-Sync)"],
			["shadows", "Ombre"], ["ssao", "Occlusione ambientale (SSAO)"], ["glow", "Bagliore (glow)"]]:
		var c := CheckBox.new()
		c.text = pair[1]
		c.button_pressed = bool(Settings.video[pair[0]])
		var key: String = pair[0]
		c.toggled.connect(func(on: bool) -> void:
			Settings.video[key] = on
			Settings.apply_video())
		v.add_child(c)
	var row := HBoxContainer.new()
	row.add_child(_label("Antialiasing  "))
	var opt := OptionButton.new()
	for pair: Array in [[0, "Disattivato"], [2, "MSAA 2x"], [4, "MSAA 4x"]]:
		opt.add_item(pair[1], pair[0])
	opt.select(opt.get_item_index(int(Settings.video["msaa"])))
	opt.item_selected.connect(func(i: int) -> void:
		Settings.video["msaa"] = opt.get_item_id(i)
		Settings.apply_video())
	row.add_child(opt)
	v.add_child(row)
	v.add_child(_slider_row("Risoluzione 3D (%)", 50.0, 100.0, 5.0, float(Settings.video["scale"]) * 100.0,
		func(x: float) -> void:
			Settings.video["scale"] = x / 100.0
			Settings.apply_video()))
	v.add_child(_label("Abbassa la risoluzione 3D, le ombre o l'SSAO se il gioco va a scatti.", 13, Color(0.6, 0.6, 0.6)))
	return v


# --- Gioco ------------------------------------------------------------------------------------------

func _build_gameplay() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.add_child(_label("Filtro del loot  "))
	var opt := OptionButton.new()
	for pair: Array in [[0, "Mostra tutto"], [1, "Nascondi i comuni"], [2, "Nascondi comuni e magici"]]:
		opt.add_item(pair[1], pair[0])
	opt.select(clampi(Settings.loot_filter, 0, 2))
	opt.item_selected.connect(func(i: int) -> void: Settings.loot_filter = opt.get_item_id(i))
	row.add_child(opt)
	v.add_child(row)
	v.add_child(_label("Gli oggetti nascosti non cadono a terra: diventano qualche sesterzio.", 13, Color(0.6, 0.6, 0.6)))
	var c := CheckBox.new()
	c.text = "Nomi degli oggetti a terra sempre visibili"
	c.button_pressed = Settings.always_show_items
	c.toggled.connect(func(on: bool) -> void: Settings.always_show_items = on)
	v.add_child(c)
	v.add_child(_label("Se disattivato si vedono solo rari, leggendari e set; tieni premuto Alt per vederli tutti.", 13, Color(0.6, 0.6, 0.6)))
	var dn := CheckBox.new()
	dn.text = "Numeri di danno"
	dn.button_pressed = Settings.damage_numbers
	dn.toggled.connect(func(on: bool) -> void: Settings.damage_numbers = on)
	v.add_child(dn)
	var cb := CheckBox.new()
	cb.text = "Modalità daltonici (lettera della rarità: C, M, R, L, S)"
	cb.button_pressed = Settings.colorblind
	cb.toggled.connect(func(on: bool) -> void: Settings.colorblind = on)
	v.add_child(cb)
	v.add_child(_slider_row("Scala dell'interfaccia (%)", 75.0, 150.0, 5.0, Settings.ui_scale * 100.0, func(x: float) -> void:
		Settings.ui_scale = x / 100.0
		Settings.apply_video()))
	return v


# --- Audio ------------------------------------------------------------------------------------------

func _build_audio() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	Sfx._load_settings()
	v.add_child(_slider_row("Effetti (dB)", -40.0, 6.0, 1.0, Sfx.volume_db, func(x: float) -> void:
		Sfx.volume_db = x
		Sfx.play("ui_click")))
	v.add_child(_slider_row("Musica (dB)", -40.0, 6.0, 1.0, Music.volume_db, func(x: float) -> void: Music.set_volume(x)))
	v.add_child(_label("La musica si attiva mettendo i brani in audio/music/ (vedi il file LEGGIMI.txt).", 13, Color(0.6, 0.6, 0.6)))
	return v


# --- Comandi ----------------------------------------------------------------------------------------

func _build_controls() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(_label("Clicca su un comando e premi il nuovo tasto (o pulsante del mouse). ESC annulla.", 14, Color(0.75, 0.7, 0.6)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for a: Array in Settings.ACTIONS:
		grid.add_child(_label(a[1]))
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 30)
		var action: String = a[0]
		b.pressed.connect(func() -> void:
			_waiting_action = action
			b.text = "Premi un tasto..."
			Sfx.play("ui_click"))
		grid.add_child(b)
		_bind_buttons[action] = b
	var reset := Button.new()
	reset.text = "Ripristina i comandi predefiniti"
	reset.custom_minimum_size = Vector2(300, 36)
	reset.pressed.connect(func() -> void:
		Settings.reset_controls()
		_refresh_binds())
	v.add_child(reset)
	return v


func _refresh_binds() -> void:
	for action: String in _bind_buttons:
		(_bind_buttons[action] as Button).text = Settings.event_text(action)


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	if _waiting_action == "":
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			close()
		return
	var ok := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			_waiting_action = ""
			_refresh_binds()
			get_viewport().set_input_as_handled()
			return
		ok = true
	elif event is InputEventMouseButton and event.pressed:
		ok = true
	if not ok:
		return
	var ev: InputEvent = Settings.deserialize(Settings.serialize(event))
	if ev == null:
		return
	Settings.rebind(_waiting_action, ev)
	_waiting_action = ""
	_refresh_binds()
	get_viewport().set_input_as_handled()


# --- Helper -----------------------------------------------------------------------------------------

func _slider_row(text: String, lo: float, hi: float, step: float, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := _label(text)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300, 24)
	var val := _label("%d" % roundi(value))
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d" % roundi(x)
		cb.call(x))
	row.add_child(s)
	row.add_child(val)
	return row


func _label(text: String, size: int = 16, color: Color = Color(0.9, 0.88, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
