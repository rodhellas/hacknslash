@tool
class_name MapBuilder
extends RefCounted
## COSTRUTTORE DEL TERRENO a partire dalla Forma del livello (nodo MapShape, di solito "Forma").
## Rigenera SOLO i gruppi in GENERATED sotto il nodo World (terreno, confini, strade, acqua,
## vegetazione, lampioni) e ricalcola la navmesh. Tutto il resto del livello resta com'è:
## la vegetazione evita gli oggetti piazzati a mano.
## Usato dal pannello Mappa dell'editor (addons/legio_map) e dai generatori (tools/build_*.gd).

const GENERATED := ["Terreno", "Confini", "Strade", "Acqua", "Vegetazione", "ArredoStradale"]
const PROPS_DIR := "res://scenes/props/"

var root: Node3D
var world: Node3D
var shape: MapShape
var cell := 8.0
var xmin := 0.0
var zmin := 0.0
var nx := 0
var nz := 0
## Stato delle celle: 0 fuori, 1 calpestabile, 2 acqua
var state := PackedByteArray()
var zone_of: Array = []
var no_scatter := PackedByteArray()
var roads_data: Array = []     # [MapRoad, punti, mezze larghezze]
var polys_data: Array = []     # [MapPolygon, vertici]
var paved: Array = []          # [a, b, mezza larghezza lastricato]
var paved_buckets := {}
var obstacles: Array = []      # [centro, raggio]
var _obst_buckets := {}
var rng := RandomNumberGenerator.new()
var report := PackedStringArray()
var _scenes := {}


static func find_shape(level_root: Node) -> MapShape:
	var list := level_root.find_children("*", "MapShape", true, false)
	return list[0] if not list.is_empty() else null


## Ricostruisce il terreno. Ritorna un resoconto leggibile.
func build(level_root: Node3D, bake: bool = true) -> String:
	report = PackedStringArray()
	var t0 := Time.get_ticks_msec()
	if not rasterize(level_root):
		return "\n".join(report)
	world = root.get_node_or_null("World") as Node3D
	if world == null:
		var region := NavigationRegion3D.new()
		region.name = "World"
		root.add_child(region)
		region.owner = root
		world = region
	for gname: String in GENERATED:
		var old := world.get_node_or_null(gname)
		if old != null:
			world.remove_child(old)
			old.free()
	_collect_obstacles(false)
	rng.seed = shape.seed
	_build_ground()
	_build_borders()
	_build_water()
	_build_roads()
	_build_lamps()
	_build_scatter()
	var textured := Terrain.texture_world(world)
	if textured > 0:
		report.append("Texture del terreno su %d pezzi." % textured)
	_check_hand_content()
	if bake:
		_bake()
	report.insert(0, "Terreno ricostruito in %d ms (%d × %d celle da %d m)." % [Time.get_ticks_msec() - t0, nx, nz, int(cell)])
	return "\n".join(report)


# ==================================================================================================
#  Rasterizzazione della forma in celle
# ==================================================================================================

