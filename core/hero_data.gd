class_name HeroData
extends RefCounted
## Dati persistenti dell'eroe: classe, livello, equipaggiamento, inventario, progressi nel mondo.
## È ciò che viene scritto nei file di salvataggio.

const INV_SIZE := 40
const MAX_LEVEL := 60
## Caselle dell'equipaggiamento (13, come D3), nell'ordine della griglia 3 × 5 dello zaino.
## "anello2" è il secondo anello (oggetti con slot "anello"); in "secondaria" il Gladiatore può tenere
## una seconda arma a una mano (doppia arma).
const EQUIP_SLOTS := ["elmo", "spalle", "amuleto", "armatura", "guanti", "bracciali", "anello", "cintura", "anello2",
	"arma", "gambali", "secondaria", "calzari"]
## Tipi di oggetto (campo "slot" delle basi): come EQUIP_SLOTS ma senza le caselle doppie.
const ITEM_SLOTS := ["elmo", "spalle", "amuleto", "armatura", "guanti", "bracciali", "anello", "cintura",
	"arma", "gambali", "secondaria", "calzari"]

var hero_name := "Lucio"
var class_id := "legionario"
var sex := "m"                   # "m" o "f": sceglie il corpo (HeroClasses "model" / "model_f")
var level := 1
var xp := 0
var gold := 0
var inventory: Array = []        # Item o null, lunghezza INV_SIZE
var equipment: Dictionary = {}   # slot -> Item
var level_id := "level_01"
var position := Vector3.ZERO
var has_position := false
var checkpoint_id := ""
var flags: Dictionary = {}       # forzieri aperti, boss uccisi, altari attivati...
var play_time := 0.0
var materials: Dictionary = {}   # materiali del fabbro: "rottami", "essenza", "frammento"
var waypoints: Dictionary = {}   # altari attivati (viaggio rapido): id -> {"level": id livello, "title": nome}
var quests: Dictionary = {}      # missioni: id -> {"state": "active"/"done", "step": int, "count": int}
var gems: Dictionary = {}        # sacchetto delle gemme: "rubino:2" -> quantità
var skills: Dictionary = {}      # abilità sui tasti: "lmb"/"rmb"/"1".."4" -> {"id": abilità, "rune": variante o ""}
var passives: Array = ["", "", ""]  # passive scelte (SkillDB.PASSIVES), "" = casella vuota
var difficulty := 0              # indice in DifficultyDB.LEVELS
var transmog: Dictionary = {}    # aspetto: slot -> id base mostrata al posto di quella indossata
var dyes: Dictionary = {}        # tinte: slot -> chiave di VisualDB.DYES
var looks: Array = []            # aspetti sbloccati (id delle basi raccolte o indossate)
var bounties: Dictionary = {}    # taglie per atto (core/bounties.gd)
var hardcore := false            # hardcore: alla morte l'eroe è perso per sempre

## Altari del livello 1 nei salvataggi fatti prima del viaggio rapido.
const LEGACY_WAYPOINTS := {
	"villa": "Altare dei Lari", "ponte": "Altare di Portuno", "necropoli": "Altare di Proserpina", "acquedotto": "Altare di Giano",
}


static func create(p_name: String, p_class: String, p_sex: String = "m") -> HeroData:
	var h := HeroData.new()
	h.hero_name = p_name
	h.class_id = p_class
	h.sex = "f" if p_sex == "f" else "m"
	h.fill_default_skills()
	h.inventory.resize(INV_SIZE)
	for base: String in HeroClasses.get_data(p_class)["start_items"]:
		var it := ItemDB.make_basic(base, 1)
		h.equipment[it.slot] = it
		h.unlock_look(base)
	return h


