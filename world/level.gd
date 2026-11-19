class_name Level
extends Node3D
## Script radice di ogni livello. Crea eroe, telecamera, HUD, inventario e menu di pausa;
## calcola cosa c'è sotto il cursore (nemico, oggetto, terreno) e gestisce morte e uscita.
## Il livello stesso (terreno, oggetti, zone nemiche) è una normale scena modificabile nell'editor.

@export var level_id := "level_01"
@export var level_title := "Livello"
@export var area_level := 1
@export_multiline var exit_text := "Livello completato."
## Città (hub): qui compare il portale di ritorno e non serve il portale cittadino.
@export var is_town := false
## Testo mostrato la prima volta che si entra nel livello (vuoto = nessuno).
@export_multiline var intro_text := ""
## Musica del livello: percorso di un file audio. Vuoto = res://audio/music/<level_id>.ogg se esiste.
@export_file("*.ogg", "*.mp3", "*.wav") var music := ""

## > 0 nei Labirinti di Dedalo: grado (sostituisce la difficoltà, vedi Game.enemy_scaling).
var rift_grade := 0
var player: Player
var camera: IsoCamera
var hud: Hud
var inventory_ui: InventoryUI
var pause_menu: PauseMenu
var touch: TouchControls
var trade_ui: TradeUI
var skills_ui: SkillsUI
var dynamic_root: Node3D
var enemies_root: Node3D
var hover: Dictionary = {"kind": "ground", "node": null, "point": Vector3.ZERO}
var _hover_ring: MeshInstance3D


func _ready() -> void:
	Game.level = self
	Game.ensure_debug_hero()
	Game.hero.level_id = level_id
	Game.hide_loading.call_deferred()

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
	trade_ui = TradeUI.new()
	add_child(trade_ui)
	trade_ui.bind(player, inventory_ui)
	inventory_ui.trade = trade_ui
	skills_ui = SkillsUI.new()
	add_child(skills_ui)
	skills_ui.bind(player)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	touch = TouchControls.new()
	add_child(touch)
	touch.bind(player, self)

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
	if is_town:
		_spawn_return_portal()
	var first_visit := not Game.hero.flags.has("visited_" + level_id)
	Game.hero.flags["visited_" + level_id] = true
	if first_visit and intro_text != "":
		hud.show_lore(level_title, intro_text)
	Quests.start_automatic()
	Quests.notify("enter", level_id)
	Music.play_level(level_id, music)
	Settings.apply_to_level(self)
	_place_world_extras()
	_onboarding()
	# Salva subito dopo un cambio di livello (così il salvataggio sa dove si trova l'eroe)
	Game.save_game.call_deferred()


## Santuari ed eventi casuali (WorldDB): a ogni visita, vicino ad alcune zone di nemici scelte a caso.
## Le mappe restano quelle fatte a mano: questi oggetti non bloccano il passaggio e non si salvano.
func _place_world_extras() -> void:
	if is_town or level_id == "dungeon":
		return
	var map := get_world_3d().navigation_map
	# La mappa di navigazione è quella del mondo (resta tra un livello e l'altro): si aspetta che
	# la navmesh di QUESTO livello ci sia davvero (il punto dell'eroe trova un punto vicino).
	for i in 300:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		var s := NavigationServer3D.map_get_closest_point(map, player.global_position)
		if i > 2 and s != Vector3.ZERO and Vector2(s.x - player.global_position.x, s.z - player.global_position.z).length() < 3.0:
			break
	var zones: Array = []
	for z: Node in get_tree().get_nodes_in_group("encounter_zones"):
		if String(z.get("unique_id")) == "" and (z as Node3D).global_position.distance_to(player.global_position) > 30.0:
			zones.append(z)
	zones.shuffle()
	var holder := Node3D.new()
	holder.name = "Extra"
	add_child(holder)
	var used := 0
	for z: Node3D in zones:
		var pos := _free_point_near(z.global_position, map)
		if pos == Vector3.INF:
			continue
		if used < WorldDB.SHRINES_PER_MAP:
			var s := Shrine.new()
			s.shrine_id = WorldDB.SHRINES.keys().pick_random()
			s.position = pos
			holder.add_child(s)
		elif used < WorldDB.SHRINES_PER_MAP + WorldDB.EVENTS_PER_MAP:
			var ev := WorldEvent.new()
			ev.event_id = WorldDB.EVENTS.keys().pick_random()
			ev.enemy_types = z.get("enemy_types")
			ev.enemy_level = int(z.get("enemy_level"))
			ev.position = pos
			holder.add_child(ev)
		else:
			break
		used += 1