func rasterize(level_root: Node3D) -> bool:
	root = level_root
	shape = find_shape(root)
	if shape == null:
		report.append("Nessuna Forma (MapShape) nel livello: aggiungila dal pannello Mappa.")
		return false
	cell = maxf(shape.cell_size, 2.0)
	roads_data.clear()
	polys_data.clear()
	var areas_data: Array = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r: MapRoad in shape.roads():
		var s := r.sample(_gx(r), 2.0)
		roads_data.append([r, s[0], s[1]])
		var pts: PackedVector2Array = s[0]
		var ws: PackedFloat32Array = s[1]
		for i in pts.size():
			lo = lo.min(pts[i] - Vector2.ONE * ws[i])
			hi = hi.max(pts[i] + Vector2.ONE * ws[i])
	for a: MapArea in shape.areas():
		var o := _gx(a).origin
		var c := Vector2(o.x, o.z)
		areas_data.append([a, c])
		if a.walkable:
			lo = lo.min(c - Vector2.ONE * a.radius)
			hi = hi.max(c + Vector2.ONE * a.radius)
	for p: MapPolygon in shape.polygons():
		var poly := p.polygon(_gx(p))
		polys_data.append([p, poly])
		if p.mode == "terra":
			for v in poly:
				lo = lo.min(v)
				hi = hi.max(v)
	if lo.x == INF:
		report.append("La Forma è vuota: aggiungi almeno una strada, un'area o un poligono di terra.")
		return false
	xmin = floorf(lo.x / cell) * cell - 2.0 * cell
	zmin = floorf(lo.y / cell) * cell - 2.0 * cell
	nx = int(ceilf((hi.x - xmin) / cell)) + 2
	nz = int(ceilf((hi.y - zmin) / cell)) + 2
	var n := nx * nz
	var land := PackedByteArray()
	var water := PackedByteArray()
	var over := PackedByteArray()
	var voids := PackedByteArray()
	var pri := PackedByteArray()
	# (gli array "packed" sono valori: vanno ridimensionati uno per uno)
	land.resize(n)
	water.resize(n)
	over.resize(n)
	voids.resize(n)
	pri.resize(n)
	no_scatter = PackedByteArray()
	no_scatter.resize(n)
	zone_of = []
	zone_of.resize(n)
	zone_of.fill("")

	# Strade
	for rd: Array in roads_data:
		var r: MapRoad = rd[0]
		var pts: PackedVector2Array = rd[1]
		var ws: PackedFloat32Array = rd[2]
		# Larghezza minima mezza cella: anche ponti e sentieri stretti coprono almeno una cella
		var wmin := cell * 0.5
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var wmax := maxf(maxf(ws[i - 1], ws[i]), wmin)
			for k in _cells_in_rect(a.min(b) - Vector2.ONE * wmax, a.max(b) + Vector2.ONE * wmax):
				var c := _center(k)
				var sd := _seg_dist(c, a, b)
				if sd.x <= maxf(lerpf(ws[i - 1], ws[i], sd.y), wmin):
					if r.over_water:
						over[k] = 1
					else:
						land[k] = 1
					if r.zone != "" and pri[k] < 1:
						zone_of[k] = r.zone
						pri[k] = 1
	# Poligoni
	for pd: Array in polys_data:
		var p: MapPolygon = pd[0]
		var poly: PackedVector2Array = pd[1]
		if poly.size() < 3:
			continue
		var plo := Vector2(INF, INF)
		var phi := Vector2(-INF, -INF)
		for v in poly:
			plo = plo.min(v)
			phi = phi.max(v)
		for k in _cells_in_rect(plo, phi):
			if not Geometry2D.is_point_in_polygon(_center(k), poly):
				continue
			match p.mode:
				"acqua": water[k] = 1
				"vuoto": voids[k] = 1
				_:
					if p.over_water:
						over[k] = 1
					else:
						land[k] = 1
			if p.zone != "" and pri[k] < 2:
				zone_of[k] = p.zone
				pri[k] = 2
			if not p.scatter:
				no_scatter[k] = 1
	# Aree
	for ad: Array in areas_data:
		var a: MapArea = ad[0]
		var c0: Vector2 = ad[1]
		for k in _cells_in_rect(c0 - Vector2.ONE * a.radius, c0 + Vector2.ONE * a.radius):
			if _center(k).distance_to(c0) > a.radius:
				continue
			if a.walkable:
				if a.over_water:
					over[k] = 1
				else:
					land[k] = 1
			if a.zone != "" and pri[k] < 3:
				zone_of[k] = a.zone
				pri[k] = 3
			if not a.scatter:
				no_scatter[k] = 1
	# Stato finale
	state = PackedByteArray()
	state.resize(n)
	for k in n:
		if over[k] == 1:
			state[k] = 1
		elif water[k] == 1:
			state[k] = 2
		elif voids[k] == 1:
			state[k] = 0
		elif land[k] == 1:
			state[k] = 1
	# Zone lungo la strada principale per le celle senza zona
	var mr := shape.main_road()
	var mpts := PackedVector2Array()
	var mcum := PackedFloat32Array()
	if mr != null:
		for rd: Array in roads_data:
			if rd[0] == mr:
				var all_pts: PackedVector2Array = rd[1]
				for i in range(0, all_pts.size(), 4):
					mpts.append(all_pts[i])
				mpts.append(all_pts[all_pts.size() - 1])
		var acc := 0.0
		for i in mpts.size():
			if i > 0:
				acc += mpts[i].distance_to(mpts[i - 1])
			mcum.append(acc)
	for k in n:
		if state[k] != 1 or pri[k] > 0:
			continue
		if mpts.size() >= 2:
			var best := INF
			var best_s := 0.0
			for i in range(1, mpts.size()):
				var sd := _seg_dist(_center(k), mpts[i - 1], mpts[i])
				if sd.x < best:
					best = sd.x
					best_s = lerpf(mcum[i - 1], mcum[i], sd.y)
			var z := mr.zone_at(best_s / maxf(mcum[mcum.size() - 1], 1.0))
			zone_of[k] = z if z != "" else shape.default_zone
		else:
			zone_of[k] = shape.default_zone
	# Lastricati (per tenere la vegetazione lontana dalle strade)
	paved.clear()
	paved_buckets.clear()
	for rd: Array in roads_data:
		var r: MapRoad = rd[0]
		if r.paved_width <= 0.0:
			continue
		var pts: PackedVector2Array = rd[1]
		var hw := r.paved_width * 0.5
		for i in range(1, pts.size()):
			var si := paved.size()
			paved.append([pts[i - 1], pts[i], hw])
			var m := hw + 6.0
			for k in _cells_in_rect(pts[i - 1].min(pts[i]) - Vector2.ONE * m, pts[i - 1].max(pts[i]) + Vector2.ONE * m):
				if not paved_buckets.has(k):
					paved_buckets[k] = []
				paved_buckets[k].append(si)
	return true


