extends SceneTree
## GENERATORE GRAYBOXING
## Crea:
##   scenes/props/*.tscn        oggetti di scena (alberi, colonne, case...) -> da sostituire con modelli Tripo
##   scenes/characters/*.tscn   modelli segnaposto delle 4 classi
##   scenes/enemies/*.tscn      modelli segnaposto dei nemici
##   scenes/npcs/*.tscn         modelli segnaposto dei personaggi non giocanti
##   scenes/levels/level_01.tscn  la mappa del livello 1, con navmesh già calcolata
##   (la città di Ostia Nova ha il suo generatore: tools/build_ostia.gd, che riusa questo file)
##
## Uso (da terminale, nella cartella del progetto):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_world.gd
## Opzioni dopo "--":  props  models  level   (default: tutto)
##                     missing  = crea SOLO props e modelli che non esistono ancora (non tocca gli altri)
##
## ATTENZIONE: rigenerare il livello SOVRASCRIVE level_01.tscn. Quando inizierai a ritoccare la
## mappa a mano nell'editor, non rigenerarla più (puoi ancora rigenerare props e modelli).

const SEED := 3000
const CELL := 8.0
const X0 := -232.0
const Z0 := 72.0
const NX := 66
const NZ := 128

# Palette grayboxing
const BARK := Color(0.35, 0.24, 0.15)
const PINE := Color(0.16, 0.32, 0.17)
const LEAF := Color(0.24, 0.42, 0.2)
const OLIVE := Color(0.45, 0.52, 0.36)
const CYPRESS := Color(0.12, 0.26, 0.14)
const STONE := Color(0.55, 0.53, 0.5)
const MARBLE := Color(0.86, 0.84, 0.79)
const ROCK := Color(0.42, 0.4, 0.38)
const WOOD := Color(0.45, 0.32, 0.2)
const HAY := Color(0.8, 0.68, 0.3)
const TERRACOTTA := Color(0.7, 0.38, 0.22)
const ROOF := Color(0.62, 0.25, 0.15)
const PLASTER := Color(0.82, 0.76, 0.62)
const GOLD := Color(0.9, 0.72, 0.3)
const RED := Color(0.65, 0.08, 0.08)
const PLASMA := Color(0.2, 0.9, 1.0)
const METAL := Color(0.4, 0.42, 0.46)
const CLOTH := Color(0.6, 0.5, 0.36)
const FIRE := Color(1.0, 0.5, 0.1)

## Percorso principale (x, z). Nord = z negativo. Dalla villa (sud) alla porta di Ostia Nova (nord).
const ROAD := [
	Vector2(0, 0), Vector2(0, -60), Vector2(40, -110), Vector2(100, -140), Vector2(150, -200),
	Vector2(140, -270), Vector2(90, -320), Vector2(60, -380), Vector2(0, -420), Vector2(-60, -470),
	Vector2(-80, -540), Vector2(-40, -610), Vector2(30, -650), Vector2(90, -700), Vector2(100, -780),
	Vector2(60, -840), Vector2(50, -895),
]
## Mezza larghezza esplorabile attorno a ogni tratto di strada
const ROAD_HW := [40, 40, 38, 34, 24, 24, 26, 26, 26, 30, 30, 28, 28, 28, 34, 34]

## Aree laterali esplorabili (centro, raggio, zona)
const SIDE := [
	[Vector2(0, 15), 42.0, "fattoria"],
	[Vector2(-58, -98), 26.0, "fattoria"],
	[Vector2(205, -250), 28.0, "relitto"],
	[Vector2(-110, -292), 25.0, "boschetto"],
	[Vector2(-115, -410), 34.0, "tempio"],
	[Vector2(-118, -548), 32.0, "campo"],
	[Vector2(150, -662), 26.0, "necropoli"],
	[Vector2(50, -905), 30.0, "citta"],
]
## Sentieri che collegano le aree laterali (da, a, mezza larghezza)
const PATHS := [
	[Vector2(5, -85), Vector2(-40, -95), 10.0],
	[Vector2(145, -238), Vector2(185, -246), 10.0],
	[Vector2(-108, -312), Vector2(-112, -382), 9.0],
	[Vector2(-8, -428), Vector2(-85, -412), 10.0],
	[Vector2(88, -692), Vector2(128, -668), 9.0],
]
const FORD := Vector2(-110, -334)

const ZONE_COLORS := {
	"fattoria": Color(0.42, 0.5, 0.26), "bosco": Color(0.22, 0.36, 0.18), "fiume": Color(0.3, 0.42, 0.24),
	"boschetto": Color(0.26, 0.4, 0.22), "tempio": Color(0.36, 0.42, 0.28), "relitto": Color(0.32, 0.34, 0.26),
	"campo": Color(0.45, 0.38, 0.27), "necropoli": Color(0.34, 0.36, 0.3), "citta": Color(0.5, 0.47, 0.4),
}
## Disseminazione casuale per zona: [oggetto, probabilità per cella 8x8 m]
const ZONE_SCATTER := {
	"fattoria": [["olivo", 0.22], ["cespuglio", 0.2], ["pino_marittimo", 0.08], ["roccia_piccola", 0.05], ["covone", 0.04]],
	"bosco": [["albero_pino", 0.55], ["albero_quercia", 0.35], ["cespuglio", 0.4], ["roccia_piccola", 0.1], ["tronco", 0.06], ["roccia_grande", 0.04]],
	"fiume": [["albero_quercia", 0.2], ["canne", 0.35], ["cespuglio", 0.3], ["roccia_piccola", 0.12]],
	"boschetto": [["cipresso", 0.2], ["albero_quercia", 0.3], ["cespuglio", 0.35]],
	"tempio": [["cipresso", 0.15], ["albero_quercia", 0.25], ["colonna_rotta", 0.04], ["cespuglio", 0.3], ["roccia_piccola", 0.08]],
	"relitto": [["albero_pino", 0.3], ["roccia_piccola", 0.2], ["cassa", 0.05], ["cespuglio", 0.2]],
	"campo": [["roccia_grande", 0.12], ["roccia_piccola", 0.22], ["albero_pino", 0.1], ["tronco", 0.05], ["cespuglio", 0.1]],
	"necropoli": [["cipresso", 0.28], ["cespuglio", 0.15], ["colonna_rotta", 0.03], ["sarcofago", 0.03]],
	"citta": [["pino_marittimo", 0.15], ["cipresso", 0.1], ["cespuglio", 0.2], ["cassa", 0.03]],
}
const BIG_PROPS := ["albero_pino", "albero_quercia", "pino_marittimo", "cipresso", "olivo", "roccia_grande", "colonna_rotta", "sarcofago", "covone", "tronco"]

var rng := RandomNumberGenerator.new()
var prop_scenes := {}
var road_cum: Array = []
var road_total := 0.0
var level_root: Node3D
var _occupied := {}
var _clear: Array = []   # [Vector2 centro, raggio] aree da non riempire con la disseminazione
var _bridge_c := Vector2.ZERO
var _bridge_d := Vector2.UP


var _done := false


func _process(_delta: float) -> bool:
	# La generazione parte al primo frame: serve che l'albero di scena sia attivo (navmesh).
	if not _done:
		_done = true
		_generate()
	return false


func _generate() -> void:
	var args := OS.get_cmdline_user_args()
	var all := args.is_empty()
	rng.seed = SEED
	_compute_road()
	if "missing" in args:
		_build_props(true)
		_build_models(true)
	if all or "props" in args or "level" in args:
		_build_props()
	if all or "models" in args:
		_build_models()
	if all or "level" in args:
		_build_level()
	print("Generazione completata.")
	quit()


# ==========================================================================================
#  Utilità geometriche
# ==========================================================================================

func _compute_road() -> void:
	road_cum = [0.0]
	for i in range(1, ROAD.size()):
		road_total += (ROAD[i] as Vector2).distance_to(ROAD[i - 1])
		road_cum.append(road_total)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Array:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return [p.distance_to(a + ab * t), t]


## [distanza dalla strada, ascissa curvilinea, indice tratto]
func _road_info(p: Vector2) -> Array:
	var best := [INF, 0.0, 0]
	for i in ROAD.size() - 1:
		var r := _seg_dist(p, ROAD[i], ROAD[i + 1])
		if r[0] < best[0]:
			var seg_len := (ROAD[i + 1] as Vector2).distance_to(ROAD[i])
			best = [r[0], float(road_cum[i]) + seg_len * float(r[1]), i]
	return best


func _road_point(s: float) -> Array:
	s = clampf(s, 0.0, road_total - 0.01)
	for i in ROAD.size() - 1:
		if s <= road_cum[i + 1]:
			var a: Vector2 = ROAD[i]
			var b: Vector2 = ROAD[i + 1]
			var t := (s - float(road_cum[i])) / a.distance_to(b)
			return [a.lerp(b, t), (b - a).normalized()]
	return [ROAD[-1], Vector2.UP]


func _allowed(p: Vector2) -> bool:
	for i in ROAD.size() - 1:
		if float(_seg_dist(p, ROAD[i], ROAD[i + 1])[0]) <= ROAD_HW[i]:
			return true
	for s: Array in SIDE:
		if p.distance_to(s[0]) <= float(s[1]):
			return true
	for c: Array in PATHS:
		if float(_seg_dist(p, c[0], c[1])[0]) <= float(c[2]):
			return true
	return false


func _zone(p: Vector2) -> String:
	for s: Array in SIDE:
		if p.distance_to(s[0]) <= float(s[1]):
			return s[2]
	var t := float(_road_info(p)[1]) / road_total
	if t < 0.17: return "fattoria"
	if t < 0.35: return "bosco"
	if t < 0.43: return "fiume"
	if t < 0.53: return "tempio"
	if t < 0.66: return "campo"
	if t < 0.83: return "necropoli"
	return "citta"


func _river_z(x: float) -> float:
	return -335.0 + 8.0 * sin(x * 0.03) + 3.0 * sin(x * 0.011 + 1.0)


func _in_river(p: Vector2, margin: float) -> bool:
	return absf(p.y - _river_z(p.x)) < 7.0 + margin


func _is_clear(p: Vector2) -> bool:
	for c: Array in _clear:
		if p.distance_to(c[0]) < float(c[1]):
			return false
	return true


func _free_spot(p: Vector2, r: float) -> bool:
	var k := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for q: Array in _occupied.get(k + Vector2i(dx, dz), []):
				if p.distance_to(q[0]) < r + float(q[1]):
					return false
	return true


func _occupy(p: Vector2, r: float) -> void:
	var k := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	if not _occupied.has(k):
		_occupied[k] = []
	_occupied[k].append([p, r])


static func _v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _perp(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x)


# ==========================================================================================
#  Costruzione mesh dai "pezzi"
#  pezzo = [forma, posizione, dimensioni, colore, emissione?, rotazione_gradi?, nome?]
#  forme: box(x,y,z)  cyl(raggio_sopra, altezza, raggio_sotto)  sphere(raggio, altezza)
#         capsule(raggio, altezza)  torus(int, est)  prism(x,y,z)
# ==========================================================================================

