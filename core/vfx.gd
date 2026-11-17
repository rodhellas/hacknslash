class_name Vfx
extends RefCounted
## Kit degli effetti visivi (vedi docs/EFFETTI_VISIVI.md): pochi shader procedurali e poche mesh,
## riusati da tutti gli effetti e colorati per elemento. Niente texture: quando arriveranno
## (fumo, fiamme, fulmini...) si mettono negli shader al posto del rumore procedurale.
##
## Shader (in cache, condivisi; il colore è un "instance uniform" per oggetto):
##   glow      bagliore morbido rivolto alla telecamera (lampi, nuclei dei proiettili, stelle)
##   fire      fiamma procedurale rivolta alla telecamera (fuoco, braci, nemici in fiamme)
##   ring      anello d'urto a terra che si allarga
##   telegraph avviso a terra che si riempie fino al colpo (aree, boss, pericoli)
##   scorch    segno a terra che svanisce (bruciatura, brina, crepa)
##   pool      pozza animata (fuoco, ghiaccio) per i pericoli a terra
##   slash     falce del fendente con scia
##   fresnel   bolla luminosa sui bordi (scudi, aura)
##   dissolve  dissolvenza con bordo luminoso (morte dei nemici)
##   distort   distorsione dell'aria (onde d'urto grandi)

const ELEMENT_COLORS := {
	"fisico": Color(1.0, 0.92, 0.75), "fuoco": Color(1.0, 0.5, 0.12),
	"freddo": Color(0.5, 0.85, 1.0), "fulmine": Color(0.75, 0.65, 1.0),
}

static var _shaders: Dictionary = {}
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _hitstop_until := 0

const _NOISE := """
float vhash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(vhash(i), vhash(i + vec2(1.0, 0.0)), f.x), mix(vhash(i + vec2(0.0, 1.0)), vhash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { vec2 q = p; float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(q); q *= 2.03; a *= 0.5; } return v; }
"""

const _BILLBOARD := """
void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
"""

const SHADER_CODE := {
	"glow": """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float intensity = 2.0;
%s
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = tint.rgb * intensity * (0.6 + 0.8 * a);
	ALPHA = a * tint.a * fade;
}""",
	"fire": """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
%s
%s
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float n = fbm(vec2(uv.x * 3.0 + seed, uv.y * 2.5 - TIME * 2.6 + seed));
	float shape = (1.0 - abs(uv.x - 0.5) * 2.0) * (1.0 - uv.y * 0.9);
	float f = clamp(shape * 1.7 + (n - 0.5) * 1.1 - uv.y * 0.5, 0.0, 1.0);
	vec3 col = mix(vec3(0.9, 0.18, 0.03), vec3(1.0, 0.85, 0.35), f) * tint.rgb;
	ALBEDO = col * 2.2;
	ALPHA = smoothstep(0.12, 0.55, f) * fade * tint.a;
}""",
	"ring": """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float width = 0.25;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0 - width, 1.0 - width * 0.35, d) * (1.0 - smoothstep(0.96, 1.0, d));
	a += (1.0 - smoothstep(0.0, 1.0, d)) * 0.08;
	ALBEDO = tint.rgb * 2.5;
	ALPHA = a * fade * tint.a;
}""",
	"telegraph": """shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float progress = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	if (d > 1.0) { discard; }
	float edge = smoothstep(0.9, 0.96, d) * (1.0 - smoothstep(0.985, 1.0, d));
	float fill = (1.0 - smoothstep(progress - 0.04, progress, d)) * 0.35;
	float ang = atan(p.y, p.x) / 6.28318;
	float dash = step(0.5, fract(ang * 24.0 + TIME * 0.25)) * smoothstep(0.78, 0.8, d) * (1.0 - smoothstep(0.84, 0.86, d));
	float pulse = 0.85 + 0.15 * sin(TIME * 10.0);
	ALBEDO = tint.rgb * 1.6;
	ALPHA = clamp(edge * pulse + fill + dash * 0.5 + 0.06, 0.0, 1.0) * fade * tint.a;
}""",
	"scorch": """shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(0.1, 0.08, 0.06, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
%s
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float n = fbm(UV * 6.0 + seed);
	float a = 1.0 - smoothstep(0.25, 1.0, d + (n - 0.5) * 0.6);
	ALBEDO = tint.rgb * (0.7 + 0.6 * n);
	ALPHA = a * 0.75 * fade * tint.a;
}""",
	"pool": """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0, 0.4, 0.1, 1.0);
instance uniform float fade = 1.0;
%s
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float n = fbm(UV * 5.0 + vec2(TIME * 0.25, -TIME * 0.18));
	float a = (1.0 - smoothstep(0.75, 1.0, d)) * (0.35 + 0.65 * n);
	ALBEDO = tint.rgb * (0.8 + 1.6 * n);
	ALPHA = a * fade * tint.a;
}""",
	"slash": """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float head = 0.0;
void fragment() {
	float along = UV.x;
	float trail = clamp(1.0 - (head - along) / 0.55, 0.0, 1.0) * step(along, head);
	float radial = smoothstep(0.0, 0.75, UV.y) * (1.0 - smoothstep(0.9, 1.0, UV.y));
	ALBEDO = tint.rgb * (1.0 + trail * 2.5);
	ALPHA = trail * radial * fade * tint.a;
}""",
	"fresnel": """shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = tint.rgb * 2.0;
	ALPHA = (rim * 0.9 + 0.05 + 0.04 * sin(TIME * 4.0)) * tint.a * fade;
}""",
	"dissolve": """shader_type spatial;
instance uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
instance uniform float progress = 0.0;
uniform vec4 edge : source_color = vec4(1.0, 0.55, 0.15, 1.0);
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = fbm(wpos.xz * 2.5 + vec2(wpos.y * 1.7));
	if (n < progress) { discard; }
	ALBEDO = base.rgb;
	ROUGHNESS = 0.8;
	EMISSION = edge.rgb * (1.0 - smoothstep(progress, progress + 0.07, n)) * 5.0 * step(0.001, progress);
}""",
	"distort": """shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float band = smoothstep(0.6, 0.85, d) * (1.0 - smoothstep(0.88, 1.0, d));
	vec2 off = normalize(p + 0.0001) * band * 0.025 * fade;
	ALBEDO = texture(screen_tex, SCREEN_UV - off).rgb;
	ALPHA = band * fade;
}""",
}