# ==================================================================================================
#  Costruzione
# ==================================================================================================

func _build_ground() -> void:
	var ground := _group("Terreno")
	var base := MeshInstance3D.new()
	base.name = "Sfondo"
	var pm := PlaneMesh.new()
	pm.size = Vector2(nx * cell + 400.0, nz * cell + 400.0)
	base.mesh = pm
	base.material_override = Fx.mat(shape.background_color, 0.15 if shape.background_y < -0.1 else 0.0)
	base.position = Vector3(xmin + nx * cell * 0.5, shape.background_y, zmin + nz * cell * 0.5)
	_add(ground, base)
	var runs := 0
	for iz in nz:
		var ix := 0
		while ix < nx:
			var k := iz * nx + ix
			if state[k] != 1:
				ix += 1
				continue
			var z: String = zone_of[k]
			var start := ix
			while ix < nx and state[iz * nx + ix] == 1 and zone_of[iz * nx + ix] == z:
				ix += 1
			var count := ix - start
			var sb := StaticBody3D.new()
			sb.name = "Suolo_%d" % runs
			sb.collision_layer = Layers.WORLD
			sb.collision_mask = 0
			sb.position = Vector3(xmin + (start + count * 0.5) * cell, -0.5, zmin + (iz + 0.5) * cell)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(count * cell, 1.0, cell)
			cs.shape = bs
			sb.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = bs.size
			mi.mesh = bm
			mi.material_override = Fx.mat((MapZones.get_zone(z)["color"] as Color).darkened(0.04 * (iz % 2)))
			sb.add_child(mi)
			_add(ground, sb)
			runs += 1
	report.append("Terreno: %d strisce." % runs)


func _build_borders() -> void:
	var g := _group("Confini")
	var props := 0
	var walls := 0
	for iz in nz:
		for ix in nx:
			var k := iz * nx + ix
			if state[k] == 1:
				continue
			var nz_zone := ""
			var near := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var jx := ix + dx
					var jz := iz + dz
					if jx >= 0 and jx < nx and jz >= 0 and jz < nz and state[jz * nx + jx] == 1:
						near = true
						nz_zone = zone_of[jz * nx + jx]
			if not near:
				continue
			var c := _center(k)
			var border := String(MapZones.get_zone(nz_zone)["border"])
			if state[k] == 2 or border == "" or not ResourceLoader.exists(PROPS_DIR + border + ".tscn"):
				var blk := StaticBody3D.new()
				blk.name = "Blocco_%d" % walls
				blk.collision_layer = Layers.WORLD
				blk.collision_mask = 0
				blk.position = Vector3(c.x, 1.5, c.y)
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(cell, 3.0, cell)
				cs.shape = bs
				blk.add_child(cs)
				_add(g, blk)
				walls += 1
			else:
				var inst := _instance(border)
				inst.position = Vector3(c.x, 0.0, c.y)
				inst.rotation_degrees.y = 90.0 * rng.randi_range(0, 3)
				if cell != 8.0:
					inst.scale = Vector3(cell / 8.0, 1.0, cell / 8.0)
				_add(g, inst)
				props += 1
	report.append("Confini: %d blocchi decorati, %d muri invisibili." % [props, walls])


