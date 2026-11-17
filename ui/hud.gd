class_name Hud
extends CanvasLayer
## Interfaccia di gioco stile Diablo: globi vita/risorsa, barra abilità + pozione, esperienza,
## riquadro del bersaglio, minimappa, messaggi, raccolta oggetti, pannelli morte/storia/fine livello.

const GOLD := Color(0.95, 0.78, 0.35)

var player: Player
var level: Level
var life_globe: Globe
var res_globe: Globe
var slots: Dictionary = {}
var potion_slot: SkillSlot
var xp_bar: ProgressBar
var xp_label: Label
var target_box: PanelContainer
var target_name: Label
var target_bar: ProgressBar
var _target: Enemy = null
var _target_timer := 0.0
var minimap: Minimap
var area_label: Label
var banner: Label
var message: Label
var warning: Label
var hover_label: Label
var pickup_log: VBoxContainer
var death_panel: Control
var lore_panel: Control
var lore_title: Label
var lore_text: RichTextLabel
var end_panel: Control
var end_title: Label
var end_text: Label
var waypoint_panel: Control
var waypoint_list: VBoxContainer
var cast_bar: ProgressBar
var cast_label: Label
var quest_tracker: RichTextLabel
var quest_log: Control
var quest_log_text: RichTextLabel
var choice_panel: Control
var choice_title: Label
var choice_body: Label
var choice_list: VBoxContainer
var rift_box: PanelContainer
var rift_label: Label
var rift_bar: ProgressBar
var event_box: PanelContainer
var event_label: Label
var buff_label: Label
var _pad_glyphs := false
var boss_box: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar
var _banner_t := 0.0
var _msg_t := 0.0
var _warn_t := 0.0


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Barra in basso ---
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -430
	bottom.offset_right = 430
	bottom.offset_top = -150
	bottom.offset_bottom = -6
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	life_globe = Globe.new()
	life_globe.custom_minimum_size = Vector2(140, 140)
	life_globe.fill_color = Color(0.75, 0.06, 0.08)
	life_globe.caption = "Vita"
	life_globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(life_globe)

	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_END
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(mid)
	xp_label = _label(13, Color(0.9, 0.85, 0.6))
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(xp_label)
	xp_bar = _bar(Color(0.85, 0.65, 0.2), Vector2(520, 8))
	mid.add_child(xp_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(row)
	potion_slot = SkillSlot.new()
	potion_slot.set_ability({"name": "Pozione", "color": Color(0.9, 0.15, 0.2), "desc": "Cura il 60% della vita. Ricarica 30 s."}, "Q")
	potion_slot.label_override = "POZ"
	row.add_child(potion_slot)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(10, 0)
	row.add_child(sep)
	for s: String in HeroClasses.SLOT_ORDER:
		var sl := SkillSlot.new()
		row.add_child(sl)
		slots[s] = sl

	res_globe = Globe.new()
	res_globe.custom_minimum_size = Vector2(140, 140)
	res_globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(res_globe)

	# --- Bersaglio in alto ---
	target_box = PanelContainer.new()
	target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_box.offset_left = -220
	target_box.offset_right = 220
	target_box.offset_top = 10
	target_box.add_theme_stylebox_override("panel", _panel_style(0.6))
	target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := VBoxContainer.new()
	target_box.add_child(tv)
	target_name = _label(18, Color.WHITE)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(target_name)
	target_bar = _bar(Color(0.8, 0.1, 0.1), Vector2(420, 14))
	tv.add_child(target_bar)
	target_box.visible = false
	root.add_child(target_box)

	# --- Barra del boss (in alto, grande) ---
	boss_box = PanelContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -330
	boss_box.offset_right = 330
	boss_box.offset_top = 8
	boss_box.add_theme_stylebox_override("panel", _panel_style(0.7))
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bv := VBoxContainer.new()
	boss_box.add_child(bv)
	boss_name = _label(22, Color(1.0, 0.6, 0.15))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(boss_name)
	boss_bar = _bar(Color(0.85, 0.35, 0.05), Vector2(620, 22))
	bv.add_child(boss_bar)
	boss_box.visible = false
	root.add_child(boss_box)

	# --- Labirinto di Dedalo: tempo e avanzamento ---
	rift_box = PanelContainer.new()
	rift_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rift_box.offset_left = 14
	rift_box.offset_top = 14
	rift_box.add_theme_stylebox_override("panel", _panel_style(0.65))
	rift_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rv := VBoxContainer.new()
	rift_box.add_child(rv)
	rift_label = _label(16, Color(0.85, 0.7, 1.0))
	rv.add_child(rift_label)
	rift_bar = _bar(Color(0.6, 0.3, 1.0), Vector2(300, 14))
	rv.add_child(rift_bar)
	rift_box.visible = false
	root.add_child(rift_box)

	# --- Evento in corso ---
	event_box = PanelContainer.new()
	event_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	event_box.offset_left = -230
	event_box.offset_right = 230
	event_box.offset_top = 150
	event_box.add_theme_stylebox_override("panel", _panel_style(0.6))
	event_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_label = _label(17, Color(1.0, 0.6, 0.95))
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_box.add_child(event_label)
	event_box.visible = false
	root.add_child(event_box)

	# --- Potenziamenti attivi (santuari, piloni, abilità), sopra la barra ---
	buff_label = _label(15, Color(0.9, 0.95, 1.0))
	buff_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buff_label.offset_left = -400
	buff_label.offset_right = 400
	buff_label.offset_top = -180
	buff_label.offset_bottom = -156
	buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(buff_label)

	# --- Minimappa ---
	minimap = Minimap.new()
	root.add_child(minimap)
	area_label = _label(16, GOLD)
	area_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	area_label.offset_left = -260
	area_label.offset_right = -14
	area_label.offset_top = 250
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(area_label)

	# --- Messaggi ---
	banner = _label(46, GOLD)
	_center(banner, -260, 80)
	root.add_child(banner)
	message = _label(28, Color(1, 0.92, 0.7))
	_center(message, -170, 90)
	root.add_child(message)
	warning = _label(20, Color(1, 0.45, 0.4))
	_center(warning, 170, 40)
	root.add_child(warning)
	hover_label = _label(16, Color.WHITE)
	hover_label.visible = false
	root.add_child(hover_label)

	pickup_log = VBoxContainer.new()
	pickup_log.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pickup_log.offset_left = -360
	pickup_log.offset_right = -20
	pickup_log.offset_top = -40
	pickup_log.offset_bottom = 160
	pickup_log.alignment = BoxContainer.ALIGNMENT_END
	pickup_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pickup_log)

	# --- Pannelli ---
	death_panel = _make_panel(root, "SEI CADUTO", "Gli dèi ti concedono un'altra possibilità.",
		[["Risorgi all'ultimo altare", func() -> void: level.respawn_player()]])
	var lp := _make_panel(root, "", "", [["Chiudi", func() -> void: lore_panel.visible = false]])
	lore_panel = lp
	lore_title = lp.find_child("Title", true, false)
	var body := lp.find_child("Body", true, false) as Label
	lore_text = RichTextLabel.new()
	lore_text.bbcode_enabled = true
	lore_text.fit_content = true
	lore_text.custom_minimum_size = Vector2(520, 0)
	lore_text.add_theme_font_size_override("normal_font_size", 18)
	body.get_parent().add_child(lore_text)
	body.get_parent().move_child(lore_text, body.get_index())
	body.queue_free()
	end_panel = _make_panel(root, "", "", [
		["Continua a esplorare", func() -> void: end_panel.visible = false],
		["Salva e torna al menu", func() -> void: Game.quit_to_menu(true)],
	])
	end_title = end_panel.find_child("Title", true, false)
	end_text = end_panel.find_child("Body", true, false)
	waypoint_panel = _make_panel(root, "Viaggio rapido", "Scegli un altare già attivato.",
		[["Chiudi", func() -> void: waypoint_panel.visible = false]])
	waypoint_list = VBoxContainer.new()
	waypoint_list.add_theme_constant_override("separation", 6)
	var wbody := waypoint_panel.find_child("Body", true, false) as Label
	wbody.get_parent().add_child(waypoint_list)
	wbody.get_parent().move_child(waypoint_list, wbody.get_index() + 1)
	choice_panel = _make_panel(root, "", "", [])
	choice_title = choice_panel.find_child("Title", true, false)
	choice_body = choice_panel.find_child("Body", true, false)
	choice_list = VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 6)
	choice_list.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_body.get_parent().add_child(choice_list)
	choice_body.get_parent().move_child(choice_list, choice_body.get_index() + 1)

	# --- Missioni: elenco a sinistra e diario (J) ---
	quest_tracker = RichTextLabel.new()
	quest_tracker.bbcode_enabled = true
	quest_tracker.fit_content = true
	quest_tracker.scroll_active = false
	quest_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker.offset_left = 16
	quest_tracker.offset_top = 16
	quest_tracker.custom_minimum_size = Vector2(360, 0)
	quest_tracker.add_theme_font_size_override("normal_font_size", 15)
	quest_tracker.add_theme_font_size_override("bold_font_size", 17)
	quest_tracker.add_theme_constant_override("outline_size", 5)
	quest_tracker.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(quest_tracker)
	quest_log = _make_panel(root, "Diario delle missioni", "", [["Chiudi", func() -> void: quest_log.visible = false]])
	var qbody := quest_log.find_child("Body", true, false) as Label
	quest_log_text = RichTextLabel.new()
	quest_log_text.bbcode_enabled = true
	quest_log_text.fit_content = true
	quest_log_text.custom_minimum_size = Vector2(620, 0)
	quest_log_text.add_theme_font_size_override("normal_font_size", 16)
	qbody.get_parent().add_child(quest_log_text)
	qbody.get_parent().move_child(quest_log_text, qbody.get_index())
	qbody.queue_free()
	Game.quests_changed.connect(update_quests)

	# --- Barra di canalizzazione (portale cittadino) ---
	var cast_box := VBoxContainer.new()
	cast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cast_box.offset_left = -160
	cast_box.offset_right = 160
	cast_box.offset_top = -230
	cast_box.offset_bottom = -190
	cast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cast_box)
	cast_label = _label(15, Color(0.7, 0.85, 1.0))
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_label.text = "Portale verso %s" % Game.level_title(Game.HUB)
	cast_box.add_child(cast_label)
	cast_bar = _bar(Color(0.35, 0.65, 1.0), Vector2(320, 12))
	cast_box.add_child(cast_bar)
	cast_box.visible = false
	cast_bar.set_meta("box", cast_box)