# --- Risorse condivise ---------------------------------------------------------------------------

static func material(kind: String) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var code: String = SHADER_CODE[kind]
	match kind:
		"glow": code = code % _BILLBOARD
		"fire": code = code % [_NOISE, _BILLBOARD]
		"scorch", "pool", "dissolve": code = code % _NOISE
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	_materials[kind] = m
	return m


static func quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


## Piano orizzontale 2 × 2 (raggio 1): si scala al raggio voluto.
static func plane() -> PlaneMesh:
	if not _meshes.has("plane"):
		var p := PlaneMesh.new()
		p.size = Vector2(2, 2)
		_meshes["plane"] = p
	return _meshes["plane"]


static func _mi(mesh: Mesh, kind: String, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("tint", color)
	return mi


static func _fade(mi: GeometryInstance3D, from: float, to: float, time: float, delay: float = 0.0) -> Tween:
	var tw := mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), from, to, time)
	return tw


static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, ELEMENT_COLORS["fisico"])


static func reduced() -> bool:
	return Settings.reduced_vfx


# --- Effetti di base -----------------------------------------------------------------------------

## Bagliore che si allarga e svanisce (lampi dei colpi, esplosioni).
## life <= 0: resta attaccato a `parent` (anche se non è ancora nella scena: posizione locale zero).
static func glow(parent: Node, pos: Vector3, color: Color, size: float = 1.0, life: float = 0.2, grow: float = 1.6) -> MeshInstance3D:
	if parent == null or (not parent.is_inside_tree() and life > 0.0):
		return null
	var mi := _mi(quad(), "glow", color)
	parent.add_child(mi)
	if parent.is_inside_tree():
		mi.global_position = pos
	mi.scale = Vector3.ONE * size
	if life > 0.0:
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * size * grow, life).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, life)
		tw.chain().tween_callback(mi.queue_free)
	return mi


