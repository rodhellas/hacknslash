class_name InventoryUI
extends CanvasLayer
## Pannello Personaggio + Inventario (tasto I o C).
##   Clic su un oggetto dello zaino: equipaggia (scambia con quello indossato)
##   Clic su un oggetto equipaggiato: lo rimette nello zaino
##   Shift + clic su un oggetto dello zaino: lo getta a terra
##   Con mercante/fabbro aperto: clic destro su un oggetto dello zaino = vendi / smonta
## Passando il mouse sopra un oggetto compare il tooltip con il confronto.

const GOLD := Color(0.95, 0.78, 0.35)

var player: Player
var panel: PanelContainer
var title_label: Label
var equip_buttons: Dictionary = {}
var bag_buttons: Array = []
var stats_label: RichTextLabel
var gold_label: Label
var mats_label: Label
var hint_label: Label
var trade: TradeUI = null
var tooltip: PanelContainer
var tooltip_text: RichTextLabel
var is_open := false
var _tooltip_right := false
var details := false             # statistiche dettagliate
var preview: CharacterPreview


func _ready() -> void:
	layer = 6
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -560
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", Hud._panel_style(0.95))
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	title_label = _label(24, GOLD)
	v.add_child(title_label)

	v.add_child(_label(16, Color(0.7, 0.65, 0.55), "Equipaggiamento"))
	var eq := GridContainer.new()
	eq.columns = 3
	eq.add_theme_constant_override("h_separation", 6)
	eq.add_theme_constant_override("v_separation", 6)
	v.add_child(eq)
	for slot: String in HeroData.EQUIP_SLOTS:
		var b := make_slot_button(Vector2(168, 58))
		b.gui_input.connect(_on_equip_input.bind(slot))
		b.mouse_entered.connect(_on_hover_equip.bind(slot))
		b.focus_entered.connect(_on_focus.bind(b, _on_hover_equip.bind(slot)))
		b.focus_exited.connect(_hide_tooltip)
		b.mouse_exited.connect(_hide_tooltip)
		eq.add_child(b)
		equip_buttons[slot] = b

	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.add_theme_font_size_override("normal_font_size", 15)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(stats_label)

	var hb := HBoxContainer.new()
	hb.add_child(_label(16, Color(0.7, 0.65, 0.55), "Zaino"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	gold_label = _label(16, GOLD)
	hb.add_child(gold_label)
	v.add_child(hb)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	v.add_child(tools)
	var sort_b := Button.new()
	sort_b.text = "Ordina zaino"
	sort_b.focus_mode = Control.FOCUS_NONE
	sort_b.pressed.connect(func() -> void:
		sort_bag()
		player.inventory_changed.emit())
	tools.add_child(sort_b)
	var det_b := Button.new()
	det_b.text = "Statistiche dettagliate"
	det_b.toggle_mode = true
	det_b.focus_mode = Control.FOCUS_NONE
	det_b.toggled.connect(func(on: bool) -> void:
		details = on
		_refresh_stats())
	tools.add_child(det_b)
	mats_label = _label(13, Color(0.75, 0.7, 0.6))
	v.add_child(mats_label)
	var bag := GridContainer.new()
	bag.columns = 8
	bag.add_theme_constant_override("h_separation", 4)
	bag.add_theme_constant_override("v_separation", 4)
	v.add_child(bag)
	for i in HeroData.INV_SIZE:
		var b := make_slot_button(Vector2(60, 60))
		b.gui_input.connect(_on_bag_input.bind(i))
		b.mouse_entered.connect(_on_hover_bag.bind(i))
		b.focus_entered.connect(_on_focus.bind(b, _on_hover_bag.bind(i)))
		b.focus_exited.connect(_hide_tooltip)
		b.mouse_exited.connect(_hide_tooltip)
		bag.add_child(b)
		bag_buttons.append(b)
	hint_label = _label(13, Color(0.6, 0.6, 0.6))
	v.add_child(hint_label)

	tooltip = PanelContainer.new()
	tooltip.add_theme_stylebox_override("panel", Hud._panel_style(0.97))
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = RichTextLabel.new()
	tooltip_text.bbcode_enabled = true
	tooltip_text.fit_content = true
	tooltip_text.custom_minimum_size = Vector2(340, 0)
	tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text.add_theme_font_size_override("normal_font_size", 15)
	tooltip.add_child(tooltip_text)
	add_child(tooltip)
	tooltip.visible = false
	panel.visible = false
	# Anteprima 3D dell'eroe con l'equipaggiamento, a sinistra del pannello (come in D3)
	preview = CharacterPreview.new()
	preview.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	preview.offset_left = -560 - 270
	preview.offset_right = -566
	preview.offset_top = 10
	preview.offset_bottom = 380
	preview.visible = false
	add_child(preview)


func bind(p: Player) -> void:
	player = p
	p.inventory_changed.connect(refresh)
	p.xp_changed.connect(func(_a: int, _b: int, _c: int) -> void: refresh())


func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	preview.visible = is_open and (trade == null or not trade.is_open)
	_hide_tooltip()
	if is_open:
		refresh()
		if player and player.using_pad:
			(bag_buttons[0] as Button).grab_focus()
	elif get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_get_focus_owner().release_focus()


func open() -> void:
	if not is_open:
		toggle()
	else:
		refresh()


func close() -> void:
	if is_open:
		toggle()


func _process(_delta: float) -> void:
	if tooltip.visible:
		var mp := get_viewport().get_mouse_position()
		if _pad_anchor != null and is_instance_valid(_pad_anchor) and _pad_anchor.has_focus():
			mp = _pad_anchor.global_position + Vector2(0, _pad_anchor.size.y)
		var vs := get_viewport().get_visible_rect().size
		var pos := mp + Vector2(-tooltip.size.x - 20, 16)
		if _tooltip_right:
			pos.x = mp.x + 24.0
		pos.x = clampf(pos.x, 8.0, vs.x - tooltip.size.x - 8.0)
		pos.y = clampf(pos.y, 8.0, vs.y - tooltip.size.y - 8.0)
		tooltip.position = pos


func refresh() -> void:
	if player == null:
		return
	var h := player.hero
	title_label.text = "%s - %s livello %d" % [h.hero_name, player.cls["name"], h.level]
	gold_label.text = "%d sesterzi" % h.gold
	var m := ""
	for id: String in ItemDB.MATERIALS:
		m += "%s: %d    " % [ItemDB.MATERIALS[id]["name"], h.material(id)]
	var ng := 0
	for k: String in h.gems:
		ng += h.gem_count(k)
	if ng > 0:
		m += "Gemme: %d" % ng
	mats_label.text = m
	var hint := "Clic: equipaggia / togli    Ctrl+clic: secondo anello / arma nella mano sinistra    Shift+clic: getta a terra"
	if trade != null and trade.is_open:
		hint = "Clic destro: %s    Clic: equipaggia    I / C: chiudi" % {"vendor": "VENDI", "stash": "DEPOSITA"}.get(trade.mode, "SMONTA")
	hint_label.text = hint
	for slot: String in equip_buttons:
		var it: Item = h.equipment.get(slot)
		paint_slot(equip_buttons[slot], it, Item.SLOT_NAMES[slot], it == null or h.can_equip(it))
	for i in bag_buttons.size():
		var it: Item = h.inventory[i]
		paint_slot(bag_buttons[i], it, "", it == null or h.can_equip(it))
	_refresh_stats()
	if preview.visible:
		preview.show_hero(h)


const SORT_ORDER := ["arma", "secondaria", "elmo", "spalle", "armatura", "guanti", "bracciali", "cintura", "gambali",
	"calzari", "amuleto", "anello"]


## Zaino in ordine: per tipo (armi prima), poi rarità e livello più alti.
func sort_bag() -> void:
	var h := player.hero
	var items: Array = []
	for it: Variant in h.inventory:
		if it != null:
			items.append(it)
	var order: Array = SORT_ORDER
	items.sort_custom(func(a: Item, b: Item) -> bool:
		var sa := order.find(a.slot)
		var sb := order.find(b.slot)
		if sa != sb:
			return sa < sb
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.ilvl > b.ilvl)
	for i in h.inventory.size():
		h.inventory[i] = items[i] if i < items.size() else null


func _refresh_stats() -> void:
	var s := player.stats
	var main := String(player.cls["main_stat"])
	var t := "[color=#c8a050]Statistiche[/color]\n"
	for k: String in HeroClasses.STAT_NAMES:
		var mark := " ★" if k == main else ""
		t += "%s: [b]%d[/b]%s    " % [HeroClasses.STAT_NAMES[k], roundi(s[k]), mark]
	var armor_dr := float(s["armor"]) / (float(s["armor"]) + 50.0 * player.hero.level) * 100.0
	t += "\nDanno al secondo: [b]%.1f[/b]    Danno arma: %d-%d\n" % [s["dps"], roundi(s["weapon_min"]), roundi(s["weapon_max"])]
	t += "Vita: [b]%d[/b]    Armatura: %d (-%d%% danni)\n" % [roundi(s["max_life"]), roundi(s["armor"]), roundi(armor_dr)]
	t += "Critico: %.1f%%  (+%d%% danno)    Attacchi/s: %.2f\n" % [s["crit_chance"], roundi(s["crit_damage"]), s["aps"]]
	t += "Rigenerazione: %.1f/s    Vita per colpo: %d    Movimento: +%d%%" % [s["life_regen"], roundi(s["life_on_hit"]), roundi(s["move_speed_pct"])]
	if details:
		t += "\n\n[color=#c8a050]Dettagli[/color]\n"
		var rows := [
			["Danni bonus", "+%d%%" % roundi(s["damage_pct"])],
			["Riduzione ricariche", "%d%%" % roundi(minf(s["cdr_pct"], 40.0))],
			["Riduzione danni (passive)", "%d%%" % roundi(s.get("dr_pct", 0.0))],
			["Danno medio per colpo", "%.1f" % float(s["damage_avg"])],
			["%s: massimo" % player.cls["resource"], "%d" % roundi(s["resource_max"])],
			["%s: rigenerazione" % player.cls["resource"], "%.1f/s" % float(s["resource_regen"])],
			["Sesterzi trovati", "+%d%%" % roundi(s["gold_find"])],
			["Velocità di movimento", "%.1f m/s" % float(s["move_speed"])],
			["Difficoltà", DifficultyDB.level_name(player.hero.difficulty)],
			["Labirinto: grado sbloccato", "%d" % int(player.hero.flags.get("rift_max", 1))],
		]
		for sid: String in ItemDB.set_counts(player.hero.equipment):
			rows.append([ItemDB.SETS[sid]["name"], "%d pezzi" % int(ItemDB.set_counts(player.hero.equipment)[sid])])
		for pw: String in player.powers:
			rows.append(["Potere", ItemDB.POWERS.get(pw, pw)])
		for r: Array in rows:
			t += "%s: [b]%s[/b]\n" % r
	stats_label.text = t


static func paint_slot(b: Button, it: Item, empty_text: String, usable: bool = true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.25, 0.18)
	if it != null:
		sb.border_color = it.color()
		sb.bg_color = it.color().darkened(0.82)
		if not usable:
			sb.bg_color = Color(0.3, 0.05, 0.05)
		b.text = it.short_label() if b.custom_minimum_size.x < 100 else it.item_name
		if Settings.colorblind:
			b.text = "[%s] %s" % [it.rarity_letter(), b.text]
		if it.is_new:
			b.text = "✦ " + b.text
			sb.border_color = Color(1.0, 0.95, 0.6)
		b.add_theme_color_override("font_color", it.color())
		b.add_theme_color_override("font_hover_color", it.color().lightened(0.3))
	else:
		b.text = empty_text
		b.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)


## Controller: il tooltip segue la casella selezionata invece del mouse.
var _pad_anchor: Control = null


func _on_focus(b: Control, show: Callable) -> void:
	if Input.get_connected_joypads().is_empty() and not (player and player.using_pad):
		return
	_pad_anchor = b
	show.call()


func _on_bag_input(event: InputEvent, index: int) -> void:
	# Controller: A = equipaggia, Y = come il clic destro (vendi / smonta / deposita), B esce dal pannello
	if event is InputEventJoypadButton and event.pressed:
		var it0: Item = player.hero.inventory[index]
		var jb := (event as InputEventJoypadButton).button_index
		if it0 != null and jb == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			if player.hero.can_equip(it0):
				player.hero.equip_from_inventory(index)
				player.refresh_stats()
				player.inventory_changed.emit()
		elif it0 != null and jb == JOY_BUTTON_Y and trade != null and trade.is_open:
			get_viewport().set_input_as_handled()
			trade.on_bag_right_click(index)
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var h := player.hero
	var it: Item = h.inventory[index]
	if it == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and trade != null and trade.is_open:
		_hide_tooltip()
		trade.on_bag_right_click(index)
		return
	if mb.shift_pressed:
		h.inventory[index] = null
		Loot.spawn_item(it, player.global_position)
	elif not h.can_equip(it):
		Game.level.hud.show_warning("Il %s non può usare questo oggetto" % player.cls["name"])
		return
	else:
		h.equip_from_inventory(index, mb.ctrl_pressed)
		player.refresh_stats()
	_hide_tooltip()
	player.inventory_changed.emit()


func _on_equip_input(event: InputEvent, slot: String) -> void:
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		get_viewport().set_input_as_handled()
		if player.hero.equipment.has(slot) and player.hero.unequip(slot):
			player.refresh_stats()
			player.inventory_changed.emit()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not player.hero.equipment.has(slot):
		return
	if player.hero.unequip(slot):
		player.refresh_stats()
		_hide_tooltip()
		player.inventory_changed.emit()
	else:
		Game.level.hud.show_warning("Inventario pieno")


func _on_hover_bag(index: int) -> void:
	var it: Item = player.hero.inventory[index]
	if it == null:
		return
	if it.is_new:
		it.is_new = false
		paint_slot(bag_buttons[index], it, "", player.hero.can_equip(it))
	var equipped: Item = player.hero.equipment.get(player.hero.target_slot(it))
	var t := it.tooltip_bbcode(equipped, player.hero.can_equip(it))
	# Shift: mostra anche il tooltip completo di ciò che indossi (entrambi gli anelli / le mani)
	if Input.is_key_pressed(KEY_SHIFT):
		var worn_slots: Array = ["anello", "anello2"] if it.slot == "anello" else [player.hero.target_slot(it)]
		if it.slot == "arma" and player.hero.can_dual_wield(it):
			worn_slots.append("secondaria")
		for ws: String in worn_slots:
			var w: Item = player.hero.equipment.get(ws)
			if w != null:
				t += "\n\n[color=#999999]──── Indossato (%s) ────[/color]\n" % Item.SLOT_NAMES[ws] + w.tooltip_bbcode()
	else:
		t += "\n[color=#777777]Tieni premuto Shift per il confronto completo[/color]"
	if trade != null and trade.is_open:
		if trade.mode == "vendor":
			t += "\n[color=#f2c75a]Valore: %d sesterzi (clic destro per vendere)[/color]" % ItemDB.sell_value(it)
		elif trade.mode == "smith":
			t += "\n[color=#f2c75a]Clic destro per smontare[/color]"
		else:
			t += "\n[color=#f2c75a]Clic destro per depositare nel forziere[/color]"
	_show_tooltip(t)


func _on_hover_equip(slot: String) -> void:
	var it: Item = player.hero.equipment.get(slot)
	if it != null:
		_show_tooltip("[color=#999999]Equipaggiato[/color]\n" + it.tooltip_bbcode())


func _show_tooltip(text: String) -> void:
	show_tooltip(text, false)


## Tooltip condiviso (usato anche dal negozio). right_side = a destra del mouse.
func show_tooltip(text: String, right_side: bool = false) -> void:
	_tooltip_right = right_side
	tooltip_text.text = text
	tooltip.reset_size()
	tooltip.visible = true


func _hide_tooltip() -> void:
	tooltip.visible = false


func hide_tooltip() -> void:
	tooltip.visible = false


static func make_slot_button(min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL   # navigabile col controller
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	return b


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
