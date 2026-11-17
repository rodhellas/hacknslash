class_name Minimap
extends Control
## Minimappa in alto a destra (telecamera ortografica dall'alto). TAB = mappa grande al centro.
## Le icone (eroe, nemici, forzieri, altari, uscita) sono mesh sul livello visivo 11,
## visibili solo da questa telecamera.

const SMALL := 230.0
const BIG := 760.0
const SMALL_ZOOM := 75.0
const BIG_ZOOM := 280.0

var target: Node3D
var big := false
var container: SubViewportContainer
var viewport: SubViewport
var cam: Camera3D
var frame: Panel
var title: Label
var overlay: MapOverlay
var side: PanelContainer   # mappa grande: legenda e viaggio rapido

## Legenda della mappa grande: [colore, testo] (stessi colori delle icone, Fx.minimap_icon).
const LEGEND := [
	[Color(1.0, 0.85, 0.2), "Tu"], [Color(0.95, 0.15, 0.15), "Nemici"], [Color(1.0, 0.5, 0.1), "Boss"],
	[Color(0.3, 0.7, 1.0), "Altari"], [Color(0.3, 1.0, 0.4), "Uscite"], [Color(0.85, 0.4, 1.0), "Dungeon"],
	[Color(1.0, 0.4, 0.9), "Eventi"], [Color(1.0, 0.85, 0.3), "Missioni, taglie"], [Color(0.0, 0.0, 0.0), "Nebbia: non esplorato"],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	container = SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(viewport)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SMALL_ZOOM
	cam.cull_mask = 1 | Layers.VIS_MINIMAP
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.near = 1.0
	cam.far = 150.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.ambient_light_energy = 0.8
	cam.environment = env
	viewport.add_child(cam)
	cam.current = true

	overlay = MapOverlay.new()
	overlay.map = self
	add_child(overlay)
	frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(0.6, 0.48, 0.25)
	sb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	title = Label.new()
	title.text = "N"
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(6, 2)
	add_child(title)
	_apply_size()


func _process(_delta: float) -> void:
	if target and is_instance_valid(target):
		cam.global_position = target.global_position + Vector3(0, 70, 0)


func toggle_big() -> void:
	big = not big
	_apply_size()
	_build_side()


func _build_side() -> void:
	if side != null:
		side.queue_free()
		side = null
	if not big or Game.hero == null or Game.level == null:
		return
	side = PanelContainer.new()
	side.add_theme_stylebox_override("panel", Hud._panel_style(0.92))
	side.position = Vector2(BIG + 10, 0)
	side.custom_minimum_size = Vector2(280, BIG)
	side.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	v.add_child(_side_label("Legenda", 18, Color(0.95, 0.78, 0.35)))
	for e: Array in LEGEND:
		v.add_child(_side_label("■  " + String(e[1]), 14, (e[0] as Color) if (e[0] as Color).v > 0.1 else Color(0.5, 0.5, 0.5)))
	v.add_child(_side_label("Viaggio rapido", 18, Color(0.95, 0.78, 0.35)))
	var wps: Dictionary = Game.hero.waypoints
	if wps.is_empty():
		v.add_child(_side_label("Nessun altare attivato.", 14, Color(0.6, 0.6, 0.6)))
	for lvl: String in Game.LEVEL_TITLES:
		for id: String in wps:
			if String(wps[id]["level"]) != lvl:
				continue
			var b := Button.new()
			b.text = "%s  (%s)" % [wps[id]["title"], Game.level_title(lvl)]
			b.clip_text = true
			b.custom_minimum_size = Vector2(250, 30)
			b.pressed.connect(func() -> void:
				toggle_big()
				Game.level.travel_to_waypoint(id))
			v.add_child(b)
	var dungeons: Array = []
	for n: Node in Game.level.find_children("*", "StaticBody3D", true, false):
		if n is DungeonEntrance:
			dungeons.append(String(DungeonDB.get_data((n as DungeonEntrance).dungeon_id)["title"]))
	if not dungeons.is_empty():
		v.add_child(_side_label("Dungeon in questa zona", 18, Color(0.95, 0.78, 0.35)))
		for d: String in dungeons:
			v.add_child(_side_label("■  " + d, 14, Color(0.85, 0.4, 1.0)))


func _side_label(t: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l


func _apply_size() -> void:
	var s := BIG if big else SMALL
	if big:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -s * 0.5
		offset_right = s * 0.5
		offset_top = -s * 0.5
		offset_bottom = s * 0.5
		modulate.a = 0.85
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -s - 14
		offset_right = -14
		offset_top = 14
		offset_bottom = 14 + s
		modulate.a = 1.0
	cam.size = BIG_ZOOM if big else SMALL_ZOOM
