class_name PauseMenu
extends CanvasLayer
## Menu di pausa (ESC): riprendi, salva, comandi, torna al menu, esci.

const CONTROLS := """[b]Movimento[/b]: clic sinistro sul terreno (tieni premuto per seguire il cursore) oppure WASD
[b]Attacco[/b]: clic sinistro su un nemico (tieni premuto per continuare)
[b]Attacca sul posto[/b]: Shift + clic sinistro
[b]Abilità[/b]: clic destro, tasti 1 - 2 - 3 - 4
[b]Pozione[/b]: Q        [b]Interagisci / raccogli[/b]: clic o E
[b]Portale per Ostia Nova[/b]: T (in città clicca il portale per tornare indietro)
[b]Viaggio rapido[/b]: clicca un altare già attivato
[b]Mercante / fabbro[/b]: clic destro su un oggetto dello zaino per vendere / smontare
[b]Inventario[/b]: I o C        [b]Mappa[/b]: TAB        [b]Zoom[/b]: rotellina
[b]Pausa[/b]: ESC"""

var root: Control
var info: Label
var controls: RichTextLabel


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud._panel_style())
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "PAUSA"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Hud.GOLD)
	v.add_child(t)
	for pair: Array in [
		["Riprendi", close],
		["Salva partita", _save],
		["Comandi", func() -> void: controls.visible = not controls.visible],
		["Salva e torna al menu", func() -> void: Game.quit_to_menu(true)],
		["Esci dal gioco", func() -> void:
			Game.save_game()
			get_tree().quit()],
	]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(320, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(pair[1])
		v.add_child(b)
	var vol_row := HBoxContainer.new()
	vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var vl := Label.new()
	vl.text = "Volume effetti "
	vol_row.add_child(vl)
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 6.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(200, 24)
	Sfx._load_settings()
	slider.value = Sfx.volume_db
	slider.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(v)
		Sfx.play("ui_click"))
	vol_row.add_child(slider)
	v.add_child(vol_row)
	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	v.add_child(info)
	controls = RichTextLabel.new()
	controls.bbcode_enabled = true
	controls.fit_content = true
	controls.custom_minimum_size = Vector2(620, 0)
	controls.text = CONTROLS
	controls.visible = false
	v.add_child(controls)
	root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if root.visible:
		close()
		return
	var lvl := Game.level
	if lvl == null or not lvl.close_top_panel():
		open()


func open() -> void:
	root.visible = true
	info.text = ""
	get_tree().paused = true


func close() -> void:
	root.visible = false
	get_tree().paused = false


func _save() -> void:
	if Game.save_game():
		info.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
		info.text = "Partita salvata nello slot %d" % (Game.current_slot + 1)
	else:
		info.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		info.text = "Salvataggio non disponibile (partita di prova avviata dall'editor)"
