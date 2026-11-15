class_name OcclusionFader
extends Node
## Rende semitrasparenti gli oggetti tra la telecamera e l'eroe (come in Diablo 3).
## Funziona con qualsiasi oggetto che:
##   1) ha un collider sul livello "mondo" (1) o "occlusione" (5) che copre la parte visibile
##   2) ha il nodo radice nel gruppo "fadeable"
## Usa GeometryInstance3D.transparency, quindi non serve modificare i materiali (vale anche per modelli Tripo).

const FADE_TO := 0.78
const FADE_SPEED := 5.0

var camera: Camera3D
var target: Node3D
var _current: Dictionary = {}   # nodo -> trasparenza attuale
var _wanted: Dictionary = {}
var _timer := 0.0
const OFFSETS := [Vector3(0, 0.4, 0), Vector3(0, 1.2, 0), Vector3(0, 2.0, 0), Vector3(0.8, 1.0, 0), Vector3(-0.8, 1.0, 0)]


func _physics_process(delta: float) -> void:
	if camera == null or target == null or not is_instance_valid(target):
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.08
		_detect()
	_animate(delta)


func _detect() -> void:
	var space := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var hits := {}
	for off: Vector3 in OFFSETS:
		var to: Vector3 = target.global_position + off
		var exclude: Array[RID] = []
		for i in 6:
			var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.OCCLUDER, exclude)
			var r := space.intersect_ray(q)
			if r.is_empty():
				break
			var root := _fade_root(r["collider"])
			if root != null:
				hits[root] = true
			exclude.append(r["rid"])
	_wanted = hits
	for root: Node3D in hits:
		if not _current.has(root):
			_current[root] = 0.0


func _animate(delta: float) -> void:
	for root: Variant in _current.keys():
		if not is_instance_valid(root):
			_current.erase(root)
			continue
		var goal := FADE_TO if _wanted.has(root) else 0.0
		var cur := move_toward(float(_current[root]), goal, delta * FADE_SPEED)
		_current[root] = cur
		for gi: GeometryInstance3D in Fx.meshes(root):
			if is_instance_valid(gi):
				gi.transparency = cur
		if cur <= 0.0 and goal <= 0.0:
			_current.erase(root)


func _fade_root(n: Object) -> Node3D:
	var node := n as Node
	while node != null:
		if node.is_in_group("fadeable"):
			return node as Node3D
		node = node.get_parent()
	return null
