class_name HealthGlobe
extends Area3D
## Globo di vita lasciato dai nemici: cura il 20% della vita massima passandoci sopra.

const HEAL_PCT := 0.2
var _t := 0.0
var _mesh: MeshInstance3D
var _life := 30.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	_mesh.mesh = sm
	_mesh.material_override = Fx.mat(Color(1.0, 0.12, 0.18), 3.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_mesh.position.y = 0.6 + sin(_t * 4.0) * 0.15
	var p: Player = Game.level.player if Game.level else null
	if p and not p.dead:
		var to := p.global_position - global_position
		to.y = 0.0
		if to.length() < 3.5:
			global_position += to.normalized() * 9.0 * delta


func _on_body_entered(body: Node) -> void:
	if body is Player and not (body as Player).dead:
		var p := body as Player
		var vesta := p.has_power("vesta")
		p.heal(float(p.stats["max_life"]) * HEAL_PCT * (2.0 if vesta else 1.0))
		if vesta:
			p.resource = minf(p.resource + float(p.stats["resource_max"]) * 0.2, p.stats["resource_max"])
		Fx.burst(Game.world_root(), global_position + Vector3(0, 0.6, 0), Color(1.0, 0.2, 0.25), 10, 3.0, 0.1, 0.4, 2.0)
		Sfx.play("globo_vita")
		queue_free()
