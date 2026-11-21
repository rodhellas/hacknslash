class_name SkillsUI
extends CanvasLayer
## Finestra Abilità (tasto K), come in Diablo 3: per ogni tasto scegli l'abilità e la sua variante,
## più 3 passive. A sinistra i tasti, a destra la scelta per il tasto selezionato.
## Cambiare abilità la mette in ricarica (non si può aggirare la ricarica cambiandola).

const GOLD := Color(0.95, 0.78, 0.35)

var player: Player
var panel: PanelContainer
var title_label: Label
var slot_buttons: Dictionary = {}
var passive_buttons: Array = []
var chooser: VBoxContainer
var info: RichTextLabel
var is_open := false
## Cosa si sta scegliendo: un tasto ("lmb", "1"...) o "passiva:N".
var selected := "lmb"


func _ready() -> void:
	layer = 6
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -340
	panel.offset_bottom = 340
	panel.add_theme_stylebox_override("panel", Hud._panel_style(0.96))
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	title_label = _label(26, GOLD)
	root.add_child(title_label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(_label(16, Color(0.7, 0.65, 0.55), "Abilità sui tasti"))
	for s: String in HeroClasses.SLOT_ORDER:
		var b := _button("", Vector2(380, 54))
		b.pressed.connect(_select.bind(s))
		left.add_child(b)
		slot_buttons[s] = b
	left.add_child(_label(16, Color(0.7, 0.65, 0.55), "Passive"))
	for i in SkillDB.PASSIVE_SLOTS.size():
		var b := _button("", Vector2(380, 44))
		b.pressed.connect(_select.bind("passiva:%d" % i))
		left.add_child(b)
		passive_buttons.append(b)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	chooser = VBoxContainer.new()
	chooser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chooser.add_theme_constant_override("separation", 4)
	scroll.add_child(chooser)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.custom_minimum_size = Vector2(0, 120)
	info.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(info)
	var close := _button("Chiudi (K)", Vector2(160, 40))
	close.pressed.connect(close_panel)
	root.add_child(close)
	panel.visible = false


func bind(p: Player) -> void:
	player = p


func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	if is_open:
		refresh()
		if slot_buttons.has(selected):
			(slot_buttons[selected] as Button).grab_focus()


func close_panel() -> void:
	if is_open:
		toggle()


func refresh() -> void:
	if player == null:
		return
	var h := player.hero
	title_label.text = "Abilità di %s – livello %d" % [h.hero_name, h.level]
	for s: String in slot_buttons:
		var ab: Dictionary = player.abilities.get(s, {})
		var b: Button = slot_buttons[s]
		var txt := "[%s]  %s" % [HeroClasses.SLOT_KEYS[s], ab.get("name", "—")]
		if String(ab.get("rune_name", "")) != "":
			txt += "\n      %s" % ab["rune_name"]
		b.text = txt
		_set_icon(b, Icons.ability(String(ab.get("id", ""))), 44)
		_style(b, ab.get("color", Color.GRAY), selected == s)
	for i in passive_buttons.size():
		var b: Button = passive_buttons[i]
		var need := int(SkillDB.PASSIVE_SLOTS[i])
		var pid := String(h.passives[i])
		if h.level < need:
			b.text = "Casella bloccata (livello %d)" % need
		else:
			b.text = SkillDB.find_passive(h.class_id, pid).get("name", "— vuota —") if pid != "" else "— vuota —"
		_set_icon(b, Icons.passive(pid) if h.level >= need else null, 36)
		_style(b, Color(0.8, 0.7, 0.4), selected == "passiva:%d" % i)
	_build_chooser()


func _select(what: String) -> void:
	selected = what
	refresh()


func _build_chooser() -> void:
	for c in chooser.get_children():
		c.queue_free()
	var h := player.hero
	if selected.begins_with("passiva:"):
		var idx := int(selected.get_slice(":", 1))
		chooser.add_child(_label(18, GOLD, "Scegli la passiva"))
		if h.level < int(SkillDB.PASSIVE_SLOTS[idx]):
			chooser.add_child(_label(15, Color(0.7, 0.7, 0.7), "Si sblocca al livello %d." % SkillDB.PASSIVE_SLOTS[idx]))
			info.text = ""
			return
		var none := _button("— Nessuna —", Vector2(0, 36))
		none.pressed.connect(_pick_passive.bind(idx, ""))
		chooser.add_child(none)
		for pd: Dictionary in SkillDB.passives(h.class_id):
			var ok := h.level >= int(pd.get("unlock", 1))
			var b := _button("%s%s" % [pd["name"], "" if ok else "   (liv. %d)" % int(pd["unlock"])], Vector2(0, 36))
			b.disabled = not ok
			_set_icon(b, Icons.passive(String(pd["id"])), 30)
			_style(b, Color(0.8, 0.7, 0.4), h.passives[idx] == pd["id"])
			b.pressed.connect(_pick_passive.bind(idx, String(pd["id"])))
			b.mouse_entered.connect(func() -> void: info.text = "[b]%s[/b]\n%s" % [pd["name"], pd["desc"]])
			b.focus_entered.connect(func() -> void: info.text = "[b]%s[/b]\n%s" % [pd["name"], pd["desc"]])
			chooser.add_child(b)
		var cur := SkillDB.find_passive(h.class_id, String(h.passives[idx]))
		info.text = "[b]%s[/b]\n%s" % [cur["name"], cur["desc"]] if not cur.is_empty() else ""
		return
	var slot := selected
	var cur_id := String((h.skills.get(slot, {}) as Dictionary).get("id", ""))
	var cur_rune := String((h.skills.get(slot, {}) as Dictionary).get("rune", ""))
	chooser.add_child(_label(18, GOLD, "Abilità per il tasto %s" % HeroClasses.SLOT_KEYS[slot]))
	for ab: Dictionary in SkillDB.pool_for_slot(h.class_id, slot):
		var ok := h.level >= int(ab.get("unlock", 1))
		var b := _button("%s%s" % [ab["name"], "" if ok else "   (liv. %d)" % int(ab["unlock"])], Vector2(0, 38))
		b.disabled = not ok
		_set_icon(b, Icons.ability(String(ab["id"])), 32)
		_style(b, ab.get("color", Color.GRAY), ab["id"] == cur_id)
		b.pressed.connect(_pick.bind(slot, String(ab["id"]), "" if ab["id"] != cur_id else cur_rune))
		b.mouse_entered.connect(_show_ability.bind(ab, ""))
		b.focus_entered.connect(_show_ability.bind(ab, ""))
		chooser.add_child(b)
	# Varianti dell'abilità scelta
	var cur_ab := SkillDB.find_ability(h.class_id, cur_id)
	if cur_ab.is_empty():
		return
	chooser.add_child(_label(18, GOLD, "Variante di %s" % cur_ab["name"]))
	var none := _button("— Nessuna variante —", Vector2(0, 34))
	_style(none, Color.GRAY, cur_rune == "")
	none.pressed.connect(_pick.bind(slot, cur_id, ""))
	chooser.add_child(none)
	var rs := SkillDB.runes(cur_id)
	for i in rs.size():
		var r: Dictionary = rs[i]
		var need := SkillDB.rune_unlock(cur_ab, i)
		var ok := h.level >= need
		var b := _button("%s%s" % [r["name"], "" if ok else "   (liv. %d)" % need], Vector2(0, 34))
		b.disabled = not ok
		_style(b, r.get("mods", {}).get("color", cur_ab.get("color", Color.GRAY)), cur_rune == r["id"])
		b.pressed.connect(_pick.bind(slot, cur_id, String(r["id"])))
		b.mouse_entered.connect(_show_ability.bind(cur_ab, String(r["id"])))
		b.focus_entered.connect(_show_ability.bind(cur_ab, String(r["id"])))
		chooser.add_child(b)
	_show_ability(cur_ab, cur_rune)


func _show_ability(ab: Dictionary, rune_id: String) -> void:
	var r := SkillDB.resolve(player.hero.class_id, selected, String(ab["id"]), rune_id, player.powers)
	var t := "[b]%s[/b]  [color=#888888](liv. %d)[/color]\n%s" % [ab["name"], int(ab.get("unlock", 1)), ab["desc"]]
	if rune_id != "":
		var rd := SkillDB.find_rune(String(ab["id"]), rune_id)
		t += "\n[color=#f2c75a]%s:[/color] %s" % [rd.get("name", ""), rd.get("desc", "")]
	var extra: Array = []
	if float(r.get("cost", 0.0)) > 0.0:
		extra.append("Costo %d %s" % [roundi(float(r["cost"])), player.cls["resource"]])
	if float(r.get("cooldown", 0.0)) > 0.0:
		extra.append("Ricarica %.1f s" % float(r["cooldown"]))
	if float(r.get("dmg", 0.0)) > 0.0:
		extra.append("%d%% danno dell'arma" % roundi(float(r["dmg"]) * 100.0))
	if not extra.is_empty():
		t += "\n[color=#aaaaaa]%s[/color]" % "   ".join(extra)
	for pw: String in player.powers:
		if SkillDB.power_ability(pw) == ab["id"]:
			t += "\n[color=#ff8c1a]Leggendario: %s[/color]" % ItemDB.POWERS.get(pw, "")
	info.text = t


func _pick(slot: String, ability_id: String, rune_id: String) -> void:
	var old := String((player.hero.skills.get(slot, {}) as Dictionary).get("id", ""))
	if player.hero.set_skill(slot, ability_id, rune_id):
		if old != ability_id:
			var ab := SkillDB.find_ability(player.hero.class_id, ability_id)
			player.cooldowns[ability_id] = float(ab.get("cooldown", 0.0))
		player.rebuild_abilities()
	refresh()


func _pick_passive(index: int, pid: String) -> void:
	if player.hero.set_passive(index, pid):
		player.refresh_stats()
		player.inventory_changed.emit()
	refresh()


func _style(b: Button, col: Color, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.7) if active else Color(0.1, 0.08, 0.06)
	sb.border_color = col if active else Color(0.35, 0.28, 0.18)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = sb.bg_color.lightened(0.1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_color_override("font_color", col.lightened(0.5) if active else Color(0.85, 0.8, 0.7))


## Icona a sinistra del testo del pulsante (null = niente icona).
func _set_icon(b: Button, tex: Texture2D, px: int) -> void:
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", px)
	b.add_theme_constant_override("h_separation", 10)


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 16)
	return b


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
