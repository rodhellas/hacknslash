extends SceneTree
## TEST AUTOMATICO delle meccaniche di progressione: abilità alternative, varianti (rune), passive,
## leggendari che cambiano le abilità, elite con affissi (Campioni e Rari), difficoltà, Labirinti di Dedalo.
## Uso:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tools/test_endgame.gd
## Non salva niente (partita di prova, slot -1).

var game: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	checks += 1
	print(("  OK       " if cond else "  FALLITO  ") + what)
	if not cond:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_level(id: String, max_frames: int = 900) -> bool:
	for i in max_frames:
		await process_frame
		var lvl: Variant = game.level
		if lvl != null and is_instance_valid(lvl) and lvl.level_id == id and lvl.player != null and lvl.is_node_ready():
			await _frames(3)
			return true
	return false


func _enemy(t: String, pos: Vector3, elite := false, affs: Array = [], rare := false) -> Variant:
	var E: GDScript = load("res://entities/enemy.gd")
	var e: Variant = E.create(t, 5, elite, affs, rare)
	e.position = pos
	game.level.enemies_root.add_child(e)
	return e


func _clear_enemies() -> void:
	for e: Variant in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)


func _run() -> void:
	game = root.get_node("Game")
	var SDB: GDScript = load("res://data/skill_db.gd")
	var HC: GDScript = load("res://data/hero_classes.gd")
	var HD: GDScript = load("res://core/hero_data.gd")
	var IDB: GDScript = load("res://data/item_db.gd")
	var DDB: GDScript = load("res://data/difficulty_db.gd")
	var EDB: GDScript = load("res://data/enemy_db.gd")

	print("\n== 1. Dati delle abilità")
	var ok := true
	var n_ab := 0
	var known_keys := ["dmg", "range", "arc", "gain", "combo", "color", "cost", "speed", "pierce", "length", "max_range",
		"cooldown", "duration", "dr", "shockwave", "knock", "mode", "distance", "damage", "heal_pct", "radius", "delay",
		"strike", "hits", "ticks", "interval", "spin", "explode_radius", "slow", "slow_time", "thickness", "count", "spread",
		"chain", "aspd", "lifesteal", "dot", "dot_time", "stun", "heal_hit", "gain_hit", "pull", "echo", "self_buff",
		"crit_bonus", "move", "crit"]
	for cid: String in HC.ORDER:
		for slot: String in HC.SLOT_ORDER:
			if SDB.pool_for_slot(cid, slot).size() < 2:
				ok = false
				print("    %s: tasto %s senza alternative" % [cid, slot])
		for ab: Dictionary in SDB.all_abilities(cid):
			n_ab += 1
			var rs: Array = SDB.runes(String(ab["id"]))
			if rs.size() != 3:
				ok = false
				print("    %s: %d varianti" % [ab["id"], rs.size()])
			for r: Dictionary in rs:
				for part: String in ["mods", "add", "mul"]:
					for k: String in r.get(part, {}):
						if not known_keys.has(k):
							ok = false
							print("    %s/%s: chiave sconosciuta %s" % [ab["id"], r["id"], k])
		if SDB.passives(cid).size() != 6:
			ok = false
	_check(ok and n_ab == 40, "40 abilità (10 per classe), 3 varianti ciascuna, ogni tasto ha un'alternativa, 6 passive per classe")
	var pm_ok := true
	for pw: String in SDB.POWER_MODS:
		var found := false
		for l: Dictionary in IDB.LEGENDARIES:
			if l["power"] == pw:
				found = true
		var ab_id: String = SDB.power_ability(pw)
		var cls_ok := false
		for cid: String in HC.ORDER:
			if not SDB.find_ability(cid, ab_id).is_empty():
				cls_ok = true
		pm_ok = pm_ok and found and cls_ok and IDB.POWERS.has(pw)
	_check(pm_ok and IDB.LEGENDARIES.size() == 24, "24 leggendari, 12 cambiano un'abilità esistente")
	var sets_ok: bool = IDB.SETS.size() == 8
	for sid: String in IDB.SETS:
		for id: String in (IDB.SETS[sid]["bonus"][4]["skills"] as Dictionary):
			if SDB.find_ability(String(IDB.SETS[sid]["class"]), id).is_empty():
				sets_ok = false
				print("    set %s: abilità %s inesistente" % [sid, id])
	_check(sets_ok, "8 set (2 per classe), i bonus a 4 pezzi citano abilità vere")

	print("\n== 2. Scelte dell'eroe")
	var h: Variant = HD.create("Collaudatore", "legionario")
	_check(h.skills["rmb"]["id"] == "pilum" and h.skills["4"]["id"] == "bombardamento", "abilità iniziali sui tasti giusti")
	_check(not h.set_skill("rmb", "colpo_scudo"), "abilità non ancora sbloccata: rifiutata")
	h.level = 40
	_check(not h.set_skill("lmb", "pilum"), "una secondaria non va sul clic sinistro")
	_check(h.set_skill("rmb", "colpo_scudo", "spinta") and h.skills["rmb"]["rune"] == "spinta", "Colpo di scudo con variante Spinta sul clic destro")
	_check(h.set_skill("1", "bombardamento") and h.skills["4"]["id"] == "testuggine", "mettere un'abilità già usata su un altro tasto le scambia")
	_check(not h.set_skill("2", "carica", "inesistente"), "variante inesistente rifiutata")
	h.level = 9
	_check(not h.set_skill("2", "carica", "seconda"), "variante non ancora sbloccata rifiutata")
	h.level = 40
	_check(h.set_passive(0, "veterano") and h.set_passive(1, "veterano") and h.passives[0] == "" and h.passives[1] == "veterano",
		"una passiva sta in una casella sola")
	var s0: Dictionary = h.compute_stats()
	h.set_passive(2, "furia_legione")
	var s1: Dictionary = h.compute_stats()
	_check(absf(float(s1["damage_pct"]) - float(s0["damage_pct"]) - 10.0) < 0.01, "la passiva Furia della legione dà +10% danni")
	h.difficulty = 4
	var back: Variant = HD.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	_check(back.skills["rmb"]["id"] == "colpo_scudo" and back.skills["rmb"]["rune"] == "spinta" and back.passives == h.passives and back.difficulty == 4,
		"abilità, varianti, passive e difficoltà restano nel salvataggio")
	var old: Dictionary = h.to_dict()
	old.erase("skills")
	old.erase("passives")
	_check(HD.from_dict(old).skills["lmb"]["id"] == "colpo_gladio", "salvataggi vecchi: abilità base sui tasti")

	print("\n== 3. Abilità in gioco")
	var hero: Variant = HD.create("Collaudatore", "legionario")
	hero.level = 40
	game.hero = hero
	game.current_slot = -1
	game.travel("ostia_nova")
	_check(await _wait_level("ostia_nova"), "Ostia Nova caricata")
	var p: Variant = game.level.player
	var ppos: Vector3 = p.global_position
	hero.set_skill("rmb", "pilum", "stordente")
	p.rebuild_abilities()
	_check(p.abilities["rmb"].get("stun", 0.0) == 1.0 and float(p.abilities["rmb"]["cost"]) == 15.0, "la variante cambia l'abilità (stordisce, costa 5 in meno)")
	_check(game.level.hud.slots["rmb"].ability.get("rune", "") == "stordente", "la barra delle abilità si aggiorna")
	var e: Variant = _enemy("bruto", ppos + Vector3(0, 0, -4))
	await _frames(2)
	e.max_life = 1e6
	e.life = 1e6
	var ab: Dictionary = p.abilities["rmb"].duplicate()
	load("res://core/abilities.gd").hit_enemy(p, e, 1.0, Vector3.ZERO, ab)
	_check(e.stun_timer > 0.0, "il colpo stordisce il nemico")
	ab = {"id": "x", "dmg": 1.0, "dot": 1.0, "dot_time": 2.0}
	load("res://core/abilities.gd").hit_enemy(p, e, 1.0, Vector3.ZERO, ab)
	var life_before: float = e.life
	await _frames(150)
	_check(e.dot_timer <= 0.0 and e.life < life_before, "le fiamme fanno danno nel tempo (%d)" % roundi(life_before - e.life))
	p.life = 10.0
	load("res://core/abilities.gd").hit_enemy(p, e, 1.0, Vector3.ZERO, {"id": "x", "dmg": 1.0, "heal_hit": 0.5})
	_check(p.life > 10.0, "le varianti con cura ti curano colpendo")
	# Echo: la seconda salva
	hero.set_skill("4", "bombardamento", "salva_doppia")
	p.rebuild_abilities()
	p.resource = 100.0
	e.global_position = ppos + Vector3(0, 0, -6)
	e.stun_timer = 100.0   # resta fermo sotto il bombardamento
	var lb: float = e.life
	p.cooldowns.clear()
	p.cast_lock = 0.0
	p._try_cast("4", e.global_position)
	await _frames(65)
	var after_first: float = e.life
	await _frames(70)
	_check(after_first < lb and e.life < after_first, "Salva doppia: il bombardamento colpisce due volte")
	# Leggendario che cambia l'abilità
	var mario: Variant = IDB.make_basic("spatha", 40)
	mario.power = "mario"
	mario.rarity = 3
	hero.equipment["arma"] = mario
	hero.set_skill("rmb", "pilum", "")
	p.refresh_stats()
	_check(int(p.abilities["rmb"].get("count", 1)) == 3, "Spatha di Gaio Mario: Pilum lancia tre pila")
	p.rebuild_abilities()
	var n_proj := 0
	p.resource = 100.0
	p.cast_lock = 0.0
	p._try_cast("rmb", ppos + Vector3(0, 0, -10))
	await _frames(1)
	for c: Node in game.level.dynamic_root.get_children():
		if c.get_script() == load("res://entities/projectile.gd"):
			n_proj += 1
	_check(n_proj == 3, "in gioco partono 3 proiettili (%d)" % n_proj)
	# Passiva Ultimo baluardo
	hero.set_passive(1, "baluardo")
	p.refresh_stats()
	p.life = float(p.stats["max_life"])
	p.take_damage(10.0, 1)
	var dmg_full: float = float(p.stats["max_life"]) - p.life
	p.life = float(p.stats["max_life"]) * 0.2
	var l0: float = p.life
	p.take_damage(10.0, 1)
	_check(l0 - p.life < dmg_full * 0.8, "Ultimo baluardo: sotto il 35%% di vita meno danni (%.1f contro %.1f)" % [l0 - p.life, dmg_full])
	p.life = float(p.stats["max_life"])
	await _clear_enemies()

	print("\n== 4. Elite con affissi")
	var corazz: Variant = _enemy("predone", ppos + Vector3(5, 0, 0), true, ["corazzato"])
	var plain: Variant = _enemy("predone", ppos + Vector3(-5, 0, 0), true, [])
	await _frames(2)
	corazz.take_damage(10.0)
	plain.take_damage(10.0)
	_check(absf((corazz.max_life - corazz.life) - 6.5) < 0.01 and absf((plain.max_life - plain.life) - 10.0) < 0.01, "Corazzato subisce il 35% di danni in meno")
	_check(corazz.name_label.text.contains("Corazzato"), "il nome mostra gli affissi")
	var vamp: Variant = _enemy("predone", ppos + Vector3(0, 0, 3), true, ["vampirico"])
	await _frames(2)
	vamp.life = 10.0
	vamp._hit_player(p, 20.0)
	_check(vamp.life > 10.0, "Vampirico si cura colpendoti")
	var shield: Variant = _enemy("predone", ppos + Vector3(0, 0, 6), true, ["scudato"])
	await _frames(2)
	shield.aggro()
	shield._aff_cd["scudato"] = 0.0
	await _frames(3)
	var sl: float = shield.life
	shield.take_damage(50.0)
	_check(shield._shield_t > 0.0 and shield.life == sl, "Scudato: invulnerabile mentre lo scudo è attivo")
	var expl: Variant = _enemy("predone", ppos + Vector3(8, 0, 8), true, ["esplosivo"])
	await _frames(2)
	expl.take_damage(1e6)
	await _frames(2)
	var hz := 0
	for c: Node in game.level.dynamic_root.get_children():
		if c.get_script() == load("res://entities/hazard.gd"):
			hz += 1
	_check(hz >= 1, "Esplosivo: morendo lascia un'esplosione a terra")
	await _clear_enemies()
	# Gruppi: Campioni e Rari
	var Zone: GDScript = load("res://world/encounter_zone.gd")
	var seen_rare := false
	var seen_champ := false
	var aff_ok := true
	for i in 12:
		var z: Variant = Zone.new()
		z.enemy_types = PackedStringArray(["predone"])
		z.count = 3
		z.elite = true
		z.position = ppos + Vector3(0, 0, 12)
		game.level.add_child(z)
		z.spawn()
		var leaders := 0
		var minions := 0
		var champs := 0
		for en: Variant in z.enemies:
			if en.rare:
				leaders += 1
				aff_ok = aff_ok and en.affixes.size() == 1
			elif en.elite:
				champs += 1
				aff_ok = aff_ok and en.affixes.size() == 1
			else:
				minions += 1
		if leaders == 1 and minions >= 4 and champs == 0:
			seen_rare = true
		if champs >= 3 and leaders == 0:
			seen_champ = true
		for en: Variant in z.enemies:
			en.queue_free()
		z.queue_free()
		await _frames(1)
	_check(seen_rare and seen_champ, "gruppi elite: Campioni (tutti blu) e capi rari con servitori")
	_check(aff_ok, "a Normale ogni elite ha 1 affisso")

	print("\n== 5. Difficoltà")
	hero.difficulty = 3
	var z2: Variant = Zone.new()
	z2.enemy_types = PackedStringArray(["predone"])
	z2.count = 3
	z2.elite = true
	z2.enemy_level = 2
	z2.position = ppos + Vector3(0, 0, 14)
	game.level.add_child(z2)
	z2.spawn()
	var en0: Variant = null
	for en: Variant in z2.enemies:
		if en.elite:
			en0 = en
	_check(en0 != null and en0.affixes.size() == 3, "Tormento I: 3 affissi per le elite")
	_check(en0 != null and en0.level == hero.level, "da Esperto in su i nemici hanno il livello dell'eroe (%d)" % (en0.level if en0 else -1))
	var normal: Variant = load("res://entities/enemy.gd").create("predone", 40)
	hero.difficulty = 0
	var normal0: Variant = load("res://entities/enemy.gd").create("predone", 40)
	_check(absf(normal.max_life / normal0.max_life - 4.0) < 0.01, "Tormento I: vita dei nemici ×4")
	normal.free()
	normal0.free()
	var legs := [0, 0]
	for k in 2:
		for i in 4000:
			if IDB.roll_rarity("elite", 1.0 if k == 0 else 3.0) == 3:
				legs[k] += 1
	_check(legs[1] > legs[0] * 2, "più leggendari alle difficoltà alte (%d contro %d su 4000)" % [legs[1], legs[0]])
	for en: Variant in z2.enemies:
		en.queue_free()
	z2.queue_free()
	await _clear_enemies()

	print("\n== 6. Labirinti di Dedalo")
	var ob: Variant = game.level.find_child("ObeliscoDedalo", true, false)
	_check(ob != null, "Obelisco di Dedalo nel foro di Ostia Nova")
	ob.interact(p)
	_check(game.level.hud.choice_panel.visible, "l'obelisco chiede il grado")
	game.level.hud.hide_choice()
	load("res://world/rift_obelisk.gd").start(3)
	_check(await _wait_level("dungeon"), "si entra nel labirinto")
	var lv: Variant = game.level
	_check(lv.rift_grade == 3 and lv.level_title.contains("grado 3"), "grado 3: %s" % lv.level_title)
	_check(game.enemy_scaling()["hp"] > 1.5, "i nemici seguono il grado del labirinto, non la difficoltà")
	_check(lv.rift_target > 10.0 and lv.hud.rift_box.visible, "barra dell'avanzamento (obiettivo %d)" % roundi(lv.rift_target))
	var map: RID = lv.get_world_3d().navigation_map
	for i in 120:
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break
		await process_frame
	var p2: Variant = lv.player
	lv.rift_progress = lv.rift_target - 0.5
	var victim: Variant = _enemy("predone", p2.global_position + Vector3(2, 0, 0))
	await _frames(2)
	victim.take_damage(1e7)
	await _frames(3)
	_check(lv.guardian_spawned and lv.guardian != null and lv.guardian.display_name.begins_with("Guardiano"), "barra piena: arriva il Guardiano")
	await _frames(3)
	_check(lv.hud.boss_box.visible and lv.hud.boss_name.text.begins_with("Guardiano"), "barra del boss in alto")
	var gid: String = lv.guardian.type_id
	lv.guardian.take_damage(1e9)
	await _frames(5)
	_check(lv.rift_done and int(game.hero.flags.get("rift_max", 1)) >= 4, "Guardiano sconfitto in tempo: sbloccato il grado %d" % int(game.hero.flags.get("rift_max", 1)))
	_check(not game.hero.flags.has("unique_" + gid), "il Guardiano non conta come il boss della campagna")
	var items := 0
	for c: Node in lv.dynamic_root.get_children():
		if c.get_script() == load("res://entities/loot_drop.gd") and c.item != null:
			items += 1
	_check(items >= 4, "ricompensa del labirinto (%d oggetti)" % items)
	var leg_drop: Variant = null
	for c: Node in lv.dynamic_root.get_children():
		if c.get_script() == load("res://entities/loot_drop.gd") and String(c.gem).begins_with("leg:"):
			leg_drop = c
	_check(leg_drop != null, "il primo labirinto lascia una gemma leggendaria")
	if leg_drop != null:
		leg_drop._take_gold()
		await _frames(2)
		lv.gem_upgrades_left = 3
		lv.offer_gem_upgrade()
		await _frames(1)
		_check(lv.hud.choice_panel.visible and String(lv.hud.choice_title.text).begins_with("Potenzia"), "dopo il labirinto si può potenziare la gemma")
		var entry: Dictionary = game.hero.owned_legendary_gems()[0]
		_check(lv.try_gem_upgrade(entry, 0.0) and game.hero.owned_legendary_gems()[0]["key"].ends_with(":2") and lv.gem_upgrades_left == 2,
			"potenziamento: la gemma passa al grado 2")
		await _frames(2)
		lv.hud.hide_choice()
	var recs: Array = game.hero.flags.get("rift_records", [])
	_check(recs.size() == 1 and int(recs[0]["grade"]) == 3, "record personale del labirinto salvato")
	var ex: Variant = lv.find_child("UscitaLabirinto", true, false)
	_check(ex != null, "compare l'uscita per tornare in città")
	p2.global_position = ex.global_position
	_check(await _wait_level("ostia_nova"), "l'uscita riporta a Ostia Nova")
	_check(not game.hero.flags.has("dungeon"), "il labirinto si chiude")

	print("\n%d controlli, %d falliti" % [checks, fails])
	quit(1 if fails > 0 else 0)