func _mesh(shape: String, s: Vector3) -> Mesh:
	match shape:
		"box":
			var m := BoxMesh.new()
			m.size = s
			return m
		"cyl":
			var m := CylinderMesh.new()
			m.top_radius = s.x
			m.height = s.y
			m.bottom_radius = s.z
			m.radial_segments = 12
			m.rings = 1
			return m
		"sphere":
			var m := SphereMesh.new()
			m.radius = s.x
			m.height = s.y
			m.radial_segments = 14
			m.rings = 7
			return m
		"capsule":
			var m := CapsuleMesh.new()
			m.radius = s.x
			m.height = s.y
			m.radial_segments = 12
			m.rings = 4
			return m
		"torus":
			var m := TorusMesh.new()
			m.inner_radius = s.x
			m.outer_radius = s.y
			return m
		"prism":
			var m := PrismMesh.new()
			m.size = s
			return m
	return BoxMesh.new()


func _part(parent: Node3D, owner_node: Node, p: Array, vis: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(p[0], p[2])
	var emission := float(p[4]) if p.size() > 4 else 0.0
	mi.material_override = Fx.mat(p[3], emission)
	mi.position = p[1]
	if p.size() > 5:
		mi.rotation_degrees = p[5]
	mi.name = String(p[6]) if p.size() > 6 and String(p[6]) != "" else "%s_%d" % [p[0], parent.get_child_count()]
	if emission > 0.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis > 0.0:
		mi.visibility_range_end = vis
		mi.visibility_range_end_margin = 6.0
	parent.add_child(mi)
	mi.owner = owner_node
	return mi


func _shape(c: Array) -> Shape3D:
	if c[0] == "cyl":
		var s := CylinderShape3D.new()
		s.radius = (c[2] as Vector3).x
		s.height = (c[2] as Vector3).y
		return s
	var b := BoxShape3D.new()
	b.size = c[2]
	return b


func _save_scene(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack fallito per %s" % path)
		return
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("salvataggio fallito per %s: %s" % [path, error_string(err)])


# ==========================================================================================
#  OGGETTI DI SCENA
# ==========================================================================================

func _prop_defs() -> Dictionary:
	var d := {}
	d["albero_pino"] = {"parts": [["cyl", Vector3(0, 1.5, 0), Vector3(0.22, 3, 0.3), BARK],
			["cyl", Vector3(0, 4.2, 0), Vector3(0, 4, 1.7), PINE], ["cyl", Vector3(0, 6, 0), Vector3(0, 3, 1.2), PINE]],
		"col": [["cyl", Vector3(0, 1.5, 0), Vector3(0.45, 3, 0)]], "occ": ["box", Vector3(0, 4.5, 0), Vector3(3, 5.5, 3)], "fade": true, "vis": 110.0}
	d["albero_quercia"] = {"parts": [["cyl", Vector3(0, 1.4, 0), Vector3(0.3, 2.8, 0.4), BARK],
			["sphere", Vector3(0, 4.2, 0), Vector3(2.4, 3.8, 0), LEAF], ["sphere", Vector3(1.2, 3.8, 0.6), Vector3(1.4, 2.4, 0), LEAF.darkened(0.1)]],
		"col": [["cyl", Vector3(0, 1.5, 0), Vector3(0.5, 3, 0)]], "occ": ["box", Vector3(0, 4, 0), Vector3(4.5, 4.5, 4.5)], "fade": true, "vis": 110.0}
	d["pino_marittimo"] = {"parts": [["cyl", Vector3(0, 2.5, 0), Vector3(0.2, 5, 0.28), BARK], ["sphere", Vector3(0, 5.6, 0), Vector3(2.8, 1.6, 0), PINE.lightened(0.1)]],
		"col": [["cyl", Vector3(0, 2, 0), Vector3(0.4, 4, 0)]], "occ": ["box", Vector3(0, 5.5, 0), Vector3(5, 2, 5)], "fade": true, "vis": 110.0}
	d["cipresso"] = {"parts": [["cyl", Vector3(0, 0.5, 0), Vector3(0.15, 1, 0.2), BARK], ["capsule", Vector3(0, 3.5, 0), Vector3(0.75, 6, 0), CYPRESS]],
		"col": [["cyl", Vector3(0, 1.5, 0), Vector3(0.5, 3, 0)]], "occ": ["box", Vector3(0, 3.5, 0), Vector3(1.4, 6, 1.4)], "fade": true, "vis": 110.0}
	d["olivo"] = {"parts": [["cyl", Vector3(0, 0.9, 0), Vector3(0.2, 1.8, 0.3), BARK], ["sphere", Vector3(0, 2.4, 0), Vector3(1.8, 1.8, 0), OLIVE]],
		"col": [["cyl", Vector3(0, 1, 0), Vector3(0.35, 2, 0)]], "occ": ["box", Vector3(0, 2.4, 0), Vector3(3.4, 1.8, 3.4)], "fade": true, "vis": 110.0}
	d["cespuglio"] = {"parts": [["sphere", Vector3(0, 0.5, 0), Vector3(0.9, 1.1, 0), LEAF.darkened(0.15)]], "vis": 90.0}
	d["canne"] = {"parts": [["cyl", Vector3(0.2, 0.8, 0), Vector3(0.04, 1.6, 0.05), Color(0.5, 0.55, 0.3)],
			["cyl", Vector3(-0.2, 0.9, 0.15), Vector3(0.04, 1.8, 0.05), Color(0.45, 0.5, 0.28)],
			["cyl", Vector3(0, 0.7, -0.2), Vector3(0.04, 1.4, 0.05), Color(0.52, 0.56, 0.3)]], "vis": 80.0}
	d["roccia_piccola"] = {"parts": [["box", Vector3(0, 0.35, 0), Vector3(1.2, 0.7, 1), ROCK, 0.0, Vector3(10, 20, 8)]],
		"col": [["box", Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 0.9)]], "vis": 100.0}
	d["roccia_grande"] = {"parts": [["box", Vector3(0, 1.2, 0), Vector3(3, 2.4, 2.6), ROCK, 0.0, Vector3(0, 15, 6)],
			["box", Vector3(1.4, 0.8, 1), Vector3(1.8, 1.6, 1.6), ROCK.darkened(0.1), 0.0, Vector3(0, 40, -8)]],
		"col": [["box", Vector3(0.3, 1.2, 0.3), Vector3(3.6, 2.4, 3.2)]], "fade": true, "vis": 120.0}
	d["scogliera"] = {"parts": [["box", Vector3(0, 2.5, 0), Vector3(8.2, 5, 8.2), ROCK],
			["box", Vector3(1.5, 5.5, -1), Vector3(5, 2.5, 5), ROCK.darkened(0.1), 0.0, Vector3(0, 20, 0)],
			["box", Vector3(-2, 4.5, 2), Vector3(4, 3, 3.5), ROCK.lightened(0.05), 0.0, Vector3(0, -15, 5)]],
		"col": [["box", Vector3(0, 3, 0), Vector3(8, 6, 8)]], "fade": true}
	d["bosco_fitto"] = {"parts": [["box", Vector3(0, 0.6, 0), Vector3(8, 1.2, 8), PINE.darkened(0.35)],
			["cyl", Vector3(-2.2, 4, -2), Vector3(0, 7, 2.4), PINE], ["cyl", Vector3(2.3, 4.5, -1.5), Vector3(0, 8, 2.6), PINE.darkened(0.1)],
			["cyl", Vector3(-1.5, 4.2, 2.4), Vector3(0, 7.5, 2.5), PINE.lightened(0.05)], ["cyl", Vector3(2, 3.8, 2.2), Vector3(0, 6.5, 2.2), PINE]],
		"col": [["box", Vector3(0, 3, 0), Vector3(8, 6, 8)]], "fade": true}
	d["cassa"] = {"parts": [["box", Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), WOOD]], "col": [["box", Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2)]], "vis": 100.0}
	d["barile"] = {"parts": [["cyl", Vector3(0, 0.55, 0), Vector3(0.45, 1.1, 0.45), WOOD.darkened(0.1)]], "col": [["cyl", Vector3(0, 0.55, 0), Vector3(0.45, 1.1, 0)]], "vis": 100.0}
	d["anfora"] = {"parts": [["sphere", Vector3(0, 0.45, 0), Vector3(0.35, 0.8, 0), TERRACOTTA], ["cyl", Vector3(0, 0.95, 0), Vector3(0.12, 0.3, 0.15), TERRACOTTA]],
		"col": [["box", Vector3(0, 0.5, 0), Vector3(0.8, 1, 0.8)]], "script": "res://world/breakable.gd", "vis": 90.0}
	d["forziere"] = {"parts": [["box", Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 0.9), WOOD],
			["box", Vector3(0, 0.82, 0), Vector3(1.45, 0.25, 0.95), GOLD, 0.2, Vector3.ZERO, "Lid"],
			["box", Vector3(0, 0.5, -0.47), Vector3(0.25, 0.3, 0.05), GOLD, 1.0]],
		"col": [["box", Vector3(0, 0.5, 0), Vector3(1.4, 1, 0.9)]], "script": "res://world/chest.gd"}
	d["colonna"] = {"parts": [["cyl", Vector3(0, 0.2, 0), Vector3(0.85, 0.4, 0.85), MARBLE], ["cyl", Vector3(0, 3, 0), Vector3(0.55, 5.2, 0.62), MARBLE],
			["box", Vector3(0, 5.75, 0), Vector3(1.5, 0.4, 1.5), MARBLE]],
		"col": [["cyl", Vector3(0, 3, 0), Vector3(0.7, 6, 0)]], "fade": true}
	d["colonna_rotta"] = {"parts": [["cyl", Vector3(0, 0.2, 0), Vector3(0.85, 0.4, 0.85), MARBLE], ["cyl", Vector3(0, 1.2, 0), Vector3(0.55, 1.8, 0.62), MARBLE],
			["cyl", Vector3(1.6, 0.5, 0.4), Vector3(0.5, 2.6, 0.5), MARBLE.darkened(0.1), 0.0, Vector3(0, 30, 90)]],
		"col": [["cyl", Vector3(0, 1, 0), Vector3(0.7, 2, 0)]], "vis": 120.0}
	d["statua"] = {"parts": [["box", Vector3(0, 0.75, 0), Vector3(1.8, 1.5, 1.8), MARBLE], ["capsule", Vector3(0, 2.9, 0), Vector3(0.5, 2.6, 0), GOLD, 0.3],
			["sphere", Vector3(0, 4.45, 0), Vector3(0.33, 0.66, 0), GOLD, 0.3]],
		"col": [["box", Vector3(0, 2, 0), Vector3(1.8, 4, 1.8)]], "fade": true}
	d["tomba"] = {"parts": [["box", Vector3(0, 1.2, 0), Vector3(5, 2.4, 5), STONE], ["cyl", Vector3(0, 3.6, 0), Vector3(2.2, 2.4, 2.2), STONE.lightened(0.1)],
			["cyl", Vector3(0, 5.2, 0), Vector3(0, 0.8, 2.3), STONE.darkened(0.1)]],
		"col": [["box", Vector3(0, 2.5, 0), Vector3(5, 5, 5)]], "fade": true}
	d["sarcofago"] = {"parts": [["box", Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 1), STONE], ["box", Vector3(0, 1.0, 0), Vector3(2.3, 0.2, 1.1), MARBLE]],
		"col": [["box", Vector3(0, 0.55, 0), Vector3(2.3, 1.1, 1.1)]], "vis": 110.0}
	d["staccionata"] = {"parts": [["box", Vector3(-1.9, 0.6, 0), Vector3(0.15, 1.2, 0.15), WOOD], ["box", Vector3(1.9, 0.6, 0), Vector3(0.15, 1.2, 0.15), WOOD],
			["box", Vector3(0, 0.85, 0), Vector3(4, 0.12, 0.08), WOOD], ["box", Vector3(0, 0.45, 0), Vector3(4, 0.12, 0.08), WOOD]],
		"col": [["box", Vector3(0, 0.6, 0), Vector3(4, 1.2, 0.3)]], "vis": 100.0}
	d["covone"] = {"parts": [["cyl", Vector3(0, 0.7, 0), Vector3(0.9, 1.4, 1.1), HAY]], "col": [["cyl", Vector3(0, 0.7, 0), Vector3(1.0, 1.4, 0)]], "vis": 110.0}
	d["filare"] = {"parts": [["box", Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 8), Color(0.35, 0.55, 0.2)]], "vis": 100.0}
	d["tenda"] = {"parts": [["prism", Vector3(0, 1.2, 0), Vector3(3.5, 2.4, 4), CLOTH], ["box", Vector3(0, 0.02, 0), Vector3(3.6, 0.04, 4.2), CLOTH.darkened(0.3)]],
		"col": [["box", Vector3(0, 1, 0), Vector3(3.4, 2, 4)]], "fade": true}
	d["falo"] = {"parts": [["cyl", Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 1.0), ROCK], ["cyl", Vector3(0, 0.6, 0), Vector3(0, 1.0, 0.5), FIRE, 6.0]],
		"col": [["cyl", Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 0)]], "light": [Vector3(0, 1.5, 0), FIRE, 2.5, 10.0]}
	var pal := []
	for i in 5:
		var x := -1.6 + i * 0.8
		pal.append(["cyl", Vector3(x, 1.5, 0), Vector3(0.2, 3, 0.22), WOOD])
		pal.append(["cyl", Vector3(x, 3.2, 0), Vector3(0, 0.4, 0.2), WOOD])
	d["palizzata"] = {"parts": pal, "col": [["box", Vector3(0, 1.5, 0), Vector3(4, 3, 0.5)]], "fade": true}
	d["lampione_plasma"] = {"parts": [["box", Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), METAL], ["cyl", Vector3(0, 1.75, 0), Vector3(0.08, 3.5, 0.12), METAL],
			["sphere", Vector3(0, 3.7, 0), Vector3(0.3, 0.6, 0), PLASMA, 5.0]],
		"col": [["cyl", Vector3(0, 1.75, 0), Vector3(0.25, 3.5, 0)]], "light": [Vector3(0, 3.6, 0), PLASMA, 1.6, 9.0]}
	d["miliario"] = {"parts": [["cyl", Vector3(0, 0.8, 0), Vector3(0.35, 1.6, 0.4), MARBLE], ["torus", Vector3(0, 1.2, 0), Vector3(0.42, 0.5, 0), PLASMA, 4.0]],
		"col": [["cyl", Vector3(0, 0.8, 0), Vector3(0.4, 1.6, 0)]], "vis": 110.0}
	d["arco_acquedotto"] = {"parts": [["box", Vector3(-4, 3.5, 0), Vector3(2, 7, 2), STONE], ["box", Vector3(4, 3.5, 0), Vector3(2, 7, 2), STONE],
			["box", Vector3(0, 7.6, 0), Vector3(10.2, 1.4, 2.2), STONE.lightened(0.05)], ["box", Vector3(0, 8.5, 0), Vector3(10.2, 0.4, 1.4), Color(0.2, 0.5, 0.8), 1.0]],
		"col": [["box", Vector3(-4, 3.5, 0), Vector3(2, 7, 2)], ["box", Vector3(4, 3.5, 0), Vector3(2, 7, 2)]],
		"occ": ["box", Vector3(0, 7.8, 0), Vector3(10, 2, 2.2)], "fade": true}
	d["muro"] = {"parts": [["box", Vector3(0, 2.5, 0), Vector3(8, 5, 1.4), PLASTER], ["box", Vector3(0, 5.1, 0), Vector3(8.1, 0.3, 1.6), GOLD]],
		"col": [["box", Vector3(0, 2.5, 0), Vector3(8, 5, 1.4)]], "fade": true}
	d["muro_rovina"] = {"parts": [["box", Vector3(-2, 1, 0), Vector3(4, 2, 0.8), STONE], ["box", Vector3(2.2, 0.6, 0), Vector3(3.6, 1.2, 0.8), STONE.darkened(0.05)]],
		"col": [["box", Vector3(0, 1, 0), Vector3(8, 2, 0.8)]], "fade": true}
	d["casa"] = {"parts": [["box", Vector3(0, 2.5, 0), Vector3(14, 5, 10), PLASTER], ["prism", Vector3(0, 6.2, 0), Vector3(11, 2.4, 15), ROOF, 0.0, Vector3(0, 90, 0)],
			["box", Vector3(0, 1.2, -5.05), Vector3(2, 2.4, 0.1), WOOD], ["box", Vector3(-4, 3, -5.05), Vector3(1.2, 1, 0.1), Color(0.15, 0.2, 0.3)],
			["box", Vector3(4, 3, -5.05), Vector3(1.2, 1, 0.1), Color(0.15, 0.2, 0.3)]],
		"col": [["box", Vector3(0, 2.5, 0), Vector3(14, 5, 10)]], "occ": ["box", Vector3(0, 6.2, 0), Vector3(15, 2.6, 11)], "fade": true}
	d["fienile"] = {"parts": [["box", Vector3(0, 2, 0), Vector3(10, 4, 7), WOOD.lightened(0.1)], ["prism", Vector3(0, 5, 0), Vector3(7.6, 2, 10.6), ROOF.darkened(0.2), 0.0, Vector3(0, 90, 0)]],
		"col": [["box", Vector3(0, 2, 0), Vector3(10, 4, 7)]], "occ": ["box", Vector3(0, 5, 0), Vector3(10.6, 2.2, 7.6)], "fade": true}
	d["pozzo"] = {"parts": [["cyl", Vector3(0, 0.5, 0), Vector3(1, 1, 1), STONE], ["box", Vector3(-0.9, 1.3, 0), Vector3(0.15, 1.6, 0.15), WOOD],
			["box", Vector3(0.9, 1.3, 0), Vector3(0.15, 1.6, 0.15), WOOD], ["box", Vector3(0, 2.1, 0), Vector3(2.2, 0.15, 0.15), WOOD]],
		"col": [["cyl", Vector3(0, 0.5, 0), Vector3(1.0, 1, 0)]]}
	d["porta_citta"] = {"parts": [["box", Vector3(-8, 5, 0), Vector3(6, 10, 6), PLASTER], ["box", Vector3(8, 5, 0), Vector3(6, 10, 6), PLASTER],
			["box", Vector3(0, 9, 0), Vector3(10, 2.5, 4), PLASTER], ["box", Vector3(0, 10.6, 0), Vector3(22, 0.6, 6.4), GOLD, 0.3],
			["box", Vector3(0, 7.4, 2.05), Vector3(9, 0.3, 0.1), RED, 2.0]],
		"col": [["box", Vector3(-8, 5, 0), Vector3(6, 10, 6)], ["box", Vector3(8, 5, 0), Vector3(6, 10, 6)]],
		"occ": ["box", Vector3(0, 9, 0), Vector3(10, 3, 4)], "fade": true}
	d["ponte"] = {"parts": [["box", Vector3(0, 0.07, 0), Vector3(7, 0.14, 24), WOOD.darkened(0.1)],
			["box", Vector3(-3.5, 0.6, 0), Vector3(0.35, 1.0, 24), STONE], ["box", Vector3(3.5, 0.6, 0), Vector3(0.35, 1.0, 24), STONE]],
		"col": [["box", Vector3(-3.5, 0.6, 0), Vector3(0.35, 1.2, 24)], ["box", Vector3(3.5, 0.6, 0), Vector3(0.35, 1.2, 24)]]}
	d["relitto_navetta"] = {"parts": [["box", Vector3(0, 1.8, 0), Vector3(5, 3, 14), METAL, 0.0, Vector3(8, 0, -12)],
			["box", Vector3(5, 1, 1), Vector3(7, 0.4, 4), METAL.darkened(0.2), 0.0, Vector3(0, 10, -20)],
			["box", Vector3(-4.5, 0.6, -2), Vector3(5, 0.4, 3.5), METAL.darkened(0.2), 0.0, Vector3(0, -30, 15)],
			["cyl", Vector3(0, 2, 7.1), Vector3(1.1, 0.6, 1.1), PLASMA, 4.0, Vector3(90, 0, 0)],
			["box", Vector3(0, 3.4, -4), Vector3(2.2, 0.8, 3), Color(0.2, 0.3, 0.4)]],
		"col": [["box", Vector3(0, 1.8, 0), Vector3(6, 3.6, 14)]], "fade": true, "light": [Vector3(0, 2.5, 8.5), PLASMA, 2.0, 10.0]}
	d["tronco"] = {"parts": [["cyl", Vector3(0, 0.4, 0), Vector3(0.4, 4, 0.45), BARK, 0.0, Vector3(0, 0, 90)]],
		"col": [["box", Vector3(0, 0.4, 0), Vector3(4, 0.8, 0.8)]], "vis": 110.0}
	d["altare"] = {"parts": [["box", Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 2.4), MARBLE], ["box", Vector3(0, 1.2, 0), Vector3(1.4, 0.8, 1.4), MARBLE],
			["cyl", Vector3(0, 1.75, 0), Vector3(0.6, 0.3, 0.5), GOLD], ["sphere", Vector3(0, 2.3, 0), Vector3(0.45, 0.9, 0), Color(0.3, 0.7, 1.0), 6.0, Vector3.ZERO, "Flame"]],
		"col": [["box", Vector3(0, 0.8, 0), Vector3(2.4, 1.6, 2.4)]], "script": "res://world/checkpoint.gd", "light": [Vector3(0, 2.6, 0), Color(0.4, 0.7, 1.0), 1.5, 8.0]}
	d["cartello"] = {"parts": [["box", Vector3(0, 0.9, 0), Vector3(0.15, 1.8, 0.15), WOOD], ["box", Vector3(0, 1.6, 0), Vector3(1.4, 0.8, 0.1), WOOD.lightened(0.2)],
			["box", Vector3(0, 1.6, -0.06), Vector3(1.1, 0.5, 0.02), GOLD, 1.0]],
		"col": [["box", Vector3(0, 1, 0), Vector3(1.4, 2, 0.4)]], "script": "res://world/lore_sign.gd"}
	d["pavimento_tempio"] = {"parts": [["box", Vector3(0, 0.04, 0), Vector3(16, 0.08, 26), MARBLE.darkened(0.15)]]}
	d["stendardo"] = {"parts": [["cyl", Vector3(0, 2.5, 0), Vector3(0.06, 5, 0.08), METAL], ["box", Vector3(0.55, 3.6, 0), Vector3(1, 2, 0.05), RED, 0.8],
			["box", Vector3(0.55, 4.2, 0.04), Vector3(0.5, 0.5, 0.02), GOLD, 2.0]],
		"col": [["cyl", Vector3(0, 2.5, 0), Vector3(0.2, 5, 0)]], "vis": 120.0}
	d["torre_guardia"] = {"parts": [["box", Vector3(-1.2, 2, -1.2), Vector3(0.3, 4, 0.3), WOOD], ["box", Vector3(1.2, 2, -1.2), Vector3(0.3, 4, 0.3), WOOD],
			["box", Vector3(-1.2, 2, 1.2), Vector3(0.3, 4, 0.3), WOOD], ["box", Vector3(1.2, 2, 1.2), Vector3(0.3, 4, 0.3), WOOD],
			["box", Vector3(0, 4.1, 0), Vector3(3.2, 0.3, 3.2), WOOD.darkened(0.1)], ["prism", Vector3(0, 5.6, 0), Vector3(3.4, 1.4, 3.4), CLOTH]],
		"col": [["box", Vector3(0, 2.5, 0), Vector3(3, 5, 3)]], "fade": true}
	d["carro"] = {"parts": [["box", Vector3(0, 0.9, 0), Vector3(2, 0.5, 3.4), WOOD],
			["cyl", Vector3(-1.1, 0.5, -1), Vector3(0.5, 0.15, 0.5), WOOD.darkened(0.3), 0.0, Vector3(0, 0, 90)],
			["cyl", Vector3(1.1, 0.5, -1), Vector3(0.5, 0.15, 0.5), WOOD.darkened(0.3), 0.0, Vector3(0, 0, 90)],
			["cyl", Vector3(-1.1, 0.5, 1), Vector3(0.5, 0.15, 0.5), WOOD.darkened(0.3), 0.0, Vector3(0, 0, 90)],
			["cyl", Vector3(1.1, 0.5, 1), Vector3(0.5, 0.15, 0.5), WOOD.darkened(0.3), 0.0, Vector3(0, 0, 90)]],
		"col": [["box", Vector3(0, 0.7, 0), Vector3(2.4, 1.4, 3.4)]], "vis": 110.0}
	# --- Città (Ostia Nova) ---
	d["bancarella"] = {"parts": [["box", Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 1.4), WOOD],
			["box", Vector3(-1.5, 1.3, -0.6), Vector3(0.12, 2.6, 0.12), WOOD], ["box", Vector3(1.5, 1.3, -0.6), Vector3(0.12, 2.6, 0.12), WOOD],
			["box", Vector3(-1.5, 1.1, 0.6), Vector3(0.12, 2.2, 0.12), WOOD], ["box", Vector3(1.5, 1.1, 0.6), Vector3(0.12, 2.2, 0.12), WOOD],
			["box", Vector3(0, 2.45, 0), Vector3(3.6, 0.08, 1.9), RED, 0.0, Vector3(-12, 0, 0)],
			["box", Vector3(-0.8, 1.15, 0), Vector3(0.6, 0.3, 0.5), TERRACOTTA], ["box", Vector3(0.2, 1.12, 0.1), Vector3(0.5, 0.25, 0.4), GOLD, 0.5],
			["sphere", Vector3(1.0, 1.2, -0.1), Vector3(0.22, 0.4, 0), PLASMA, 3.0]],
		"col": [["box", Vector3(0, 0.6, 0), Vector3(3.2, 1.2, 1.5)]], "vis": 110.0}
	d["fucina"] = {"parts": [["box", Vector3(0, 0.6, 0), Vector3(2.6, 1.2, 2.0), STONE.darkened(0.2)],
			["box", Vector3(0, 1.25, 0), Vector3(2.0, 0.1, 1.5), FIRE, 5.0],
			["box", Vector3(0, 2.8, 0.6), Vector3(1.0, 3.2, 0.8), STONE.darkened(0.3)],
			["box", Vector3(2.6, 0.4, 0.2), Vector3(0.6, 0.8, 0.5), STONE], ["box", Vector3(2.6, 0.9, 0.2), Vector3(1.1, 0.25, 0.45), METAL.darkened(0.3)],
			["box", Vector3(-2.5, 2, -1.8), Vector3(0.25, 4, 0.25), WOOD], ["box", Vector3(3.5, 2, -1.8), Vector3(0.25, 4, 0.25), WOOD],
			["box", Vector3(-2.5, 2, 1.8), Vector3(0.25, 4, 0.25), WOOD], ["box", Vector3(3.5, 2, 1.8), Vector3(0.25, 4, 0.25), WOOD],
			["box", Vector3(0.5, 4.1, 0), Vector3(6.6, 0.25, 4.2), ROOF.darkened(0.25)]],
		"col": [["box", Vector3(0, 0.8, 0), Vector3(2.6, 1.6, 2.0)], ["box", Vector3(2.6, 0.5, 0.2), Vector3(1.1, 1.0, 0.5)]],
		"occ": ["box", Vector3(0.5, 4.1, 0), Vector3(6.6, 0.6, 4.2)], "fade": true, "light": [Vector3(0, 2.0, 0), FIRE, 2.5, 9.0]}
	d["fontana"] = {"parts": [["cyl", Vector3(0, 0.4, 0), Vector3(3.2, 0.8, 3.3), MARBLE],
			["cyl", Vector3(0, 0.75, 0), Vector3(2.9, 0.1, 2.9), Color(0.2, 0.5, 0.8), 1.0],
			["cyl", Vector3(0, 1.4, 0), Vector3(0.4, 1.6, 0.5), MARBLE], ["cyl", Vector3(0, 2.2, 0), Vector3(1.1, 0.2, 0.6), MARBLE],
			["sphere", Vector3(0, 2.6, 0), Vector3(0.35, 0.7, 0), PLASMA, 4.0]],
		"col": [["cyl", Vector3(0, 0.5, 0), Vector3(3.3, 1.0, 0)]], "light": [Vector3(0, 2.8, 0), PLASMA, 1.5, 10.0]}
	var bas := [["box", Vector3(0, 0.3, 0), Vector3(26, 0.6, 16), MARBLE.darkened(0.1)],
		["box", Vector3(0, 4.5, 1.5), Vector3(24, 8, 12), PLASTER], ["prism", Vector3(0, 9.7, 1.5), Vector3(14, 2.4, 25), ROOF, 0.0, Vector3(0, 90, 0)],
		["box", Vector3(0, 2.0, -4.55), Vector3(3, 4, 0.1), WOOD.darkened(0.2)], ["box", Vector3(0, 8.3, -5.6), Vector3(24, 0.6, 2.2), MARBLE]]
	for i in 8:
		bas.append(["cyl", Vector3(-10.5 + i * 3.0, 4.3, -6.2), Vector3(0.45, 7.4, 0.5), MARBLE])
	d["basilica"] = {"parts": bas, "col": [["box", Vector3(0, 4, 0.5), Vector3(24.5, 8, 14)]],
		"occ": ["box", Vector3(0, 8.5, 0.5), Vector3(26, 4, 15)], "fade": true}
	d["insula"] = {"parts": [["box", Vector3(0, 5, 0), Vector3(12, 10, 10), PLASTER.darkened(0.08)],
			["box", Vector3(0, 10.2, 0), Vector3(12.4, 0.4, 10.4), ROOF],
			["box", Vector3(0, 1.4, -5.05), Vector3(2.2, 2.8, 0.1), WOOD], ["box", Vector3(-3.5, 1.6, -5.05), Vector3(2.4, 1.4, 0.1), RED, 0.3],
			["box", Vector3(-3, 5, -5.05), Vector3(1.0, 1.2, 0.1), Color(0.15, 0.2, 0.3)], ["box", Vector3(3, 5, -5.05), Vector3(1.0, 1.2, 0.1), Color(0.15, 0.2, 0.3)],
			["box", Vector3(-3, 8, -5.05), Vector3(1.0, 1.2, 0.1), Color(0.15, 0.2, 0.3)], ["box", Vector3(3, 8, -5.05), Vector3(1.0, 1.2, 0.1), Color(0.15, 0.2, 0.3)],
			["box", Vector3(0, 6.5, -5.4), Vector3(12, 0.2, 0.8), WOOD]],
		"col": [["box", Vector3(0, 5, 0), Vector3(12, 10, 10)]], "occ": ["box", Vector3(0, 7, 0), Vector3(12.4, 7, 10.4)], "fade": true}
	d["cancello"] = {"parts": [["box", Vector3(0, 3.5, 0), Vector3(10, 7, 0.4), METAL.darkened(0.2)],
			["box", Vector3(0, 2.0, -0.22), Vector3(9.6, 0.15, 0.05), PLASMA, 3.0], ["box", Vector3(0, 4.5, -0.22), Vector3(9.6, 0.15, 0.05), PLASMA, 3.0],
			["box", Vector3(0, 3.5, -0.24), Vector3(1.6, 1.6, 0.05), GOLD, 1.0]],
		"col": [["box", Vector3(0, 3.5, 0), Vector3(10, 7, 0.6)]]}
	return d