## Punto calpestabile a 8-12 m dal centro di una zona (lontano dai nemici che ci stanno).
func _free_point_near(center: Vector3, map: RID) -> Vector3:
	for k in 8:
		var a := randf() * TAU
		var p := center + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 12.0)
		var s := NavigationServer3D.map_get_closest_point(map, p)
		if s != Vector3.ZERO and s.y < 1.0 and Vector2(s.x - p.x, s.z - p.z).length() < 1.5:
			return Vector3(s.x, 0.0, s.z)
	return Vector3.INF


## Suggerimenti dei primi minuti (una volta per eroe).
func _onboarding() -> void:
	if is_town:
		hud.hint("citta", "in città trovi mercante, fabbro, forziere, la Tabula delle taglie e l'Obelisco di Dedalo.")
	elif rift_grade > 0:
		hud.hint("labirinto", "riempi la barra in alto a sinistra uccidendo nemici: poi arriva il Guardiano. Sconfiggilo in tempo per salire di grado.")
	elif level_id == "dungeon":
		hud.hint("dungeon", "i dungeon hanno sempre la stessa pianta; nemici e forzieri tornano a ogni ingresso. Cerca santuari nelle stanze.")
	elif level_id == "level_01":
		if Settings.touch_enabled():
			hud.hint("muovi", "joystick a sinistra per muoverti, pulsante grande per attaccare; tocca un'abilità per la mira automatica o trascinala per mirare.")
		else:
			hud.hint("muovi", "clic sinistro per muoverti e attaccare, clic destro e 1-4 per le abilità, Q per la pozione.")


func _exit_tree() -> void:
	if Game.level == self:
		Game.level = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _spawn_position() -> Vector3:
	var h := Game.hero
	var spawn := Game.pending_spawn
	Game.pending_spawn = ""
	if h.has_position and h.level_id == level_id:
		return h.position
	if spawn != "":
		var marker := find_child(spawn, true, false) as Node3D
		if marker != null:
			return marker.global_position
		var wp := _find_checkpoint(spawn)
		if wp:
			return wp.spawn_point()
	return _respawn_position()


## Ultimo altare attivato in QUESTO livello, altrimenti l'inizio del livello.
func _respawn_position() -> Vector3:
	var cp := _find_checkpoint(String(Game.hero.flags.get("cp_last_" + level_id, "")))
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
		if inventory_ui.is_open:
			trade_ui.close()
		inventory_ui.toggle()
	elif event.is_action_pressed("map"):
		hud.minimap.toggle_big()
	elif event.is_action_pressed("quest_log"):
		hud.toggle_quest_log()
	elif event.is_action_pressed("skills"):
		skills_ui.toggle()


## C'è un pannello aperto (zaino, abilità, negozio, diario, mappa grande, pausa...)?
func any_panel_open() -> bool:
	return skills_ui.is_open or trade_ui.is_open or inventory_ui.is_open or hud.minimap.big \
		or hud.quest_log.visible or hud.waypoint_panel.visible or hud.lore_panel.visible \
		or hud.choice_panel.visible or hud.death_panel.visible or hud.end_panel.visible or pause_menu.root.visible


