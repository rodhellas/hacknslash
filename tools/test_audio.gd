extends SceneTree
## TEST AUTOMATICO dell'audio (data/sound_db.gd, core/sfx.gd, core/music.gd, docs/AUDIO_AI.md):
## ogni suono usato nel codice è nel catalogo, ogni suono ha la sua riserva sintetizzata (o il silenzio voluto),
## il documento e il catalogo hanno gli stessi nomi, ogni abilità/nemico/elemento ha un suono, i file già presenti
## in audio/ hanno nomi validi, musica e ambienti si cercano nell'ordine giusto.
## In headless non si sente niente: i suoni vanno ascoltati nel gioco.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/test_audio.gd

var fails := 0
var checks := 0


func _initialize() -> void:
	_run()
	quit(1 if fails > 0 else 0)


func _check(cond: bool, what: String) -> void:
	checks += 1
	print(("  OK       " if cond else "  FALLITO  ") + what)
	if not cond:
		fails += 1


func _gd_files(dir: String, out: Array) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


func _run() -> void:
	var SDB: GDScript = load("res://data/sound_db.gd")
	var SFX: GDScript = load("res://core/sfx.gd")
	var HC: GDScript = load("res://data/hero_classes.gd")
	var SKD: GDScript = load("res://data/skill_db.gd")
	var EDB: GDScript = load("res://data/enemy_db.gd")
	var sounds: Dictionary = SDB.SOUNDS

	print("\n== 1. Suoni usati nel codice")
	var files: Array = []
	for d: String in ["res://core", "res://entities", "res://world", "res://ui"]:
		_gd_files(d, files)
	var re := RegEx.new()
	re.compile("Sfx\\.play\\(\"([a-z_]+)\"")
	var used := {}
	var unknown: Array = []
	for f: String in files:
		var text := FileAccess.get_file_as_string(f)
		for m: RegExMatch in re.search_all(text):
			var id := m.get_string(1)
			used[id] = true
			# nomi composti ("eroe_ferito_" + sesso): basta che esista un suono che inizia così
			var ok := sounds.has(id)
			if not ok and id.ends_with("_"):
				for k: String in sounds:
					if k.begins_with(id):
						ok = true
			if not ok:
				unknown.append("%s (%s)" % [id, f.get_file()])
	_check(unknown.is_empty() and used.size() > 30, "%d nomi usati nel codice, tutti nel catalogo %s" % [used.size(), str(unknown)])

	print("\n== 2. Abilità, elementi, nemici")
	var missing: Array = []
	var abilities: Array = []
	for c: String in HC.DATA:
		abilities.append_array(HC.DATA[c]["abilities"])
	for k: String in SKD.EXTRA:
		abilities.append_array(SKD.EXTRA[k])
	for ab: Dictionary in abilities:
		var s: String = SDB.cast_sound(ab)
		if not sounds.has(s):
			missing.append(ab["id"] + "->" + s)
	for v: String in SDB.IMPACT.values():
		if not sounds.has(v):
			missing.append(v)
	for el: String in ["fisico", "fuoco", "freddo", "fulmine"]:
		for s: String in [SDB.hit_sound(el), SDB.explosion_sound(el)]:
			if not sounds.has(s):
				missing.append(s)
	for eid: String in EDB.DATA:
		for suffix: String in ["_attacco", "_morte"]:
			if not sounds.has(SDB.enemy_family(eid) + suffix):
				missing.append(eid + suffix)
		if not SDB.ENEMY_FAMILY.has(eid):
			missing.append(eid + " senza famiglia")
	_check(missing.is_empty(), "%d abilità, 4 elementi e %d nemici hanno i loro suoni %s" % [abilities.size(), EDB.DATA.size(), str(missing)])

	print("\n== 3. Riserve sintetizzate")
	var bad: Array = []
	var silent: Array = []
	for id: String in sounds:
		var fb: String = SDB.fallback(id)
		if fb == "":
			silent.append(id)
			continue
		var w: AudioStreamWAV = SFX._synth(fb)
		if w == null or w.data.size() < 200:
			bad.append(id)
	_check(bad.is_empty(), "%d suoni con una riserva sintetizzata funzionante %s" % [sounds.size() - silent.size(), str(bad)])
	_check(silent == ["passo_terra", "passo_pietra"], "solo i passi restano muti finché manca il file %s" % str(silent))

	print("\n== 4. Documento docs/AUDIO_AI.md")
	var doc := FileAccess.get_file_as_string("res://docs/AUDIO_AI.md")
	var part_a := doc.substr(doc.find("## A."), doc.find("## B.") - doc.find("## A."))
	var re2 := RegEx.new()
	re2.compile("(?m)^\\| `([a-z_]+)` \\|")
	var in_doc := {}
	for m: RegExMatch in re2.search_all(part_a):
		in_doc[m.get_string(1)] = true
	var not_in_doc: Array = sounds.keys().filter(func(k: String) -> bool: return not in_doc.has(k))
	var not_in_db: Array = in_doc.keys().filter(func(k: String) -> bool: return not sounds.has(k))
	_check(not_in_doc.is_empty() and not_in_db.is_empty(), "documento e catalogo hanno gli stessi %d suoni %s %s" % [sounds.size(), str(not_in_doc), str(not_in_db)])

	print("\n== 5. File già presenti in audio/")
	var strays: Array = []
	var found := 0
	for f: String in DirAccess.get_files_at("res://audio/sfx"):
		if not (f.ends_with(".ogg") or f.ends_with(".wav")):
			continue
		found += 1
		var base := f.get_basename()
		var parts := base.rsplit("_", true, 1)
		var known := sounds.has(base) or (parts.size() == 2 and parts[1].is_valid_int() and sounds.has(parts[0]))
		if not known:
			strays.append(f)
	_check(strays.is_empty(), "%d file in audio/sfx, tutti con un nome del catalogo %s" % [found, str(strays)])
	var amb_names := ["level_01", "ostia_nova", "level_03_porto", "dungeon_catacombe", "dungeon_caverne_clan", "dungeon_cisterne", "labirinto"]
	var mus_names := ["menu", "level_01", "ostia_nova", "level_03_porto", "dungeon", "dungeon_catacombe", "dungeon_caverne_clan", "dungeon_cisterne", "labirinto", "boss"]
	var strays2: Array = []
	for pair: Array in [["ambience", amb_names], ["music", mus_names]]:
		if not DirAccess.dir_exists_absolute("res://audio/" + pair[0]):
			continue
		for f: String in DirAccess.get_files_at("res://audio/" + pair[0]):
			if (f.ends_with(".ogg") or f.ends_with(".mp3") or f.ends_with(".wav")) and not (pair[1] as Array).has(f.get_basename()):
				strays2.append(pair[0] + "/" + f)
	_check(strays2.is_empty(), "musica e ambienti con nomi validi %s" % str(strays2))

	print("\n== 6. Musica: ordine di ricerca")
	var MUS: GDScript = load("res://core/music.gd")
	_check(MUS.find("music", ["nome_che_non_esiste"]) == "", "un brano che manca = silenzio")
	var DL: GDScript = load("res://world/dungeon_level.gd")
	var dl: Variant = DL.new()
	dl.dungeon_id = "catacombe"
	var normal: Array = dl.music_names()
	dl.rift_grade = 3
	var rift: Array = dl.music_names()
	dl.free()
	_check(normal == ["dungeon_catacombe", "dungeon"] and rift == ["labirinto", "dungeon"], "dungeon: prima il suo brano poi quello comune; labirinti: \"labirinto\"")

	print("\n%d controlli, %d falliti" % [checks, fails])
