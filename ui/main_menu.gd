extends Control
## Menu principale: Continua, Nuova partita (slot -> classe -> nome), Carica, Esci.

const GOLD := Color(0.95, 0.78, 0.35)

const BACKGROUND := "res://textures/ui/sfondo_menu.png"
var shade: ColorRect
var pages: Dictionary = {}
var slot_list: VBoxContainer
var slot_mode := "new"   # "new" o "load"
var chosen_slot := 0
var chosen_class := "legionario"
var chosen_sex := "m"
var hardcore_check: CheckBox
var sex_buttons: Dictionary = {}
var class_buttons: Dictionary = {}
var class_detail: RichTextLabel
var name_edit: LineEdit
var confirm: ConfirmationDialog
var _pending_slot := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Sfondo dipinto (textures/ui/sfondo_menu.png): la zona scura a sinistra è per i pulsanti
	if ResourceLoader.exists(BACKGROUND):
		var art := TextureRect.new()
		art.texture = load(BACKGROUND)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var stripe := ColorRect.new()
	stripe.color = Color(0.45, 0.05, 0.05, 0.5)
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_top = 150
	stripe.offset_bottom = 156
	add_child(stripe)

	var title := _label(72, GOLD, "LEGIO 3000")
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := _label(20, Color(0.8, 0.75, 0.65), "L'Impero non è mai caduto. Nova Roma, 3000 d.C.")
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 165
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	if ResourceLoader.exists(BACKGROUND):
		# Titolo nella zona scura a sinistra del dipinto, con il contorno per leggerlo sopra l'immagine
		for c: Control in [stripe, title, sub]:
			c.anchor_right = 0.42
		for l: Label in [title, sub]:
			l.add_theme_constant_override("outline_size", 10)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	pages["main"] = _build_main()
	pages["slots"] = _build_slots()
	pages["class"] = _build_class()
	confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Lo slot contiene già una partita. Sovrascriverla?"
	confirm.ok_button_text = "Sovrascrivi"
	confirm.cancel_button_text = "Annulla"
	confirm.confirmed.connect(func() -> void:
		chosen_slot = _pending_slot
		_show("class"))
	add_child(confirm)
	_show("main")
	Music.play_level(["menu"])


func _page() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 200
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	return v


func _show(page: String) -> void:
	for k: String in pages:
		(pages[k] as Control).get_parent().visible = k == page
	# Pagina principale: pulsanti nella zona scura a sinistra del dipinto; le altre (larghe) al centro, su fondo scurito
	var main_center := (pages["main"] as Control).get_parent() as Control
	main_center.anchor_right = 0.42 if ResourceLoader.exists(BACKGROUND) else 1.0
	shade.color.a = 0.0 if page == "main" else 0.6
	if page == "slots":
		_refresh_slots()
	elif page == "main":
		_refresh_main()


# --- Pagina principale ---------------------------------------------------------

var _continue_btn: Button


func _build_main() -> VBoxContainer:
	var v := _page()
	_continue_btn = _button("Continua", func() -> void:
		var s := Game.latest_slot()
		if s >= 0:
			Game.load_game(s))
	v.add_child(_continue_btn)
	v.add_child(_button("Nuova partita", func() -> void:
		slot_mode = "new"
		_show("slots")))
	v.add_child(_button("Carica partita", func() -> void:
		slot_mode = "load"
		_show("slots")))
	var opts := OptionsMenu.new()
	add_child(opts)
	v.add_child(_button("Opzioni", func() -> void: opts.open()))
	v.add_child(_button("Esci", func() -> void: get_tree().quit()))
	return v


func _refresh_main() -> void:
	var s := Game.latest_slot()
	if s >= 0 and bool(Game.slot_info(s).get("dead", false)):
		s = -1   # l'ultimo eroe è un hardcore caduto
	_continue_btn.visible = s >= 0
	if s >= 0:
		var info := Game.slot_info(s)
		_continue_btn.text = "Continua  (%s, %s liv. %d)" % [info["name"], HeroClasses.get_data(info["class_id"])["name"], info["level"]]


# --- Slot di salvataggio ------------------------------------------------------------

func _build_slots() -> VBoxContainer:
	var v := _page()
	var t := _label(28, GOLD, "")
	t.name = "SlotTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	slot_list = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 10)
	v.add_child(slot_list)
	v.add_child(_button("Indietro", func() -> void: _show("main")))
	return v


