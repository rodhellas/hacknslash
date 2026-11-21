class_name MapOverlay
extends Control
## Disegnato sopra la minimappa e la mappa grande (TAB):
##   - nebbia di guerra: le zone non ancora esplorate sono scure. L'esplorato si salva per livello
##     in hero.flags["fog"][chiave] (celle da CELL metri); i Labirinti di Dedalo non si salvano;
##     le città non hanno nebbia.
##   - segnalini delle missioni: dove andare per l'obiettivo attuale (NPC, boss, altare, uscita...).
##     Fuori dalla mappa diventano una freccia sul bordo.

const CELL := 8.0
const REVEAL := 30.0
const FOG := Color(0.0, 0.0, 0.0, 0.88)
const MARK := Color(1.0, 0.82, 0.25)

var map: Minimap
var _explored: Dictionary = {}     # Vector2i -> true
var _saved: Array = []             # stesso contenuto, nel formato del salvataggio (int)
var _key := ""
var _t := 0.0
var _marks: Array = []             # [Vector3 posizione, testo]
var _marks_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if Game.level == null or Game.hero == null or map.target == null or not is_instance_valid(map.target):
		return
	if _key == "":
		_load_fog()
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		reveal(map.target.global_position, REVEAL)
	_marks_t -= delta
	if _marks_t <= 0.0:
		_marks_t = 1.0
		_marks = quest_marks()
	queue_redraw()


func fog_enabled() -> bool:
	return Game.level != null and not Game.level.is_town


func _load_fog() -> void:
	_key = Game.level.level_id
	if Game.level.level_id == "dungeon":
		var info: Dictionary = Game.hero.flags.get("dungeon", {})
		_key = "rift" if info.has("rift") else "dungeon_" + String(info.get("id", ""))
	_explored.clear()
	if _key == "rift":
		_saved = []
		return
	var all: Dictionary = Game.hero.flags.get("fog", {})
	if not Game.hero.flags.has("fog"):
		Game.hero.flags["fog"] = all
	if not all.has(_key):
		all[_key] = []
	_saved = all[_key]
	for v: Variant in _saved:
		_explored[_decode(int(v))] = true


static func _encode(c: Vector2i) -> int:
	return (c.x + 20000) * 40000 + (c.y + 20000)


static func _decode(v: int) -> Vector2i:
	return Vector2i(v / 40000 - 20000, v % 40000 - 20000)


func is_explored(p: Vector3) -> bool:
	return _explored.has(Vector2i(floori(p.x / CELL), floori(p.z / CELL)))


func reveal(p: Vector3, radius: float) -> void:
	var r := ceili(radius / CELL)
	var c0 := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := c0 + Vector2i(dx, dy)
			if _explored.has(c):
				continue
			var center := Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)
			if center.distance_to(Vector2(p.x, p.z)) <= radius + CELL * 0.5:
				_explored[c] = true
				_saved.append(_encode(c))


func explored_count() -> int:
	return _explored.size()


## Posizioni degli obiettivi delle missioni attive in questo livello.
func quest_marks() -> Array:
	var out: Array = []
	var tree := get_tree()
	for id: String in Quests.active_ids():
		var st := Quests.current_step(id)
		var target := String(st.get("target", ""))
		match String(st.get("type", "")):
			"talk":
				for n: Node in tree.get_nodes_in_group("npcs"):
					if String(n.get("npc_id")) == target:
						out.append([(n as Node3D).global_position, "!"])
			"kill_unique":
				for z: Node in tree.get_nodes_in_group("encounter_zones"):
					if String(z.get("unique_id")) == target:
						out.append([(z as Node3D).global_position, "☠"])
				for e: Node in tree.get_nodes_in_group("enemies"):
					if (e as Enemy).type_id == target:
						out.append([(e as Node3D).global_position, "☠"])
			"altar":
				for c: Node in tree.get_nodes_in_group("checkpoint"):
					if String(c.get("checkpoint_id")) == target:
						out.append([(c as Node3D).global_position, "✦"])
			"enter":
				for ex: Node in Game.level.find_children("*", "Area3D", true, false):
					if ex is LevelExit and (ex as LevelExit).target_level == target:
						out.append([(ex as Node3D).global_position, "➜"])
			"chest":
				for ch: Node in tree.get_nodes_in_group("interactable"):
					if ch is Chest and (target == "" or (ch as Chest).flag_id == target) and not (ch as Chest).opened:
						out.append([(ch as Node3D).global_position, "▣"])
						if target == "":
							break
	# NPC con una missione da affidare o consegnare (come i "!" / "?" sopra la testa)
	for n: Node in tree.get_nodes_in_group("npcs"):
		var m := Quests.npc_marker(String(n.get("npc_id")))
		if m != "":
			out.append([(n as Node3D).global_position, m])
	return out


func _to_screen(p: Vector3) -> Vector2:
	var cam := map.cam
	var s := size
	var z := cam.size
	return Vector2((p.x - cam.global_position.x) / z * s.y + s.x * 0.5, (p.z - cam.global_position.z) / z * s.y + s.y * 0.5)


func _draw() -> void:
	if map == null or map.cam == null or Game.level == null:
		return
	var cam := map.cam
	var s := size
	if fog_enabled():
		var px_per_m := s.y / cam.size
		var half := Vector2(s.x, s.y) * 0.5 / px_per_m
		var cx := cam.global_position.x
		var cz := cam.global_position.z
		var x0 := floori((cx - half.x) / CELL)
		var x1 := floori((cx + half.x) / CELL)
		var y0 := floori((cz - half.y) / CELL)
		var y1 := floori((cz + half.y) / CELL)
		for cy in range(y0, y1 + 1):
			# righe intere di celle non esplorate: un solo rettangolo per tratto
			var run_start := -99999
			for cxi in range(x0, x1 + 2):
				var dark := cxi <= x1 and not _explored.has(Vector2i(cxi, cy))
				if dark and run_start == -99999:
					run_start = cxi
				elif not dark and run_start != -99999:
					var a := _to_screen(Vector3(run_start * CELL, 0, cy * CELL))
					var b := _to_screen(Vector3(cxi * CELL, 0, (cy + 1) * CELL))
					draw_rect(Rect2(a, b - a).intersection(Rect2(Vector2.ZERO, s)), FOG)
					run_start = -99999
	var font := get_theme_default_font()
	for m: Array in _marks:
		var sp := _to_screen(m[0])
		var inside := Rect2(Vector2(8, 8), s - Vector2(16, 16)).has_point(sp)
		if not inside:
			# freccia sul bordo verso l'obiettivo
			var c := s * 0.5
			var d := (sp - c).normalized()
			var t := minf(absf((s.x * 0.5 - 12.0) / maxf(absf(d.x), 0.001)), absf((s.y * 0.5 - 12.0) / maxf(absf(d.y), 0.001)))
			sp = c + d * t
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([sp + d * 9.0, sp - d * 5.0 + n * 6.0, sp - d * 5.0 - n * 6.0]), MARK)
			continue
		draw_circle(sp, 8.0, Color(0, 0, 0, 0.6))
		draw_string_outline(font, sp + Vector2(-6, 6), String(m[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color.BLACK)
		draw_string(font, sp + Vector2(-6, 6), String(m[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MARK)
