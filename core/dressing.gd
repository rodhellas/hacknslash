class_name Dressing
extends RefCounted
## ARREDO DEI LIVELLI ALL'APERTO (grayboxing, stesso concetto delle mappe di Diablo 3 / Diablo Immortal):
## - il percorso è "scavato" dentro una massa fitta: oltre i confini bosco a strati (cespugli, poi alberi
##   sempre più fitti), pareti di roccia o tetti di case a seconda della zona; qua e là rovine e torri
##   lontane come punti di riferimento;
## - il terreno calpestabile è coperto: ciuffi d'erba che ondeggiano, fiori, felci, sassi, funghi, rami,
##   ossa e lastre nella necropoli, detriti in città e al porto; più fitto lungo i bordi e ai lati delle strade;
## - verso la telecamera (a sud del percorso) solo roba bassa, così l'eroe non sparisce dietro gli alberi.
## Tutto è decorativo: nessuna collisione, non tocca la navmesh né il .tscn. Si costruisce al caricamento
## del livello (Level._ready) dalla Forma (prima che si cancelli), con un seme fisso: stesso livello =
## stesso arredo. Disegnato con MultiMesh a blocchi da CHUNK metri (pochi draw call, si spengono da lontano).
## Le forme sono semplici solidi colorati (in attesa dei modelli veri) generati qui sotto (`mesh(id)`).

const CHUNK := 64.0
const OOB_RINGS := 7          # celle (da 8 m) arredate oltre il bordo calpestabile
const COVER_RANGE := 75.0     # distanza oltre cui spariscono erba e sassi
const BIG_RANGE := 95.0

## Zona -> famiglia di arredo.
const FAMILY := {
	"fattoria": "prato", "fiume": "prato", "boschetto": "prato", "tempio": "prato",
	"bosco": "bosco",
	"relitto": "secco", "campo": "secco", "necropoli": "necropoli", "citta": "secco", "faro": "secco",
	"urbe": "urbano", "foro": "urbano", "piazzale": "urbano",
	"strada": "porto", "magazzini": "porto", "cantieri": "porto", "spazioporto": "porto", "sale": "porto",
	"molo": "porto", "cantiere": "porto",
}

## Copertura del suolo calpestabile: [forma, quanti per cella da 8×8 m, scala min, scala max].
const COVER := {
	"prato": [["erba", 30, 0.8, 1.3], ["erba_alta", 4, 0.8, 1.2], ["fiori_gialli", 2.5, 0.8, 1.2], ["fiori_bianchi", 2.0, 0.8, 1.2],
		["fiori_viola", 1.5, 0.8, 1.2], ["sassolini", 2.5, 0.8, 1.3], ["cespuglietto", 0.5, 0.7, 1.2], ["sasso", 0.4, 0.7, 1.4]],
	"bosco": [["erba", 14, 0.8, 1.3], ["felce", 10, 0.7, 1.4], ["sassolini", 2.5, 0.8, 1.3], ["funghi", 0.8, 0.8, 1.3],
		["ramo", 0.9, 0.8, 1.3], ["cespuglietto", 0.9, 0.7, 1.3], ["sasso", 0.6, 0.7, 1.4], ["foglie", 3.0, 0.8, 1.4]],
	"secco": [["erba_secca", 14, 0.8, 1.3], ["sassolini", 7, 0.8, 1.4], ["sasso", 1.2, 0.6, 1.4], ["ramo", 0.3, 0.8, 1.2],
		["erba", 3, 0.7, 1.0]],
	"necropoli": [["erba_secca", 12, 0.8, 1.3], ["sassolini", 6, 0.8, 1.4], ["sasso", 0.8, 0.6, 1.3], ["lastra", 0.7, 0.8, 1.3],
		["ossa", 0.5, 0.8, 1.2], ["foglie", 1.5, 0.8, 1.2]],
	"urbano": [["erbacce", 1.2, 0.8, 1.2], ["detriti", 0.8, 0.7, 1.2], ["sassolini", 0.8, 0.8, 1.2]],
	"porto": [["detriti", 1.5, 0.7, 1.3], ["assi", 0.5, 0.8, 1.2], ["erbacce", 1.0, 0.8, 1.2], ["sassolini", 1.0, 0.8, 1.2],
		["corde", 0.4, 0.8, 1.2]],
}