func _build_water() -> void:
	var g := _group("Acqua")
	var n := 0
	for pd: Array in polys_data:
		var p: MapPolygon = pd[0]
		if p.mode != "acqua" or (pd[1] as PackedVector2Array).size() < 3:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Acqua_%s" % p.name
		mi.mesh = MapPolygon.polygon_mesh(pd[1], 0.03, Fx.mat(shape.water_color, 0.2))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(g, mi)
		n += 1
	if n > 0:
		report.append("Acqua: %d specchi d'acqua." % n)


func _build_roads() -> void:
	var g := _group("Strade")
	for rd: Array in roads_data:
		var r: MapRoad = rd[0]
		if r.paved_width <= 0.0:
			continue
		var pts: PackedVector2Array = rd[1]
		var y := 0.06 if r.over_water else 0.02
		var am := ArrayMesh.new()
		var hw := PackedFloat32Array()
		hw.resize(pts.size())
		hw.fill(r.paved_width * 0.5)
		MapRoad.add_ribbon(am, pts, hw, y, Fx.mat(r.paved_color))
		if r.curbs:
			var cw := PackedFloat32Array()
			cw.resize(pts.size())
			cw.fill(0.2)
			for side: float in [-1.0, 1.0]:
				MapRoad.add_ribbon(am, _offset(pts, (r.paved_width * 0.5 + 0.2) * side), cw, y + 0.03, Fx.mat(r.paved_color.darkened(0.25)))
		var mi := MeshInstance3D.new()
		mi.name = "Strada_%s" % r.name
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(g, mi)


func _build_lamps() -> void:
	var g := _group("ArredoStradale")
	var placed := 0
	for rd: Array in roads_data:
		var r: MapRoad = rd[0]
		if r.lamp_spacing <= 0.0 or not ResourceLoader.exists(PROPS_DIR + r.lamp_prop + ".tscn"):
			continue
		var pts: PackedVector2Array = rd[1]
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var total := cum[cum.size() - 1]
		var s := 30.0
		var side := 1.0
		var idx := 0
		var j := 1
		while s < total - 10.0:
			while j < pts.size() - 1 and cum[j] < s:
				j += 1
			var t := (s - cum[j - 1]) / maxf(cum[j] - cum[j - 1], 0.001)
			var p := pts[j - 1].lerp(pts[j], t)
			var d := (pts[j] - pts[j - 1]).normalized()
			var nrm := Vector2(-d.y, d.x)
			var off := r.paved_width * 0.5 + 1.6
			var q := p + nrm * off * side
			if _placeable(q, 1.2):
				_put(g, r.lamp_prop, q, 0.0, 1.0)
				placed += 1
			if r.milestone_every > 0 and idx % r.milestone_every == r.milestone_every / 2:
				var m := p - nrm * off * side
				if _placeable(m, 1.0) and ResourceLoader.exists(PROPS_DIR + "miliario.tscn"):
					_put(g, "miliario", m, 0.0, 1.0)
			side = -side
			s += r.lamp_spacing
			idx += 1
	if placed > 0:
		report.append("Lampioni: %d." % placed)


func _build_scatter() -> void:
	var g := _group("Vegetazione")
	var count := 0
	var jit := cell * 0.45
	for iz in nz:
		for ix in nx:
			var k := iz * nx + ix
			if state[k] != 1:
				continue
			var entries: Array = MapZones.get_zone(zone_of[k])["scatter"]
			for entry: Array in entries:
				if rng.randf() >= float(entry[1]):
					continue
				var pname: String = entry[0]
				var p := _center(k) + Vector2(rng.randf_range(-jit, jit), rng.randf_range(-jit, jit))
				var pk := _cell_of(p)
				if pk < 0 or state[pk] != 1 or no_scatter[pk] == 1:
					continue
				var big := pname in MapZones.BIG_PROPS
				var rad := 2.0 if big else 0.8
				var near_water := _near_water(pk)
				if pname in MapZones.WATER_EDGE_PROPS:
					if not near_water:
						continue
				elif near_water and big:
					continue
				if _paved_clearance(p) < (2.5 if big else 1.0) + shape.scatter_road_margin - 1.0:
					continue
				if not _free(p, rad):
					continue
				var sc := rng.randf_range(0.85, 1.25) if big else rng.randf_range(0.8, 1.2)
				_put(g, pname, p, rng.randf() * 360.0, sc)
				_add_obstacle(p, rad)
				count += 1
	report.append("Vegetazione e oggetti sparsi: %d." % count)


