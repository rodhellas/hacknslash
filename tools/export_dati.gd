extends SceneTree
## Esporta tutti i dati del gioco (data/*.gd) in user://dati.json per tools/export_excel.py
## (foglio Excel docs/Legio3000_dati.xlsx).
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/export_dati.gd


func _conv(v: Variant) -> Variant:
	if v is Color:
		return (v as Color).to_html(false)
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[str(k)] = _conv(v[k])
		return d
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_conv(x))
		return a
	if v is Vector3:
		return str(v)
	return v


func _initialize() -> void:
	var out := {}
	out["classes"] = load("res://data/hero_classes.gd").DATA
	out["order"] = load("res://data/hero_classes.gd").ORDER
	var S: GDScript = load("res://data/skill_db.gd")
	out["extra"] = S.EXTRA
	out["runes"] = S.RUNES
	out["passives"] = S.PASSIVES
	out["elements"] = S.ELEMENTS
	out["rune_elements"] = S.RUNE_ELEMENTS
	out["power_mods"] = S.POWER_MODS
	var rune_unlocks := {}
	for cid: String in S.EXTRA:
		for ab: Dictionary in S.all_abilities(cid):
			var arr: Array = []
			for i in S.runes(ab["id"]).size():
				arr.append(S.rune_unlock(ab, i))
			rune_unlocks[ab["id"]] = arr
	out["rune_unlocks"] = rune_unlocks
	var I: GDScript = load("res://data/item_db.gd")
	for k: String in ["BASES", "AFFIXES", "LEGENDARIES", "POWERS", "SETS", "GEMS", "GEM_TIERS", "GEM_TIER_MULT", "MAX_SOCKETS", "SOCKET_CHANCE",
			"LEGENDARY_GEMS", "RARITY_TABLE", "SELL_VALUE", "RECIPES", "ELEMENTS", "GEM_DROP_CHANCE", "MATERIALS"]:
		out["item_" + k] = I.get(k)
	var E: GDScript = load("res://data/enemy_db.gd")
	out["enemies"] = E.DATA
	out["elite_affixes"] = E.ELITE_AFFIXES
	out["bosses"] = E.BOSSES
	var D: GDScript = load("res://data/difficulty_db.gd")
	out["difficulty"] = D.LEVELS
	out["rift"] = {"time": D.RIFT_TIME, "fast": D.RIFT_FAST, "progress": D.RIFT_PROGRESS, "guardians": D.RIFT_GUARDIANS, "enemies": D.RIFT_ENEMIES}
	out["dungeons"] = load("res://data/dungeon_db.gd").DUNGEONS
	var W: GDScript = load("res://data/world_db.gd")
	out["shrines"] = W.SHRINES
	out["pylons"] = W.PYLONS
	out["events"] = W.EVENTS
	out["acts"] = W.ACTS
	out["quests"] = load("res://data/quest_db.gd").QUESTS
	out["npcs"] = load("res://data/npc_db.gd").DATA
	out["visuals"] = load("res://data/visual_db.gd").VISUALS
	var f := FileAccess.open("user://dati.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_conv(out), "\t"))
	f.close()
	print("Dati esportati in ", ProjectSettings.globalize_path("user://dati.json"))
	quit()