func _build_props(only_missing: bool = false) -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/props")
	var defs := _prop_defs()
	for pname: String in defs:
		var def: Dictionary = defs[pname]
		var out_path := "res://scenes/props/%s.tscn" % pname
		if only_missing and ResourceLoader.exists(out_path):
			prop_scenes[pname] = load(out_path)
			continue
		var root: Node3D
		if def.has("col") or def.has("script"):
			var sb := StaticBody3D.new()
			sb.collision_layer = Layers.WORLD
			sb.collision_mask = 0
			root = sb
		else:
			root = Node3D.new()
		root.name = pname.to_pascal_case()
		if def.has("script"):
			root.set_script(load(def["script"]))
		if def.get("fade", false):
			root.add_to_group("fadeable", true)
		var gfx := Node3D.new()
		gfx.name = "Graybox"
		root.add_child(gfx)
		gfx.owner = root
		var vis := float(def.get("vis", 0.0))
		for p: Array in def["parts"]:
			_part(gfx, root, p, vis)
		var i := 0
		for c: Array in def.get("col", []):
			var cs := CollisionShape3D.new()
			cs.name = "Collision%d" % i
			cs.shape = _shape(c)
			cs.position = c[1]
			root.add_child(cs)
			cs.owner = root
			i += 1
		if def.has("occ"):
			var occ := StaticBody3D.new()
			occ.name = "OcclusionVolume"
			occ.collision_layer = Layers.OCCLUDER
			occ.collision_mask = 0
			root.add_child(occ)
			occ.owner = root
			var cs := CollisionShape3D.new()
			cs.shape = _shape(def["occ"])
			cs.position = def["occ"][1]
			occ.add_child(cs)
			cs.owner = root
		if def.has("light"):
			var l: Array = def["light"]
			var light := OmniLight3D.new()
			light.name = "Light"
			light.position = l[0]
			light.light_color = l[1]
			light.light_energy = l[2]
			light.omni_range = l[3]
			light.distance_fade_enabled = true
			light.distance_fade_begin = 60.0
			light.distance_fade_length = 15.0
			root.add_child(light)
			light.owner = root
		var path := "res://scenes/props/%s.tscn" % pname
		_save_scene(root, path)
		root.free()
		prop_scenes[pname] = load(path)
	print("Oggetti di scena: %d" % prop_scenes.size())


