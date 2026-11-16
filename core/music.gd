class_name Music
extends RefCounted
## Musica dei livelli. Non c'è musica inclusa: metti i tuoi brani in res://audio/music/
## con il nome dell'id del livello (es. level_01.ogg, ostia_nova.ogg, level_03_porto.ogg)
## oppure imposta il campo "music" nel nodo radice del livello. Formati: .ogg, .mp3, .wav.
## Il brano va in loop e si dissolve nel successivo quando cambi livello.

const FADE := 1.5
static var volume_db := -10.0
static var _player: AudioStreamPlayer
static var _current := ""


static func play_level(level_id: String, explicit: String = "") -> void:
	var path := explicit
	if path == "":
		for ext in ["ogg", "mp3", "wav"]:
			var p := "res://audio/music/%s.%s" % [level_id, ext]
			if ResourceLoader.exists(p):
				path = p
				break
	play(path)


## Riproduce un brano (vuoto = silenzio), con dissolvenza.
static func play(path: String) -> void:
	if path == _current or DisplayServer.get_name() == "headless":
		return
	_current = path
	var p := _get_player()
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
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		var w := stream as AudioStreamWAV
		var bytes := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
		w.loop_end = w.data.size() / bytes
	tw.tween_callback(func() -> void:
		p.stream = stream
		p.volume_db = -60.0
		p.play())
	tw.tween_property(p, "volume_db", volume_db, FADE)


static func set_volume(db: float) -> void:
	volume_db = db
	if _player != null and is_instance_valid(_player) and _player.playing:
		_player.volume_db = db


static func _get_player() -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_player = AudioStreamPlayer.new()
	_player.name = "Musica"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_player)
	return _player