## In più lungo il bordo del calpestabile (celle accanto al confine): il bordo diventa una siepe/una frana.
const EDGE := {
	"prato": [["erba_alta", 7, 0.9, 1.4], ["cespuglietto", 2.0, 0.8, 1.4], ["felce", 3, 0.8, 1.3], ["sasso", 0.8, 0.8, 1.5]],
	"bosco": [["felce", 7, 0.9, 1.5], ["cespuglietto", 2.5, 0.8, 1.5], ["tronco_caduto", 0.25, 0.8, 1.2], ["sasso", 0.8, 0.8, 1.6]],
	"secco": [["sasso", 2.0, 0.8, 1.8], ["masso", 0.5, 0.6, 1.0], ["erba_secca", 6, 0.9, 1.4]],
	"necropoli": [["sasso", 1.5, 0.8, 1.6], ["lastra", 1.0, 0.9, 1.4], ["erba_secca", 6, 0.9, 1.3]],
	"urbano": [["detriti", 1.5, 0.8, 1.3], ["erbacce", 2.0, 0.8, 1.3]],
	"porto": [["detriti", 2.0, 0.8, 1.4], ["assi", 0.8, 0.8, 1.2]],
}

## Oltre i confini, per anello (1 = la cella del confine, che ha già il suo oggetto di scena):
## [forma, quanti per cella, scala min, scala max, anello minimo, alto (niente a sud del percorso)].
const OOB := {
	"bosco": [["felce", 6, 0.9, 1.5, 1, false], ["cespuglio", 2.5, 0.8, 1.4, 1, false], ["sasso", 0.6, 0.8, 1.6, 1, false],
		["ALBERO", 2.5, 0.85, 1.25, 2, true], ["ALBERO", 2.5, 0.9, 1.3, 3, true], ["cespuglio", 1.0, 0.9, 1.5, 3, false],
		["masso", 0.15, 0.8, 1.3, 2, false]],
	"roccia": [["sasso", 2.5, 0.8, 1.8, 1, false], ["masso", 1.0, 0.7, 1.2, 1, false], ["erba_secca", 6, 0.9, 1.4, 1, false],
		["masso_grande", 1.0, 0.7, 1.3, 2, true], ["parete", 0.9, 0.8, 1.3, 2, true], ["ALBERO", 0.6, 0.85, 1.2, 2, true],
		["parete", 1.2, 0.9, 1.4, 4, true]],
	"citta": [["detriti", 2.0, 0.8, 1.4, 1, false], ["erbacce", 2.0, 0.8, 1.3, 1, false],
		["EDIFICIO", 0.9, 0.95, 1.05, 2, true]],
}
## Punti di riferimento lontani (anelli 3-6): uno ogni tanto.
const LANDMARKS := {"bosco": ["rovina", "torre", "statua"], "roccia": ["rovina", "torre"], "citta": []}
## Alberi oltre i confini per zona.
const TREES := {
	"fattoria": ["olivo", "quercia", "pino_marittimo"], "fiume": ["quercia", "quercia", "pino"],
	"boschetto": ["cipresso", "quercia"], "tempio": ["cipresso", "quercia", "cipresso"],
	"bosco": ["pino", "pino", "quercia"], "relitto": ["pino"], "campo": ["pino"], "necropoli": ["cipresso"],
	"citta": ["pino_marittimo", "cipresso"], "faro": ["pino_marittimo"],
}
## Forme che ondeggiano col vento e non fanno ombra (copertura del suolo).
const SOFT := ["erba", "erba_alta", "erba_secca", "erbacce", "felce", "fiori_gialli", "fiori_bianchi", "fiori_viola", "foglie"]
const NO_SHADOW := ["erba", "erba_alta", "erba_secca", "erbacce", "felce", "fiori_gialli", "fiori_bianchi", "fiori_viola",
	"foglie", "sassolini", "funghi", "ramo", "ossa", "detriti", "assi", "corde", "lastra", "sasso", "cespuglietto"]

const SHADER := """
shader_type spatial;
render_mode %s;

uniform float sway = 0.07;

void vertex() {
	// alfa del colore del vertice = quanto ondeggia (0 alla base, 1 in cima)
	float w = COLOR.a;
	if (w > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float t = TIME * 1.6 + wp.x * 0.31 + wp.z * 0.23;
		VERTEX.x += sin(t) * sway * w;
		VERTEX.z += cos(t * 0.83) * sway * 0.6 * w;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.93;
	SPECULAR = 0.15;
}
"""

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}

var level: Node3D
var mb: MapBuilder
var rng := RandomNumberGenerator.new()
var density := 1.0
## chunk (Vector2i) -> forma -> [PackedVector3Array posizioni..] come Array di [Transform3D, Color]
var _chunks: Dictionary = {}
var count := 0


## Costruisce l'arredo del livello sotto il nodo "Arredo". Ritorna il numero di oggetti.
static func build(level_root: Node3D) -> int:
	var d := Dressing.new()
	return d._build(level_root)