## Tasti senza abilità assegnata: abilità base della classe (quella con quello "slot").
func fill_default_skills() -> void:
	for ab: Dictionary in HeroClasses.get_data(class_id)["abilities"]:
		var s := String(ab["slot"])
		if not skills.has(s) or SkillDB.find_ability(class_id, String((skills[s] as Dictionary).get("id", ""))).is_empty():
			skills[s] = {"id": String(ab["id"]), "rune": ""}
	passives.resize(SkillDB.PASSIVE_SLOTS.size())
	for i in passives.size():
		if passives[i] == null or SkillDB.find_passive(class_id, String(passives[i])).is_empty():
			passives[i] = ""


## Assegna un'abilità (e una variante) a un tasto. false se non è permesso.
func set_skill(slot: String, ability_id: String, rune_id: String = "") -> bool:
	var ab := SkillDB.find_ability(class_id, ability_id)
	if ab.is_empty() or not SkillDB.pool_for_slot(class_id, slot).has(ab) or level < int(ab.get("unlock", 1)):
		return false
	if rune_id != "":
		var rs := SkillDB.runes(ability_id)
		var idx := -1
		for i in rs.size():
			if rs[i]["id"] == rune_id:
				idx = i
		if idx < 0 or level < SkillDB.rune_unlock(ab, idx):
			return false
	# La stessa abilità non può stare su due tasti: scambia
	for s: String in skills:
		if s != slot and String(skills[s]["id"]) == ability_id:
			skills[s] = (skills[slot] as Dictionary).duplicate()
	skills[slot] = {"id": ability_id, "rune": rune_id}
	return true


## Mette una passiva in una casella (index 0-2). "" la svuota.
func set_passive(index: int, passive_id: String) -> bool:
	if index < 0 or index >= passives.size() or level < int(SkillDB.PASSIVE_SLOTS[index]):
		return false
	if passive_id != "":
		var p := SkillDB.find_passive(class_id, passive_id)
		if p.is_empty() or level < int(p.get("unlock", 1)):
			return false
		for i in passives.size():
			if passives[i] == passive_id:
				passives[i] = ""
	passives[index] = passive_id
	return true


func has_passive(id: String) -> bool:
	return passives.has(id)


## Scena del modello dell'eroe (corpo maschile o femminile della classe).
func model_path() -> String:
	var cls := HeroClasses.get_data(class_id)
	return String(cls.get("model_f", cls["model"])) if sex == "f" else String(cls["model"])


func material(id: String) -> int:
	return int(materials.get(id, 0))


func add_material(id: String, amount: int) -> void:
	materials[id] = material(id) + amount


func gem_count(key: String) -> int:
	return int(gems.get(key, 0))


func add_gem(key: String, amount: int = 1) -> void:
	var n := gem_count(key) + amount
	if n > 0:
		gems[key] = n
	else:
		gems.erase(key)


## +% danni per abilità dati dai set indossati: {id abilità: %}.
func skill_bonuses() -> Dictionary:
	return ItemDB.set_bonuses(equipment, level)["skills"]


## Gemme leggendarie incastonate negli oggetti indossati: id -> grado.
func legendary_gems() -> Dictionary:
	var out := {}
	for slot: String in equipment:
		for g: Variant in (equipment[slot] as Item).gems:
			if ItemDB.is_legendary_gem(String(g)):
				var id := ItemDB.leg_gem_id(String(g))
				out[id] = maxi(int(out.get(id, 0)), ItemDB.leg_gem_rank(String(g)))
	return out


## Tutte le gemme leggendarie possedute: [{key, item (o null se nel sacchetto), index}].
func owned_legendary_gems() -> Array:
	var out: Array = []
	for k: String in gems:
		if ItemDB.is_legendary_gem(k):
			for i in gem_count(k):
				out.append({"key": k, "item": null, "index": -1})
	for slot: String in equipment:
		var it: Item = equipment[slot]
		for i in it.gems.size():
			if ItemDB.is_legendary_gem(String(it.gems[i])):
				out.append({"key": String(it.gems[i]), "item": it, "index": i})
	for it: Variant in inventory:
		if it != null:
			for i in (it as Item).gems.size():
				if ItemDB.is_legendary_gem(String(it.gems[i])):
					out.append({"key": String(it.gems[i]), "item": it, "index": i})
	return out


