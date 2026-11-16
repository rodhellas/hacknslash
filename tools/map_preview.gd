@tool
class_name MapPreview
extends RefCounted
## PIANTA DALL'ALTO di un livello, salvata come immagine PNG (nord in alto).
## Usata dal pannello Mappa dell'editor e da tools/export_maps.gd (riga di comando).
##
## Legenda:
##   colori del suolo = zone (data/map_zones.gd)    blu = acqua    grigio scuro = fuori mappa
##   strisce chiare = strade lastricate              macchie scure = edifici e oggetti piazzati a mano
##   puntini verdi = vegetazione generata            griglia = 50 m
##   cerchi rossi = nemici, blu = Campioni, arancioni = boss (raggio = zona, punto = numero)
##   quadrati oro = forzieri    rombi azzurri = altari    gialli = NPC    viola = forziere personale
##   rettangoli verdi = uscite  triangolo bianco = inizio del livello

const OUT_DIR := "res://docs/mappe/"


static func render(level_root: Node3D, ppm: float = 2.0) -> Image:
	var b := MapBuilder.new()
	if not b.rasterize(level_root):
		return null
	b.world = level_root.get_node_or_null("World") as Node3D
	var w := b.nx * b.cell * ppm
	var h := b.nz * b.cell * ppm
	var big := maxf(w, h)
	if big > 4096.0:
		ppm *= 4096.0 / big
		w = b.nx * b.cell * ppm
		h = b.nz * b.cell * ppm
	var img := Image.create(int(w), int(h), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.09))
	var cpx := int(ceilf(b.cell * ppm))
	for k in b.nx * b.nz:
		var col := Color(0.08, 0.08, 0.09)
		if b.state[k] == 1:
			col = MapZones.get_zone(b.zone_of[k])["color"]
		elif b.state[k] == 2:
			col = b.shape.water_color
		else:
			continue
		var c := b._center(k)
		var px := _px(b, c - Vector2.ONE * b.cell * 0.5, ppm)
		img.fill_rect(Rect2i(px, Vector2i(cpx, cpx)), col)
	# Griglia ogni 50 m
	var grid := Color(1, 1, 1, 0.08)
	var gx := ceilf(b.xmin / 50.0) * 50.0
	while gx < b.xmin + b.nx * b.cell:
		var x := int((gx - b.xmin) * ppm)
		for y in img.get_height():
			_blend(img, x, y, grid)
		gx += 50.0
	var gz := ceilf(b.zmin / 50.0) * 50.0
	while gz < b.zmin + b.nz * b.cell:
		var y := int((gz - b.zmin) * ppm)
		for x in img.get_width():
			_blend(img, x, y, grid)
		gz += 50.0
	# Strade lastricate
	for rd: Array in b.roads_data:
		var r: MapRoad = rd[0]
		if r.paved_width <= 0.0:
			continue
		var pts: PackedVector2Array = rd[1]
		for i in range(1, pts.size()):
			_line(img, b, pts[i - 1], pts[i], r.paved_width * ppm * 0.5, r.paved_color.lightened(0.15), ppm)
	# Oggetti: a mano (macchie scure) e generati (puntini)
	if b.world != null:
		for c in b.world.get_children():
			var gen := String(c.name) in MapBuilder.GENERATED
			if String(c.name) in ["Terreno", "Confini", "Strade", "Acqua"]:
				continue
			b.obstacles.clear()
			b._collect_from(c)
			for o: Array in b.obstacles:
				if gen:
					_circle(img, _pxf(b, o[0], ppm), maxf(float(o[1]) * ppm * 0.6, 1.5), Color(0.12, 0.25, 0.1, 0.9))
				else:
					_circle(img, _pxf(b, o[0], ppm), maxf(float(o[1]) * ppm, 2.0), Color(0.15, 0.13, 0.12, 0.85))
	# Elementi di gioco
	for n in level_root.find_children("*", "", true, false):
		if not n is Node3D:
			continue
		var o := b._gx(n as Node3D).origin
		var p := _pxf(b, Vector2(o.x, o.z), ppm)
		if n is EncounterZone:
			var ez := n as EncounterZone
			var col := Color(0.95, 0.2, 0.15)
			if ez.elite:
				col = Color(0.3, 0.55, 1.0)
			if ez.unique_id != "":
				col = Color(1.0, 0.55, 0.1)
			_ring(img, p, ez.radius * ppm, col)
			_circle(img, p, 2.0 + ez.count * 0.6 + (4.0 if ez.unique_id != "" else 0.0), col)
		elif n is Chest:
			img.fill_rect(Rect2i(Vector2i(p) - Vector2i(4, 4), Vector2i(9, 9)), Color(1.0, 0.8, 0.2))
		elif n is Checkpoint:
			_diamond(img, p, 7, Color(0.35, 0.85, 1.0))
		elif n is Npc:
			_circle(img, p, 4.0, Color(1.0, 0.92, 0.3))
		elif n is Stash:
			img.fill_rect(Rect2i(Vector2i(p) - Vector2i(4, 4), Vector2i(9, 9)), Color(0.7, 0.4, 1.0))
		elif n is LevelExit:
			img.fill_rect(Rect2i(Vector2i(p) - Vector2i(10, 4), Vector2i(21, 9)), Color(0.3, 1.0, 0.4))
		elif n is Marker3D and n.name == "PlayerStart":
			_diamond(img, p, 8, Color.WHITE)
	return img


## Salva la pianta in docs/mappe/<nome scena>.png e ritorna il percorso ("" se fallisce).
static func export(level_root: Node3D, scene_path: String) -> String:
	var img := render(level_root)
	if img == null:
		return ""
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out := OUT_DIR + scene_path.get_file().get_basename() + ".png"
	img.save_png(out)
	return out


static func _px(b: MapBuilder, p: Vector2, ppm: float) -> Vector2i:
	return Vector2i(int((p.x - b.xmin) * ppm), int((p.y - b.zmin) * ppm))


static func _pxf(b: MapBuilder, p: Vector2, ppm: float) -> Vector2:
	return Vector2((p.x - b.xmin) * ppm, (p.y - b.zmin) * ppm)


static func _blend(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _circle(img: Image, c: Vector2, r: float, col: Color) -> void:
	var ri := int(ceilf(r))
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if dx * dx + dy * dy <= r * r:
				_blend(img, int(c.x) + dx, int(c.y) + dy, col)


static func _ring(img: Image, c: Vector2, r: float, col: Color) -> void:
	var steps := maxi(24, int(r * 4.0))
	for i in steps:
		var a := TAU * i / steps
		var p := c + Vector2(cos(a), sin(a)) * r
		_blend(img, int(p.x), int(p.y), col)
		_blend(img, int(p.x) + 1, int(p.y), col)


static func _diamond(img: Image, c: Vector2, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var span := r - absi(dy)
		for dx in range(-span, span + 1):
			_blend(img, int(c.x) + dx, int(c.y) + dy, col)


static func _line(img: Image, b: MapBuilder, a: Vector2, c: Vector2, half: float, col: Color, ppm: float) -> void:
	var pa := _pxf(b, a, ppm)
	var pc := _pxf(b, c, ppm)
	var length := pa.distance_to(pc)
	var steps := maxi(1, int(length / maxf(half * 0.7, 1.0)))
	for i in steps + 1:
		_circle(img, pa.lerp(pc, float(i) / steps), maxf(half, 1.0), col)
