class_name Npc
extends StaticBody3D
## Personaggio non giocante. Dati e dialoghi in data/npc_db.gd (campo npc_id).
## Clic (o E vicino): mercante e fabbro aprono il loro pannello, gli altri parlano.
## Per aggiungerne uno nell'editor: StaticBody3D con questo script sotto il nodo World, imposta npc_id.
## Se non ha un CollisionShape3D figlio, ne crea uno da solo (ma allora non buca la navmesh).

@export var npc_id := "cittadino"
## Testo personalizzato per questo NPC (vuoto = quello di NpcDB).
@export_multiline var text_override := ""

var data: Dictionary = {}
var model: Node3D
var _bark_cd := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	collision_layer = Layers.WORLD | Layers.INTERACT
	collision_mask = 0
	data = NpcDB.get_data(npc_id)
	if find_children("*", "CollisionShape3D", false).is_empty():
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5
		cyl.height = 1.9
		cs.shape = cyl
		cs.position.y = 0.95
		add_child(cs)
	var scene := load(String(data["model"])) as PackedScene
	model = scene.instantiate() if scene else Node3D.new()
	add_child(model)
	var role := String(data["role"])
	var label := Label3D.new()
	label.text = String(data["name"]) + ("\n<%s>" % data["title"] if String(data["title"]) != "" else "")
	label.modulate = NpcDB.ROLE_COLORS.get(role, Color.WHITE)
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.visibility_range_end = 30.0
	label.position.y = 2.6
	add_child(label)
	if role != "talk" or String(data["text"]) != "":
		Fx.minimap_icon(self, NpcDB.ROLE_COLORS.get(role, Color.WHITE), 1.4, "square")
	_bark_cd = randf_range(2.0, 8.0)


func interact_name() -> String:
	return String(data["name"])


func can_interact() -> bool:
	return true


func interact(p: Player) -> void:
	_face(p.global_position)
	Sfx.play("talk", global_position)
	match String(data["role"]):
		"vendor", "smith":
			_bark()
			Game.level.open_trade(self)
		_:
			var t := text_override if text_override != "" else String(data["text"])
			if t == "":
				_bark(true)
			else:
				Game.level.hud.show_lore(String(data["name"]), t)


func _process(delta: float) -> void:
	if Game.level == null or Game.level.player == null:
		return
	var p := Game.level.player
	var d := global_position.distance_to(p.global_position)
	# Si gira verso l'eroe quando è vicino
	if d < 7.0:
		model.rotation.y = lerp_angle(model.rotation.y, _local_yaw(p.global_position), 1.0 - exp(-5.0 * delta))
	else:
		model.rotation.y = lerp_angle(model.rotation.y, 0.0, 1.0 - exp(-2.0 * delta))
	# Frasi casuali quando l'eroe passa vicino
	_bark_cd -= delta
	if d < 6.0 and _bark_cd <= 0.0 and not (data["lines"] as Array).is_empty():
		_bark()


func _bark(force: bool = false) -> void:
	var lines: Array = data["lines"]
	if lines.is_empty() or (_bark_cd > 0.0 and not force):
		return
	_bark_cd = randf_range(14.0, 24.0)
	Fx.popup_speech(self, String(lines.pick_random()))


func _face(target: Vector3) -> void:
	model.rotation.y = _local_yaw(target)


## Angolo (rispetto alla rotazione del nodo) per guardare verso un punto.
func _local_yaw(target: Vector3) -> float:
	var to := target - global_position
	return atan2(-to.x, -to.z) - global_rotation.y