func _check_hand_content() -> void:
	var warn := 0
	for n in root.find_children("*", "", true, false):
		if not (n is Node3D) or _is_generated(n):
			continue
		var what := ""
		if n is EncounterZone:
			what = "zona nemici"
		elif n is Chest:
			what = "forziere"
		elif n is Checkpoint:
			what = "altare"
		elif n is Npc:
			what = "NPC"
		elif n is LevelExit:
			what = "uscita"
		elif n is Marker3D and n.get_parent() == root:
			what = "punto di arrivo"
		if what == "":
			continue
		var o := _gx(n as Node3D).origin
		var k := _cell_of(Vector2(o.x, o.z))
		if k < 0 or state[k] != 1:
			var ok := false
			# Uscite e altari possono stare sul bordo: basta una cella calpestabile vicina
			if what in ["uscita", "altare", "forziere", "NPC"] and k >= 0:
				ok = _has_land_neighbor(k)
			if not ok:
				report.append("ATTENZIONE: %s \"%s\" è fuori dall'area calpestabile (%d, %d)." % [what, n.name, roundi(o.x), roundi(o.z)])
				warn += 1
	if warn == 0:
		report.append("Tutti i luoghi, nemici, forzieri, altari e NPC sono nell'area calpestabile.")


func _bake() -> void:
	if not world is NavigationRegion3D:
		report.append("Il nodo World non è una NavigationRegion3D: navmesh non calcolata.")
		return
	var region := world as NavigationRegion3D
	var nm := region.navigation_mesh
	if nm == null:
		nm = NavigationMesh.new()
		region.navigation_mesh = nm
	nm.cell_size = 0.4
	nm.cell_height = 0.25
	nm.agent_radius = 0.4
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.region_min_size = 30.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	if not region.is_inside_tree():
		report.append("Livello fuori dall'albero di scena: navmesh non calcolata.")
		return
	region.bake_navigation_mesh(false)
	report.append("Navmesh: %d poligoni." % nm.get_polygon_count())


# ==================================================================================================
#  Ostacoli (oggetti piazzati a mano) e utilità
# ==================================================================================================

## Raccoglie gli ingombri degli oggetti del livello. include_generated = anche vegetazione e confini.
func _collect_obstacles(include_generated: bool) -> void:
	obstacles.clear()
	_obst_buckets.clear()
	if world == null:
		world = root.get_node_or_null("World") as Node3D
	var start: Node = world if world != null else root
	for c in start.get_children():
		if not include_generated and String(c.name) in GENERATED:
			continue
		_collect_from(c)


func _collect_from(n: Node) -> void:
	if n is MapShape:
		return
	if n is Node3D and n.scene_file_path != "":
		var box := _world_aabb(n as Node3D)
		if box.size != Vector3.ZERO:
			var c := box.get_center()
			_add_obstacle(Vector2(c.x, c.z), maxf(box.size.x, box.size.z) * 0.5)
			return
	if n is CollisionShape3D and (n as CollisionShape3D).shape != null:
		var cs := n as CollisionShape3D
		var o := _gx(cs).origin
		var r := 0.5
		if cs.shape is BoxShape3D:
			var s := (cs.shape as BoxShape3D).size
			r = maxf(s.x, s.z) * 0.5
		elif cs.shape is CylinderShape3D:
			r = (cs.shape as CylinderShape3D).radius
		elif cs.shape is SphereShape3D:
			r = (cs.shape as SphereShape3D).radius
		elif cs.shape is CapsuleShape3D:
			r = (cs.shape as CapsuleShape3D).radius
		_add_obstacle(Vector2(o.x, o.z), r)
	for c in n.get_children():
		_collect_from(c)


