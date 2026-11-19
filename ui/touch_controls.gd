class_name TouchControls
extends CanvasLayer
## Controlli a video per gli schermi touch (telefoni e tablet Android), stile ARPG per cellulari:
## - joystick "mobile" in basso a sinistra (compare dove appoggi il dito);
## - pulsante grande d'attacco in basso a destra (tieni premuto per continuare ad attaccare; vicino a
##   NPC/forzieri/altari interagisce), con attorno pozione e abilità (clic destro, 1-4);
## - abilità: tocca = mira automatica (come col controller), trascina = mira a mano con un anello a terra
##   (direzione e distanza del trascinamento = direzione e distanza del colpo);
## - colonna di pulsanti a sinistra: zaino, abilità, mappa, diario, portale, menu.
## Multi-touch: ogni dito è seguito col suo indice. Toccare il mondo fuori dai pulsanti funziona come il
## clic del mouse (Godot emula il mouse dal primo dito): si cammina, si attacca, si parla con gli NPC.
## Visibili se Settings.touch_enabled() (Opzioni > Gioco).

const STICK_ZONE_W := 0.3      # frazione della larghezza (da sinistra) dove nasce il joystick
const STICK_ZONE_TOP := 0.45   # frazione dell'altezza da cui parte la zona del joystick
const STICK_RADIUS := 85.0
const ATTACK_RADIUS := 66.0
const BUTTON_RADIUS := 38.0
const ARC_RADIUS := 215.0
const MENU_SIZE := 58.0
const AIM_DEADZONE := 26.0     # trascinamento minimo per mirare a mano
const AIM_FULL := 170.0        # trascinamento per la portata massima
## Pulsanti dei menu: [azione, sigla].
const MENU := [["inventory", "Zaino"], ["skills", "Abil."], ["map", "Mappa"], ["quest_log", "Diario"],
	["town_portal", "Portale"], ["pause", "Menu"]]
## Pulsanti attorno all'attacco, dall'orizzontale (sinistra) verso l'alto e a destra.
const ARC := ["potion", "rmb", "1", "2", "3", "4"]

var player: Player
var level: Level
var root: Control
## Pulsanti: {kind: attack/skill/potion/menu, id (tasto o azione), label, center, radius, blocker, show}
var buttons: Array[Dictionary] = []
var _stick_zone: Control
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
## indice del dito -> {button, start, pos}
var _fingers: Dictionary = {}
var _aim_ring: MeshInstance3D
var _size := Vector2.ZERO
var _gameplay := false
var _menu := false


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_controls)
	add_child(root)
	# Zona del joystick: blocca il clic emulato dal tocco (altrimenti l'eroe camminerebbe lì)
	_stick_zone = _blocker()
	buttons.append({"kind": "attack", "id": "lmb", "label": "", "radius": ATTACK_RADIUS})
	for id: String in ARC:
		buttons.append({"kind": "potion" if id == "potion" else "skill", "id": id, "label": "POZ" if id == "potion" else "", "radius": BUTTON_RADIUS})
	for m: Array in MENU:
		buttons.append({"kind": "menu", "id": m[0], "label": m[1], "radius": MENU_SIZE * 0.5})
	for b: Dictionary in buttons:
		b["blocker"] = _blocker()
		b["center"] = Vector2.ZERO
		b["show"] = true


func bind(p: Player, l: Level) -> void:
	player = p
	level = l


func _blocker() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(c)
	return c


## Posizioni dei pulsanti (ricalcolate quando cambia la dimensione dello schermo).
func _layout() -> void:
	_size = root.size
	var w := _size.x
	var h := _size.y
	var attack_c := Vector2(w - 115.0, h - 115.0)
	var arc_i := 0
	var menu_i := 0
	for b: Dictionary in buttons:
		match String(b["kind"]):
			"attack":
				b["center"] = attack_c
			"skill", "potion":
				var ang := deg_to_rad(180.0 + 21.0 * arc_i)
				b["center"] = attack_c + Vector2(cos(ang), sin(ang)) * ARC_RADIUS
				arc_i += 1
			"menu":
				b["center"] = Vector2(14.0 + MENU_SIZE * 0.5, 200.0 + menu_i * (MENU_SIZE + 8.0))
				menu_i += 1
		var r: float = b["radius"]
		var bl: Control = b["blocker"]
		bl.position = Vector2(b["center"]) - Vector2(r, r)
		bl.size = Vector2(r, r) * 2.0
	_stick_zone.position = Vector2(0.0, h * STICK_ZONE_TOP)
	_stick_zone.size = Vector2(w * STICK_ZONE_W, h * (1.0 - STICK_ZONE_TOP))


