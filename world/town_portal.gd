class_name TownPortal
extends Area3D
## Portale cittadino (come il "Town Portal" di Diablo). Compare in città quando l'eroe ci arriva
## con il tasto T: cliccandolo si torna nel punto esatto da cui si era partiti.

var return_level := ""
var return_pos := Vector3.ZERO
var _ring: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.INTERACT
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 3.2, 1.0)
	cs.shape = box
	cs.position.y = 1.6
	add_child(cs)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.1
	tm.outer_radius = 1.35
	_ring.mesh = tm
	_ring.material_override = Fx.mat(Color(0.35, 0.65, 1.0), 4.0, false, true)
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 1.6
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.05
	disc.mesh = cm
	disc.material_override = Fx.mat(Color(0.3, 0.55, 1.0, 0.45), 2.0, true, true)
	disc.rotation_degrees.x = 90.0
	disc.position.y = 1.6
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.65, 1.0)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position.y = 1.6
	add_child(light)
	var label := Label3D.new()
	label.text = "Portale: %s" % Game.level_title(return_level)
	label.modulate = Color(0.6, 0.8, 1.0)
	label.font_size = 28
	label.outline_size = 8
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 3.6
	add_child(label)
	Fx.minimap_icon(self, Color(0.35, 0.65, 1.0), 1.6, "square")


func _process(delta: float) -> void:
	_t += delta
	_ring.rotation.z = _t * 1.5
	_ring.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.04)


func interact_name() -> String:
	return "Portale verso %s" % Game.level_title(return_level)


func can_interact() -> bool:
	return true


func interact(_p: Player) -> void:
	if Game.hero == null:
		return
	Game.hero.flags.erase("portal_return")
	Sfx.play("portal")
	Game.travel(return_level, "", return_pos)
