extends SceneTree
## Esporta la pianta dei dungeon (data/dungeon_db.gd) in docs/mappe/dungeon_<id>.png.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/export_dungeons.gd
##       ... -- 1234        prova un altro seme (file dungeon_<id>_seme1234.png): se ti piace,
##                          scrivilo come "seed" del dungeon in data/dungeon_db.gd.
## Colori: pavimento grigio, muri marroni, partenza verde, stanza del boss rossa. 1 cella = 6 px.

const PX := 6


func _initialize() -> void:
	var Gen: GDScript = load("res://world/dungeon_gen.gd")
	var DB: GDScript = load("res://data/dungeon_db.gd")
	var args := OS.get_cmdline_user_args()
	var seed_arg := int(args[0]) if not args.is_empty() and String(args[0]).is_valid_int() else -1
	DirAccess.make_dir_recursive_absolute("res://docs/mappe")
	for id: String in DB.DUNGEONS:
		var cfg: Dictionary = DB.DUNGEONS[id]
		var g: Variant = Gen.generate(cfg, seed_arg)
		var img := Image.create(g.w * PX, g.h * PX, false, Image.FORMAT_RGB8)
		img.fill(Color(0.05, 0.05, 0.06))
		for y in g.h:
			for x in g.w:
				var col := Color.TRANSPARENT
				if g.is_floor(x, y):
					col = Color(0.55, 0.53, 0.5)
				else:
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if g.is_floor(x + dx, y + dy):
								col = Color(0.36, 0.27, 0.2)
				if col.a > 0.0:
					img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), col)
		for i in g.rooms.size():
			var r: Rect2i = g.rooms[i]
			var mark := Color(0.3, 0.85, 0.35) if i == g.start_room else (Color(0.9, 0.25, 0.2) if i == g.boss_room else Color.TRANSPARENT)
			if mark.a > 0.0:
				var c: Vector2i = r.position + r.size / 2
				img.fill_rect(Rect2i(c.x * PX - PX, c.y * PX - PX, PX * 3, PX * 3), mark)
		var suffix := "_seme%d" % seed_arg if seed_arg >= 0 else ""
		var path := "res://docs/mappe/dungeon_%s%s.png" % [id, suffix]
		img.save_png(path)
		print("%s (seme %d): %d stanze, impronta %d -> %s" % [id, seed_arg if seed_arg >= 0 else int(cfg["seed"]), g.rooms.size(), g.fingerprint(), path])
	quit()
