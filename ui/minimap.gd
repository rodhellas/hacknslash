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