# ==========================================================================================
#  MODELLI SEGNAPOSTO (rivolti verso -Z)
# ==========================================================================================

func _build_models(only_missing: bool = false) -> void:
	for dir in ["characters", "enemies", "npcs"]:
		DirAccess.make_dir_recursive_absolute("res://scenes/" + dir)
	var models := _model_defs()
	for key: String in models:
		var out_path := "res://scenes/%s.tscn" % key
		if only_missing and ResourceLoader.exists(out_path):
			continue
		var root := Node3D.new()
		root.name = "Model"
		var gfx := Node3D.new()
		gfx.name = "Graybox"
		root.add_child(gfx)
		gfx.owner = root
		for p: Array in models[key]:
			var mi := _part(gfx, root, p, 0.0)
			if (p[3] as Color).a < 1.0:
				mi.material_override = Fx.new_mat(p[3], float(p[4]) if p.size() > 4 else 0.0, true)
		_save_scene(root, out_path)
		root.free()
	print("Modelli: %d" % models.size())


func _model_defs() -> Dictionary:
	var skin := Color(0.85, 0.65, 0.5)
	var bronze := Color(0.7, 0.5, 0.25)
	return {
		"characters/legionario": [
			["capsule", Vector3(0, 0.85, 0), Vector3(0.42, 1.5, 0), RED],
			["box", Vector3(0, 1.05, 0), Vector3(0.9, 0.5, 0.6), METAL.lightened(0.2)],
			["sphere", Vector3(0, 1.75, 0), Vector3(0.3, 0.55, 0), GOLD],
			["box", Vector3(0, 2.0, 0.05), Vector3(0.08, 0.22, 0.55), Color(0.9, 0.1, 0.1), 1.0],
			["box", Vector3(-0.52, 0.95, -0.15), Vector3(0.1, 1.0, 0.7), GOLD],
			["box", Vector3(0.45, 0.9, -0.55), Vector3(0.08, 0.08, 0.9), PLASMA, 4.0],
		],
		"characters/gladiatore": [
			["capsule", Vector3(0, 0.85, 0), Vector3(0.42, 1.5, 0), skin],
			["box", Vector3(0, 0.7, 0), Vector3(0.88, 0.35, 0.6), Color(0.45, 0.2, 0.12)],
			["sphere", Vector3(0, 1.75, 0), Vector3(0.32, 0.6, 0), bronze],
			["box", Vector3(0, 1.75, -0.28), Vector3(0.35, 0.3, 0.06), Color(0.2, 0.15, 0.1)],
			["box", Vector3(0, 2.05, 0), Vector3(0.1, 0.25, 0.6), bronze],
			["box", Vector3(-0.48, 1.1, 0), Vector3(0.2, 0.6, 0.25), bronze],
			["box", Vector3(0.48, 0.9, -0.5), Vector3(0.07, 0.07, 1.0), WOOD],
			["box", Vector3(0.48, 0.9, -0.95), Vector3(0.1, 0.45, 0.25), METAL.lightened(0.3), 0.5],
		],
		"characters/sagittario": [
			["capsule", Vector3(0, 0.85, 0), Vector3(0.38, 1.5, 0), Color(0.25, 0.45, 0.25)],
			["sphere", Vector3(0, 1.72, 0), Vector3(0.26, 0.5, 0), skin],
			["cyl", Vector3(0, 1.85, 0.03), Vector3(0, 0.6, 0.34), Color(0.18, 0.32, 0.18)],
			["box", Vector3(-0.45, 1.0, -0.3), Vector3(0.06, 1.5, 0.08), WOOD],
			["box", Vector3(-0.43, 1.0, -0.22), Vector3(0.02, 1.4, 0.02), PLASMA, 4.0],
			["cyl", Vector3(0.2, 1.2, 0.35), Vector3(0.12, 0.8, 0.12), Color(0.35, 0.25, 0.15), 0.0, Vector3(20, 0, -15)],
		],
		"characters/augure": [
			["cyl", Vector3(0, 0.75, 0), Vector3(0.3, 1.5, 0.55), Color(0.9, 0.9, 0.95)],
			["box", Vector3(0, 0.9, 0), Vector3(0.62, 0.12, 0.62), Color(0.45, 0.2, 0.6)],
			["sphere", Vector3(0, 1.72, 0), Vector3(0.26, 0.5, 0), skin],
			["cyl", Vector3(0, 1.88, 0.03), Vector3(0, 0.55, 0.34), Color(0.45, 0.2, 0.6)],
			["cyl", Vector3(0.5, 1.1, -0.1), Vector3(0.04, 2.2, 0.04), WOOD],
			["sphere", Vector3(0.5, 2.3, -0.1), Vector3(0.16, 0.32, 0), Color(0.5, 0.6, 1.0), 5.0],
		],
		"enemies/predone": [
			["capsule", Vector3(0, 0.8, 0), Vector3(0.42, 1.6, 0), Color(0.45, 0.33, 0.22)],
			["cyl", Vector3(0, 1.75, 0), Vector3(0, 0.55, 0.33), Color(0.3, 0.22, 0.15)],
			["box", Vector3(0, 1.55, -0.3), Vector3(0.3, 0.08, 0.05), Color(1, 0.4, 0.1), 3.0],
			["box", Vector3(0.45, 0.9, -0.4), Vector3(0.06, 0.06, 0.6), METAL.lightened(0.3)],
		],
		"enemies/lupo": [
			["capsule", Vector3(0, 0.6, 0), Vector3(0.3, 1.4, 0), Color(0.42, 0.42, 0.45), 0.0, Vector3(90, 0, 0)],
			["box", Vector3(0, 0.8, -0.78), Vector3(0.3, 0.3, 0.45), Color(0.38, 0.38, 0.4)],
			["box", Vector3(0, 0.85, -0.98), Vector3(0.22, 0.06, 0.06), Color(1, 0.1, 0.1), 4.0],
			["box", Vector3(-0.18, 0.25, -0.4), Vector3(0.1, 0.5, 0.1), METAL], ["box", Vector3(0.18, 0.25, -0.4), Vector3(0.1, 0.5, 0.1), METAL],
			["box", Vector3(-0.18, 0.25, 0.4), Vector3(0.1, 0.5, 0.1), METAL], ["box", Vector3(0.18, 0.25, 0.4), Vector3(0.1, 0.5, 0.1), METAL],
		],
		"enemies/drone": [
			["sphere", Vector3(0, 1.4, 0), Vector3(0.42, 0.84, 0), Color(0.35, 0.3, 0.42)],
			["sphere", Vector3(0, 1.4, -0.36), Vector3(0.15, 0.3, 0), Color(1, 0.2, 0.9), 5.0],
			["torus", Vector3(0, 1.85, 0), Vector3(0.45, 0.55, 0), METAL],
			["cyl", Vector3(0, 0.9, 0), Vector3(0, 0.4, 0.15), Color(1, 0.2, 0.9), 3.0],
		],
		"enemies/barbaro": [
			["capsule", Vector3(0, 0.95, 0), Vector3(0.5, 1.9, 0), Color(0.55, 0.32, 0.2)],
			["box", Vector3(0, 1.35, 0), Vector3(1.1, 0.35, 0.75), Color(0.4, 0.3, 0.2)],
			["sphere", Vector3(0, 2.0, 0), Vector3(0.32, 0.55, 0), METAL],
			["cyl", Vector3(-0.35, 2.2, 0), Vector3(0, 0.45, 0.1), MARBLE, 0.0, Vector3(0, 0, 50)],
			["cyl", Vector3(0.35, 2.2, 0), Vector3(0, 0.45, 0.1), MARBLE, 0.0, Vector3(0, 0, -50)],
			["box", Vector3(0.55, 1.0, -0.5), Vector3(0.08, 0.08, 1.0), WOOD],
			["box", Vector3(0.55, 1.0, -0.95), Vector3(0.12, 0.5, 0.3), METAL.lightened(0.2)],
		],
		"enemies/frombolier": [
			["capsule", Vector3(0, 0.8, 0), Vector3(0.4, 1.6, 0), Color(0.7, 0.6, 0.45)],
			["sphere", Vector3(0, 1.72, 0), Vector3(0.26, 0.5, 0), skin],
			["box", Vector3(0, 1.8, 0), Vector3(0.55, 0.1, 0.55), Color(0.6, 0.1, 0.1)],
			["box", Vector3(0.45, 1.1, -0.2), Vector3(0.04, 0.04, 0.8), Color(0.5, 0.4, 0.3)],
		],
		"enemies/bruto": [
			["capsule", Vector3(0, 1.35, 0), Vector3(0.85, 2.7, 0), Color(0.3, 0.42, 0.3)],
			["box", Vector3(-0.9, 2.0, 0), Vector3(0.6, 0.5, 0.8), METAL], ["box", Vector3(0.9, 2.0, 0), Vector3(0.6, 0.5, 0.8), METAL],
			["box", Vector3(0, 2.3, -0.75), Vector3(0.6, 0.12, 0.06), Color(1, 0.3, 0.1), 3.0],
			["cyl", Vector3(1.1, 1.2, -0.7), Vector3(0.28, 2.2, 0.15), WOOD.darkened(0.2), 0.0, Vector3(70, 0, 0)],
		],
		"enemies/lemure": [
			["capsule", Vector3(0, 1.2, 0), Vector3(0.4, 1.5, 0), Color(0.5, 0.9, 1.0, 0.55), 1.5],
			["cyl", Vector3(0, 0.45, 0), Vector3(0.35, 0.8, 0.05), Color(0.5, 0.9, 1.0, 0.4), 1.0],
			["box", Vector3(0, 1.65, -0.36), Vector3(0.3, 0.07, 0.05), Color(0.1, 0.2, 0.4), 0.0],
		],
		"enemies/rinnegato": [
			["capsule", Vector3(0, 0.9, 0), Vector3(0.45, 1.8, 0), Color(0.15, 0.12, 0.18)],
			["box", Vector3(0, 1.15, 0), Vector3(0.95, 0.5, 0.65), Color(0.25, 0.2, 0.3)],
			["sphere", Vector3(0, 1.9, 0), Vector3(0.32, 0.58, 0), Color(0.2, 0.18, 0.22)],
			["box", Vector3(0, 1.9, -0.3), Vector3(0.35, 0.08, 0.05), Color(1, 0.1, 0.1), 4.0],
			["box", Vector3(-0.55, 1.0, -0.15), Vector3(0.1, 1.0, 0.7), Color(0.35, 0.1, 0.4)],
			["box", Vector3(0.5, 0.95, -0.55), Vector3(0.08, 0.08, 0.9), Color(1, 0.2, 0.2), 4.0],
		],
		"enemies/brenno": [
			["capsule", Vector3(0, 1.6, 0), Vector3(1.0, 3.2, 0), Color(0.5, 0.25, 0.15)],
			["box", Vector3(0, 2.4, 0), Vector3(2.4, 0.7, 1.4), Color(0.3, 0.22, 0.15)],
			["sphere", Vector3(0, 3.35, 0), Vector3(0.5, 0.9, 0), METAL.darkened(0.2)],
			["torus", Vector3(0, 3.65, 0), Vector3(0.35, 0.5, 0), GOLD, 1.0],
			["cyl", Vector3(-0.55, 3.8, 0), Vector3(0, 0.8, 0.16), MARBLE, 0.0, Vector3(0, 0, 45)],
			["cyl", Vector3(0.55, 3.8, 0), Vector3(0, 0.8, 0.16), MARBLE, 0.0, Vector3(0, 0, -45)],
			["box", Vector3(1.2, 1.8, -0.8), Vector3(0.12, 0.12, 2.2), WOOD],
			["box", Vector3(1.2, 1.8, -1.8), Vector3(0.2, 1.1, 0.7), FIRE, 2.5],
		],
		# --- Personaggi non giocanti ---
		"npcs/mercante": [
			["capsule", Vector3(0, 0.85, 0), Vector3(0.45, 1.6, 0), Color(0.75, 0.55, 0.2)],
			["box", Vector3(0, 0.95, 0), Vector3(0.95, 0.12, 0.7), Color(0.45, 0.2, 0.55)],
			["sphere", Vector3(0, 1.78, 0), Vector3(0.27, 0.52, 0), skin],
			["cyl", Vector3(0, 2.05, 0), Vector3(0.22, 0.25, 0.26), Color(0.45, 0.2, 0.55)],
			["box", Vector3(0.45, 0.8, 0.1), Vector3(0.3, 0.35, 0.2), Color(0.5, 0.35, 0.2)],
		],
		"npcs/fabbro": [
			["capsule", Vector3(0, 0.9, 0), Vector3(0.5, 1.75, 0), Color(0.5, 0.36, 0.25)],
			["box", Vector3(0, 0.8, -0.38), Vector3(0.75, 1.1, 0.08), Color(0.25, 0.18, 0.12)],
			["sphere", Vector3(0, 1.85, 0), Vector3(0.3, 0.55, 0), skin],
			["box", Vector3(0.55, 1.0, -0.2), Vector3(0.07, 0.7, 0.07), WOOD],
			["box", Vector3(0.55, 1.4, -0.2), Vector3(0.3, 0.18, 0.18), METAL],
		],
		"npcs/prefetto": [
			["cyl", Vector3(0, 0.8, 0), Vector3(0.32, 1.6, 0.55), Color(0.93, 0.92, 0.88)],
			["box", Vector3(0.15, 1.05, -0.2), Vector3(0.12, 1.2, 0.3), Color(0.5, 0.1, 0.4), 0.0, Vector3(0, 0, 20)],
			["sphere", Vector3(0, 1.78, 0), Vector3(0.27, 0.52, 0), skin],
			["torus", Vector3(0, 1.95, 0), Vector3(0.22, 0.3, 0), GOLD, 0.8],
		],
		"npcs/vestale": [
			["cyl", Vector3(0, 0.8, 0), Vector3(0.28, 1.6, 0.5), Color(0.97, 0.96, 0.93)],
			["sphere", Vector3(0, 1.75, 0), Vector3(0.25, 0.48, 0), skin],
			["cyl", Vector3(0, 1.85, 0.05), Vector3(0.3, 0.6, 0.38), Color(0.9, 0.9, 0.95)],
			["cyl", Vector3(0.35, 1.1, -0.3), Vector3(0.18, 0.12, 0.1), GOLD],
			["sphere", Vector3(0.35, 1.3, -0.3), Vector3(0.14, 0.3, 0), FIRE, 5.0],
		],
		"npcs/guardia": [
			["capsule", Vector3(0, 0.85, 0), Vector3(0.42, 1.5, 0), Color(0.2, 0.3, 0.5)],
			["box", Vector3(0, 1.05, 0), Vector3(0.9, 0.5, 0.6), METAL.lightened(0.15)],
			["sphere", Vector3(0, 1.75, 0), Vector3(0.3, 0.55, 0), METAL.lightened(0.2)],
			["box", Vector3(0, 2.0, 0.05), Vector3(0.08, 0.22, 0.55), Color(0.2, 0.4, 0.9), 1.0],
			["cyl", Vector3(0.5, 1.3, -0.1), Vector3(0.04, 2.6, 0.04), WOOD],
			["cyl", Vector3(0.5, 2.7, -0.1), Vector3(0.0, 0.35, 0.08), PLASMA, 3.0],
		],
		"npcs/cittadino": [
			["capsule", Vector3(0, 0.85, 0), Vector3(0.4, 1.55, 0), Color(0.72, 0.65, 0.5)],
			["box", Vector3(0, 0.8, 0), Vector3(0.85, 0.1, 0.62), Color(0.4, 0.3, 0.2)],
			["sphere", Vector3(0, 1.75, 0), Vector3(0.27, 0.52, 0), skin],
		],
	}


