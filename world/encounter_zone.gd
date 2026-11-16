@tool
class_name EncounterZone
extends Node3D
## Zona di nemici (come i "pack" di Diablo). I nemici compaiono quando l'eroe si avvicina
## (activation_range) e restano nella loro zona finché non ti vedono. Se ne attacchi uno,
## tutto il gruppo si attiva. Nell'editor la zona è mostrata come un disco colorato:
## rosso = normale, blu = elite (Campioni), arancione = boss unico.

@export var enemy_types: PackedStringArray = PackedStringArray(["predone"]):
	set(v):
		enemy_types = v
		_refresh_gizmo()
@export_range(0, 30) var count: int = 4:
	set(v):
		count = v
		_refresh_gizmo()
@export var radius: float = 6.0:
	set(v):
		radius = v
		_refresh_gizmo()
@export_range(1, 60) var enemy_level: int = 1
@export var elite: bool = false:
	set(v):
		elite = v
		_refresh_gizmo()
## Boss unico (es. "brenno"): compare al centro, una sola volta per partita.
@export var unique_id: String = "":
	set(v):
		unique_id = v
		_refresh_gizmo()
@export var activation_range: float = 45.0

var spawned := false
var alerted := false
var enemies: Array = []
var _check := 0.0
var _gizmo: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_gizmo()
		return
	add_to_group("encounter_zones")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or spawned:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.3
	if Game.level == null or Game.level.player == null:
		return
	var d := Game.level.player.global_position.distance_to(global_position)
	# Aspetta che la navmesh sia pronta (al caricamento del livello serve un frame)
	if d < activation_range and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		spawn()


func spawn() -> void:
	spawned = true
	var map := get_world_3d().navigation_map
	var container: Node = Game.level.enemies_root if Game.level else get_parent()
	if unique_id != "" and not (Game.hero and Game.hero.flags.has("unique_" + unique_id)):
		_spawn_one(unique_id, global_position, false, map, container)
	for i in count:
		var t: String = enemy_types[i % enemy_types.size()] if enemy_types.size() > 0 else "predone"
		var a := randf() * TAU
		var pos := global_position + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf())
		_spawn_one(t, pos, elite, map, container)


func _spawn_one(t: String, pos: Vector3, is_elite: bool, map: RID, container: Node) -> void:
	var snapped := NavigationServer3D.map_get_closest_point(map, pos)
	if snapped != Vector3.ZERO and snapped.y < 1.0 and Vector2(snapped.x - pos.x, snapped.z - pos.z).length() < 6.0:
		pos = snapped
	pos.y = 0.0
	var e := Enemy.create(t, enemy_level, is_elite)
	e.zone = self
	e.position = pos
	container.add_child(e)
	enemies.append(e)


## Quando un nemico del gruppo ti nota, si attivano tutti.
func alert() -> void:
	if alerted:
		return
	alerted = true
	for e: Variant in enemies:
		if is_instance_valid(e):
			(e as Enemy).aggro()
	create_tween().tween_callback(func() -> void: alerted = false).set_delay(4.0)


# --- Visualizzazione nell'editor -------------------------------------------------------

func _refresh_gizmo() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _gizmo:
		_gizmo.queue_free()
	_gizmo = Node3D.new()
	add_child(_gizmo)   # senza owner: non viene salvato nella scena
	var col := Color(1, 0.2, 0.2, 0.3)
	if elite:
		col = Color(0.3, 0.5, 1.0, 0.3)
	if unique_id != "":
		col = Color(1.0, 0.55, 0.1, 0.35)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	disc.mesh = cm
	disc.material_override = Fx.new_mat(col, 0.0, true, true)
	disc.position.y = 0.1
	_gizmo.add_child(disc)
	var l := Label3D.new()
	var txt := "%d x %s" % [count, ", ".join(enemy_types)]
	if unique_id != "":
		txt = "BOSS: %s\n%s" % [unique_id, txt]
	if elite:
		txt = "ELITE\n" + txt
	l.text = txt
	l.font_size = 64
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 3.0
	_gizmo.add_child(l)
