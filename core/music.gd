class_name Music
extends RefCounted
## Musica e suoni d'ambiente (testi per generarli: docs/AUDIO_AI.md).
## Brani in res://audio/music/<nome>.ogg (.mp3/.wav), ambienti in res://audio/ambience/<nome>.ogg.
## Ogni luogo prova una lista di nomi, il primo che esiste vince (es. dungeon: "dungeon_catacombe", poi "dungeon").
##   menu · level_01 · ostia_nova · level_03_porto · dungeon_<id> / dungeon · labirinto · boss
## Il campo "music" del nodo radice del livello, se impostato, ha la precedenza.
## Durante un combattimento con un boss parte "boss" (se c'è) e alla fine si torna al brano del luogo.
## Brani e ambienti vanno in loop e si dissolvono l'uno nell'altro.

const FADE := 1.5
## Secondi senza boss prima di tornare alla musica del luogo (evita salti avanti e indietro).
const BOSS_RELEASE := 4.0
## Volume degli ambienti rispetto alla musica (dB).
const AMBIENCE_DB := -4.0
static var volume_db := -10.0
static var _player: AudioStreamPlayer
static var _amb_player: AudioStreamPlayer
static var _current := ""
static var _amb_current := ""
static var _level_path := ""
static var _boss_on := false
static var _boss_off_since := 0.0


## Musica e ambiente di un luogo: `names` = nomi da provare in ordine (o un solo nome).
static func play_level(names: Variant, explicit: String = "") -> void:
	var list: Array = names if names is Array else [String(names)]
	var path := explicit if explicit != "" else find("music", list)
	_level_path = path
	_boss_on = false
	play(path)
	play_ambience(find("ambience", list))


## Primo file esistente di res://audio/<folder>/<nome>.ogg|mp3|wav tra i nomi dati ("" se nessuno).
static func find(folder: String, names: Array) -> String:
	for n: Variant in names:
		for ext in ["ogg", "mp3", "wav"]:
			var p := "res://audio/%s/%s.%s" % [folder, String(n), ext]
			if ResourceLoader.exists(p):
				return p
	return ""


## Combattimento col boss: chiamato ogni frame dall'HUD (true se c'è un boss attivo).
static func set_boss(active: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if active:
		_boss_off_since = now
		if not _boss_on:
			var boss := find("music", ["boss"])
			if boss != "":
				_boss_on = true
				play(boss)
	elif _boss_on and now - _boss_off_since > BOSS_RELEASE:
		_boss_on = false
		play(_level_path)


## Riproduce un brano (vuoto = silenzio), con dissolvenza.
static func play(path: String) -> void:
	if path == _current or DisplayServer.get_name() == "headless":
		return
	_current = path
	_crossfade(_get_player("Musica"), path, volume_db)


static func play_ambience(path: String) -> void:
	if path == _amb_current or DisplayServer.get_name() == "headless":
		return
	_amb_current = path
	_crossfade(_get_player("Ambiente"), path, volume_db + AMBIENCE_DB)


static func _crossfade(p: AudioStreamPlayer, path: String, target_db: float) -> void:
	if p == null:
		return
	var tw := p.create_tween()
	if p.playing:
		tw.tween_property(p, "volume_db", -60.0, FADE * 0.5)
	if path == "":
		tw.tween_callback(p.stop)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_set_loop(stream)
	tw.tween_callback(func() -> void:
		p.stream = stream
		p.volume_db = -60.0
		p.play())
	tw.tween_property(p, "volume_db", target_db, FADE)


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var bytes := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
		w.loop_end = w.data.size() / bytes


static func set_volume(db: float) -> void:
	volume_db = db
	if _player != null and is_instance_valid(_player) and _player.playing:
		_player.volume_db = db
	if _amb_player != null and is_instance_valid(_amb_player) and _amb_player.playing:
		_amb_player.volume_db = db + AMBIENCE_DB


static func _get_player(player_name: String) -> AudioStreamPlayer:
	var existing := _player if player_name == "Musica" else _amb_player
	if existing != null and is_instance_valid(existing):
		return existing
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(p)
	if player_name == "Musica":
		_player = p
	else:
		_amb_player = p
	return p