# ==========================================================================================
#  LIVELLO 1: dalla villa di famiglia alla porta di Ostia Nova
# ==========================================================================================

func _place(pname: String, parent: Node, p: Vector2, rot_y: float = 0.0, scale: float = 1.0, props: Dictionary = {}) -> Node3D:
	var inst: Node3D = (prop_scenes[pname] as PackedScene).instantiate()
	inst.position = _v3(p)
	inst.rotation_degrees.y = rot_y
	if scale != 1.0:
		inst.scale = Vector3.ONE * scale
	for k: String in props:
		inst.set(k, props[k])
	parent.add_child(inst)
	inst.owner = level_root
	if not _allowed(p):
		push_warning("%s fuori dall'area giocabile in %s" % [pname, p])
	return inst


func _group(parent: Node, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	g.owner = level_root
	return g


func _strip(parent: Node, a: Vector2, b: Vector2, width: float, y: float, h: float, col: Color, collide: bool = false) -> void:
	var len := a.distance_to(b)
	var mid := (a + b) * 0.5
	var rot := atan2(-(b.y - a.y), b.x - a.x)
	var node: Node3D
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = Layers.WORLD
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(len, h, width)
		cs.shape = bs
		sb.add_child(cs)
		node = sb
		sb.position = _v3(mid, y)
		sb.rotation.y = rot
		parent.add_child(sb)
		sb.owner = level_root
		cs.owner = level_root
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(len, h, width)
	mi.mesh = bm
	mi.material_override = Fx.mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collide:
		node.add_child(mi)
	else:
		mi.position = _v3(mid, y)
		mi.rotation.y = rot
		parent.add_child(mi)
	mi.owner = level_root


func _disc(parent: Node, p: Vector2, r: float, y: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.04
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = Fx.mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = _v3(p, y)
	parent.add_child(mi)
	mi.owner = level_root


func _build_level() -> void:
	if prop_scenes.is_empty():
		for f in DirAccess.get_files_at("res://scenes/props"):
			if f.ends_with(".tscn"):
				prop_scenes[f.get_basename()] = load("res://scenes/props/" + f)
	rng.seed = SEED
	level_root = Node3D.new()
	level_root.name = "Level01"
	get_root().add_child(level_root)

	_build_environment()
	var region := NavigationRegion3D.new()
	region.name = "World"
	level_root.add_child(region)
	region.owner = level_root

	_find_bridge()
	_build_ground(region)
	_build_road(region)
	_build_river(region)
	var pois := _group(region, "Luoghi")
	_build_villa(pois)
	_build_pois(pois)
	_build_road_props(region)
	_build_scatter(region)
	_build_encounters()

	var start := Marker3D.new()
	start.name = "PlayerStart"
	start.position = Vector3(0, 0, 4)
	level_root.add_child(start)
	start.owner = level_root

	var exit: Area3D = load("res://world/level_exit.gd").new()
	exit.name = "UscitaOstiaNova"
	exit.position = Vector3(50, 0, -905)
	exit.set("title", "Ostia Nova")
	exit.set("target_level", "ostia_nova")
	exit.set("target_spawn", "DaLazio")
	var ecs := CollisionShape3D.new()
	var ebs := BoxShape3D.new()
	ebs.size = Vector3(10, 4, 4)
	ecs.shape = ebs
	ecs.position.y = 2
	exit.add_child(ecs)
	level_root.add_child(exit)
	exit.owner = level_root
	ecs.owner = level_root

	# Punto di arrivo tornando dalla città (porta sud di Ostia Nova)
	var from_hub := Marker3D.new()
	from_hub.name = "DaOstia"
	from_hub.position = Vector3(50, 0, -878)
	level_root.add_child(from_hub)
	from_hub.owner = level_root

	print("Calcolo navmesh (può richiedere un po')...")
	var t0 := Time.get_ticks_msec()
	var nm := NavigationMesh.new()
	nm.cell_size = 0.4
	nm.cell_height = 0.25
	nm.agent_radius = 0.4
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.region_min_size = 30.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	region.navigation_mesh = nm
	region.bake_navigation_mesh(false)
	print("Navmesh: %d poligoni in %d ms" % [nm.get_polygon_count(), Time.get_ticks_msec() - t0])
	var nm_path := "res://scenes/levels/level_01_navmesh.res"
	ResourceSaver.save(nm, nm_path, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH)

	get_root().remove_child(level_root)
	level_root.set_script(load("res://world/level.gd"))
	level_root.set("level_id", "level_01")
	level_root.set("level_title", "Campagna di Lazio Prime")
	level_root.set("area_level", 1)
	level_root.set("exit_text", "Hai raggiunto la porta di Ostia Nova.\n\n[TRAMA: qui inizierà il prossimo capitolo.]")
	_save_scene(level_root, "res://scenes/levels/level_01.tscn")
	print("Livello salvato. Lunghezza del percorso: %d m (circa %d s a piedi)" % [roundi(road_total), roundi(road_total / 6.0)])
	level_root.free()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.45, 0.7)
	sm.sky_horizon_color = Color(0.85, 0.7, 0.55)
	sm.ground_bottom_color = Color(0.2, 0.17, 0.14)
	sm.ground_horizon_color = Color(0.6, 0.5, 0.4)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.68, 0.6)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level_root.add_child(we)
	we.owner = level_root
	var sun := DirectionalLight3D.new()
	sun.name = "Sole"
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	level_root.add_child(sun)
	sun.owner = level_root