func _process(_delta: float) -> void:
	if player == null or level == null:
		return
	var on := Settings.touch_enabled()
	var panels := level.any_panel_open()
	var gameplay := on and not panels and not player.dead
	# I menu restano anche con zaino/mappa/diario aperti (per chiuderli); non sopra negozi, abilità e pausa
	var menu := on and not player.dead and not (level.trade_ui.is_open or level.skills_ui.is_open \
		or level.pause_menu.root.visible or level.hud.death_panel.visible or level.hud.choice_panel.visible)
	if gameplay != _gameplay or menu != _menu:
		_gameplay = gameplay
		_menu = menu
		if not gameplay:
			_release_all()
	visible = on
	level.hud.quest_tracker.offset_left = 16.0 + (MENU_SIZE + 14.0 if on else 0.0)
	if root.size != _size:
		_layout()
	_stick_zone.visible = _gameplay
	for b: Dictionary in buttons:
		var show := _menu if b["kind"] == "menu" else _gameplay
		if b["kind"] == "skill" and player.abilities.get(b["id"], {}).is_empty():
			show = false
		b["show"] = show
		(b["blocker"] as Control).visible = show
	root.queue_redraw()


# --- Input ------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var p := _to_canvas(t.position)
		if t.pressed:
			if _touch_down(t.index, p):
				get_viewport().set_input_as_handled()
		elif _touch_up(t.index, p):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touch_move(d.index, _to_canvas(d.position)):
			get_viewport().set_input_as_handled()


## Posizione dell'evento -> coordinate dei pulsanti (tiene conto di scala dell'interfaccia e stretch).
func _to_canvas(p: Vector2) -> Vector2:
	return root.get_global_transform_with_canvas().affine_inverse() * p


func button_at(p: Vector2) -> Dictionary:
	for b: Dictionary in buttons:
		if b["show"] and p.distance_to(b["center"]) <= float(b["radius"]) * 1.15:
			return b
	return {}


func _touch_down(index: int, p: Vector2) -> bool:
	var b := button_at(p)
	if not b.is_empty():
		_fingers[index] = {"button": b, "start": b["center"], "pos": p}
		match String(b["kind"]):
			"attack":
				player.touch_attack = true
				player._pad_primary()
			"potion":
				player.use_potion()
			"menu":
				_send_action(String(b["id"]))
		return true
	if _gameplay and _stick_finger == -1 and Rect2(_stick_zone.position, _stick_zone.size).has_point(p):
		_stick_finger = index
		_stick_origin = p
		_stick_pos = p
		player.touch_move = Vector2.ZERO
		return true
	return false


func _touch_move(index: int, p: Vector2) -> bool:
	if index == _stick_finger:
		_stick_pos = p
		var off := p - _stick_origin
		if off.length() > STICK_RADIUS:   # il joystick segue il dito
			_stick_origin = p - off.normalized() * STICK_RADIUS
			off = p - _stick_origin
		player.touch_move = off / STICK_RADIUS
		return true
	if _fingers.has(index):
		var f: Dictionary = _fingers[index]
		f["pos"] = p
		var b: Dictionary = f["button"]
		if b["kind"] == "skill":
			_update_aim_ring(String(b["id"]), aim_vector(f))
		return true
	return false


func _touch_up(index: int, p: Vector2) -> bool:
	if index == _stick_finger:
		_stick_finger = -1
		player.touch_move = Vector2.ZERO
		return true
	if not _fingers.has(index):
		return false
	var f: Dictionary = _fingers[index]
	f["pos"] = p
	_fingers.erase(index)
	var b: Dictionary = f["button"]
	match String(b["kind"]):
		"attack":
			player.touch_attack = false
		"skill":
			_hide_aim_ring()
			if _gameplay:
				player.touch_cast(String(b["id"]), aim_vector(f))
	return true


## Trascinamento di un dito su un pulsante abilità: Vector2.ZERO = mira automatica, altrimenti 0..1.
func aim_vector(f: Dictionary) -> Vector2:
	var off: Vector2 = Vector2(f["pos"]) - Vector2(f["start"])
	if off.length() < AIM_DEADZONE:
		return Vector2.ZERO
	return off.limit_length(AIM_FULL) / AIM_FULL


