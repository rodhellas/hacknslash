class_name PauseMenu
extends CanvasLayer
## Menu di pausa (ESC): riprendi, salva, comandi, torna al menu, esci.

const CONTROLS := """[b]Movimento[/b]: clic sinistro sul terreno (tieni premuto per seguire il cursore) oppure WASD
[b]Attacco[/b]: clic sinistro su un nemico (tieni premuto per continuare)
[b]Attacca sul posto[/b]: Shift + clic sinistro
[b]Abilità[/b]: clic destro, tasti 1 - 2 - 3 - 4
[b]Pozione[/b]: Q        [b]Interagisci / raccogli[/b]: clic o E        [b]Diario missioni[/b]: J
[b]Portale per Ostia Nova[/b]: T (in città clicca il portale per tornare indietro)
[b]Viaggio rapido[/b]: clicca un altare già attivato
[b]Mercante / fabbro / forziere[/b]: clic destro su un oggetto dello zaino per vendere / smontare / depositare
I tasti si cambiano in Opzioni > Comandi.
[b]Inventario[/b]: I o C        [b]Abilità[/b]: K        [b]Mappa[/b]: TAB        [b]Zoom[/b]: rotellina
[b]Nomi degli oggetti a terra[/b]: Alt (se nelle opzioni non sono sempre visibili)
[b]Zaino[/b]: Ctrl + clic = secondo anello / arma nella mano sinistra; Shift sul tooltip = confronto completo
[b]Taglie[/b]: Tabula nel foro di Ostia Nova        [b]Mappa grande[/b] (TAB): legenda e viaggio rapido
[b]Labirinti di Dedalo[/b]: Obelisco nel foro di Ostia Nova
[b]Controller[/b]: stick sinistro muove, A attacca / interagisce, X / B / Y / dorsali abilità, Start pausa, Back inventario
[b]Pausa[/b]: ESC"""

var root: Control
var info: Label
var controls: RichTextLabel
var options: OptionsMenu
var diff_button: OptionButton


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
		["Opzioni", func() -> void: options.open()],
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
	# Difficoltà: vale per i nemici che compaiono da adesso
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	var dl := Label.new()
	dl.text = "Difficoltà: "
	drow.add_child(dl)
	diff_button = OptionButton.new()
	diff_button.custom_minimum_size = Vector2(200, 40)
	diff_button.item_selected.connect(_on_difficulty)
	drow.add_child(diff_button)
	v.add_child(drow)
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
	options = OptionsMenu.new()
	add_child(options)
	root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or options.is_open():
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
	_fill_difficulty()
	get_tree().paused = true
	(root.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func _fill_difficulty() -> void:
	diff_button.clear()
	var lvl := Game.hero.level if Game.hero else 1
	for i in DifficultyDB.LEVELS.size():
		var d: Dictionary = DifficultyDB.LEVELS[i]
		var label := String(d["name"])
		if not DifficultyDB.is_unlocked(i, lvl):
			label += "  (liv. %d)" % int(d["unlock"])
		diff_button.add_item(label, i)
		diff_button.set_item_disabled(i, not DifficultyDB.is_unlocked(i, lvl))
	diff_button.select(Game.hero.difficulty if Game.hero else 0)
	diff_button.disabled = Game.level != null and int(Game.level.rift_grade) > 0


func _on_difficulty(index: int) -> void:
	if Game.hero == null or not DifficultyDB.is_unlocked(index, Game.hero.level):
		return
	Game.hero.difficulty = index
	var d := DifficultyDB.get_data(index)
	info.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	info.text = "Difficoltà %s: nemici ×%.1f vita, ×%.1f danni; esperienza ×%.1f, leggendari ×%.1f" % [
		d["name"], float(d["hp"]), float(d["dmg"]), float(d["xp"]), float(d["leg"])]


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