func _find_bridge() -> void:
	var prev := 0.0
	var s := 0.0
	while s < road_total:
		var rp: Array = _road_point(s)
		var p: Vector2 = rp[0]
		var v := p.y - _river_z(p.x)
		if s > 0.0 and signf(v) != signf(prev):
			_bridge_c = p
			_bridge_d = rp[1]
			break
		prev = v
		s += 0.5
	_clear.append([_bridge_c, 16.0])
	_clear.append([FORD, 9.0])


func _build_ground(region: Node3D) -> void:
	var ground := _group(region, "Terreno")
	var bounds := _group(region, "Confini")
	# Base scura sotto tutto (solo grafica)
	var base := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(NX * CELL + 200, NZ * CELL + 200)
	base.mesh = pm
	base.material_override = Fx.mat(Color(0.1, 0.14, 0.09))
	base.position = Vector3(X0 + NX * CELL * 0.5, -0.05, Z0 - NZ * CELL * 0.5)
	base.name = "Base"
	ground.add_child(base)
	base.owner = level_root

	var allowed := []
	for ix in NX:
		var col := []
		for iz in NZ:
			col.append(_allowed(_cell_center(ix, iz)))
		allowed.append(col)
	var kind := {}   # Vector2i -> "a" giocabile / "b" confine
	for ix in NX:
		for iz in NZ:
			if allowed[ix][iz]:
				kind[Vector2i(ix, iz)] = "a"
			else:
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var nx := ix + dx
						var nz := iz + dz
						if nx >= 0 and nx < NX and nz >= 0 and nz < NZ and allowed[nx][nz]:
							kind[Vector2i(ix, iz)] = "b"
	# Terreno: strisce orizzontali unite per zona (meno nodi)
	var runs := 0
	for iz in NZ:
		var ix := 0
		while ix < NX:
			if not kind.has(Vector2i(ix, iz)):
				ix += 1
				continue
			var z := _zone(_cell_center(ix, iz))
			var start := ix
			while ix < NX and kind.has(Vector2i(ix, iz)) and _zone(_cell_center(ix, iz)) == z:
				ix += 1
			var n := ix - start
			var c := Vector2(X0 + (start + n * 0.5) * CELL, Z0 - (iz + 0.5) * CELL)
			var sb := StaticBody3D.new()
			sb.name = "Suolo_%d" % runs
			sb.collision_layer = Layers.WORLD
			sb.collision_mask = 0
			sb.position = _v3(c, -0.5)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(n * CELL, 1, CELL)
			cs.shape = bs
			sb.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = bs.size
			mi.mesh = bm
			var zc: Color = ZONE_COLORS[z]
			mi.material_override = Fx.mat(zc.darkened(0.04 * (iz % 2)))
			sb.add_child(mi)
			ground.add_child(sb)
			sb.owner = level_root
			cs.owner = level_root
			mi.owner = level_root
			runs += 1
	# Confini: bosco fitto o scogliere
	var nb := 0
	for k: Vector2i in kind:
		if kind[k] != "b":
			continue
		var c := _cell_center(k.x, k.y)
		var z := _zone(c)
		var pname := "scogliera" if z in ["campo", "necropoli", "citta", "relitto"] else "bosco_fitto"
		var inst: Node3D = (prop_scenes[pname] as PackedScene).instantiate()
		inst.position = _v3(c)
		inst.rotation_degrees.y = 90.0 * rng.randi_range(0, 3)
		bounds.add_child(inst)
		inst.owner = level_root
		nb += 1
	print("Terreno: %d strisce, %d celle di confine" % [runs, nb])