## Tenta di potenziare una gemma leggendaria (voce di owned_legendary_gems). Ritorna true se riuscito.
func upgrade_legendary_gem(entry: Dictionary, grade: int, roll: float = -1.0) -> bool:
	var key := String(entry["key"])
	var r := ItemDB.leg_gem_rank(key)
	if (roll if roll >= 0.0 else randf()) >= ItemDB.leg_gem_upgrade_chance(r, grade):
		return false
	var up := ItemDB.leg_gem_key(ItemDB.leg_gem_id(key), r + 1)
	if entry["item"] == null:
		add_gem(key, -1)
		add_gem(up)
	else:
		(entry["item"] as Item).gems[int(entry["index"])] = up
	return true


## Poteri dei leggendari indossati (chiavi di ItemDB.POWERS).
func legendary_powers() -> Dictionary:
	var out := {}
	for slot: String in equipment:
		var it: Item = equipment[slot]
		if it.power != "":
			out[it.power] = true
	return out


func register_waypoint(id: String, p_level: String, title: String) -> void:
	waypoints[id] = {"level": p_level, "title": title}
	flags["cp_" + id] = true
	flags["cp_last_" + p_level] = id


static func xp_to_next(lvl: int) -> int:
	return int(80.0 * pow(lvl, 1.6))


func add_item(it: Item) -> bool:
	for i in inventory.size():
		if inventory[i] == null:
			inventory[i] = it
			unlock_look(it.base_id)
			return true
	return false


## Aspetti (scheda Aspetto del fabbro): ogni base raccolta o indossata si sblocca.
func unlock_look(base_id: String) -> void:
	if base_id != "" and not looks.has(base_id) and VisualDB.VISUALS.has(base_id):
		looks.append(base_id)


## Aspetti sbloccati utilizzabili in uno slot (stesso slot e, per armi, usabili dalla classe).
func looks_for_slot(slot: String) -> Array:
	var out: Array = []
	for b: String in looks:
		var bd: Dictionary = ItemDB.BASES.get(b, {})
		if bd.is_empty() or String(bd["slot"]) != slot:
			continue
		if slot == "arma" and not String(bd.get("type", "")) in HeroClasses.get_data(class_id)["weapons"]:
			continue
		if slot == "secondaria" and not String(bd.get("type", "")) in HeroClasses.get_data(class_id)["offhands"]:
			continue
		out.append(b)
	return out


## Base mostrata in uno slot (aspetto scelto o quella vera).
func look_for(slot: String) -> String:
	var it: Item = equipment.get(slot)
	return String(transmog.get(slot, it.base_id if it != null else ""))


func can_equip(it: Item) -> bool:
	return ItemDB.usable_by(it, class_id)


## La classe può tenere quest'arma nella mano sinistra (doppia arma)?
func can_dual_wield(it: Item) -> bool:
	return it.slot == "arma" and it.weapon_type in HeroClasses.get_data(class_id)["offhands"]


## Casella in cui va un oggetto: alt = la casella "secondaria" (secondo anello, arma nella mano sinistra).
func target_slot(it: Item, alt: bool = false) -> String:
	if it.slot == "anello":
		if alt:
			return "anello2"
		if equipment.has("anello") and not equipment.has("anello2"):
			return "anello2"
		return "anello"
	if alt and can_dual_wield(it):
		return "secondaria"
	return it.slot


## Equipaggia l'oggetto dello zaino all'indice dato (scambiandolo con quello indossato).
## alt = mettilo nella casella secondaria (Ctrl + clic): secondo anello o arma nella mano sinistra.
func equip_from_inventory(index: int, alt: bool = false) -> bool:
	var it: Item = inventory[index]
	if it == null or not can_equip(it):
		return false
	var dest := target_slot(it, alt)
	var old: Item = equipment.get(dest)
	equipment[dest] = it
	inventory[index] = old
	unlock_look(it.base_id)
	return true