func _build(level_root: Node3D) -> int:
	level = level_root
	if MapBuilder.find_shape(level_root) == null:
		return 0
	var t0 := Time.get_ticks_msec()
	mb = MapBuilder.new()
	if not mb.rasterize(level_root):
		return 0
	mb._collect_obstacles(false)
	rng.seed = mb.shape.seed + 777
	density = 0.5 if OS.has_feature("mobile") else 1.0
	_inside()
	_outside()
	_retexture_background()
	var root := Node3D.new()
	root.name = "Arredo"
	level_root.add_child(root)
	_emit(root)
	print_verbose("Arredo: %d oggetti in %d ms" % [count, Time.get_ticks_msec() - t0])
	return count


# --- Dentro: copertura del suolo ---------------------------------------------------------------------

func _inside() -> void:
	var c := mb.cell
	for k in mb.state.size():
		if mb.state[k] != 1:
			continue
		var zone: String = mb.zone_of[k]
		var fam: String = FAMILY.get(zone, "prato")
		var ix := k % mb.nx
		var iz := k / mb.nx
		var edge := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if _state(ix + dx, iz + dz) == 0:
					edge = true
		var lists: Array = [COVER.get(fam, [])]
		if edge:
			lists.append(EDGE.get(fam, []))
		var o := mb._center(k) - Vector2(c, c) * 0.5
		for list: Array in lists:
			for e: Array in list:
				var n := _amount(float(e[1]) * density)
				for i in n:
					var p := o + Vector2(rng.randf() * c, rng.randf() * c)
					var pk := mb._cell_of(p)
					if pk < 0 or mb.state[pk] != 1:
						continue
					var clear := mb._paved_clearance(p)
					var id: String = e[0]
					var small := id in ["sassolini", "foglie"]
					if clear < (0.1 if small else 0.45):
						continue
					if not mb._free(p, 0.25):
						continue
					_put(id, Vector3(p.x, 0.0, p.y), rng.randf_range(float(e[2]), float(e[3])))
				# lungo i lati delle strade un po' più di erba e sassi (bordo "sporco" come in D3)
		if fam in ["prato", "bosco", "secco", "necropoli"]:
			for i in _amount(6.0 * density):
				var p := o + Vector2(rng.randf() * c, rng.randf() * c)
				var clear := mb._paved_clearance(p)
				if clear < 0.15 or clear > 1.6 or mb._cell_of(p) != k or not mb._free(p, 0.25):
					continue
				var id := "sassolini" if rng.randf() < 0.35 else ("erba_secca" if fam in ["secco", "necropoli"] else "erba")
				_put(id, Vector3(p.x, 0.0, p.y), rng.randf_range(0.8, 1.3))


# --- Fuori: la massa che chiude il percorso -----------------------------------------------------------

func _outside() -> void:
	var R := OOB_RINGS
	var W := mb.nx + 2 * R
	var H := mb.nz + 2 * R
	# distanza (in celle, a scacchiera) dal calpestabile e zona più vicina, solo attraverso celle "fuori"
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(999)
	var zone: Array = []
	zone.resize(W * H)
	var queue: Array[int] = []
	for k in mb.state.size():
		if mb.state[k] == 1:
			var e := (k / mb.nx + R) * W + (k % mb.nx + R)
			dist[e] = 0
			zone[e] = mb.zone_of[k]
			queue.append(e)
	var head := 0
	while head < queue.size():
		var e := queue[head]
		head += 1
		var d := dist[e]
		if d >= R:
			continue
		var ex := e % W
		var ez := e / W
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var fx := ex + dx
				var fz := ez + dz
				if fx < 0 or fz < 0 or fx >= W or fz >= H:
					continue
				var f := fz * W + fx
				if dist[f] <= d + 1 or _state(fx - R, fz - R) != 0:
					continue
				dist[f] = d + 1
				zone[f] = zone[e]
				queue.append(f)
	var c := mb.cell
	var y := mb.shape.background_y
	for e in W * H:
		var ring := dist[e]
		if ring < 1 or ring > R:
			continue
		var ix := e % W - R
		var iz := e / W - R
		var z: String = zone[e]
		var kit := _oob_kit(z)
		if kit == "":
			continue
		# a sud del percorso (verso la telecamera) e vicino: solo roba bassa
		var front := false
		for dz in range(1, 3):
			for dx in range(-1, 2):
				if _state(ix + dx, iz - dz) == 1:
					front = true
		var o := Vector2(mb.xmin + ix * c, mb.zmin + iz * c)
		var trees: Array = TREES.get(z, ["pino"])
		for entry: Array in OOB[kit]:
			if ring < int(entry[4]):
				continue
			var tall: bool = entry[5]
			if tall and front and ring <= 3:
				continue
			for i in _amount(float(entry[1]) * (density if not tall else 1.0)):
				var p := o + Vector2(rng.randf() * c, rng.randf() * c)
				var id: String = entry[0]
				var yaw := -1.0
				if id == "ALBERO":
					id = trees[rng.randi() % trees.size()]
				elif id == "EDIFICIO":
					# isolati a griglia: un edificio per cella, allineato (più alti lontano dal percorso)
					id = "insula" if ring >= 3 and rng.randf() < 0.55 else "casa"
					p = o + Vector2(c, c) * 0.5
					yaw = PI * 0.5 * (rng.randi() % 4)
				_put(id, Vector3(p.x, y, p.y), rng.randf_range(float(entry[2]), float(entry[3])), yaw)
		var lm: Array = LANDMARKS[kit]
		if not lm.is_empty() and ring >= 3 and ring <= 6 and not front and rng.randf() < 0.035:
			var p := o + Vector2(c, c) * 0.5
			_put(lm[rng.randi() % lm.size()], Vector3(p.x, y, p.y), rng.randf_range(0.9, 1.2))


