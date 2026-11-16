@tool
class_name MapArea
extends Node3D
## AREA circolare della Forma del livello: spostala nell'editor e cambiane il raggio.
##   walkable = true  → rende calpestabile il cerchio (radure, piazze, zone laterali)
##   scatter  = false → niente vegetazione casuale nel cerchio (cortili, campi coltivati)
## Un'area con walkable = false e scatter = false è una "radura": non cambia dove si cammina,
## tiene solo libero lo spazio.

@export var radius := 20.0:
	set(v):
		radius = v
		_refresh()
## Zona del terreno nel cerchio ("" = invariata). Vedi data/map_zones.gd.
@export var zone := "":
	set(v):
		zone = v
		_refresh()
@export var walkable := true:
	set(v):
		walkable = v
		_refresh()
@export var scatter := true:
	set(v):
		scatter = v
		_refresh()
## Calpestabile anche sopra l'acqua (piattaforme, isolotti).
@export var over_water := false

var _gizmo: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh()


func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _gizmo:
		_gizmo.queue_free()
	_gizmo = Node3D.new()
	add_child(_gizmo)   # senza owner: non viene salvato
	var col := Color(0.4, 1.0, 0.4, 0.15) if walkable else Color(0.8, 0.8, 0.8, 0.12)
	if zone != "":
		col = Color(MapZones.get_zone(zone)["color"], 0.4)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	cm.radial_segments = 48
	disc.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	disc.material_override = m
	disc.position.y = 0.35
	_gizmo.add_child(disc)
	var l := Label3D.new()
	var txt := String(name)
	if zone != "":
		txt += "\n" + zone
	if not walkable:
		txt += "\n(radura)" if not scatter else "\n(non calpestabile)"
	l.text = txt
	l.font_size = 96
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position.y = 3.0
	_gizmo.add_child(l)
