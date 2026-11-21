class_name Sfx
extends RefCounted
## Effetti sonori. Uso: Sfx.play("colpo_fuoco", posizione) — la posizione è facoltativa (attenua i suoni lontani).
## I nomi sono nel catalogo data/sound_db.gd (testi per generarli: docs/AUDIO_AI.md).
## File: res://audio/sfx/<nome>.ogg/.wav oppure più versioni <nome>_1, <nome>_2... (scelta a caso, mai la stessa
## due volte di fila). Senza file si sente il suono SEGNAPOSTO sintetizzato da codice ("fallback" del catalogo).

const SAMPLE_RATE := 22050
const POOL_SIZE := 20
const MAX_DIST := 45.0
const SETTINGS_PATH := "user://settings.cfg"

## Volume generale degli effetti (dB). Modificabile dal menu di pausa.
static var volume_db := -6.0
static var _streams: Dictionary = {}
static var _pool: Array = []
static var _next := 0
static var _last_play: Dictionary = {}
static var _settings_loaded := false

## Intervallo minimo tra due riproduzioni dello stesso suono (evita il "muro di rumore").
const THROTTLE := {"colpo_fisico": 0.045, "colpo_fuoco": 0.045, "colpo_freddo": 0.045, "colpo_fulmine": 0.045,
	"critico": 0.06, "fendente": 0.05, "turbine": 0.08, "dardo": 0.05, "monete": 0.06, "rottura": 0.05,
	"umano_morte": 0.05, "lupo_morte": 0.05, "macchina_morte": 0.05, "spettro_morte": 0.05, "granchio_morte": 0.05,
	"passo_terra": 0.12, "passo_pietra": 0.12, "proiettile_nemico": 0.05}
## Versioni di ogni suono trovate su disco (nome -> Array di AudioStream) e ultima usata.
static var _variants: Dictionary = {}
static var _last_variant: Dictionary = {}


static func play(sound: String, pos: Variant = null, vol_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or DisplayServer.get_name() == "headless":
		return
	_load_settings()
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sound, -10.0)) < float(THROTTLE.get(sound, 0.0)):
		return
	_last_play[sound] = now
	var att := 0.0
	if pos is Vector3:
		var listener := tree.get_first_node_in_group("player") as Node3D
		if listener != null:
			var d := (pos as Vector3).distance_to(listener.global_position)
			if d > MAX_DIST:
				return
			att = -maxf(d - 8.0, 0.0) * 0.5
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _player(tree)
	p.stream = stream
	p.volume_db = volume_db + vol_db + att + SoundDB.volume(sound)
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


static func set_volume(db: float) -> void:
	volume_db = db
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "sfx_db", db)
	cfg.save(SETTINGS_PATH)


static func _load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		volume_db = float(cfg.get_value("audio", "sfx_db", volume_db))


static func _player(tree: SceneTree) -> AudioStreamPlayer:
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.name = "Sfx%d" % i
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			tree.root.add_child(p)
			_pool.append(p)
	# Primo lettore libero, altrimenti quello usato meno di recente
	for i in POOL_SIZE:
		var idx := (_next + i) % POOL_SIZE
		var cand: AudioStreamPlayer = _pool[idx]
		if not cand.playing:
			_next = (idx + 1) % POOL_SIZE
			return cand
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	return p


static func _stream(sound: String) -> AudioStream:
	var list := variants(sound)
	if not list.is_empty():
		var i := randi() % list.size()
		if list.size() > 1 and i == int(_last_variant.get(sound, -1)):
			i = (i + 1) % list.size()
		_last_variant[sound] = i
		return list[i]
	var fb := SoundDB.fallback(sound)
	if fb == "":
		return null   # nessun segnaposto (es. i passi): silenzio finché non c'è il file
	if not _streams.has(fb):
		_streams[fb] = _synth(fb)
	return _streams[fb]


## File veri di un suono: <nome>.ogg/.wav e <nome>_1 ... <nome>_9 (in cache).
static func variants(sound: String) -> Array:
	if _variants.has(sound):
		return _variants[sound]
	var list: Array = []
	var names: Array = [sound]
	for i in range(1, 10):
		names.append("%s_%d" % [sound, i])
	for n: String in names:
		for ext in ["ogg", "wav"]:
			var path := "res://audio/sfx/%s.%s" % [n, ext]
			if ResourceLoader.exists(path):
				list.append(load(path))
				break
	_variants[sound] = list
	return list


# --- Sintesi ---------------------------------------------------------------------------------

