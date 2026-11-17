class_name Bounties
extends RefCounted
## Taglie (modalità avventura, WorldDB.ACTS): obiettivi casuali per atto, presi dalla Tabula nel foro
## di Ostia Nova. Stato in HeroData.bounties = {"1": [taglia, ...], "2": [...]}; ogni taglia è
## {type, target, place, count, progress, done}. Avanzano da Enemy._die (on_kill) e WorldEvent.


## Chiave del luogo attuale: id del livello, "dungeon:<id>" nei dungeon, "rift" nei labirinti.
static func level_key() -> String:
	if Game.level == null or not is_instance_valid(Game.level):
		return ""
	if Game.level.level_id == "dungeon":
		var info: Dictionary = Game.hero.flags.get("dungeon", {})
		return "rift" if info.has("rift") else "dungeon:" + String(info.get("id", ""))
	return Game.level.level_id


static func act_list(act: int) -> Array:
	var key := str(act)
	if not Game.hero.bounties.has(key):
		Game.hero.bounties[key] = generate(act)
	return Game.hero.bounties[key]


static func generate(act: int) -> Array:
	var a: Dictionary = WorldDB.ACTS[act]
	var out: Array = []
	var bosses: Array = (a["bosses"] as Dictionary).keys()
	var boss: String = bosses.pick_random()
	out.append({"type": "boss", "target": boss, "place": String(a["bosses"][boss]), "count": 1, "progress": 0, "done": false})
	var places: Array = (a["levels"] as Array).duplicate()
	places.shuffle()
	var kinds := ["kill", "elite", "event"]
	var i := 0
	while out.size() < WorldDB.BOUNTIES_PER_ACT:
		var place: String = places[i % places.size()]
		var kind: String = kinds[i % kinds.size()]
		if kind == "event" and place.begins_with("dungeon:"):
			kind = "kill"   # gli eventi ci sono solo all'aperto
		var count := {"kill": 25, "elite": 3, "event": 1}[kind] as int
		out.append({"type": kind, "target": "", "place": place, "count": count, "progress": 0, "done": false})
		i += 1
	return out


static func text(b: Dictionary) -> String:
	var place := WorldDB.place_name(String(b["place"]))
	var t := ""
	match String(b["type"]):
		"boss": t = "Uccidi %s (%s)" % [EnemyDB.get_data(String(b["target"]))["name"], place]
		"kill": t = "Uccidi %d nemici: %s" % [int(b["count"]), place]
		"elite": t = "Uccidi %d elite: %s" % [int(b["count"]), place]
		"event": t = "Completa un evento: %s" % place
	if bool(b["done"]):
		return "✔ " + t
	if int(b["count"]) > 1:
		t += " (%d/%d)" % [int(b["progress"]), int(b["count"])]
	return t


static func act_done(act: int) -> bool:
	for b: Dictionary in act_list(act):
		if not bool(b["done"]):
			return false
	return true


## Avanza le taglie di quel tipo nel luogo indicato (target per i boss).
static func notify(type: String, place: String, target: String = "") -> void:
	if Game.hero == null or place == "" or place == "rift":
		return
	for act: int in WorldDB.ACTS:
		if not Game.hero.bounties.has(str(act)):
			continue
		for b: Dictionary in Game.hero.bounties[str(act)]:
			if bool(b["done"]) or String(b["type"]) != type or String(b["place"]) != place:
				continue
			if type == "boss" and String(b["target"]) != target:
				continue
			b["progress"] = int(b["progress"]) + 1
			if int(b["progress"]) >= int(b["count"]):
				b["done"] = true
				_reward(b, act)
	if Game.level and is_instance_valid(Game.level):
		Game.level.hud.update_quests()


static func on_kill(e: Enemy) -> void:
	var place := level_key()
	notify("kill", place)
	if e.elite and (e.rare or not e.unique):
		notify("elite", place)
	if e.unique:
		notify("boss", place, e.type_id)


static func _reward(b: Dictionary, act: int) -> void:
	var lvl := Game.hero.level
	Game.hero.gold += int(WorldDB.BOUNTY_REWARD["gold_per_level"]) * lvl
	if Game.level and is_instance_valid(Game.level):
		Game.level.player.add_xp(int(WorldDB.BOUNTY_REWARD["xp_per_level"]) * lvl)
		Game.level.hud.show_banner("Taglia completata")
		var msg := text(b)
		if act_done(act):
			msg += "\nTutte le taglie dell'atto completate: ritira la Cassa del Prefetto alla Tabula!"
		Game.level.hud.show_message(msg, 4.0)
		Sfx.play("checkpoint")


## Un boss già sconfitto ricompare se una taglia attiva lo chiede.
static func wants_boss(id: String) -> bool:
	if Game.hero == null:
		return false
	for act: String in Game.hero.bounties:
		for b: Dictionary in Game.hero.bounties[act]:
			if String(b["type"]) == "boss" and String(b["target"]) == id and not bool(b["done"]):
				return true
	return false


## Cassa del Prefetto: loot dell'atto completato, poi taglie nuove.
static func claim_cache(act: int, pos: Vector3) -> bool:
	if not act_done(act):
		return false
	var lvl := Game.hero.level
	Loot.spawn_item(ItemDB.generate(lvl, Item.Rarity.LEGGENDARIO, Game.hero.class_id), pos)
	Loot.drop("chest_rich", pos, lvl)
	Loot.drop("chest_rich", pos, lvl)
	Game.hero.add_material("essenza", 5)
	Game.hero.add_material("frammento", 1)
	Game.hero.gold += 200 * lvl
	Game.hero.bounties[str(act)] = generate(act)
	Game.hero.flags["caches_" + str(act)] = int(Game.hero.flags.get("caches_" + str(act), 0)) + 1
	return true


## Righe per il tracciatore dell'HUD: taglie dell'atto del luogo attuale.
static func tracker_lines() -> Array:
	var place := level_key()
	var out: Array = []
	for act: int in WorldDB.ACTS:
		if not Game.hero.bounties.has(str(act)):
			continue
		if not (WorldDB.ACTS[act]["levels"] as Array).has(place):
			continue
		for b: Dictionary in Game.hero.bounties[str(act)]:
			if String(b["place"]) == place:
				out.append(text(b))
	return out
