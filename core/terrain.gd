class_name Terrain
extends RefCounted
## Texture del terreno e dei dungeon (textures/terreno/<nome>.png, ripetibili, vedi docs/GRAFICA_2D_AI.md).
## Uno shader con coordinate del MONDO (triplanare): niente UV da preparare, le texture continuano da un pezzo
## all'altro e si possono usare sui blocchi del terreno, sulle strade e sui muri dei dungeon.
## Il terreno dei livelli è salvato nei .tscn con i colori delle zone: `texture_world()` (chiamato da
## Level._ready e da "Ricostruisci terreno") sostituisce quei materiali riconoscendo il colore della zona.

const DIR := "res://textures/terreno/"
## Metri coperti da una ripetizione della texture, e quanto mescolare una seconda lettura (contro la ripetizione
## visibile: solo per le texture "organiche", non per lastre e assi).
const TEXTURES := {
	"erba": {"meters": 6.0, "variation": 0.35}, "erba_secca": {"meters": 6.0, "variation": 0.35},
	"sottobosco": {"meters": 6.0, "variation": 0.35}, "terra_battuta": {"meters": 7.0, "variation": 0.3},
	"ghiaia": {"meters": 5.0, "variation": 0.3}, "saline": {"meters": 7.0, "variation": 0.3},
	"lastricato": {"meters": 7.0, "variation": 0.0}, "marmo_foro": {"meters": 8.0, "variation": 0.0},
	"assi_molo": {"meters": 6.0, "variation": 0.0}, "piastre_metallo": {"meters": 8.0, "variation": 0.0},
	"pavimento_catacombe": {"meters": 6.0, "variation": 0.0}, "muro_catacombe": {"meters": 5.0, "variation": 0.0},
	"roccia_caverna": {"meters": 6.0, "variation": 0.3}, "pavimento_cisterne": {"meters": 6.0, "variation": 0.25},
	"muro_cisterne": {"meters": 5.0, "variation": 0.0},
}

## %s = modo di culling: "cull_back" per terreno e strade (i nastri delle strade nelle curve strette hanno qualche
## triangolo ripiegato al contrario: va nascosto, come faceva il materiale semplice), "cull_disabled" per i dungeon.
const SHADER := """shader_type spatial;
render_mode %s;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.15;
uniform float scale = 0.15;
uniform float variation = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec3 sample_tex(vec2 uv) {
	vec3 c = texture(albedo_tex, uv).rgb;
	if (variation > 0.0) {
		c = mix(c, texture(albedo_tex, uv * 0.31 + vec2(0.37, 0.11)).rgb, variation);
	}
	return c;
}
void fragment() {
	vec3 w = pow(abs(wnorm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 c = sample_tex(wpos.xz * scale) * w.y + sample_tex(wpos.zy * scale) * w.x + sample_tex(wpos.xy * scale) * w.z;
	ALBEDO = mix(c, c * tint.rgb * 2.0, tint_amount);
	ROUGHNESS = 0.92;
}
"""

static var _shaders: Dictionary = {}
static var _mats: Dictionary = {}


static func has_texture(tex_name: String) -> bool:
	return tex_name != "" and ResourceLoader.exists(DIR + tex_name + ".png")