func bind(p: Player, l: Level) -> void:
	player = p
	level = l
	minimap.target = p
	area_label.text = l.level_title
	res_globe.fill_color = p.cls["resource_color"]
	res_globe.caption = p.cls["resource"]
	_bind_slots()
	p.abilities_changed.connect(_bind_slots)
	p.xp_changed.connect(func(_a: int, _b: int, _c: int) -> void: _update_xp())
	_update_xp()
	update_quests()


## Pulsanti del controller mostrati sulla barra quando si gioca col controller.
const PAD_KEYS := {"lmb": "A", "rmb": "X", "1": "Y", "2": "B", "3": "LB", "4": "RB"}


func _bind_slots() -> void:
	_pad_glyphs = player.using_pad
	for s: String in slots:
		var ab: Dictionary = player.abilities.get(s, {})
		(slots[s] as SkillSlot).set_ability(ab, PAD_KEYS[s] if _pad_glyphs else HeroClasses.SLOT_KEYS[s])
	potion_slot.key_text = "RT" if _pad_glyphs else "Q"


## Suggerimento mostrato una sola volta per eroe (primi minuti di gioco).
func hint(id: String, text: String) -> void:
	if Game.hero == null or Game.hero.flags.has("hint_" + id):
		return
	Game.hero.flags["hint_" + id] = true
	show_message("Suggerimento: " + text, 6.0)