func _cell_center(ix: int, iz: int) -> Vector2:
	return Vector2(X0 + (ix + 0.5) * CELL, Z0 - (iz + 0.5) * CELL)


func _build_road(region: Node3D) -> void:
	var road := _group(region, "Strada")
	var stone := Color(0.6, 0.57, 0.52)
	for i in ROAD.size() - 1:
		_strip(road, ROAD[i], ROAD[i + 1], 6.0, 0.02, 0.04, stone)
		_disc(road, ROAD[i], 3.0, 0.02, stone)
		# Bordi della via (cordoli)
		var d := ((ROAD[i + 1] as Vector2) - (ROAD[i] as Vector2)).normalized()
		var n := _perp(d) * 3.2
		_strip(road, (ROAD[i] as Vector2) + n, (ROAD[i + 1] as Vector2) + n, 0.4, 0.04, 0.08, stone.darkened(0.25))
		_strip(road, (ROAD[i] as Vector2) - n, (ROAD[i + 1] as Vector2) - n, 0.4, 0.04, 0.08, stone.darkened(0.25))
	_disc(road, ROAD[-1], 3.0, 0.02, stone)
	var dirt := Color(0.5, 0.4, 0.28)
	for c: Array in PATHS:
		_strip(road, c[0], c[1], 3.5, 0.015, 0.03, dirt)
		_disc(road, c[0], 1.75, 0.015, dirt)
		_disc(road, c[1], 1.75, 0.015, dirt)


func _build_river(region: Node3D) -> void:
	var river := _group(region, "Fiume")
	var water := Color(0.15, 0.38, 0.58)
	var x := X0
	while x < X0 + NX * CELL:
		var a := Vector2(x, _river_z(x))
		var b := Vector2(x + 4.0, _river_z(x + 4.0))
		var mid := (a + b) * 0.5
		_strip(river, a - (b - a).normalized() * 0.2, b + (b - a).normalized() * 0.2, 14.0, 0.03, 0.04, water)
		if mid.distance_to(_bridge_c) > 4.5 and mid.distance_to(FORD) > 4.0:
			if _allowed(mid) or _allowed(mid + Vector2(0, 8)) or _allowed(mid - Vector2(0, 8)):
				var blk := StaticBody3D.new()
				blk.collision_layer = Layers.WORLD
				blk.collision_mask = 0
				blk.position = _v3(mid, 0.75)
				blk.rotation.y = atan2(-(b.y - a.y), b.x - a.x)
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(4.4, 1.5, 12.0)
				cs.shape = bs
				blk.add_child(cs)
				river.add_child(blk)
				blk.owner = level_root
				cs.owner = level_root
		x += 4.0
	# Ponte sulla strada
	_place("ponte", river, _bridge_c, rad_to_deg(atan2(_bridge_d.x, _bridge_d.y)))
	# Guado a ovest: pietre
	for i in 6:
		var p := FORD + Vector2(rng.randf_range(-3, 3), -6 + i * 2.4)
		_disc(river, p, rng.randf_range(0.6, 0.9), 0.05, ROCK.lightened(0.1))
	for i in 10:
		var side := 1.0 if i % 2 == 0 else -1.0
		var p := _bridge_c + Vector2(rng.randf_range(-14, 14), side * rng.randf_range(8, 11))
		if absf(p.x - _bridge_c.x) > 5.0:
			_place("canne", river, p, rng.randf() * 360.0)


func _build_villa(parent: Node) -> void:
	var g := _group(parent, "VillaDiFamiglia")
	_clear.append([Vector2(0, 16), 26.0])
	_place("casa", g, Vector2(0, 28))
	_place("fienile", g, Vector2(-21, 20), 90.0)
	_place("pozzo", g, Vector2(9, 10))
	_place("carro", g, Vector2(15, 18), 20.0)
	for p: Vector2 in [Vector2(6, 21), Vector2(7.2, 21.5), Vector2(-6, 21)]:
		_place("anfora", g, p)
	_place("cassa", g, Vector2(-14, 12), 15.0)
	_place("cassa", g, Vector2(-13, 13.4), 40.0)
	# Recinto del cortile (apertura sulla strada a nord)
	var x := -26.0
	while x <= 26.0:
		if absf(x) > 5.0:
			_place("staccionata", g, Vector2(x, -6))
		x += 4.0
	var z := -4.0
	while z <= 34.0:
		_place("staccionata", g, Vector2(-28, z), 90.0)
		_place("staccionata", g, Vector2(28, z), 90.0)
		z += 4.0
	# Campi coltivati
	for side: float in [-1.0, 1.0]:
		var fx := 16.0
		while fx <= 38.0:
			var fz := -16.0
			while fz >= -50.0:
				_place("filare", g, Vector2(fx * side, fz))
				fz -= 9.0
			fx += 3.0
		_clear.append([Vector2(27 * side, -33), 18.0])
	_place("covone", g, Vector2(-30, -58))
	_place("covone", g, Vector2(-26, -61), 30.0)
	_place("covone", g, Vector2(31, -58))
	_place("altare", g, Vector2(-7, 1), 0.0, 1.0, {"checkpoint_id": "villa", "title": "Altare dei Lari"})
	_place("cartello", g, Vector2(6, 1), 180.0, 1.0, {"title": "Villa di famiglia",
		"text": "Casa. Qui sei cresciuto, tra gli ulivi e il ronzio dei droni agricoli.\n\n[TRAMA: perché il protagonista deve partire per Ostia Nova? Scrivilo qui.]\n\nSegui la Via verso nord: la città è a meno di un'ora di cammino."})