func _world_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b := _gx(mi) * mi.mesh.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


func _add_obstacle(p: Vector2, r: float) -> void:
	var idx := obstacles.size()
	obstacles.append([p, r])
	var key := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	var span := int(ceilf(r / 8.0))
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var kk := key + Vector2i(dx, dz)
			if not _obst_buckets.has(kk):
				_obst_buckets[kk] = []
			_obst_buckets[kk].append(idx)


func _free(p: Vector2, r: float) -> bool:
	var key := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for idx: int in _obst_buckets.get(key + Vector2i(dx, dz), []):
				var o: Array = obstacles[idx]
				if p.distance_to(o[0]) < r + float(o[1]):
					return false
	return true


func _placeable(p: Vector2, r: float) -> bool:
	var k := _cell_of(p)
	return k >= 0 and state[k] == 1 and not _near_water(k) and _free(p, r) and _paved_clearance(p) > 0.3


func _paved_clearance(p: Vector2) -> float:
	var k := _cell_of(p)
	var best := INF
	for si: int in paved_buckets.get(k, []):
		var s: Array = paved[si]
		best = minf(best, _seg_dist(p, s[0], s[1]).x - float(s[2]))
	return best


func _near_water(k: int) -> bool:
	var ix := k % nx
	var iz := k / nx
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var jx := ix + dx
			var jz := iz + dz
			if jx >= 0 and jx < nx and jz >= 0 and jz < nz and state[jz * nx + jx] == 2:
				return true
	return false


func _has_land_neighbor(k: int) -> bool:
	var ix := k % nx
	var iz := k / nx
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var jx := ix + dx
			var jz := iz + dz
			if jx >= 0 and jx < nx and jz >= 0 and jz < nz and state[jz * nx + jx] == 1:
				return true
	return false


func _is_generated(n: Node) -> bool:
	var cur := n
	while cur != null and cur != root:
		if cur.get_parent() == world and String(cur.name) in GENERATED:
			return true
		if cur is MapShape:
			return true
		cur = cur.get_parent()
	return false


## Trasformazione di un nodo rispetto alla radice del livello (funziona anche fuori dall'albero).
func _gx(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _center(k: int) -> Vector2:
	return Vector2(xmin + (k % nx + 0.5) * cell, zmin + (k / nx + 0.5) * cell)


func _cell_of(p: Vector2) -> int:
	var ix := floori((p.x - xmin) / cell)
	var iz := floori((p.y - zmin) / cell)
	if ix < 0 or ix >= nx or iz < 0 or iz >= nz:
		return -1
	return iz * nx + ix


func _cells_in_rect(lo: Vector2, hi: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := clampi(floori((lo.x - xmin) / cell), 0, nx - 1)
	var x1 := clampi(floori((hi.x - xmin) / cell), 0, nx - 1)
	var z0 := clampi(floori((lo.y - zmin) / cell), 0, nz - 1)
	var z1 := clampi(floori((hi.y - zmin) / cell), 0, nz - 1)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			out.append(iz * nx + ix)
	return out


## Distanza dal segmento ab (x) e posizione lungo il segmento 0-1 (y).
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.0001 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)


static func _offset(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var d := (b - a).normalized()
		out.append(pts[i] + Vector2(-d.y, d.x) * off)
	return out


func _group(gname: String) -> Node3D:
	var g := Node3D.new()
	g.name = gname
	world.add_child(g)
	g.owner = root
	return g


func _add(parent: Node, n: Node) -> void:
	parent.add_child(n)
	_own(n)


func _own(n: Node) -> void:
	n.owner = root
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


func _instance(pname: String) -> Node3D:
	if not _scenes.has(pname):
		_scenes[pname] = load(PROPS_DIR + pname + ".tscn")
	return (_scenes[pname] as PackedScene).instantiate()


func _put(parent: Node, pname: String, p: Vector2, rot: float, sc: float) -> void:
	var inst := _instance(pname)
	inst.position = Vector3(p.x, 0.0, p.y)
	inst.rotation_degrees.y = rot
	if sc != 1.0:
		inst.scale = Vector3.ONE * sc
	_add(parent, inst)