func _release_all() -> void:
	_fingers.clear()
	_stick_finger = -1
	_hide_aim_ring()
	if player != null:
		player.touch_move = Vector2.ZERO
		player.touch_attack = false


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


# --- Anello di mira a terra ------------------------------------------------------------------------

func _update_aim_ring(slot: String, aim: Vector2) -> void:
	if aim == Vector2.ZERO:
		_hide_aim_ring()
		return
	if _aim_ring == null:
		_aim_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.85
		tm.outer_radius = 1.0
		tm.rings = 32
		_aim_ring.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.35, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_aim_ring.material_override = mat
		_aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(_aim_ring)
	var ab: Dictionary = player.abilities.get(slot, {})
	var r := clampf(float(ab.get("radius", 1.0)), 0.8, 8.0)
	var pt := player.touch_aim_point(slot, aim)
	_aim_ring.visible = true
	_aim_ring.global_position = Vector3(pt.x, 0.08, pt.z)
	_aim_ring.scale = Vector3(r, 1.0, r)


func _hide_aim_ring() -> void:
	if _aim_ring != null and is_instance_valid(_aim_ring):
		_aim_ring.visible = false


# --- Disegno --------------------------------------------------------------------------------------

func _draw_controls() -> void:
	if player == null:
		return
	var font := root.get_theme_default_font()
	if _gameplay and _stick_finger != -1:
		root.draw_circle(_stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.3))
		root.draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(0.95, 0.8, 0.45, 0.6), 3.0)
		root.draw_circle(_stick_origin + player.touch_move * STICK_RADIUS, 34.0, Color(0.95, 0.8, 0.45, 0.55))
	elif _gameplay:
		# Suggerimento discreto di dove nasce il joystick
		var c := Vector2(_size.x * STICK_ZONE_W * 0.5, _size.y - 130.0)
		root.draw_arc(c, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)
		root.draw_circle(c, 30.0, Color(1, 1, 1, 0.08))
	for b: Dictionary in buttons:
		if not b["show"]:
			continue
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var pressed := false
		for f: Dictionary in _fingers.values():
			if f["button"] == b:
				pressed = true
		var col := Color(0.6, 0.5, 0.3)
		var text := String(b["label"])
		var cd := 0.0
		var dim := false
		match String(b["kind"]):
			"attack", "skill":
				var ab: Dictionary = player.abilities.get(b["id"], {})
				col = ab.get("color", col)
				text = abbrev(ab)
				if b["kind"] == "skill":
					dim = not player.is_unlocked(ab) or player.resource < float(ab.get("cost", 0.0))
					var total := maxf(float(ab.get("cooldown", 0.0)), 0.01)
					cd = clampf(player.cooldown_left(ab) / total, 0.0, 1.0)
			"potion":
				col = Color(0.9, 0.15, 0.2)
				cd = clampf(player.potion_cd / maxf(player.potion_cooldown(), 0.01), 0.0, 1.0)
		root.draw_circle(c, r, Color(0.05, 0.04, 0.03, 0.55))
		root.draw_circle(c, r - 4.0, col.darkened(0.25 if pressed else 0.55) * Color(1, 1, 1, 0.8))
		if dim:
			root.draw_circle(c, r - 4.0, Color(0.1, 0.15, 0.5, 0.5))
		if cd > 0.0:
			_draw_pie(c, r - 4.0, cd, Color(0, 0, 0, 0.65))
		root.draw_arc(c, r, 0.0, TAU, 40, Color(0.85, 0.68, 0.32) if not pressed else Color(1, 0.95, 0.7), 2.5)
		var fs := 22 if b["kind"] == "attack" else (13 if b["kind"] == "menu" else 17)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := c + Vector2(-tw * 0.5, fs * 0.35)
		root.draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
		root.draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.5) if b["kind"] != "menu" else Color(1, 0.92, 0.7))


func _draw_pie(c: Vector2, r: float, frac: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(32 * frac))
	for i in steps + 1:
		var a := -PI * 0.5 + TAU * frac * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	root.draw_colored_polygon(pts, col)


## Sigla dell'abilità (come SkillSlot).
static func abbrev(ab: Dictionary) -> String:
	var words := String(ab.get("name", "?")).split(" ", false)
	var s := ""
	for w in words:
		if w.length() > 2:
			s += w[0].to_upper()
	return s.left(3)
