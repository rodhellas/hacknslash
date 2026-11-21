class_name CharacterPreview
extends PanelContainer
## Anteprima 3D dell'eroe nello zaino: il modello con l'equipaggiamento addosso, che gira piano.
## Trascina con il mouse per ruotarlo. Usa un mondo 3D separato (non disegna il livello).

var viewport: SubViewport
var pivot: Node3D
var model: Node3D
var _model_path := ""
var _look := ""
var _drag := false


func _ready() -> void:
	add_theme_stylebox_override("panel", Hud._panel_style(0.92))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var c := SubViewportContainer.new()
	c.stretch = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	# Stesso antialiasing dello schermo: un valore diverso obbliga a ricompilare gli shader per l'anteprima
	viewport.msaa_3d = get_viewport().msaa_3d if get_viewport() != null else Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	c.add_child(viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.4)
	cam.rotation_degrees.x = -6.0
	cam.fov = 40.0
	viewport.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.65, 0.6)
	env.ambient_light_energy = 0.8
	we.environment = env
	viewport.add_child(we)
	pivot = Node3D.new()
	viewport.add_child(pivot)


## Prepara l'anteprima durante il caricamento del livello (dietro la schermata di caricamento):
## modello, pezzi dell'equipaggiamento e un primo disegno fuori schermo, così gli shader del suo
## mondo 3D si compilano subito e lo zaino si apre senza scatti.
func prewarm(h: HeroData) -> void:
	show_hero(h)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	# dopo il disegno torna a disegnare solo quando è visibile
	create_tween().tween_callback(func() -> void:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE).set_delay(0.2)


func show_hero(h: HeroData) -> void:
	var path := h.model_path()
	# Equipaggiamento invariato dall'ultima volta: niente da rifare (aprire lo zaino resta istantaneo)
	var look := path
	for slot: String in h.equipment:
		var it: Item = h.equipment[slot]
		look += "|%s:%d" % [slot, it.get_instance_id() if it != null else 0]
	look += str(h.transmog) + str(h.dyes)
	if model != null and look == _look:
		return
	_look = look
	if model == null or path != _model_path:
		if model != null:
			model.queue_free()
		var ps := load(path) as PackedScene
		model = ps.instantiate() if ps else Node3D.new()
		pivot.add_child(model)
		model.rotation_degrees.y = 180.0   # guarda verso la telecamera
		_model_path = path
		# Corpo vero animato: in piedi a riposo invece che nella posa a T
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null and ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")
	Appearance.apply(model, h.equipment, h.transmog, h.dyes)


func _process(delta: float) -> void:
	if visible and not _drag:
		pivot.rotation.y += delta * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		pivot.rotation.y += (event as InputEventMouseMotion).relative.x * 0.012