func _oob_kit(zone: String) -> String:
	match String(MapZones.get_zone(zone)["border"]):
		"bosco_fitto":
			return "bosco"
		"scogliera":
			return "roccia"
		"isolato":
			return "citta"
	return ""


## Lo sfondo piatto (fuori dalla mappa) prende la texture della famiglia più presente: niente "vuoto" tra gli alberi.
func _retexture_background() -> void:
	var bg := level.get_node_or_null("World/Terreno/Sfondo") as MeshInstance3D
	if bg == null:
		return
	var votes := {}
	for k in mb.state.size():
		if mb.state[k] == 1:
			var kit := _oob_kit(String(mb.zone_of[k]))
			votes[kit] = int(votes.get(kit, 0)) + 1
	var best := ""
	for kit: String in votes:
		if best == "" or int(votes[kit]) > int(votes[best]):
			best = kit
	var tex: String = {"bosco": "sottobosco", "roccia": "terra_battuta", "citta": "lastricato"}.get(best, "")
	if tex == "":
		return
	var m := Terrain.material(tex, mb.shape.background_color, 0.55)
	if m != null:
		bg.material_override = m


# --- Istanze ----------------------------------------------------------------------------------------

func _state(ix: int, iz: int) -> int:
	if ix < 0 or iz < 0 or ix >= mb.nx or iz >= mb.nz:
		return 0
	return mb.state[iz * mb.nx + ix]


## Quantità con parte frazionaria: 2.4 = 2, più 1 nel 40% dei casi.
func _amount(x: float) -> int:
	var n := int(x)
	if rng.randf() < x - float(n):
		n += 1
	return n


func _put(id: String, pos: Vector3, sc: float, yaw: float = -1.0) -> void:
	var key := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	if not _chunks.has(key):
		_chunks[key] = {}
	var ch: Dictionary = _chunks[key]
	if not ch.has(id):
		ch[id] = []
	var b := Basis(Vector3.UP, rng.randf() * TAU if yaw < 0.0 else yaw)
	if id in SOFT or id in ["sasso", "masso", "cespuglietto", "cespuglio"]:
		var ta := rng.randf() * TAU
		b = Basis(Vector3(cos(ta), 0.0, sin(ta)), rng.randf_range(0.0, 0.12)) * b
	b = b.scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.1), sc))
	var v := rng.randf_range(0.82, 1.12)
	var col := Color(v * rng.randf_range(0.95, 1.05), v, v * rng.randf_range(0.95, 1.05))
	(ch[id] as Array).append([Transform3D(b, pos), col])
	count += 1


func _emit(root: Node3D) -> void:
	for key: Vector2i in _chunks:
		var ch: Dictionary = _chunks[key]
		for id: String in ch:
			var list: Array = ch[id]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh(id)
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i][0])
				mm.set_instance_color(i, list[i][1])
			var mi := MultiMeshInstance3D.new()
			mi.name = "%s_%d_%d" % [id, key.x, key.y]
			mi.multimesh = mm
			var big := not (id in NO_SHADOW)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if big else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = BIG_RANGE if big else COVER_RANGE
			mi.visibility_range_end_margin = 8.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			root.add_child(mi)


# ==================================================================================================
#  Forme (grayboxing: solidi colorati, facce piatte; l'alfa del colore = quanto ondeggia col vento)
# ==================================================================================================

static func material(soft: bool) -> ShaderMaterial:
	var key := "soft" if soft else "solid"
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = SHADER % ("cull_disabled" if soft else "cull_back")
		var m := ShaderMaterial.new()
		m.shader = sh
		_mats[key] = m
	return _mats[key]