func set_event(title: String, objective: String) -> void:
	event_box.visible = true
	event_label.text = "%s\n%s" % [title, objective]


func clear_event() -> void:
	event_box.visible = false


func _update_xp() -> void:
	var need := HeroData.xp_to_next(player.hero.level)
	xp_bar.max_value = need
	xp_bar.value = player.hero.xp
	xp_label.text = "%s - %s livello %d   (%d / %d PE)" % [player.hero.hero_name, player.cls["name"], player.hero.level, player.hero.xp, need]


func _process(delta: float) -> void:
	if player == null:
		return
	life_globe.value = player.life
	life_globe.max_value = player.stats["max_life"]
	res_globe.value = player.resource
	res_globe.max_value = player.stats["resource_max"]
	for s: String in slots:
		var sl: SkillSlot = slots[s]
		var ab := sl.ability
		if ab.is_empty():
			continue
		sl.locked = not player.is_unlocked(ab)
		sl.cd_left = player.cooldown_left(ab)
		sl.cd_total = maxf(float(ab.get("cooldown", 1.0)), 0.01)
		sl.unaffordable = player.resource < float(ab.get("cost", 0.0))
	if player.using_pad != _pad_glyphs:
		_bind_slots()
	var bt: Array = []
	for b: Dictionary in player.buffs:
		if String(b.get("name", "")) != "":
			bt.append("%s %d s" % [b["name"], ceili(float(b["time"]))])
	buff_label.text = "   ".join(bt)
	potion_slot.cd_left = maxf(player.potion_cd, 0.0)
	potion_slot.cd_total = player.potion_cooldown()
	var cast_box: Control = cast_bar.get_meta("box")
	cast_box.visible = player.portal_t > 0.0
	if cast_box.visible:
		cast_bar.max_value = Player.PORTAL_TIME
		cast_bar.value = Player.PORTAL_TIME - player.portal_t

	# Bersaglio: il nemico sotto il cursore, altrimenti l'ultimo colpito
	var t: Enemy = null
	if level.hover["kind"] == "enemy":
		t = level.hover["node"]
	elif _target != null and is_instance_valid(_target) and not _target.dead and _target_timer > 0.0:
		t = _target
	_target_timer -= delta
	# Barra del boss: un nemico unico che ti ha notato, entro 45 m
	var boss: Enemy = _active_boss()
	boss_box.visible = boss != null
	if boss != null:
		boss_name.text = boss.display_name
		boss_bar.max_value = boss.max_life
		boss_bar.value = boss.life
		if t == boss:
			t = null
	target_box.offset_top = 86 if boss != null else 10
	target_box.visible = t != null
	if t != null:
		var txt := t.display_name + ("   (liv. %d)" % t.level)
		if not t.affixes.is_empty():
			txt += "\n" + t.affix_text()
		target_name.text = txt
		target_name.add_theme_color_override("font_color", t.name_color())
		if t.elite and not t.affixes.is_empty():
			hint("elite", "le elite hanno affissi (scritti sotto il nome): Scudato è invulnerabile a tratti, Incendiario lascia fuoco a terra...")
		target_bar.max_value = t.max_life
		target_bar.value = t.life
	_update_rift()

	# Etichetta sotto il cursore per oggetti interagibili
	if level.hover["kind"] == "interact" and is_instance_valid(level.hover["node"]):
		var n: Node = level.hover["node"]
		hover_label.text = n.interact_name() if n.has_method("interact_name") else n.name
		hover_label.position = get_viewport().get_mouse_position() + Vector2(18, 14)
		hover_label.visible = true
	else:
		hover_label.visible = false

	_banner_t -= delta
	banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_msg_t -= delta
	message.modulate.a = clampf(_msg_t, 0.0, 1.0)
	_warn_t -= delta
	warning.modulate.a = clampf(_warn_t * 2.0, 0.0, 1.0)