func unequip(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	if add_item(equipment[slot]):
		equipment.erase(slot)
		return true
	return false


## Calcola tutte le statistiche finali (base classe + livello + equipaggiamento).
func compute_stats() -> Dictionary:
	var cls := HeroClasses.get_data(class_id)
	var s := {}
	for k: String in ["forza", "destrezza", "intelligenza", "vitalita"]:
		s[k] = float(cls["base"][k] + cls["per_level"][k] * (level - 1))
	for k: String in ["armor", "attack_speed_pct", "life", "life_regen", "move_speed_pct", "gold_find",
			"life_on_hit", "damage_pct", "cdr_pct"]:
		s[k] = 0.0
	for k: String in ItemDB.ELEMENTS:
		s[k + "_pct"] = 0.0
	s["crit_chance"] = 5.0
	s["crit_damage"] = 50.0
	var wmin := 2.0
	var wmax := 3.0
	var aps := 1.2
	for slot: String in equipment:
		var it: Item = equipment[slot]
		s["armor"] += it.armor
		for a: Dictionary in it.affixes + it.gem_affixes():
			s[a["stat"]] = float(s.get(a["stat"], 0.0)) + float(a["value"])
		if slot == "arma":
			wmin = it.dmg_min
			wmax = it.dmg_max
			aps = it.attack_speed
	for a: Dictionary in ItemDB.set_bonuses(equipment, level)["stats"]:
		s[a["stat"]] = float(s.get(a["stat"], 0.0)) + float(a["value"])
	for pid: Variant in passives:
		var pd := SkillDB.find_passive(class_id, String(pid))
		for pair: Array in pd.get("stats", []):
			s[pair[0]] = float(s.get(pair[0], 0.0)) + float(pair[1])
	var off: Item = equipment.get("secondaria")
	if off != null and off.dmg_max > 0.0:
		wmin += off.dmg_min * 0.5
		wmax += off.dmg_max * 0.5
		if off.slot == "arma":
			aps *= 1.15   # doppia arma: +15% velocità d'attacco
	var main: float = float(s[cls["main_stat"]])
	s["main_stat"] = main
	s["weapon_min"] = wmin
	s["weapon_max"] = wmax
	s["aps"] = aps * (1.0 + s["attack_speed_pct"] / 100.0)
	s["armor"] += s["forza"] * 0.5
	s["armor"] *= 1.0 + float(s.get("armor_pct", 0.0)) / 100.0
	s["max_life"] = (60.0 + level * 12.0 + s["vitalita"] * 6.0 + s["life"]) * (1.0 + float(s.get("life_pct", 0.0)) / 100.0)
	s["dr_pct"] = float(s.get("dr_pct", 0.0))
	var avg: float = (wmin + wmax) * 0.5 * (1.0 + main / 100.0) * (1.0 + s["damage_pct"] / 100.0)
	s["damage_avg"] = avg
	s["dps"] = avg * s["aps"] * (1.0 + minf(s["crit_chance"], 75.0) / 100.0 * s["crit_damage"] / 100.0)
	s["move_speed"] = 6.0 * (1.0 + minf(s["move_speed_pct"], 25.0) / 100.0)
	s["resource_max"] = float(cls["resource_max"])
	s["resource_regen"] = float(cls["resource_regen"]) * (1.0 + float(s.get("resource_regen_pct", 0.0)) / 100.0) \
		+ float(s.get("resource_regen_flat", 0.0))
	return s


func to_dict() -> Dictionary:
	var inv: Array = []
	for it: Item in inventory:
		inv.append(it.to_dict() if it != null else null)
	var eq := {}
	for slot: String in equipment:
		eq[slot] = (equipment[slot] as Item).to_dict()
	return {
		"name": hero_name, "class_id": class_id, "sex": sex, "level": level, "xp": xp, "gold": gold,
		"inventory": inv, "equipment": eq, "level_id": level_id,
		"position": [position.x, position.y, position.z], "has_position": has_position,
		"checkpoint_id": checkpoint_id, "flags": flags, "play_time": play_time,
		"materials": materials, "waypoints": waypoints, "quests": quests, "gems": gems,
		"skills": skills, "passives": passives, "difficulty": difficulty,
		"transmog": transmog, "dyes": dyes, "looks": looks, "bounties": bounties, "hardcore": hardcore,
	}


static func from_dict(d: Dictionary) -> HeroData:
	var h := HeroData.new()
	h.hero_name = String(d.get("name", "Lucio"))
	h.class_id = String(d.get("class_id", "legionario"))
	h.sex = "f" if String(d.get("sex", "m")) == "f" else "m"
	h.level = int(d.get("level", 1))
	h.xp = int(d.get("xp", 0))
	h.gold = int(d.get("gold", 0))
	h.inventory.resize(INV_SIZE)
	var inv: Array = d.get("inventory", [])
	for i in mini(inv.size(), INV_SIZE):
		if inv[i] is Dictionary:
			h.inventory[i] = Item.from_dict(inv[i])
	var eq: Dictionary = d.get("equipment", {})
	for slot: String in eq:
		h.equipment[slot] = Item.from_dict(eq[slot])
	h.level_id = String(d.get("level_id", "level_01"))
	var p: Array = d.get("position", [0, 0, 0])
	h.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	h.has_position = bool(d.get("has_position", false))
	h.checkpoint_id = String(d.get("checkpoint_id", ""))
	h.flags = d.get("flags", {})
	h.play_time = float(d.get("play_time", 0.0))
	var mats: Dictionary = d.get("materials", {})
	for k: String in mats:
		h.materials[k] = int(mats[k])
	h.waypoints = d.get("waypoints", {})
	var gs: Dictionary = d.get("gems", {})
	for k: String in gs:
		h.gems[k] = int(gs[k])
	h.difficulty = clampi(int(d.get("difficulty", 0)), 0, DifficultyDB.LEVELS.size() - 1)
	h.bounties = d.get("bounties", {})
	h.hardcore = bool(d.get("hardcore", false))
	var tm: Dictionary = d.get("transmog", {})
	for s: String in tm:
		h.transmog[s] = String(tm[s])
	var dy: Dictionary = d.get("dyes", {})
	for s: String in dy:
		h.dyes[s] = String(dy[s])
	for b: Variant in d.get("looks", []):
		h.unlock_look(String(b))
	for slot: String in h.equipment:
		h.unlock_look((h.equipment[slot] as Item).base_id)
	var sk: Dictionary = d.get("skills", {})
	for s: String in sk:
		if sk[s] is Dictionary:
			h.skills[s] = {"id": String(sk[s].get("id", "")), "rune": String(sk[s].get("rune", ""))}
	var ps: Array = d.get("passives", [])
	for i in mini(ps.size(), h.passives.size()):
		h.passives[i] = String(ps[i]) if ps[i] != null else ""
	h.fill_default_skills()
	var qs: Dictionary = d.get("quests", {})
	for id: String in qs:
		var q: Dictionary = qs[id]
		h.quests[id] = {"state": String(q.get("state", "active")), "step": int(q.get("step", 0)), "count": int(q.get("count", 0))}
	# Salvataggi vecchi: gli altari attivati erano solo flag "cp_<id>" del livello 1
	for k: String in h.flags.keys():
		if k.begins_with("cp_") and not k.begins_with("cp_last_"):
			var id := k.substr(3)
			if not h.waypoints.has(id) and LEGACY_WAYPOINTS.has(id):
				h.waypoints[id] = {"level": "level_01", "title": LEGACY_WAYPOINTS[id]}
	if h.checkpoint_id != "" and not h.flags.has("cp_last_" + h.level_id):
		h.flags["cp_last_" + h.level_id] = h.checkpoint_id
	return h