## Fiamma rivolta alla telecamera. life <= 0 = resta (va tolta da chi la crea).
static func fire(parent: Node, pos: Vector3, size: float = 1.0, life: float = 0.6, tint: Color = Color.WHITE) -> MeshInstance3D:
	if parent == null or (not parent.is_inside_tree() and life > 0.0):
		return null
	var mi := _mi(quad(), "fire", tint)
	mi.set_instance_shader_parameter("seed", randf() * 50.0)
	parent.add_child(mi)
	if parent.is_inside_tree():
		mi.global_position = pos
	mi.scale = Vector3(size, size * 1.4, size)
	if life > 0.0:
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "global_position", pos + Vector3(0, size * 0.5, 0), life)
		tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, life)
		tw.chain().tween_callback(mi.queue_free)
	return mi


## Anello d'urto a terra che si allarga.
static func shockwave(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.35, width: float = 0.25) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := _mi(plane(), "ring", color)
	mi.set_instance_shader_parameter("width", width)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.08, pos.z)
	mi.scale = Vector3(0.15, 1, 0.15) * maxf(radius, 0.5)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Avviso a terra: il disco si riempie dal centro fino al momento del colpo.
static func telegraph(parent: Node, pos: Vector3, radius: float, color: Color, time: float) -> MeshInstance3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var mi := _mi(plane(), "telegraph", color)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.06, pos.z)
	mi.scale = Vector3(radius, 1, radius)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, maxf(time, 0.05))
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.15)
	tw.tween_callback(mi.queue_free)
	return mi


## Segno a terra che svanisce piano (bruciatura, brina, crepa).
static func scorch(parent: Node, pos: Vector3, radius: float, color: Color, life: float = 6.0) -> void:
	if parent == null or not parent.is_inside_tree() or reduced():
		return
	var mi := _mi(plane(), "scorch", color)
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.04 + randf() * 0.01, pos.z)
	mi.scale = Vector3(radius, 1, radius)
	mi.rotation.y = randf() * TAU
	_fade(mi, 1.0, 0.0, life * 0.4, life * 0.6).tween_callback(mi.queue_free)


## Pozza animata (fuoco, ghiaccio) come figlio di `owner` (resta finché c'è il nodo).
static func pool(owner: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var mi := _mi(plane(), "pool", color)
	owner.add_child(mi)
	mi.position = Vector3(0, 0.07, 0)
	mi.scale = Vector3(radius, 1, radius)
	return mi


## Distorsione dell'aria che si allarga (solo esplosioni grandi; spenta con "effetti ridotti").
static func distortion(parent: Node, pos: Vector3, radius: float, time: float = 0.4) -> void:
	if parent == null or not parent.is_inside_tree() or reduced():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = plane()
	mi.material_override = material("distort")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.6, pos.z)
	mi.rotation_degrees.x = -35.0
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 1.3, time).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Falce del fendente: arco luminoso con scia, ruota da un lato all'altro.
static func slash(owner: Node3D, yaw: float, arc_deg: float, reach: float, color: Color, time: float = 0.15) -> void:
	var mi := _mi(_slash_mesh(arc_deg, reach), "slash", color)
	owner.add_child(mi)
	mi.position = Vector3(0, 1.0, 0)
	mi.rotation.y = yaw
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("head", v), 0.0, 1.55, time + 0.12)
	tw.tween_callback(mi.queue_free)


## Nastro ad arco (UV.x lungo l'arco, UV.y dal centro al bordo), centrato su −Z.
static func _slash_mesh(arc_deg: float, reach: float) -> ArrayMesh:
	var key := "slash_%d_%d" % [roundi(arc_deg), roundi(reach * 10.0)]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := maxi(8, roundi(arc_deg / 8.0))
	var half := deg_to_rad(arc_deg) * 0.5
	var r0 := reach * 0.35
	var r1 := reach * 1.05
	for i in seg:
		var a0 := half - (2.0 * half) * i / seg
		var a1 := half - (2.0 * half) * (i + 1) / seg
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var p := [Vector3(-sin(a0) * r0, 0, -cos(a0) * r0), Vector3(-sin(a0) * r1, 0, -cos(a0) * r1),
			Vector3(-sin(a1) * r1, 0, -cos(a1) * r1), Vector3(-sin(a1) * r0, 0, -cos(a1) * r0)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	var m := st.commit()
	_meshes[key] = m
	return m


## Fulmine a zig-zag da a a b, che sfarfalla e sparisce.
static func lightning(parent: Node, a: Vector3, b: Vector3, color: Color, life: float = 0.18, segments: int = 7) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	parent.add_child(root)
	var pts: Array = [a]
	var dir := b - a
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for i in range(1, segments):
		var t := float(i) / segments
		pts.append(a + dir * t + side * randf_range(-0.5, 0.5) + Vector3.UP * randf_range(-0.35, 0.35))
	pts.append(b)
	var m := Fx.mat(color.lightened(0.4), 6.0, false, true)
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var len := p0.distance_to(p1)
		if len < 0.01:
			continue
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, len)
		seg.mesh = bm
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seg)
		seg.global_position = (p0 + p1) * 0.5
		if absf((p1 - p0).normalized().dot(Vector3.UP)) < 0.99:
			seg.look_at(p1, Vector3.UP)
	glow(parent, b, color, 0.9, life)
	var tw := root.create_tween()
	tw.tween_property(root, "visible", false, 0.04).set_delay(life * 0.4)
	tw.tween_property(root, "visible", true, 0.0).set_delay(0.03)
	tw.tween_interval(life * 0.4)
	tw.tween_callback(root.queue_free)