## Chiude il pannello aperto più in alto (ESC). Ritorna false se non c'era niente da chiudere.
func close_top_panel() -> bool:
	if hud.choice_panel.visible:
		hud.hide_choice()
		return true
	if skills_ui.is_open:
		skills_ui.close_panel()
		return true
	if hud.quest_log.visible:
		hud.quest_log.visible = false
		return true
	if hud.waypoint_panel.visible:
		hud.waypoint_panel.visible = false
		return true
	if trade_ui.is_open:
		trade_ui.close()
		inventory_ui.close()
		return true
	if inventory_ui.is_open:
		inventory_ui.close()
		return true
	if hud.lore_panel.visible:
		hud.lore_panel.visible = false
		return true
	return false


func open_trade(npc: Npc) -> void:
	trade_ui.open(npc, String(npc.data["role"]), String(npc.data["name"]))
	inventory_ui.open()


func open_stash(source: Node3D) -> void:
	trade_ui.open(source, "stash", "Forziere personale")
	inventory_ui.open()


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
	var recap := "Uccisioni: %d   Tempo in vita: %d:%02d   Sesterzi raccolti: %d" % [player.kills_since_death,
		int(player.time_since_death) / 60, int(player.time_since_death) % 60, Game.hero.gold - player.gold_at_spawn]
	if Game.hero.hardcore:
		# Hardcore: l'eroe è perso per sempre (resta nello slot come ricordo, non si può più giocare)
		Game.hero.flags["dead"] = true
		Game.hero.flags["death_place"] = level_title
		Game.save_game()
		hud.show_hardcore_death("%s è caduto per sempre a %s.\n%s" % [Game.hero.hero_name, level_title, recap])
		return
	hud.show_death(recap)


func respawn_player() -> void:
	var pos := _respawn_position()
	player.revive(pos)
	camera.global_position = pos + IsoCamera.BASE_OFFSET
	hud.hide_death()


func on_exit_reached(exit: LevelExit) -> void:
	Game.hero.flags["completed_" + level_id] = true
	if exit.target_level != "" and Game.LEVELS.has(exit.target_level):
		Sfx.play("portal")
		Game.travel(exit.target_level, exit.target_spawn)
		return
	Game.save_game()
	hud.show_end(exit.title, exit_text)


# --- Viaggi: altari e portale cittadino ----------------------------------------------------

## Viaggio rapido verso un altare attivato (anche di un altro livello).
func travel_to_waypoint(id: String) -> void:
	var w: Dictionary = Game.hero.waypoints.get(id, {})
	if w.is_empty() or player.dead:
		return
	hud.waypoint_panel.visible = false
	Sfx.play("portal")
	if String(w["level"]) == level_id:
		var cp := _find_checkpoint(id)
		if cp:
			Fx.pillar(dynamic_root, player.global_position, Color(0.4, 0.7, 1.0), 6.0, 0.6)
			teleport_player(cp.spawn_point())
			Fx.pillar(dynamic_root, player.global_position, Color(0.4, 0.7, 1.0), 6.0, 0.6)
		return
	Game.travel(String(w["level"]), id)


func teleport_player(pos: Vector3) -> void:
	player.global_position = pos
	player.move_target = Vector3.INF
	camera.global_position = pos + IsoCamera.BASE_OFFSET * camera.zoom


## Chiamato dal giocatore alla fine della canalizzazione del portale (tasto T).
func use_town_portal() -> void:
	Game.hero.flags["portal_return"] = {"level": level_id, "x": player.global_position.x, "z": player.global_position.z}
	Fx.pillar(dynamic_root, player.global_position, Color(0.35, 0.65, 1.0), 8.0, 0.8)
	Sfx.play("portal")
	Game.travel(Game.HUB, "PortaleArrivo")


func _spawn_return_portal() -> void:
	var data: Dictionary = Game.hero.flags.get("portal_return", {})
	if data.is_empty() or String(data.get("level", "")) == level_id:
		return
	var portal := TownPortal.new()
	portal.return_level = String(data["level"])
	portal.return_pos = Vector3(float(data["x"]), 0.0, float(data["z"]))
	var marker := find_child("PortaleArrivo", true, false) as Node3D
	var base := marker.global_position if marker else player.global_position
	portal.position = base + Vector3(-3.0, 0.0, 0.0)
	dynamic_root.add_child(portal)