static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var b := _MeshKit.new(id)
	match id:
		"erba": b.tuft(9, 0.3, 0.55, 0.045, Color(0.3, 0.46, 0.18), Color(0.55, 0.68, 0.3), 0.22)
		"erba_alta": b.tuft(13, 0.6, 1.0, 0.05, Color(0.28, 0.42, 0.16), Color(0.6, 0.66, 0.3), 0.3)
		"erba_secca": b.tuft(8, 0.25, 0.45, 0.04, Color(0.45, 0.4, 0.22), Color(0.72, 0.64, 0.38), 0.2)
		"erbacce": b.tuft(6, 0.15, 0.32, 0.04, Color(0.3, 0.36, 0.2), Color(0.5, 0.56, 0.32), 0.12)
		"felce": b.fronds(8, 0.55, 0.12, Color(0.16, 0.32, 0.12), Color(0.32, 0.52, 0.2))
		"fiori_gialli": b.flowers(Color(0.95, 0.8, 0.2))
		"fiori_bianchi": b.flowers(Color(0.93, 0.93, 0.88))
		"fiori_viola": b.flowers(Color(0.6, 0.35, 0.8))
		"foglie": b.leaves()
		"sassolini":
			for i in 5:
				var p := Vector3(b.r(-0.35, 0.35), 0.0, b.r(-0.35, 0.35))
				var s := b.r(0.05, 0.12)
				b.rock(p, Vector3(s, s * 0.6, s * b.r(0.8, 1.2)), Color(0.5, 0.48, 0.44), 0.3)
		"sasso": b.rock(Vector3.ZERO, Vector3(0.3, 0.2, 0.25), Color(0.5, 0.48, 0.44), 0.3)
		"masso":
			b.rock(Vector3.ZERO, Vector3(0.75, 0.55, 0.65), Color(0.47, 0.45, 0.41), 0.3)
			b.rock(Vector3(0.6, 0, 0.3), Vector3(0.35, 0.25, 0.3), Color(0.5, 0.48, 0.44), 0.3)
		"masso_grande":
			b.rock(Vector3.ZERO, Vector3(1.9, 1.5, 1.6), Color(0.45, 0.43, 0.39), 0.25)
			b.rock(Vector3(1.6, 0, 0.8), Vector3(1.0, 0.8, 0.9), Color(0.48, 0.46, 0.42), 0.25)
			b.rock(Vector3(-1.2, 0, 1.0), Vector3(0.6, 0.4, 0.6), Color(0.5, 0.48, 0.44), 0.3)
		"parete":
			# pilastro di roccia stratificato (parete della scogliera)
			var h := 0.0
			for i in 4:
				var s := 2.6 - i * 0.4
				b.rock(Vector3(b.r(-0.4, 0.4), h, b.r(-0.4, 0.4)), Vector3(s, 1.4, s * 0.85), Color(0.44, 0.4, 0.35).lightened(i * 0.04), 0.18)
				h += 1.6
		"cespuglietto":
			for i in 3:
				b.blob(Vector3(b.r(-0.25, 0.25), 0.22, b.r(-0.25, 0.25)), Vector3(0.32, 0.26, 0.32), Color(0.2, 0.36, 0.15), 0.25, 0.4)
		"cespuglio":
			for i in 5:
				b.blob(Vector3(b.r(-0.6, 0.6), b.r(0.4, 0.7), b.r(-0.6, 0.6)), Vector3.ONE * b.r(0.5, 0.75), Color(0.18, 0.33, 0.14), 0.25, 0.3)
		"funghi":
			for i in 3:
				var p := Vector3(b.r(-0.15, 0.15), 0.0, b.r(-0.15, 0.15))
				var s := b.r(0.6, 1.0)
				b.cyl(p + Vector3(0, 0.05 * s, 0), 0.02 * s, 0.1 * s, Color(0.88, 0.85, 0.78))
				b.blob(p + Vector3(0, 0.1 * s, 0), Vector3(0.07, 0.035, 0.07) * s, Color(0.7, 0.22, 0.16) if i == 0 else Color(0.55, 0.4, 0.28), 0.0, 0.0)
		"ramo":
			b.log_piece(Vector3.ZERO, 0.035, 1.1, 0.0, Color(0.32, 0.23, 0.15))
			b.log_piece(Vector3(0.2, 0.0, 0.1), 0.02, 0.45, 0.7, Color(0.32, 0.23, 0.15))
		"tronco_caduto":
			b.log_piece(Vector3(0, 0.25, 0), 0.25, 2.6, 0.0, Color(0.35, 0.25, 0.16))
			b.blob(Vector3(0.8, 0.45, 0), Vector3(0.2, 0.12, 0.2), Color(0.25, 0.4, 0.18), 0.2, 0.0)
		"ossa":
			for i in 3:
				b.log_piece(Vector3(b.r(-0.3, 0.3), 0.02, b.r(-0.3, 0.3)), 0.025, b.r(0.25, 0.45), b.r(0, 3), Color(0.85, 0.82, 0.72))
			b.blob(Vector3(0.1, 0.07, -0.2), Vector3(0.09, 0.08, 0.1), Color(0.86, 0.83, 0.74), 0.1, 0.0)
		"lastra":
			b.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.55), 0.15, Color(0.6, 0.58, 0.54))
			b.box(Vector3(0.6, 0.04, 0.35), Vector3(0.35, 0.08, 0.3), 0.6, Color(0.58, 0.56, 0.52))
		"detriti":
			for i in 5:
				var s := b.r(0.08, 0.22)
				b.box(Vector3(b.r(-0.4, 0.4), s * 0.4, b.r(-0.4, 0.4)), Vector3(s, s * 0.8, s * b.r(0.7, 1.4)), b.r(0, 3), Color(0.52, 0.5, 0.46).darkened(b.r(0, 0.25)))
		"assi":
			b.box(Vector3(0, 0.03, 0), Vector3(1.5, 0.05, 0.22), 0.0, Color(0.42, 0.31, 0.2))
			b.box(Vector3(0.1, 0.08, 0.2), Vector3(1.2, 0.05, 0.2), 0.3, Color(0.38, 0.28, 0.18))
		"corde":
			for i in 3:
				b.cyl(Vector3(0, 0.03 + i * 0.05, 0), 0.25 - i * 0.05, 0.05, Color(0.62, 0.52, 0.34))
		"pino":
			b.cyl(Vector3(0, 1.4, 0), 0.25, 2.8, Color(0.33, 0.22, 0.14))
			for i in 4:
				b.cone(Vector3(0, 2.2 + i * 1.3, 0), 2.3 - i * 0.45, 2.4, Color(0.13, 0.27, 0.14).lightened(i * 0.04), 0.03)
		"quercia":
			b.cyl(Vector3(0, 1.3, 0), 0.35, 2.6, Color(0.33, 0.24, 0.15))
			for i in 6:
				b.blob(Vector3(b.r(-1.3, 1.3), b.r(3.2, 4.6), b.r(-1.3, 1.3)), Vector3.ONE * b.r(1.3, 1.9), Color(0.2, 0.34, 0.15).lightened(b.r(0, 0.1)), 0.25, 0.03)
		"cipresso":
			b.cyl(Vector3(0, 0.6, 0), 0.22, 1.2, Color(0.3, 0.22, 0.14))
			b.blob(Vector3(0, 4.3, 0), Vector3(0.95, 4.0, 0.95), Color(0.12, 0.25, 0.13), 0.12, 0.02)
		"olivo":
			b.log_piece(Vector3(0, 0.9, 0), 0.22, 2.0, 0.0, Color(0.36, 0.3, 0.22), true, 0.3)
			for i in 4:
				b.blob(Vector3(b.r(-1.0, 1.0), b.r(2.0, 2.7), b.r(-1.0, 1.0)), Vector3(b.r(1.0, 1.4), 0.7, b.r(1.0, 1.4)), Color(0.4, 0.47, 0.32), 0.25, 0.03)
		"pino_marittimo":
			b.log_piece(Vector3(0, 3.0, 0), 0.22, 6.0, 0.0, Color(0.4, 0.27, 0.17), true, 0.18)
			b.blob(Vector3(0.6, 6.2, 0), Vector3(2.4, 0.8, 2.2), Color(0.18, 0.33, 0.16), 0.25, 0.02)
		"casa":
			b.box(Vector3(0, 2.0, 0), Vector3(6.0, 4.0, 5.5), 0.0, Color(0.72, 0.62, 0.48))
			b.roof(Vector3(0, 4.0, 0), Vector3(6.6, 1.6, 6.1), Color(0.6, 0.3, 0.2))
		"insula":
			b.box(Vector3(0, 4.0, 0), Vector3(7.0, 8.0, 6.5), 0.0, Color(0.68, 0.55, 0.42))
			b.box(Vector3(0, 2.6, 3.3), Vector3(7.0, 0.3, 0.6), 0.0, Color(0.5, 0.4, 0.3))
			b.roof(Vector3(0, 8.0, 0), Vector3(7.6, 1.8, 7.1), Color(0.58, 0.28, 0.19))
		"rovina":
			var marble := Color(0.74, 0.71, 0.65)
			b.box(Vector3(0, 0.25, 0), Vector3(7.0, 0.5, 4.0), 0.0, marble.darkened(0.15))
			for i in 4:
				var hgt := b.r(1.5, 5.5)
				b.cyl(Vector3(-2.7 + i * 1.8, 0.5 + hgt * 0.5, -1.2), 0.38, hgt, marble)
			b.box(Vector3(1.0, 1.2, 1.4), Vector3(4.0, 1.4, 0.6), 0.1, marble.darkened(0.08))
			b.log_piece(Vector3(-1.0, 0.85, 1.0), 0.38, 3.0, 0.4, marble.darkened(0.05))
		"torre":
			b.cyl(Vector3(0, 5.0, 0), 2.2, 10.0, Color(0.55, 0.5, 0.44))
			for i in 6:
				var a := TAU * i / 6.0
				b.box(Vector3(cos(a) * 1.9, 10.4 + b.r(0, 0.4), sin(a) * 1.9), Vector3(0.9, b.r(0.6, 1.2), 0.9), a, Color(0.55, 0.5, 0.44))
		"statua":
			b.box(Vector3(0, 0.8, 0), Vector3(1.8, 1.6, 1.8), 0.0, Color(0.6, 0.57, 0.52))
			b.blob(Vector3(0, 3.0, 0), Vector3(0.55, 1.4, 0.45), Color(0.78, 0.75, 0.68), 0.05, 0.0)
			b.blob(Vector3(0, 4.6, 0), Vector3(0.3, 0.32, 0.3), Color(0.78, 0.75, 0.68), 0.05, 0.0)
		_:
			b.box(Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), 0.0, Color(1, 0, 1))
	var m := b.commit()
	m.surface_set_material(0, material(id in SOFT))
	_meshes[id] = m
	return m