# --- Colpi per elemento ---------------------------------------------------------------------------

## Effetto di un colpo su un nemico: lampo + schegge diverse per elemento; più grande per i critici.
static func hit(parent: Node, pos: Vector3, element: String, crit: bool = false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var col := element_color(element)
	var k := 1.6 if crit else 1.0
	var n := 1 if reduced() else 2
	glow(parent, pos, col, 0.9 * k, 0.14)
	match element:
		"fuoco":
			Fx.burst(parent, pos, Color(1.0, 0.55, 0.15), 5 * n, 3.5 * k, 0.07, 0.6, 4.0, 70.0)
			fire(parent, pos - Vector3(0, 0.2, 0), 0.7 * k, 0.4)
		"freddo":
			Fx.shards(parent, pos, Color(0.7, 0.92, 1.0), 4 * n, 5.0 * k, 0.5)
			glow(parent, pos, Color(0.6, 0.85, 1.0, 0.5), 1.6 * k, 0.5, 1.3)
		"fulmine":
			for i in (2 if crit else 1) + n - 1:
				var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)).normalized()
				lightning(parent, pos, pos + dir * randf_range(0.8, 1.6) * k, col, 0.12, 4)
		_:
			Fx.shards(parent, pos, Color(1.0, 0.85, 0.5), 4 * n, 6.0 * k, 0.25)
	if crit:
		shockwave(parent, pos - Vector3(0, pos.y, 0), 1.6, col, 0.25, 0.4)


