class_name IsoCamera
extends Camera3D
## Telecamera stile Diablo 3: guarda verso nord dall'alto, segue l'eroe senza ruotare.
## Rotellina del mouse = zoom leggero. Contiene l'OcclusionFader che rende trasparente
## ciò che copre l'eroe (alberi, colonne, edifici).

const BASE_OFFSET := Vector3(0, 17.0, 12.5)
var target: Node3D
var zoom := 1.0
var _shake := 0.0
var fader: OcclusionFader


func setup(t: Node3D) -> void:
	target = t
	fov = 45.0
	far = 300.0
	cull_mask = 0xFFFFF & ~Layers.VIS_MINIMAP
	global_position = t.global_position + BASE_OFFSET
	look_at(t.global_position, Vector3.UP)
	make_current()
	fader = OcclusionFader.new()
	fader.camera = self
	fader.target = t
	add_child(fader)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom = clampf(zoom - 0.08, 0.7, 1.3)
	elif event.is_action_pressed("zoom_out"):
		zoom = clampf(zoom + 0.08, 0.7, 1.3)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dest := target.global_position + BASE_OFFSET * zoom
	global_position = global_position.lerp(dest, 1.0 - exp(-10.0 * delta))
	if _shake > 0.0:
		h_offset = randf_range(-_shake, _shake)
		v_offset = randf_range(-_shake, _shake)
		_shake = maxf(_shake - delta * 1.5, 0.0)
	else:
		h_offset = 0.0
		v_offset = 0.0
