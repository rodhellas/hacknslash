class_name Quests
extends RefCounted
## Logica delle missioni (i dati sono in data/quest_db.gd).
## Lo stato è in Game.hero.quests: id -> {"state": "active" | "done", "step": int, "count": int}.
## Il gioco segnala gli eventi con Quests.notify(tipo, bersaglio): uccisioni (enemy.gd), ingresso nei
## livelli (level.gd), altari (checkpoint.gd), forzieri (chest.gd), oggetti smontati (trade_ui.gd).
## I dialoghi passano da Quests.talk(npc_id), chiamato da npc.gd.


static func state(id: String) -> String:
	if Game.hero == null:
		return ""
	return String((Game.hero.quests.get(id, {}) as Dictionary).get("state", ""))


static func is_done(id: String) -> bool:
	return state(id) == "done"


static func active_ids() -> Array:
	var out: Array = []
	for id: String in QuestDB.ORDER:
		if state(id) == "active":
			out.append(id)
	return out


static func current_step(id: String) -> Dictionary:
	var q := QuestDB.get_data(id)
	var st: Dictionary = Game.hero.quests.get(id, {})
	var i := int(st.get("step", 0))
	var steps: Array = q.get("steps", [])
	return steps[i] if i < steps.size() else {}


## Testo dell'obiettivo corrente con l'avanzamento (es. "Sconfiggi i lemuri (4/12)").
static func step_text(id: String) -> String:
	var s := current_step(id)
	if s.is_empty():
		return ""
	var need := int(s.get("count", 1))
	if need > 1:
		return "%s (%d/%d)" % [s["text"], int(Game.hero.quests[id].get("count", 0)), need]
	return String(s["text"])


static func can_start(id: String) -> bool:
	if Game.hero == null or state(id) != "":
		return false
	for r: String in QuestDB.get_data(id).get("requires", []):
		if not is_done(r):
			return false
	return true


static func start(id: String, announce: bool = true) -> void:
	if not can_start(id):
		return
	var q := QuestDB.get_data(id)
	Game.hero.quests[id] = {"state": "active", "step": 0, "count": 0}
	if String(q.get("on_start", "")) != "":
		Game.hero.flags[q["on_start"]] = true
	if announce:
		_message("Nuova missione: %s" % q["title"])
		Sfx.play("missione_nuova")
	_check_already(id)
	Game.quests_changed.emit()
	Cutscene.trigger("quest_start:" + id)


## Avvia le missioni senza NPC (giver "") i cui requisiti sono soddisfatti.
static func start_automatic() -> void:
	if Game.hero == null:
		return
	for id: String in QuestDB.ORDER:
		if String(QuestDB.get_data(id).get("giver", "")) == "" and can_start(id):
			start(id, false)


## Evento di gioco. type: kill, kill_unique, enter, altar, salvage, chest.
static func notify(type: String, target: String = "", amount: int = 1) -> void:
	if Game.hero == null:
		return
	var changed := false
	for id: String in active_ids():
		var s := current_step(id)
		if s.is_empty() or String(s["type"]) != type:
			continue
		var t := String(s.get("target", ""))
		if t != "" and t != target:
			continue
		var st: Dictionary = Game.hero.quests[id]
		st["count"] = int(st.get("count", 0)) + amount
		changed = true
		if int(st["count"]) >= int(s.get("count", 1)):
			_advance(id)
	if changed:
		Game.quests_changed.emit()


