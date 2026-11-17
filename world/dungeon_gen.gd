class_name DungeonGen
extends RefCounted
## Pianta di un dungeon: stanze rettangolari collegate da corridoi su una griglia di celle.
## Deterministica: usa solo il proprio RandomNumberGenerator, quindi con lo stesso seme
## (e gli stessi parametri di data/dungeon_db.gd) il risultato è identico ogni volta.
## Non crea nodi: world/dungeon_level.gd costruisce la scena, tools/export_dungeons.gd la pianta PNG.

const EMPTY := 0
const FLOOR := 1

var w := 0
var h := 0
var tile := 3.0
var cells := PackedByteArray()
var rooms: Array[Rect2i] = []
## Coppie di stanze collegate da un corridoio: [indice a, indice b].
var links: Array = []
var start_room := 0
var boss_room := 0
## Distanza (in celle, a piedi) di ogni cella dal centro della stanza di partenza; -1 = irraggiungibile.
var dist := PackedInt32Array()


static func generate(cfg: Dictionary, seed_override: int = -1) -> DungeonGen:
	var g := DungeonGen.new()
	g._build(cfg, int(cfg.get("seed", 1)) if seed_override < 0 else seed_override)
	return g


func _build(cfg: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	w = int(cfg.get("grid", 56))
	h = w
	tile = float(cfg.get("tile", 3.0))
	cells.resize(w * h)
	cells.fill(EMPTY)
	var rmin := int(cfg.get("room_min", 5))
	var rmax := int(cfg.get("room_max", 9))
	var wanted := int(cfg.get("rooms", 10))
	var cw := int(cfg.get("corridor", 2))

	# 1. Stanze: posizioni casuali, senza sovrapporsi (almeno 3 celle tra una stanza e l'altra)
	var attempts := wanted * 40
	while rooms.size() < wanted and attempts > 0:
		attempts -= 1
		var rw := rng.randi_range(rmin, rmax)
		var rh := rng.randi_range(rmin, rmax)
		var r := Rect2i(rng.randi_range(2, w - rw - 2), rng.randi_range(2, h - rh - 2), rw, rh)
		var ok := true
		for o: Rect2i in rooms:
			if o.grow(3).intersects(r):
				ok = false
				break
		if ok:
			rooms.append(r)
	for r: Rect2i in rooms:
		_carve(r)

	# 2. Corridoi: ogni stanza si collega alla più vicina tra quelle già collegate (albero)...
	for i in range(1, rooms.size()):
		var best := 0
		var best_d := INF
		for j in i:
			var d := _center(i).distance_squared_to(_center(j))
			if d < best_d:
				best_d = d
				best = j
		_connect(i, best, cw, rng)
	# ...più qualche anello tra stanze vicine non ancora collegate
	var loops := int(cfg.get("loops", 0))
	var tries := loops * 10
	while loops > 0 and tries > 0 and rooms.size() > 3:
		tries -= 1
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := -1
		var bd := INF
		for j in rooms.size():
			if j != a and not _linked(a, j):
				var d := _center(a).distance_squared_to(_center(j))
				if d < bd:
					bd = d
					b = j
		if b >= 0:
			_connect(a, b, cw, rng)
			loops -= 1

	# 3. Partenza = stanza 0, boss = la stanza più lontana a piedi
	start_room = 0
	_flood(_center(start_room))
	var far := -1
	for i in rooms.size():
		var c := _center(i)
		var d := dist[c.y * w + c.x]
		if d > far:
			far = d
			boss_room = i


func _carve(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 1 and y >= 1 and x < w - 1 and y < h - 1:
				cells[y * w + x] = FLOOR


## Corridoio a L tra i centri di due stanze, largo cw celle.
func _connect(a: int, b: int, cw: int, rng: RandomNumberGenerator) -> void:
	links.append([a, b])
	var p := _center(a)
	var q := _center(b)
	var o := -(cw / 2)
	if rng.randf() < 0.5:
		_carve(Rect2i(mini(p.x, q.x) + o, p.y + o, absi(q.x - p.x) + cw, cw))
		_carve(Rect2i(q.x + o, mini(p.y, q.y) + o, cw, absi(q.y - p.y) + cw))
	else:
		_carve(Rect2i(p.x + o, mini(p.y, q.y) + o, cw, absi(q.y - p.y) + cw))
		_carve(Rect2i(mini(p.x, q.x) + o, q.y + o, absi(q.x - p.x) + cw, cw))


func _linked(a: int, b: int) -> bool:
	for l: Array in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return true
	return false


func _center(i: int) -> Vector2i:
	var r := rooms[i]
	return r.position + r.size / 2


func _flood(from: Vector2i) -> void:
	dist.resize(w * h)
	dist.fill(-1)
	var queue: Array[Vector2i] = [from]
	dist[from.y * w + from.x] = 0
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := dist[c.y * w + c.x]
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + n
			if is_floor(q.x, q.y) and dist[q.y * w + q.x] < 0:
				dist[q.y * w + q.x] = d + 1
				queue.append(q)


func is_floor(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and cells[y * w + x] == FLOOR


## Tutte le celle di pavimento raggiungibili dalla partenza?
func all_connected() -> bool:
	for i in cells.size():
		if cells[i] == FLOOR and dist[i] < 0:
			return false
	return true


## Centro di una cella in coordinate del mondo (la griglia è centrata nell'origine; y della griglia = z).
func cell_to_world(c: Vector2) -> Vector3:
	return Vector3((c.x - w * 0.5 + 0.5) * tile, 0.0, (c.y - h * 0.5 + 0.5) * tile)


func room_center_world(i: int) -> Vector3:
	var r := rooms[i]
	return cell_to_world(Vector2(r.position) + Vector2(r.size) * 0.5 - Vector2(0.5, 0.5))


## Impronta della pianta: due piante uguali hanno la stessa impronta.
func fingerprint() -> int:
	return hash(cells) ^ hash(str(rooms))