static func _synth(sound: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	match sound:
		"swing":
			buf = _noise(0.16, 0.35, 0.5, 0.02)
		"hit":
			buf = _mix([_noise(0.07, 0.6, 0.55, 0.0), _tone(150.0, 60.0, 0.1, "sine", 0.7)])
		"crit":
			buf = _mix([_noise(0.09, 0.7, 0.6, 0.0), _tone(160.0, 55.0, 0.14, "sine", 0.8), _tone(1400.0, 1100.0, 0.12, "sine", 0.25)])
		"enemy_die":
			buf = _mix([_noise(0.3, 0.15, 0.5, 0.0), _tone(220.0, 70.0, 0.3, "saw", 0.25)])
		"player_hurt":
			buf = _mix([_tone(190.0, 110.0, 0.16, "square", 0.25), _noise(0.08, 0.5, 0.3, 0.0)])
		"enemy_attack":
			buf = _noise(0.2, 0.2, 0.35, 0.05)
		"cast":
			buf = _mix([_tone(300.0, 900.0, 0.25, "sine", 0.4), _noise(0.25, 0.8, 0.12, 0.05)])
		"projectile":
			buf = _tone(950.0, 380.0, 0.12, "triangle", 0.35)
		"dash":
			buf = _noise(0.25, 0.25, 0.5, 0.06)
		"explosion":
			buf = _mix([_noise(0.7, 0.08, 0.9, 0.0), _tone(80.0, 35.0, 0.5, "sine", 0.8)])
		"gold":
			buf = _concat([_tone(1650.0, 1650.0, 0.06, "sine", 0.35), _tone(2200.0, 2200.0, 0.12, "sine", 0.35)])
		"pickup":
			buf = _tone(520.0, 820.0, 0.09, "triangle", 0.4)
		"rare_drop":
			buf = _concat([_tone(660.0, 660.0, 0.08, "sine", 0.4), _tone(990.0, 990.0, 0.2, "sine", 0.4)])
		"legendary":
			buf = _concat([_tone(523.0, 523.0, 0.1, "sine", 0.4), _tone(659.0, 659.0, 0.1, "sine", 0.4),
				_tone(784.0, 784.0, 0.1, "sine", 0.4), _mix([_tone(1046.0, 1046.0, 0.6, "sine", 0.4), _tone(523.0, 523.0, 0.6, "triangle", 0.2)])])
		"levelup":
			buf = _concat([_tone(392.0, 392.0, 0.1, "triangle", 0.4), _tone(523.0, 523.0, 0.1, "triangle", 0.4),
				_tone(659.0, 659.0, 0.1, "triangle", 0.4), _mix([_tone(784.0, 784.0, 0.7, "triangle", 0.4), _tone(1046.0, 1046.0, 0.7, "sine", 0.2)])])
		"potion":
			var parts: Array = []
			for i in 5:
				var f := 400.0 + i * 130.0
				parts.append(_tone(f, f * 1.5, 0.05, "sine", 0.35))
			buf = _concat(parts)
		"chest":
			buf = _mix([_noise(0.25, 0.1, 0.4, 0.0), _tone(110.0, 70.0, 0.25, "square", 0.15)])
		"break":
			buf = _noise(0.18, 0.5, 0.5, 0.0)
		"checkpoint":
			buf = _mix([_tone(523.0, 523.0, 0.8, "sine", 0.25), _tone(659.0, 659.0, 0.8, "sine", 0.2), _tone(784.0, 784.0, 0.8, "sine", 0.18)])
		"portal":
			buf = _mix([_tone(200.0, 1200.0, 0.8, "sine", 0.3), _tone(205.0, 1210.0, 0.8, "triangle", 0.2), _noise(0.8, 0.9, 0.08, 0.3)])
		"ui_click":
			buf = _tone(1000.0, 900.0, 0.03, "square", 0.15)
		"coins":
			buf = _concat([_tone(1800.0, 1800.0, 0.05, "sine", 0.3), _tone(2400.0, 2400.0, 0.05, "sine", 0.3), _tone(2000.0, 2000.0, 0.1, "sine", 0.3)])
		"anvil":
			buf = _mix([_tone(820.0, 820.0, 0.7, "sine", 0.35), _tone(1243.0, 1243.0, 0.5, "sine", 0.2),
				_tone(1771.0, 1771.0, 0.35, "sine", 0.15), _noise(0.05, 0.9, 0.4, 0.0)])
		"talk":
			buf = _concat([_tone(300.0, 360.0, 0.07, "triangle", 0.2), _tone(260.0, 240.0, 0.08, "triangle", 0.2)])
		_:
			buf = _tone(440.0, 440.0, 0.1, "sine", 0.3)
	return _to_wav(buf)


## Tono con glissando lineare da f0 a f1 e inviluppo attacco/rilascio.
static func _tone(f0: float, f1: float, dur: float, wave: String, vol: float) -> PackedFloat32Array:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / SAMPLE_RATE
		var ph := fmod(phase, 1.0)
		var v := 0.0
		match wave:
			"square": v = 1.0 if ph < 0.5 else -1.0
			"saw": v = ph * 2.0 - 1.0
			"triangle": v = 4.0 * absf(ph - 0.5) - 1.0
			_: v = sin(ph * TAU)
		out[i] = v * vol * _env(t, dur)
	return out


## Rumore filtrato (passa-basso a un polo: smooth basso = suono cupo).
static func _noise(dur: float, smooth: float, vol: float, attack: float) -> PackedFloat32Array:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += (randf_range(-1.0, 1.0) - y) * smooth
		var e := _env(t, dur)
		if attack > 0.0:
			e *= clampf(t * dur / attack, 0.0, 1.0)
		out[i] = y * vol * e * (1.0 / sqrt(maxf(smooth, 0.05)))
	return out


static func _env(t: float, dur: float) -> float:
	var a := clampf(t * dur / 0.005, 0.0, 1.0)
	return a * pow(1.0 - t, 2.0)


static func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


static func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SAMPLE_RATE
	w.stereo = false
	w.data = data
	return w
