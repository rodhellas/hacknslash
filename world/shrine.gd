class_name Shrine
extends StaticBody3D
## Santuario (o pilone nei Labirinti): cliccandolo dà un potenziamento a tempo (WorldDB.SHRINES / PYLONS).
## Si piazza da codice (Level._place_world_extras); non blocca il passaggio.

var shrine_id := "furia"
var pylon := false
var used := false
var _glow: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("shrines")
	collision_layer = Layers.INTERACT
	collision_mask = 0
	var d := data()
	var col: Color = d["color"]
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.9
	cs.height = 2.5
	shape.shape = cs
	shape.position.y = 1.25
	add_child(shape)
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.9
	bm.bottom_radius = 1.1
	bm.height = 0.5
	base.mesh = bm
	base.material_override = Fx.mat(Color(0.75, 0.72, 0.66))
	base.position.y = 0.25
	add_child(base)
	_glow = MeshInstance3D.new()
	if pylon:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.45
		pm.height = 3.0
		pm.radial_segments = 4
		_glow.mesh = pm
		_glow.position.y = 2.0
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.4
		sm.height = 0.8
		_glow.mesh = sm
		_glow.position.y = 1.4
	_glow.material_override = Fx.mat(col, 4.0, false, true)
	add_child(_glow)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.6
	l.omni_range = 6.0
	l.position.y = 1.8
	add_child(l)
	Fx.minimap_icon(self, col, 1.4, "square")


func data() -> Dictionary:
	return (WorldDB.PYLONS if pylon else WorldDB.SHRINES).get(shrine_id, WorldDB.SHRINES["furia"])


func interact_name() -> String:
	var d := data()
	return "%s (%s)" % [d["name"], d["desc"]] if not used else "%s (esaurito)" % d["name"]


func can_interact() -> bool:
	return not used


func interact(p: Player) -> void:
	if used:
		return
	used = true
	var d := data()
	var b: Dictionary = (d["buff"] as Dictionary).duplicate()
	b["id"] = "santuario_" + shrine_id
	b["name"] = d["name"]
	b["duration"] = d["duration"]
	p.add_buff(b)
	Fx.pillar(Game.world_root(), global_position, d["color"], 10.0, 1.0)
	Fx.ring(Game.world_root(), global_position, 3.0, d["color"], 0.5)
	Sfx.play("santuario", global_position)
	if Game.level:
		Game.level.hud.show_banner(String(d["name"]))
		Game.level.hud.show_message(String(d["desc"]) + " per %d s" % int(d["duration"]), 3.0)
		Game.level.hud.hint("santuario", "I santuari danno un potenziamento a tempo: lo vedi sopra la barra delle abilità.")
	_glow.material_override = Fx.mat(Color(0.3, 0.3, 0.3))