## Esplosione per elemento: lampo, anello, schegge, segno a terra, distorsione se grande.
static func explosion(parent: Node, pos: Vector3, radius: float, element: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var col := color if color.a > 0.0 else element_color(element)
	var ground := Vector3(pos.x, 0.0, pos.z)
	glow(parent, ground + Vector3(0, 1.0, 0), col, radius * 1.1, 0.3, 1.5)
	shockwave(parent, ground, radius, col, 0.35)
	match element:
		"fuoco":
			for i in (3 if reduced() else 6):
				var o := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * radius * 0.5
				fire(parent, ground + o + Vector3(0, 0.6, 0), radius * 0.45, randf_range(0.5, 0.9))
			scorch(parent, ground, radius * 0.8, Color(0.08, 0.05, 0.04))
		"freddo":
			Fx.shards(parent, ground + Vector3(0, 0.4, 0), Color(0.75, 0.93, 1.0), 14, radius * 3.0, 0.7)
			scorch(parent, ground, radius * 0.9, Color(0.8, 0.95, 1.0), 4.0)
		"fulmine":
			for i in (3 if reduced() else 6):
				var a := randf() * TAU
				lightning(parent, ground + Vector3(0, 2.5, 0), ground + Vector3(cos(a), 0.1, sin(a)) * radius * randf_range(0.3, 1.0), col, 0.2, 5)
			scorch(parent, ground, radius * 0.6, Color(0.12, 0.1, 0.16), 3.0)
		_:
			scorch(parent, ground, radius * 0.7, Color(0.18, 0.15, 0.12), 4.0)
	if radius >= 4.0:
		distortion(parent, ground, radius)


## Colpo dal cielo (meteora, bombardamento, saetta): oggetto che cade con la scia fino a `pos`.
static func strike(parent: Node, pos: Vector3, delay: float, element: String, size: float = 0.8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var col := element_color(element)
	var from := pos + Vector3(-4, 22, 4)
	if element == "fulmine":
		var t := parent.create_tween()
		t.tween_interval(maxf(delay - 0.05, 0.0))
		t.tween_callback(func() -> void: lightning(parent, pos + Vector3(0, 18, 0), pos, col, 0.25, 9))
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = from
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size * 0.6
	sm.height = size * 1.2
	core.mesh = sm
	core.material_override = Fx.mat(col, 6.0, false, true)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var g := glow(root, from, col, size * 3.0, 0.0)
	if g:
		g.position = Vector3.ZERO
	if element == "fuoco":
		var f := fire(root, from, size * 2.0, 0.0)
		if f:
			f.position = Vector3(0, 0.6, 0)
	Fx.trail(root, col, size * 0.35)
	var tw := root.create_tween()
	tw.tween_property(root, "global_position", pos, maxf(delay, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


# --- Personaggi -----------------------------------------------------------------------------------

## Materiale "bolla" (bordo luminoso) da mettere su una sfera: scudi, protezioni.
static func make_bubble(mi: MeshInstance3D, color: Color) -> void:
	mi.material_override = material("fresnel")
	mi.set_instance_shader_parameter("tint", color)


## Dissolvenza del modello (morte dei nemici). Il colore di ogni pezzo resta quello del suo materiale.
static func dissolve(model: Node3D, time: float = 0.9, edge: Color = Color(1.0, 0.55, 0.15)) -> void:
	if model == null or not model.is_inside_tree():
		return
	var mat := material("dissolve")
	mat.set_shader_parameter("edge", edge)
	var list: Array = []
	for gi: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := gi as MeshInstance3D
		var base := Color(0.5, 0.5, 0.5)
		var m: Material = mi.material_override if mi.material_override else (mi.mesh.surface_get_material(0) if mi.mesh and mi.mesh.get_surface_count() > 0 else null)
		if m is StandardMaterial3D:
			if (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mi.visible = false
				continue
			base = (m as StandardMaterial3D).albedo_color
		elif m is ShaderMaterial:
			mi.visible = false
			continue
		mi.material_override = mat
		mi.material_overlay = null
		mi.set_instance_shader_parameter("base", base)
		list.append(mi)
	var tw := model.create_tween()
	tw.tween_method(func(v: float) -> void:
		for x: Variant in list:
			if is_instance_valid(x):
				(x as MeshInstance3D).set_instance_shader_parameter("progress", v), 0.0, 1.05, time)


## Immagine fantasma del modello (scatti, cariche): copia trasparente che svanisce.
static func afterimage(model: Node3D, color: Color, life: float = 0.3) -> void:
	if model == null or not model.is_inside_tree() or reduced():
		return
	var ghost := model.duplicate(0) as Node3D
	for c: Node in ghost.find_children("*", "", true, false):
		if not c is MeshInstance3D:
			if c is Light3D or c is CPUParticles3D or c is Label3D:
				c.queue_free()
			continue
		var mi := c as MeshInstance3D
		if mi.layers & Layers.VIS_MINIMAP:
			mi.visible = false
			continue
		mi.material_override = material("fresnel")
		mi.material_overlay = null
		mi.set_instance_shader_parameter("tint", color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent := Game.world_root()
	parent.add_child(ghost)
	ghost.global_transform = model.global_transform
	var tw := ghost.create_tween()
	tw.tween_method(func(v: float) -> void:
		for c: Node in ghost.find_children("*", "MeshInstance3D", true, false):
			(c as MeshInstance3D).set_instance_shader_parameter("fade", v), 0.5, 0.0, life)
	tw.tween_callback(ghost.queue_free)


## Micro-pausa sui colpi forti (sensazione d'impatto). Non in headless (test) e non con gli effetti ridotti.
static func hitstop(seconds: float = 0.05) -> void:
	if DisplayServer.get_name() == "headless" or reduced():
		return
	var now := Time.get_ticks_msec()
	if now < _hitstop_until + 250:
		return
	_hitstop_until = now + roundi(seconds * 1000.0)
	Engine.time_scale = 0.05
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
