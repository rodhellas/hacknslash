class_name Level
extends Node3D
## Script radice di ogni livello. Crea eroe, telecamera, HUD, inventario e menu di pausa;
## calcola cosa c'è sotto il cursore (nemico, oggetto, terreno) e gestisce morte e uscita.
## Il livello stesso (terreno, oggetti, zone nemiche) è una normale scena modificabile nell'editor.

@export var level_id := "level_01"
@export var level_title := "Livello"
@export var area_level := 1
@export_multiline var exit_text := "Livello completato."

var player: Player
var camera: IsoCamera
var hud: Hud
var inventory_ui: InventoryUI
var pause_menu: PauseMenu
var dynamic_root: Node3D
var enemies_root: Node3D
var hover: Dictionary = {"kind": "ground", "node": null, "point": Vector3.ZERO}
var _hover_ring: MeshInstance3D


func _ready() -> void:
	Game.level = self
	Game.ensure_debug_hero()
	Game.hero.level_id = level_id

	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)

	player = Player.new()
	player.name = "Player"
	player.setup(Game.hero)
	add_child(player)
	player.global_position = _spawn_position()
	player.died.connect(_on_player_died)

	camera = IsoCamera.new()
	add_child(camera)
	camera.setup(player)

	hud = Hud.new()
	add_child(hud)
	hud.bind(player, self)
	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.bind(player)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)

	_hover_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.05
	_hover_ring.mesh = tm
	_hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_ring.visible = false
	add_child(_hover_ring)

	hud.show_banner(level_title)
	if Game.current_slot < 0:
		hud.show_warning("Partita di prova: i salvataggi sono disattivati")


func _exit_tree() -> void:
	if Game.level == self:
		Game.level = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _spawn_position() -> Vector3:
	var h := Game.hero
	if h.has_position and h.level_id == level_id:
		return h.position
	var cp := _find_checkpoint(h.checkpoint_id)
	if cp:
		return cp.spawn_point()
	var start := get_node_or_null("PlayerStart") as Node3D
	return start.global_position if start else Vector3.ZERO


func _find_checkpoint(id: String) -> Checkpoint:
	if id == "":
		return null
	for cp: Checkpoint in get_tree().get_nodes_in_group("checkpoint"):
		if cp.checkpoint_id == id:
			return cp
	return null


## Chiamato da Game.save_game() prima di scrivere il file.
func store_state() -> void:
	if player and not player.dead:
		Game.hero.position = player.global_position
		Game.hero.has_position = true
	Game.hero.level_id = level_id


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		inventory_ui.toggle()
	elif event.is_action_pressed("map"):
		hud.minimap.toggle_big()


# --- Cosa c'è sotto il cursore ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_update_hover()


func _update_hover() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	var point: Vector3 = ground if ground != null else player.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 250.0, Layers.ENEMY | Layers.INTERACT)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var kind := "ground"
	var node: Node3D = null
	if not hit.is_empty():
		var c: Node = hit["collider"]
		if c is Enemy and not (c as Enemy).dead:
			kind = "enemy"
			node = c
		else:
			while c != null and not c.is_in_group("interactable"):
				c = c.get_parent()
			if c != null and (not c.has_method("can_interact") or c.can_interact()):
				kind = "interact"
				node = c
	if kind == "ground":
		# Tolleranza: un nemico vicino al cursore conta come "sotto il cursore"
		var best_d := 1.1
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			var d := Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length() - e.radius()
			if d < best_d:
				best_d = d
				node = e
				kind = "enemy"
	if kind != "ground":
		point = node.global_position
	hover = {"kind": kind, "node": node, "point": point}

	match kind:
		"enemy":
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			_show_hover_ring(node, Color(1, 0.2, 0.15), (node as Enemy).radius() + 0.3)
		"interact":
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			_show_hover_ring(node, Color(1, 0.85, 0.3), 1.0)
		_:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			_hover_ring.visible = false


func _show_hover_ring(node: Node3D, col: Color, r: float) -> void:
	_hover_ring.visible = true
	_hover_ring.global_position = Vector3(node.global_position.x, 0.05, node.global_position.z)
	_hover_ring.scale = Vector3.ONE * r
	_hover_ring.material_override = Fx.mat(col, 2.0, false, true)


# --- Eventi ------------------------------------------------------------------------------

func on_enemy_hit(e: Enemy) -> void:
	hud.set_target(e)


func _on_player_died() -> void:
	hud.show_death()


func respawn_player() -> void:
	var cp := _find_checkpoint(Game.hero.checkpoint_id)
	var pos: Vector3
	if cp:
		pos = cp.spawn_point()
	else:
		var start := get_node_or_null("PlayerStart") as Node3D
		pos = start.global_position if start else Vector3.ZERO
	player.revive(pos)
	camera.global_position = pos + IsoCamera.BASE_OFFSET
	hud.hide_death()


func on_exit_reached(exit: LevelExit) -> void:
	Game.hero.flags["completed_" + level_id] = true
	Game.save_game()
	hud.show_end(exit.title, exit_text)