## Materiale con la texture `tex_name`, tinta leggermente col colore `tint` (quello della zona). null se manca.
## double_sided: anche le facce dietro (muri dei dungeon); terreno e strade no.
static func material(tex_name: String, tint: Color = Color(0.5, 0.5, 0.5), tint_amount: float = 0.15, double_sided: bool = false) -> ShaderMaterial:
	if not has_texture(tex_name):
		return null
	var key := "%s|%s|%.2f|%s" % [tex_name, tint.to_html(false), tint_amount, double_sided]
	if _mats.has(key):
		return _mats[key]
	var mode := "cull_disabled" if double_sided else "cull_back"
	if not _shaders.has(mode):
		var sh := Shader.new()
		sh.code = SHADER % mode
		_shaders[mode] = sh
	var info: Dictionary = TEXTURES.get(tex_name, {"meters": 6.0, "variation": 0.0})
	var m := ShaderMaterial.new()
	m.shader = _shaders[mode]
	m.set_shader_parameter("albedo_tex", load(DIR + tex_name + ".png"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tint_amount", tint_amount)
	m.set_shader_parameter("scale", 1.0 / float(info["meters"]))
	m.set_shader_parameter("variation", float(info["variation"]))
	_mats[key] = m
	return m


## Colore (anche nella versione scurita delle righe alterne) -> zona.
static func _zone_by_color() -> Dictionary:
	var out := {}
	for z: String in MapZones.ZONES:
		var c: Color = MapZones.ZONES[z]["color"]
		out[c.to_html(false)] = z
		out[c.darkened(0.04).to_html(false)] = z
	return out


## Mette le texture sul terreno (World/Terreno) e sulle strade (World/Strade) di un livello.
## Si può chiamare più volte: i pezzi già con la texture si saltano. Ritorna quanti pezzi ha cambiato.
static func texture_world(world: Node) -> int:
	if world == null:
		return 0
	var changed := 0
	var by_color := _zone_by_color()
	var ground := world.get_node_or_null("Terreno")
	if ground != null:
		for mi: MeshInstance3D in ground.find_children("*", "MeshInstance3D", true, false):
			var sm := mi.material_override as StandardMaterial3D
			if sm == null:
				continue
			var z: String = by_color.get(sm.albedo_color.to_html(false), "")
			if z == "":
				continue
			var zd: Dictionary = MapZones.get_zone(z)
			var m := material(String(zd.get("texture", "")), zd["color"])
			if m != null:
				mi.material_override = m
				changed += 1
	var roads := world.get_node_or_null("Strade")
	if roads != null:
		for mi: MeshInstance3D in roads.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			if mi.mesh is ArrayMesh and not mi.has_meta("nastro_corretto"):
				mi.mesh = fix_ribbon(mi.mesh as ArrayMesh)
				mi.set_meta("nastro_corretto", true)
			for i in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if sm == null or mi.get_surface_override_material(i) != null:
					continue
				var m := material(road_texture(sm.albedo_color), sm.albedo_color, 0.3)
				if m != null:
					mi.set_surface_override_material(i, m)
					changed += 1
	return changed


## Nastri delle strade costruiti prima della correzione di MapRoad.add_ribbon: i triangoli erano girati
## dal lato del "retro" (Godot considera davanti le facce in senso orario viste dall'alto) e nelle curve strette
## alcuni si ripiegavano. Rifà la mesh tenendo solo i triangoli del verso principale, girati dal lato giusto:
## così i ripiegati spariscono (niente "spicchi") e la strada si vede con il culling normale.
static func fix_ribbon(src: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var up := 0
		for i in range(0, v.size() - 2, 3):
			if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).y > 0.0:
				up += 1
		var main_up := up * 2 >= v.size() / 3   # verso della maggioranza dei triangoli
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for i in range(0, v.size() - 2, 3):
			var is_up := (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).y > 0.0
			if is_up != main_up:
				continue   # triangolo ripiegato in una curva
			# davanti = senso orario visto dall'alto (prodotto vettoriale verso il basso)
			if is_up:
				st.add_vertex(v[i])
				st.add_vertex(v[i + 2])
				st.add_vertex(v[i + 1])
			else:
				st.add_vertex(v[i])
				st.add_vertex(v[i + 1])
				st.add_vertex(v[i + 2])
		st.set_material(src.surface_get_material(s))
		st.commit(out)
	return out


## Strade: color legno = assi (pontili del porto), altrimenti lastricato romano.
static func road_texture(col: Color) -> String:
	return "assi_molo" if col.r - col.b > 0.18 else "lastricato"