## Dialogo con un NPC: completa un obiettivo "parla con" oppure affida una nuova missione.
## Ritorna il testo da mostrare ("" = nessun dialogo di missione).
static func talk(npc_id: String) -> String:
	if Game.hero == null:
		return ""
	for id: String in active_ids():
		var s := current_step(id)
		if String(s.get("type", "")) == "talk" and String(s.get("target", "")) == npc_id:
			var text := String(s.get("say", ""))
			var q := QuestDB.get_data(id)
			_advance(id)
			if is_done(id) and String(q.get("outro", "")) != "":
				text += "\n\n" + String(q["outro"])
			Game.quests_changed.emit()
			return text
	for id: String in QuestDB.ORDER:
		var q := QuestDB.get_data(id)
		if String(q.get("giver", "")) == npc_id and can_start(id):
			start(id)
			return "[color=#f2c75a][b]%s[/b][/color]\n\n%s" % [q["title"], q.get("offer", "")]
	return ""


## Segno sopra la testa dell'NPC: "!" ha una missione da affidare, "?" aspetta che torni da lui.
static func npc_marker(npc_id: String) -> String:
	if Game.hero == null:
		return ""
	for id: String in active_ids():
		var s := current_step(id)
		if String(s.get("type", "")) == "talk" and String(s.get("target", "")) == npc_id:
			return "?"
	for id: String in QuestDB.ORDER:
		if String(QuestDB.get_data(id).get("giver", "")) == npc_id and can_start(id):
			return "!"
	return ""


static func _advance(id: String) -> void:
	var st: Dictionary = Game.hero.quests[id]
	var steps: Array = QuestDB.get_data(id)["steps"]
	st["step"] = int(st["step"]) + 1
	st["count"] = 0
	if int(st["step"]) >= steps.size():
		_complete(id)
		return
	_message("Obiettivo: %s" % step_text(id))
	_check_already(id)


## Se l'obiettivo è già stato fatto (es. boss ucciso prima di avere la missione), lo salta.
static func _check_already(id: String) -> void:
	var s := current_step(id)
	if s.is_empty():
		return
	var t := String(s.get("target", ""))
	var h := Game.hero
	var done := false
	match String(s["type"]):
		"kill_unique": done = h.flags.has("unique_" + t)
		"enter": done = h.flags.has("visited_" + t) or (Game.level != null and is_instance_valid(Game.level) and Game.level.level_id == t)
		"altar": done = h.waypoints.has(t)
		"chest": done = t != "" and h.flags.has(t)
	if done:
		_advance(id)


static func _complete(id: String) -> void:
	var q := QuestDB.get_data(id)
	Game.hero.quests[id]["state"] = "done"
	Cutscene.trigger.call_deferred("quest_done:" + id)
	var r: Dictionary = q.get("reward", {})
	var lines: Array = []
	var lvl: Level = Game.level if Game.level != null and is_instance_valid(Game.level) else null
	if r.has("gold"):
		Game.hero.gold += int(r["gold"])
		lines.append("+%d sesterzi" % int(r["gold"]))
	var mats: Dictionary = r.get("mats", {})
	for m: String in mats:
		Game.hero.add_material(m, int(mats[m]))
		lines.append("+%d %s" % [int(mats[m]), ItemDB.MATERIALS[m]["name"]])
	if r.has("item"):
		var it := ItemDB.generate(Game.hero.level, int(r["item"]), Game.hero.class_id)
		lines.append(it.item_name)
		if not Game.hero.add_item(it) and lvl != null:
			Loot.spawn_item(it, lvl.player.global_position)
	if r.has("xp") and lvl != null and lvl.player != null:
		lvl.player.add_xp(int(r["xp"]))
		lines.append("+%d PE" % int(r["xp"]))
	_message("Missione completata: %s\n%s" % [q["title"], "   ".join(lines)], 4.0)
	Sfx.play("missione_compiuta")
	if lvl != null and lvl.player != null:
		Fx.pillar(lvl.dynamic_root, lvl.player.global_position, Color(1.0, 0.8, 0.3), 10.0, 1.2)
		lvl.player.inventory_changed.emit()
	start_automatic()


static func _message(text: String, time: float = 3.0) -> void:
	if Game.level != null and is_instance_valid(Game.level) and Game.level.hud != null:
		Game.level.hud.show_message(text, time)