func _refresh_slots() -> void:
	(pages["slots"] as Control).find_child("SlotTitle", true, false).text = \
		"Scegli uno slot per la nuova partita" if slot_mode == "new" else "Carica partita"
	for c in slot_list.get_children():
		c.queue_free()
	for i in Game.SLOT_COUNT:
		var info := Game.slot_info(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var text := "Slot %d  -  vuoto" % (i + 1)
		if not info.is_empty():
			var secs := int(info["play_time"])
			text = "Slot %d  -  %s, %s liv. %d   (%dh %02dm)   %s" % [i + 1, info["name"],
				HeroClasses.get_data(info["class_id"])["name"], info["level"], secs / 3600, (secs / 60) % 60, info["saved_at"]]
			var extra: Array = [DifficultyDB.level_name(int(info["difficulty"]))]
			if int(info["rift_max"]) > 1:
				extra.append("Labirinto grado %d" % int(info["rift_max"]))
			if bool(info["hardcore"]):
				extra.append("HARDCORE" + ("  † caduto" if bool(info["dead"]) else ""))
			text += "\n          " + "   ·   ".join(extra)
		var b := _button(text, _on_slot_pressed.bind(i, not info.is_empty()))
		b.custom_minimum_size = Vector2(700, 52)
		b.disabled = slot_mode == "load" and (info.is_empty() or bool(info.get("dead", false)))
		row.add_child(b)
		if slot_mode == "load" and not info.is_empty():
			var del := _button("Elimina", func() -> void:
				Game.delete_slot(i)
				_refresh_slots())
			del.custom_minimum_size = Vector2(110, 52)
			row.add_child(del)
		slot_list.add_child(row)


func _on_slot_pressed(slot: int, occupied: bool) -> void:
	if slot_mode == "load":
		Game.load_game(slot)
		return
	if occupied:
		_pending_slot = slot
		confirm.popup_centered()
		return
	chosen_slot = slot
	_show("class")


# --- Scelta della classe --------------------------------------------------------------

func _build_class() -> VBoxContainer:
	var v := _page()
	v.add_child(_center_label(28, GOLD, "Scegli la tua classe"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for id: String in HeroClasses.ORDER:
		var data := HeroClasses.get_data(id)
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\n%s" % [data["name"], HeroClasses.STAT_NAMES[data["main_stat"]]]
		b.custom_minimum_size = Vector2(200, 70)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_select_class.bind(id))
		row.add_child(b)
		class_buttons[id] = b
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 10)
	srow.add_child(_label(18, Color.WHITE, "Corpo: "))
	for sx: String in ["m", "f"]:
		var sb := Button.new()
		sb.toggle_mode = true
		sb.text = "Uomo" if sx == "m" else "Donna"
		sb.custom_minimum_size = Vector2(140, 40)
		sb.add_theme_font_size_override("font_size", 18)
		sb.pressed.connect(_select_sex.bind(sx))
		srow.add_child(sb)
		sex_buttons[sx] = sb
	hardcore_check = CheckBox.new()
	hardcore_check.text = "Hardcore (se muori l'eroe è perso per sempre; forziere separato)"
	hardcore_check.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	srow.add_child(hardcore_check)
	v.add_child(srow)
	class_detail = RichTextLabel.new()
	class_detail.bbcode_enabled = true
	class_detail.fit_content = true
	class_detail.custom_minimum_size = Vector2(840, 260)
	class_detail.add_theme_font_size_override("normal_font_size", 16)
	v.add_child(class_detail)
	var nrow := HBoxContainer.new()
	nrow.alignment = BoxContainer.ALIGNMENT_CENTER
	nrow.add_child(_label(18, Color.WHITE, "Nome dell'eroe: "))
	name_edit = LineEdit.new()
	name_edit.text = "Lucio"
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(280, 40)
	nrow.add_child(name_edit)
	v.add_child(nrow)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 12)
	brow.add_child(_button("Indietro", func() -> void: _show("slots")))
	brow.add_child(_button("Inizia l'avventura", _start))
	v.add_child(brow)
	_select_class("legionario")
	_select_sex("m")
	return v


func _select_sex(sx: String) -> void:
	chosen_sex = sx
	for k: String in sex_buttons:
		(sex_buttons[k] as Button).button_pressed = k == sx


func _select_class(id: String) -> void:
	chosen_class = id
	for k: String in class_buttons:
		(class_buttons[k] as Button).button_pressed = k == id
	var d := HeroClasses.get_data(id)
	var t := "[font_size=24][color=#%s]%s[/color][/font_size]\n%s\n\n" % [GOLD.to_html(false), d["name"], d["desc"]]
	t += "Statistica principale: [b]%s[/b]    Risorsa: [color=#%s]%s[/color]\n\n" % [
		HeroClasses.STAT_NAMES[d["main_stat"]], (d["resource_color"] as Color).to_html(false), d["resource"]]
	for ab: Dictionary in d["abilities"]:
		t += "[color=#e0c070][%s][/color] [b]%s[/b] [color=#888888](liv. %d)[/color] - %s\n" % [
			HeroClasses.SLOT_KEYS[ab["slot"]], ab["name"], int(ab["unlock"]), ab["desc"]]
	class_detail.text = t


func _start() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Lucio"
	Game.new_game(chosen_slot, n, chosen_class, chosen_sex, hardcore_check.button_pressed)


# --- Helper ---------------------------------------------------------------------------

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _label(size: int, color: Color, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _center_label(size: int, color: Color, text: String) -> Label:
	var l := _label(size, color, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
