class_name HeroData
extends RefCounted
## Dati persistenti dell'eroe: classe, livello, equipaggiamento, inventario, progressi nel mondo.
## È ciò che viene scritto nei file di salvataggio.

const INV_SIZE := 40
const MAX_LEVEL := 60
const EQUIP_SLOTS := ["elmo", "amuleto", "armatura", "guanti", "anello", "gambali", "arma", "calzari", "secondaria"]

var hero_name := "Lucio"
var class_id := "legionario"
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


static func create(p_name: String, p_class: String) -> HeroData:
	var h := HeroData.new()
	h.hero_name = p_name
	h.class_id = p_class
	h.inventory.resize(INV_SIZE)
	for base: String in HeroClasses.get_data(p_class)["start_items"]:
		var it := ItemDB.make_basic(base, 1)
		h.equipment[it.slot] = it
	return h


static func xp_to_next(lvl: int) -> int:
	return int(80.0 * pow(lvl, 1.6))


func add_item(it: Item) -> bool:
	for i in inventory.size():
		if inventory[i] == null:
			inventory[i] = it
			return true
	return false


func can_equip(it: Item) -> bool:
	return ItemDB.usable_by(it, class_id)


## Equipaggia l'oggetto dello zaino all'indice dato (scambiandolo con quello indossato).
func equip_from_inventory(index: int) -> bool:
	var it: Item = inventory[index]
	if it == null or not can_equip(it):
		return false
	var old: Item = equipment.get(it.slot)
	equipment[it.slot] = it
	inventory[index] = old
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
	s["crit_chance"] = 5.0
	s["crit_damage"] = 50.0
	var wmin := 2.0
	var wmax := 3.0
	var aps := 1.2
	for slot: String in equipment:
		var it: Item = equipment[slot]
		s["armor"] += it.armor
		for a: Dictionary in it.affixes:
			s[a["stat"]] = float(s.get(a["stat"], 0.0)) + float(a["value"])
		if slot == "arma":
			wmin = it.dmg_min
			wmax = it.dmg_max
			aps = it.attack_speed
	var off: Item = equipment.get("secondaria")
	if off != null and off.dmg_max > 0.0:
		wmin += off.dmg_min * 0.5
		wmax += off.dmg_max * 0.5
	var main: float = float(s[cls["main_stat"]])
	s["main_stat"] = main
	s["weapon_min"] = wmin
	s["weapon_max"] = wmax
	s["aps"] = aps * (1.0 + s["attack_speed_pct"] / 100.0)
	s["armor"] += s["forza"] * 0.5
	s["max_life"] = 60.0 + level * 12.0 + s["vitalita"] * 6.0 + s["life"]
	var avg: float = (wmin + wmax) * 0.5 * (1.0 + main / 100.0) * (1.0 + s["damage_pct"] / 100.0)
	s["damage_avg"] = avg
	s["dps"] = avg * s["aps"] * (1.0 + minf(s["crit_chance"], 75.0) / 100.0 * s["crit_damage"] / 100.0)
	s["move_speed"] = 6.0 * (1.0 + minf(s["move_speed_pct"], 25.0) / 100.0)
	s["resource_max"] = float(cls["resource_max"])
	s["resource_regen"] = float(cls["resource_regen"])
	return s


func to_dict() -> Dictionary:
	var inv: Array = []
	for it: Item in inventory:
		inv.append(it.to_dict() if it != null else null)
	var eq := {}
	for slot: String in equipment:
		eq[slot] = (equipment[slot] as Item).to_dict()
	return {
		"name": hero_name, "class_id": class_id, "level": level, "xp": xp, "gold": gold,
		"inventory": inv, "equipment": eq, "level_id": level_id,
		"position": [position.x, position.y, position.z], "has_position": has_position,
		"checkpoint_id": checkpoint_id, "flags": flags, "play_time": play_time,
	}


static func from_dict(d: Dictionary) -> HeroData:
	var h := HeroData.new()
	h.hero_name = String(d.get("name", "Lucio"))
	h.class_id = String(d.get("class_id", "legionario"))
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
	return h
