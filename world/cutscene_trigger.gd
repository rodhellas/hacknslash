@tool
class_name CutsceneTrigger
extends Area3D
## Area che fa partire una cutscene quando l'eroe ci entra (una volta per eroe).
## `cutscene_id` = id in data/cutscene_db.gd; in alternativa le cutscene con trigger "area:<nome di questo nodo>".
## Va messa fuori dal nodo World (non deve toccare la navmesh). Nell'editor si vede come un cerchio viola.

@export var cutscene_id := ""
@export var radius := 4.0:
	set(v):
		radius = v
		_refresh_shape()


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	_refresh_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _refresh_shape() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("Forma") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = "Forma"
		add_child(cs)
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = 3.0
	cs.shape = sh
	cs.position.y = 1.5
	cs.debug_color = Color(0.7, 0.3, 1.0, 0.35)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if cutscene_id != "" and not Cutscene.seen(cutscene_id):
		Cutscene.play(cutscene_id)
	Cutscene.trigger("area:" + String(name))