func _active_boss() -> Enemy:
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.unique and not e.dead and e.state != Enemy.State.IDLE and e.global_position.distance_to(player.global_position) < 45.0:
			return e
	return null


func _update_rift() -> void:
	var grade := int(level.rift_grade)
	rift_box.visible = grade > 0
	if grade <= 0:
		return
	var t := float(level.get("rift_time"))
	var lim := DifficultyDB.RIFT_TIME
	var txt := "Labirinto grado %d   %02d:%02d / %02d:00" % [grade, int(t) / 60, int(t) % 60, int(lim / 60.0)]
	if bool(level.get("rift_done")):
		txt += "\nCompletato!"
	elif bool(level.get("guardian_spawned")):
		txt += "\nIl Guardiano è arrivato"
	rift_label.text = txt
	rift_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if t > lim else Color(0.85, 0.7, 1.0))
	rift_bar.max_value = maxf(float(level.get("rift_target")), 1.0)
	rift_bar.value = float(level.get("rift_progress"))


## Pannello con una scelta tra più opzioni: options = [[testo, Callable], ...] (+ "Annulla").
func show_choice(title: String, body: String, options: Array) -> void:
	choice_title.text = title
	choice_body.text = body
	for c in choice_list.get_children():
		c.queue_free()
	var first: Button = null
	for o: Array in options:
		var b := Button.new()
		b.text = String(o[0])
		b.custom_minimum_size = Vector2(360, 38)
		b.disabled = o.size() > 2 and bool(o[2])
		b.pressed.connect(o[1])
		choice_list.add_child(b)
		if first == null and not b.disabled:
			first = b
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.custom_minimum_size = Vector2(360, 38)
	cancel.pressed.connect(hide_choice)
	choice_list.add_child(cancel)
	choice_panel.visible = true
	if first != null:
		first.grab_focus()


func hide_choice() -> void:
	choice_panel.visible = false


func set_target(e: Enemy) -> void:
	_target = e
	_target_timer = 3.0


func show_banner(text: String) -> void:
	banner.text = text
	_banner_t = 3.5


func show_message(text: String, duration: float = 2.5) -> void:
	message.text = text
	_msg_t = duration


func show_warning(text: String) -> void:
	warning.text = text
	_warn_t = 1.6