func _build_pois(parent: Node) -> void:
	# --- Fattoria razziata dai predoni ---
	var g := _group(parent, "FattoriaRazziata")
	var c := Vector2(-58, -98)
	_clear.append([c, 13.0])
	_place("muro_rovina", g, c + Vector2(-6, 0), 90.0)
	_place("muro_rovina", g, c + Vector2(6, 0), 90.0)
	_place("muro_rovina", g, c + Vector2(0, -6))
	_place("fienile", g, c + Vector2(-12, -12), 20.0)
	_place("carro", g, c + Vector2(10, -10), 40.0)
	_place("falo", g, c)
	_place("cassa", g, c + Vector2(8, 8))
	_place("cassa", g, c + Vector2(9.3, 8.4), 30.0)
	_place("forziere", g, c + Vector2(-3, -3), 0.0, 1.0, {"flag_id": "chest_fattoria", "item_level": 1})
	for i in 4:
		_place("anfora", g, c + Vector2(rng.randf_range(-5, 5), rng.randf_range(2, 5)))

	# --- Relitto di una navetta imperiale ---
	g = _group(parent, "RelittoNavetta")
	c = Vector2(205, -250)
	_clear.append([c, 14.0])
	_place("relitto_navetta", g, c, 30.0)
	for i in 6:
		var a := rng.randf() * TAU
		_place("cassa", g, c + Vector2(cos(a), sin(a)) * rng.randf_range(8, 12), rng.randf() * 90.0)
	_place("forziere", g, c + Vector2(9, -8), -30.0, 1.0, {"flag_id": "chest_relitto", "item_level": 2, "rich": true})
	_place("forziere", g, Vector2(172, -180), 60.0, 1.0, {"flag_id": "chest_bosco", "item_level": 2})

	# --- Fiume: capanno e checkpoint dopo il ponte ---
	g = _group(parent, "Ponte")
	_place("tenda", g, Vector2(112, -316), 20.0)
	_place("barile", g, Vector2(108, -312))
	var cp := _bridge_c + _bridge_d * 18.0 + _perp(_bridge_d) * 6.0
	_place("altare", g, cp, 0.0, 1.0, {"checkpoint_id": "ponte", "title": "Altare di Portuno"})
	_clear.append([cp, 4.0])
	_place("forziere", g, Vector2(95, -355), 0.0, 1.0, {"flag_id": "chest_ponte", "item_level": 2})

	# --- Boschetto sacro oltre il guado ---
	g = _group(parent, "BoschettoSacro")
	c = Vector2(-110, -292)
	_clear.append([c, 11.0])
	for i in 8:
		var a := i * TAU / 8.0
		_place("cipresso", g, c + Vector2(cos(a), sin(a)) * 9.0)
	_place("statua", g, c, 180.0)
	_place("forziere", g, c + Vector2(0, 4), 180.0, 1.0, {"flag_id": "chest_boschetto", "item_level": 3, "rich": true})

	# --- Tempio in rovina ---
	g = _group(parent, "TempioInRovina")
	c = Vector2(-115, -410)
	_clear.append([c, 17.0])
	_place("pavimento_tempio", g, c)
	var zz := -11.0
	while zz <= 11.0:
		for sx: float in [-6.5, 6.5]:
			_place("colonna" if rng.randf() > 0.4 else "colonna_rotta", g, c + Vector2(sx, zz), rng.randf() * 360.0)
		zz += 4.4
	_place("statua", g, c + Vector2(0, -10), 0.0, 1.2)
	_place("forziere", g, c + Vector2(0, -6), 0.0, 1.0, {"flag_id": "chest_tempio", "item_level": 3, "rich": true})
	_place("muro_rovina", g, c + Vector2(-16, 12), 90.0)
	_place("muro_rovina", g, c + Vector2(15, -14), 10.0)
	_place("cartello", g, Vector2(-14, -432), 0.0, 1.0, {"title": "Bivio del Tempio",
		"text": "Una deviazione verso ovest porta al vecchio tempio di Saturno.\n\n[TRAMA: leggenda del tempio / indizio sulla missione.]"})
	for i in 4:
		_place("anfora", g, c + Vector2(rng.randf_range(-4, 4), rng.randf_range(6, 11)))

	# --- Accampamento barbaro e cava ---
	g = _group(parent, "AccampamentoBarbaro")
	c = Vector2(-118, -548)
	_clear.append([c, 20.0])
	var a := 0.0
	while a < 360.0:
		var gap := (a < 25.0 or a > 335.0) or (a > 245.0 and a < 290.0)
		if not gap:
			var r := deg_to_rad(a)
			var p := c + Vector2(cos(r), sin(r)) * 20.0
			_place("palizzata", g, p, rad_to_deg(atan2(-cos(r), -sin(r))))
		a += 11.5
	for i in 6:
		var r := deg_to_rad(40.0 + i * 50.0)
		_place("tenda", g, c + Vector2(cos(r), sin(r)) * 12.0, rad_to_deg(-r) + 90.0)
	_place("falo", g, c)
	_place("falo", g, c + Vector2(-8, 5))
	_place("falo", g, c + Vector2(6, -7))
	_place("torre_guardia", g, c + Vector2(22, 9))
	_place("torre_guardia", g, c + Vector2(22, -9))
	_place("carro", g, c + Vector2(-4, 10), 70.0)
	_place("forziere", g, c + Vector2(-13, -2), 90.0, 1.0, {"flag_id": "chest_campo", "item_level": 4, "rich": true})
	for i in 5:
		_place("anfora", g, c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-12, -8)))
	for i in 3:
		_place("cassa", g, c + Vector2(-9 + i * 1.3, 9), rng.randf() * 30.0)

	# --- Necropoli lungo la Via (come la Via Appia) ---
	g = _group(parent, "Necropoli")
	var s := float(road_cum[10]) + 30.0
	var side := 1.0
	while s < float(road_cum[13]):
		var rp: Array = _road_point(s)
		var p: Vector2 = rp[0]
		var d: Vector2 = rp[1]
		var off: Vector2 = p + _perp(d) * 11.0 * side
		if _is_clear(off):
			if rng.randf() < 0.6:
				_place("tomba", g, off, rad_to_deg(atan2(d.x, d.y)))
			else:
				for k in 3:
					_place("sarcofago", g, off + d * (k - 1) * 1.6, rad_to_deg(atan2(d.x, d.y)) + 90.0)
			_clear.append([off, 4.0])
		for sd: float in [-1.0, 1.0]:
			var cy := p + d * 8.0 + _perp(d) * 6.0 * sd
			_place("cipresso", g, cy)
			_clear.append([cy, 1.5])
		side = -side
		s += 17.0
	var rp2: Array = _road_point(float(road_cum[11]) - 12.0)
	_place("altare", g, (rp2[0] as Vector2) + _perp(rp2[1]) * 6.0, 0.0, 1.0, {"checkpoint_id": "necropoli", "title": "Altare di Proserpina"})
	var rp3: Array = _road_point(float(road_cum[11]) + 6.0)
	_place("cartello", g, (rp3[0] as Vector2) - _perp(rp3[1]) * 5.0, 0.0, 1.0, {"title": "Via dei Sepolcri",
		"text": "Qui riposano le grandi famiglie di Ostia Nova. Di notte, dicono, i lemuri tornano a camminare.\n\n[TRAMA]"})

	# --- Mausoleo ---
	g = _group(parent, "Mausoleo")
	c = Vector2(150, -662)
	_clear.append([c, 14.0])
	_place("tomba", g, c, 0.0, 2.0)
	_place("statua", g, c + Vector2(-7, 9), 180.0)
	_place("statua", g, c + Vector2(7, 9), 180.0)
	_place("forziere", g, c + Vector2(0, 8), 180.0, 1.0, {"flag_id": "chest_mausoleo", "item_level": 5, "rich": true})
	for i in 4:
		_place("anfora", g, c + Vector2(rng.randf_range(-6, 6), rng.randf_range(10, 13)))

	# --- Periferia di Ostia Nova: acquedotto, mura, porta ---
	g = _group(parent, "OstiaNova")
	s = float(road_cum[13]) + 5.0
	while s < float(road_cum[15]) + 20.0:
		var rp: Array = _road_point(s)
		var p: Vector2 = (rp[0] as Vector2) - _perp(rp[1]) * 17.0
		var d: Vector2 = rp[1]
		_place("arco_acquedotto", g, p, rad_to_deg(atan2(-d.y, d.x)))
		_clear.append([p, 6.0])
		s += 10.0
	var wx := 18.0
	while wx <= 84.0:
		if absf(wx - 50.0) > 12.0:
			_place("muro", g, Vector2(wx, -896))
		wx += 8.0
	_place("porta_citta", g, Vector2(50, -896))
	_clear.append([Vector2(50, -890), 12.0])
	_place("stendardo", g, Vector2(41, -889))
	_place("stendardo", g, Vector2(59, -889))
	var rp4: Array = _road_point(float(road_cum[13]) + 40.0)
	_place("altare", g, (rp4[0] as Vector2) + _perp(rp4[1]) * 6.0, 0.0, 1.0, {"checkpoint_id": "acquedotto", "title": "Altare di Giano"})
	_place("cartello", g, Vector2(66, -884), 0.0, 1.0, {"title": "Porta di Ostia Nova",
		"text": "La porta della città. Le guardie sono sparite e un rinnegato si è accampato qui davanti.\n\n[TRAMA]"})


func _build_road_props(region: Node3D) -> void:
	var g := _group(region, "ArredoStradale")
	var s := 30.0
	var side := 1.0
	var i := 0
	while s < road_total - 10.0:
		var rp: Array = _road_point(s)
		var p: Vector2 = (rp[0] as Vector2) + _perp(rp[1]) * 4.6 * side
		if p.distance_to(_bridge_c) > 15.0 and _is_clear(p):
			_place("lampione_plasma", g, p)
		if i % 6 == 3:
			var m: Vector2 = (rp[0] as Vector2) - _perp(rp[1]) * 4.6 * side
			if _is_clear(m) and m.distance_to(_bridge_c) > 15.0:
				_place("miliario", g, m)
		side = -side
		s += 36.0
		i += 1


func _build_scatter(region: Node3D) -> void:
	var g := _group(region, "Vegetazione")
	var count := 0
	for ix in NX:
		for iz in NZ:
			var cc := _cell_center(ix, iz)
			if not _allowed(cc):
				continue
			var z := _zone(cc)
			for entry: Array in ZONE_SCATTER[z]:
				if rng.randf() >= float(entry[1]):
					continue
				var pname: String = entry[0]
				var p := cc + Vector2(rng.randf_range(-3.6, 3.6), rng.randf_range(-3.6, 3.6))
				var big := pname in BIG_PROPS
				var rad := 2.0 if big else 0.8
				if float(_road_info(p)[0]) < (5.5 if big else 4.0):
					continue
				if _in_river(p, 2.0) and pname != "canne":
					continue
				if pname == "canne" and not _in_river(p, 6.0):
					continue
				if not _allowed(p) or not _is_clear(p) or not _free_spot(p, rad):
					continue
				_occupy(p, rad)
				_place(pname, g, p, rng.randf() * 360.0, rng.randf_range(0.85, 1.25) if big else rng.randf_range(0.8, 1.2))
				count += 1
	print("Vegetazione e oggetti sparsi: %d" % count)


func _build_encounters() -> void:
	var g := Node3D.new()
	g.name = "Incontri"
	level_root.add_child(g)
	g.owner = level_root
	# [nome, posizione, tipi, numero, livello, elite, boss]
	var list := [
		["Predoni_fattoria", Vector2(-50, -95), ["predone"], 5, 1, false, ""],
		["Predoni_campi", Vector2(30, -118), ["predone"], 3, 1, false, ""],
		["Lupi_margine", Vector2(110, -160), ["lupo"], 4, 1, false, ""],
		["Lupi_bosco", Vector2(160, -218), ["lupo"], 5, 2, false, ""],
		["Banditi_bosco", Vector2(128, -282), ["predone", "lupo"], 5, 2, false, ""],
		["Droni_relitto", Vector2(200, -246), ["drone"], 3, 2, true, ""],
		["Droni_relitto2", Vector2(190, -262), ["drone"], 3, 2, false, ""],
		["Predoni_ponte", Vector2(100, -305), ["predone"], 4, 2, false, ""],
		["Imboscata_nord", Vector2(68, -372), ["drone", "predone"], 6, 2, false, ""],
		["Lemuri_boschetto", Vector2(-110, -298), ["lemure"], 3, 3, true, ""],
		["Barbari_avanguardia", Vector2(30, -405), ["barbaro", "predone"], 5, 3, false, ""],
		["Predoni_tempio", Vector2(-115, -404), ["predone"], 3, 3, true, ""],
		["Rinnegati_tempio", Vector2(-108, -420), ["rinnegato"], 2, 3, false, ""],
		["Lupi_colline", Vector2(-40, -455), ["lupo"], 5, 3, false, ""],
		["Barbari_strada", Vector2(-82, -500), ["barbaro", "frombolier"], 6, 3, false, ""],
		["Campo_barbaro", Vector2(-115, -548), ["barbaro", "frombolier"], 8, 4, false, ""],
		["Campioni_campo", Vector2(-122, -566), ["barbaro"], 3, 4, true, ""],
		["Bruto_cava", Vector2(-68, -590), ["bruto", "barbaro", "barbaro", "barbaro"], 4, 4, false, ""],
		["Lemuri_sepolcri", Vector2(-8, -628), ["lemure"], 5, 4, false, ""],
		["Lemuri_sepolcri2", Vector2(42, -662), ["lemure"], 6, 4, false, ""],
		["Lemuri_mausoleo", Vector2(150, -650), ["lemure"], 3, 5, true, ""],
		["Rinnegati_acquedotto", Vector2(88, -722), ["rinnegato", "lemure"], 5, 5, false, ""],
		["Rinnegati_porta", Vector2(100, -790), ["rinnegato", "drone"], 6, 5, false, ""],
		["Boss_Brenno", Vector2(62, -852), ["rinnegato"], 3, 5, false, "brenno"],
	]
	for e: Array in list:
		var z: Node3D = load("res://world/encounter_zone.gd").new()
		z.name = e[0]
		z.position = _v3(e[1])
		z.set("enemy_types", PackedStringArray(e[2]))
		z.set("count", e[3])
		z.set("enemy_level", e[4])
		z.set("elite", e[5])
		z.set("unique_id", e[6])
		z.set("radius", 7.0 if e[3] > 4 else 5.0)
		g.add_child(z)
		z.owner = level_root
		if not _allowed(e[1]):
			push_warning("Incontro %s fuori dall'area giocabile" % e[0])
	print("Incontri: %d" % list.size())