## Costruttore delle forme: triangoli con colore (lineare) e alfa = peso del vento.
class _MeshKit:
	var st := SurfaceTool.new()
	var rng := RandomNumberGenerator.new()
	var flat_normals := true

	func _init(id: String) -> void:
		rng.seed = hash(id)
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)   # facce piatte (stile low poly)

	func r(a: float, b: float) -> float:
		return rng.randf_range(a, b)

	func _v(p: Vector3, col: Color, w: float, n: Vector3 = Vector3.ZERO) -> void:
		var c := col.srgb_to_linear()
		c.a = clampf(w, 0.0, 1.0)
		st.set_color(c)
		if n != Vector3.ZERO:
			st.set_normal(n)
		st.add_vertex(p)

	## Ciuffo d'erba: lame triangolari a ventaglio, normali verso l'alto (luce uniforme come l'erba dei giochi).
	func tuft(blades: int, h0: float, h1: float, w: float, base: Color, tip: Color, spread: float) -> void:
		flat_normals = false
		for i in blades:
			var a := r(0.0, TAU)
			var off := Vector3(cos(a), 0, sin(a)) * r(0.0, spread)
			var side := Vector3(-sin(a), 0, cos(a)).rotated(Vector3.UP, r(-1.0, 1.0)) * w
			var h := r(h0, h1)
			var lean := Vector3(cos(a), 0, sin(a)) * h * r(0.1, 0.5)
			var n := Vector3(0, 1, 0)
			var tc := tip.lerp(base, r(0.0, 0.3))
			_v(off - side, base, 0.0, n)
			_v(off + lean + Vector3(0, h, 0), tc, 1.0, n)
			_v(off + side, base, 0.0, n)

	## Felce: foglie lunghe e piatte, arcuate verso l'esterno.
	func fronds(n_fronds: int, length: float, w: float, base: Color, tip: Color) -> void:
		flat_normals = false
		for i in n_fronds:
			var a := TAU * i / n_fronds + r(-0.3, 0.3)
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-sin(a), 0, cos(a)) * w
			var l := length * r(0.75, 1.2)
			var mid := dir * l * 0.5 + Vector3(0, l * 0.45, 0)
			var end := dir * l + Vector3(0, l * 0.25, 0)
			var n := Vector3(0, 1, 0)
			_v(Vector3.ZERO, base, 0.0, n)
			_v(mid + side, base.lerp(tip, 0.5), 0.6, n)
			_v(mid - side, base.lerp(tip, 0.5), 0.6, n)
			_v(mid - side, base.lerp(tip, 0.5), 0.6, n)
			_v(mid + side, base.lerp(tip, 0.5), 0.6, n)
			_v(end, tip, 1.0, n)

	func flowers(head: Color) -> void:
		tuft(5, 0.18, 0.3, 0.035, Color(0.28, 0.42, 0.17), Color(0.4, 0.55, 0.24), 0.15)
		for i in 4:
			var p := Vector3(r(-0.18, 0.18), r(0.26, 0.4), r(-0.18, 0.18))
			_v(p - Vector3(0.012, p.y, 0), Color(0.3, 0.45, 0.2), 0.0, Vector3.UP)
			_v(p, Color(0.3, 0.45, 0.2), 1.0, Vector3.UP)
			_v(p - Vector3(-0.012, p.y, 0), Color(0.3, 0.45, 0.2), 0.0, Vector3.UP)
			var s := r(0.045, 0.07)
			for k in 5:   # corolla: piccola stella piatta
				var a0 := TAU * k / 5.0
				var a1 := TAU * (k + 0.5) / 5.0
				_v(p, head, 1.0, Vector3.UP)
				_v(p + Vector3(cos(a0), 0.01, sin(a0)) * s, head, 1.0, Vector3.UP)
				_v(p + Vector3(cos(a1), 0.0, sin(a1)) * s * 0.5, head.darkened(0.2), 1.0, Vector3.UP)

	## Foglie secche a terra: piccole losanghe piatte.
	func leaves() -> void:
		flat_normals = false
		for i in 7:
			var p := Vector3(r(-0.45, 0.45), 0.015, r(-0.45, 0.45))
			var a := r(0, TAU)
			var d := Vector3(cos(a), 0, sin(a)) * 0.07
			var s := Vector3(-sin(a), 0, cos(a)) * 0.035
			var col := [Color(0.55, 0.38, 0.18), Color(0.62, 0.5, 0.22), Color(0.45, 0.3, 0.16)][i % 3] as Color
			_v(p - d, col, 0.0, Vector3.UP)
			_v(p + s, col, 0.0, Vector3.UP)
			_v(p + d, col, 0.0, Vector3.UP)
			_v(p - d, col, 0.0, Vector3.UP)
			_v(p + d, col, 0.0, Vector3.UP)
			_v(p - s, col, 0.0, Vector3.UP)

	## Solido da una mesh primitiva di Godot, trasformato, con i vertici spostati un po' (forma irregolare).
	func prim(pm: PrimitiveMesh, xf: Transform3D, col: Color, jitter: float, wind: float) -> void:
		var arr := pm.get_mesh_arrays()
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if ids.is_empty():
			for i in vs.size():
				ids.append(i)
		for i in ids.size():
			var v := vs[ids[i]]
			if jitter > 0.0:
				v += _jit(v) * jitter
			var p := xf * v
			_v(p, col, p.y * wind)

	static func _jit(v: Vector3) -> Vector3:
		var q := (v * 13.0).round()
		var hx := fposmod(sin(q.dot(Vector3(12.99, 78.23, 37.72))) * 43758.55, 1.0)
		var hy := fposmod(sin(q.dot(Vector3(39.35, 11.13, 83.17))) * 24634.63, 1.0)
		var hz := fposmod(sin(q.dot(Vector3(73.16, 52.24, 9.41))) * 56445.21, 1.0)
		return Vector3(hx - 0.5, hy - 0.5, hz - 0.5) * 2.0

	func rock(p: Vector3, size: Vector3, col: Color, jitter: float) -> void:
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 7
		sm.rings = 4
		var xf := Transform3D(Basis(Vector3.UP, r(0, TAU)).scaled(size), p + Vector3(0, size.y * 0.55, 0))
		prim(sm, xf, col.darkened(r(0.0, 0.12)), jitter, 0.0)

	func blob(p: Vector3, size: Vector3, col: Color, jitter: float, wind: float) -> void:
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 8
		sm.rings = 5
		prim(sm, Transform3D(Basis(Vector3.UP, r(0, TAU)).scaled(size), p), col, jitter, wind)

	func cyl(center: Vector3, radius: float, height: float, col: Color) -> void:
		var cm := CylinderMesh.new()
		cm.top_radius = radius * 0.85
		cm.bottom_radius = radius
		cm.height = height
		cm.radial_segments = 8
		cm.rings = 1
		prim(cm, Transform3D(Basis(), center), col, 0.0, 0.0)

	func cone(base_center: Vector3, radius: float, height: float, col: Color, wind: float) -> void:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = radius
		cm.height = height
		cm.radial_segments = 9
		cm.rings = 1
		prim(cm, Transform3D(Basis(Vector3.UP, r(0, TAU)), base_center + Vector3(0, height * 0.5, 0)), col, 0.08, wind)

	## Tronco/ramo: cilindro sdraiato (o in piedi e un po' storto con `upright`).
	func log_piece(center: Vector3, radius: float, length: float, yaw: float, col: Color, upright: bool = false, tilt: float = 0.0) -> void:
		var cm := CylinderMesh.new()
		cm.top_radius = radius * 0.8
		cm.bottom_radius = radius
		cm.height = length
		cm.radial_segments = 7
		cm.rings = 2
		var basis := Basis(Vector3.UP, yaw)
		if upright:
			basis = basis * Basis(Vector3.RIGHT, tilt)
		else:
			basis = basis * Basis(Vector3.FORWARD, PI * 0.5)
		prim(cm, Transform3D(basis, center), col, 0.04 if upright else 0.0, 0.0)

	func box(center: Vector3, size: Vector3, yaw: float, col: Color) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		prim(bm, Transform3D(Basis(Vector3.UP, yaw), center), col, 0.0, 0.0)

	func roof(base_center: Vector3, size: Vector3, col: Color) -> void:
		var pm := PrismMesh.new()
		pm.size = size
		prim(pm, Transform3D(Basis(), base_center + Vector3(0, size.y * 0.5, 0)), col, 0.0, 0.0)

	func commit() -> ArrayMesh:
		if flat_normals:
			st.generate_normals()
		return st.commit()