func log_pickup(text: String, col: Color) -> void:
	var l := _label(17, col)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pickup_log.add_child(l)
	if pickup_log.get_child_count() > 6:
		pickup_log.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func show_death(recap: String = "") -> void:
	(death_panel.find_child("Body", true, false) as Label).text = "Gli dèi ti concedono un'altra possibilità.\n\n" + recap
	death_panel.visible = true


## Morte in hardcore: niente rinascita.
func show_hardcore_death(text: String) -> void:
	show_choice("CADUTO PER SEMPRE", text, [["Torna al menu", func() -> void: Game.quit_to_menu(false)]])
	for c in choice_list.get_children():
		if c is Button and (c as Button).text == "Annulla":
			c.queue_free()


func hide_death() -> void:
	death_panel.visible = false


func show_lore(title: String, text: String) -> void:
	lore_title.text = title
	lore_text.text = text
	lore_panel.visible = true


## Missioni attive in alto a sinistra (obiettivo corrente).
func update_quests() -> void:
	if Game.hero == null:
		return
	var t := ""
	for id: String in Quests.active_ids():
		var q := QuestDB.get_data(id)
		t += "[b][color=#f2c75a]%s[/color][/b]\n[color=#e8e0d0]• %s[/color]\n" % [q["title"], Quests.step_text(id)]
	var bl: Array = Bounties.tracker_lines()
	if not bl.is_empty():
		t += "[b][color=#f2c75a]Taglie[/color][/b]\n"
		for line: String in bl:
			t += "[color=#e8e0d0]• %s[/color]\n" % line
	if t != "":
		t += "[color=#888888][font_size=12]J: diario delle missioni[/font_size][/color]"
	quest_tracker.text = t
	if quest_log.visible:
		_fill_quest_log()


func toggle_quest_log() -> void:
	quest_log.visible = not quest_log.visible
	if quest_log.visible:
		_fill_quest_log()


func _fill_quest_log() -> void:
	var active := ""
	var done := ""
	for id: String in QuestDB.ORDER:
		var q := QuestDB.get_data(id)
		match Quests.state(id):
			"active":
				active += "[b][color=#f2c75a]%s[/color][/b]  [color=#888888](atto %d)[/color]\n%s\n[color=#9fd0ff]Obiettivo: %s[/color]\n\n" % [
					q["title"], int(q.get("act", 1)), q.get("desc", ""), Quests.step_text(id)]
			"done":
				done += "[color=#8a8a8a]✔ %s[/color]\n" % q["title"]
	var t := "[font_size=19][color=#c8a050]In corso[/color][/font_size]\n" + (active if active != "" else "Nessuna missione in corso.\n\n")
	if done != "":
		t += "[font_size=19][color=#c8a050]Completate[/color][/font_size]\n" + done
	quest_log_text.text = t


## Elenco degli altari attivati, raggruppati per livello (viaggio rapido).
func show_waypoints(current_id: String = "") -> void:
	for c in waypoint_list.get_children():
		c.queue_free()
	var wps: Dictionary = Game.hero.waypoints
	for lvl: String in Game.LEVEL_TITLES:
		var ids: Array = []
		for id: String in wps:
			if String(wps[id]["level"]) == lvl:
				ids.append(id)
		if ids.is_empty():
			continue
		var head := _label(18, GOLD)
		head.text = Game.level_title(lvl)
		waypoint_list.add_child(head)
		for id: String in ids:
			var b := Button.new()
			b.text = String(wps[id]["title"]) + ("   (sei qui)" if id == current_id else "")
			b.disabled = id == current_id
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(360, 36)
			b.pressed.connect(func() -> void: level.travel_to_waypoint(id))
			waypoint_list.add_child(b)
	waypoint_panel.visible = true


func show_end(title: String, text: String) -> void:
	end_title.text = title
	end_text.text = text
	end_panel.visible = true


# --- Helper di costruzione ----------------------------------------------------------------

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	bg.border_color = Color(0.6, 0.48, 0.25, 0.8)
	bg.set_border_width_all(1)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


func _center(l: Label, y: float, h: float) -> void:
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -700
	l.offset_right = 700
	l.offset_top = y
	l.offset_bottom = y + h
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0


static func _panel_style(alpha: float = 0.92) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.04, alpha)
	sb.border_color = Color(0.6, 0.48, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	return sb


func _make_panel(root: Control, title: String, body: String, buttons: Array) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := _label(34, GOLD)
	t.name = "Title"
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _label(18, Color(0.9, 0.88, 0.8))
	b.name = "Body"
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(520, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	for pair: Array in buttons:
		var btn := Button.new()
		btn.text = pair[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(pair[1])
		hb.add_child(btn)
	center.visible = false
	return center
