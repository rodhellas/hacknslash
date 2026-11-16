class_name ItemDB
extends RefCounted
## Database oggetti: basi, affissi, leggendari e generazione casuale del loot (stile Diablo).
## Rarità: Comune (bianco, 0 affissi), Magico (blu, 1-2), Raro (giallo, 3-4), Leggendario (arancione, fissi + 2).

const BASES := {
	# --- Armi ---
	"gladio_plasma": {"name": "Gladio al plasma", "slot": "arma", "type": "gladio", "dmg": [6.0, 10.0], "aps": 1.4},
	"spatha": {"name": "Spatha a vibrazione", "slot": "arma", "type": "spatha", "dmg": [9.0, 15.0], "aps": 1.1},
	"scure": {"name": "Scure da arena", "slot": "arma", "type": "ascia", "dmg": [8.0, 13.0], "aps": 1.25},
	"arco_plasma": {"name": "Arco al plasma", "slot": "arma", "type": "arco", "dmg": [7.0, 11.0], "aps": 1.4},
	"manuballista": {"name": "Manuballista a rotaia", "slot": "arma", "type": "arco", "dmg": [11.0, 17.0], "aps": 0.95},
	"lituo": {"name": "Lituo augurale", "slot": "arma", "type": "scettro", "dmg": [6.0, 11.0], "aps": 1.25},
	"bastone_giove": {"name": "Bastone di Giove", "slot": "arma", "type": "scettro", "dmg": [10.0, 16.0], "aps": 0.95},
	# --- Mano secondaria ---
	"scutum": {"name": "Scutum a campo di forza", "slot": "secondaria", "type": "scudo", "armor": 12.0},
	"parma": {"name": "Parma rotonda", "slot": "secondaria", "type": "scudo", "armor": 8.0},
	"pugio": {"name": "Pugio", "slot": "secondaria", "type": "pugnale", "dmg": [3.0, 5.0]},
	"faretra": {"name": "Faretra energetica", "slot": "secondaria", "type": "faretra", "armor": 3.0},
	"sfera_oracolo": {"name": "Sfera oracolare", "slot": "secondaria", "type": "focus", "armor": 3.0},
	# --- Armature ---
	"galea": {"name": "Galea", "slot": "elmo", "armor": 6.0},
	"elmo_centurione": {"name": "Elmo da centurione", "slot": "elmo", "armor": 8.0},
	"cappuccio": {"name": "Cappuccio augurale", "slot": "elmo", "armor": 4.0},
	"lorica": {"name": "Lorica segmentata", "slot": "armatura", "armor": 14.0},
	"lorica_hamata": {"name": "Lorica hamata", "slot": "armatura", "armor": 11.0},
	"toga": {"name": "Toga rinforzata", "slot": "armatura", "armor": 7.0},
	"manicae": {"name": "Manicae", "slot": "guanti", "armor": 4.0},
	"guanti_cuoio": {"name": "Guanti di cuoio sintetico", "slot": "guanti", "armor": 3.0},
	"ocreae": {"name": "Ocreae", "slot": "gambali", "armor": 6.0},
	"bracae": {"name": "Bracae", "slot": "gambali", "armor": 4.0},
	"caligae": {"name": "Caligae", "slot": "calzari", "armor": 4.0},
	"calcei": {"name": "Calcei", "slot": "calzari", "armor": 3.0},
	# --- Gioielli ---
	"bulla": {"name": "Bulla", "slot": "amuleto"},
	"torque": {"name": "Torque", "slot": "amuleto"},
	"anello_sigillo": {"name": "Anello con sigillo", "slot": "anello"},
	"anello_ferro": {"name": "Anello di ferro", "slot": "anello"},
}

## Affissi: testo, intervallo di valori (a livello oggetto 1), se crescono col livello, slot ammessi ([] = tutti).
const AFFIXES := {
	"forza": {"text": "+%d Forza", "min": 3.0, "max": 8.0, "scale": true, "slots": []},
	"destrezza": {"text": "+%d Destrezza", "min": 3.0, "max": 8.0, "scale": true, "slots": []},
	"intelligenza": {"text": "+%d Intelligenza", "min": 3.0, "max": 8.0, "scale": true, "slots": []},
	"vitalita": {"text": "+%d Vitalità", "min": 3.0, "max": 8.0, "scale": true, "slots": []},
	"crit_chance": {"text": "+%.1f%% Probabilità di critico", "min": 0.5, "max": 3.0, "scale": false, "slots": ["guanti", "amuleto", "anello", "elmo"]},
	"crit_damage": {"text": "+%d%% Danno critico", "min": 6.0, "max": 18.0, "scale": false, "slots": ["guanti", "amuleto", "anello", "arma"]},
	"attack_speed_pct": {"text": "+%d%% Velocità d'attacco", "min": 3.0, "max": 7.0, "scale": false, "slots": ["guanti", "amuleto", "anello", "arma"]},
	"armor": {"text": "+%d Armatura", "min": 4.0, "max": 12.0, "scale": true, "slots": []},
	"life": {"text": "+%d Vita", "min": 10.0, "max": 30.0, "scale": true, "slots": []},
	"life_regen": {"text": "+%.1f Vita al secondo", "min": 0.5, "max": 2.0, "scale": true, "slots": []},
	"move_speed_pct": {"text": "+%d%% Velocità di movimento", "min": 4.0, "max": 10.0, "scale": false, "slots": ["calzari"]},
	"gold_find": {"text": "+%d%% Sesterzi trovati", "min": 10.0, "max": 25.0, "scale": false, "slots": []},
	"life_on_hit": {"text": "+%d Vita per colpo", "min": 1.0, "max": 4.0, "scale": true, "slots": ["arma", "amuleto", "anello", "guanti"]},
	"damage_pct": {"text": "+%d%% Danni", "min": 3.0, "max": 8.0, "scale": false, "slots": ["arma", "amuleto", "anello", "secondaria"]},
	"cdr_pct": {"text": "-%d%% Tempo di ricarica", "min": 3.0, "max": 6.0, "scale": false, "slots": ["elmo", "amuleto", "anello", "secondaria"]},
}

const SUFFIXES := {
	"forza": "del Toro", "destrezza": "della Volpe", "intelligenza": "della Sibilla", "vitalita": "dell'Orso",
	"crit_chance": "dell'Aquila", "crit_damage": "del Leone", "attack_speed_pct": "di Mercurio", "armor": "della Legione",
	"life": "di Esculapio", "life_regen": "della Fonte", "move_speed_pct": "del Vento", "gold_find": "del Mercante",
	"life_on_hit": "del Lupo", "damage_pct": "di Marte", "cdr_pct": "di Crono",
}
const RARE_A := ["Furia", "Ombra", "Gloria", "Aquila", "Tempesta", "Vendetta", "Onore", "Fato", "Eco", "Sangue", "Ruggito", "Stella", "Rovina", "Vigilia"]
const RARE_B := ["di Marte", "di Giove", "dell'Impero", "del Senato", "di Cartagine", "di Nova Roma", "della Legione", "di Saturno", "dei Cesari", "dell'Esilio", "di Ostia", "del Tevere"]

## Leggendari: statistiche fisse + 2 affissi casuali + un POTERE (vedi POWERS) che cambia il modo di giocare.
const LEGENDARIES := [
	{"base": "gladio_plasma", "name": "Gladio di Spartaco", "affixes": [["damage_pct", 25.0], ["attack_speed_pct", 10.0], ["life_on_hit", 6.0]], "flavor": "Non fu forgiato per un padrone.", "power": "spartaco"},
	{"base": "scure", "name": "Scure di Commodo", "affixes": [["forza", 25.0], ["crit_damage", 45.0], ["damage_pct", 12.0]], "flavor": "L'imperatore che si credeva Ercole.", "power": "commodo"},
	{"base": "arco_plasma", "name": "Arco di Diana Stellare", "affixes": [["destrezza", 25.0], ["crit_chance", 6.0], ["crit_damage", 40.0]], "flavor": "Dicono che non manchi mai la luna.", "power": "diana"},
	{"base": "lituo", "name": "Lituo di Romolo", "affixes": [["intelligenza", 25.0], ["cdr_pct", 12.0], ["damage_pct", 15.0]], "flavor": "Con questo bastone fu tracciato il primo solco.", "power": "romolo"},
	{"base": "scutum", "name": "Scutum dell'Ultima Legione", "affixes": [["armor", 40.0], ["vitalita", 20.0], ["life_regen", 4.0]], "flavor": "Nessuno è tornato. Lo scudo sì.", "power": "ultima_legione"},
	{"base": "galea", "name": "Elmo di Scipione", "affixes": [["forza", 20.0], ["crit_chance", 5.0], ["armor", 20.0]], "flavor": "L'Africa era solo l'inizio.", "power": "scipione"},
	{"base": "anello_sigillo", "name": "Anello di Cesare", "affixes": [["damage_pct", 18.0], ["crit_damage", 35.0], ["gold_find", 50.0]], "flavor": "Il dado è tratto.", "power": "cesare"},
	{"base": "caligae", "name": "Calzari di Mercurio", "affixes": [["move_speed_pct", 20.0], ["destrezza", 15.0], ["attack_speed_pct", 8.0]], "flavor": "Ali ai piedi, fretta nel cuore.", "power": "mercurio"},
	{"base": "toga", "name": "Toga del Pontefice", "affixes": [["intelligenza", 22.0], ["life", 60.0], ["cdr_pct", 8.0]], "flavor": "Tra gli dèi e gli uomini, un ponte.", "power": "pontefice"},
	{"base": "manicae", "name": "Manicae di Ercole", "affixes": [["forza", 20.0], ["attack_speed_pct", 8.0], ["crit_chance", 4.0]], "flavor": "Dodici fatiche, nemmeno un graffio.", "power": "ercole"},
	{"base": "bulla", "name": "Bulla di Vesta", "affixes": [["vitalita", 20.0], ["life_regen", 3.0], ["life", 50.0]], "flavor": "Il fuoco sacro non si spegne mai.", "power": "vesta"},
	{"base": "ocreae", "name": "Ocreae di Achille", "affixes": [["armor", 30.0], ["vitalita", 18.0], ["life", 40.0]], "flavor": "Proteggono tutto. Quasi tutto.", "power": "achille"},
]

## Poteri dei leggendari: il testo è mostrato nel tooltip; l'effetto è implementato dove indicato.
##   player.gd (uccisioni, danni subiti, abilità, pozione), abilities.gd (colpi), projectile.gd,
##   loot_drop.gd (sesterzi), health_globe.gd (globi)
const POWERS := {
	"spartaco": "Ogni nemico ucciso ti cura del 3% della vita e aumenta i danni del 5% per 5 s (fino a 5 volte).",
	"commodo": "I colpi critici provocano un'esplosione che infligge il 60% del danno dell'arma ai nemici vicini.",
	"diana": "I tuoi proiettili trapassano tutti i nemici.",
	"romolo": "Ogni nemico ucciso riduce di 1 secondo il tempo di ricarica delle abilità.",
	"ultima_legione": "Quando la vita scende sotto il 30% ottieni uno scudo pari al 30% della vita massima (una volta ogni 60 s).",
	"scipione": "+50% danni contro Campioni e boss.",
	"cesare": "Raccogliere sesterzi ti cura del 2% della vita massima.",
	"mercurio": "Dopo un'abilità di movimento ottieni +30% velocità d'attacco per 4 s.",
	"pontefice": "Le abilità hanno il 25% di probabilità di non consumare risorsa.",
	"ercole": "L'attacco principale ha il 15% di probabilità di generare un'onda d'urto che infligge il 150% del danno dell'arma.",
	"vesta": "I globi di vita curano il doppio e ripristinano il 20% della risorsa.",
	"achille": "La pozione si ricarica in metà tempo e ti rende invulnerabile per 2 s.",
}

## Materiali del fabbro (si ottengono smontando gli oggetti).
const MATERIALS := {
	"rottami": {"name": "Rottami di bronzo", "color": Color(0.85, 0.6, 0.35)},
	"essenza": {"name": "Essenza arcana", "color": Color(0.45, 0.62, 1.0)},
	"frammento": {"name": "Frammento divino", "color": Color(1.0, 0.55, 0.1)},
}
## Valore di vendita di base per rarità (cresce col livello dell'oggetto). Il mercante vende a ×BUY_MULT.
const SELL_VALUE := [5, 15, 40, 120]
const BUY_MULT := 5

## Probabilità di rarità per fonte: [comune, magico, raro, leggendario]
const RARITY_TABLE := {
	"normal": [0.70, 0.25, 0.045, 0.005],
	"elite": [0.25, 0.47, 0.23, 0.05],
	"unique": [0.0, 0.15, 0.6, 0.25],
	"chest": [0.35, 0.45, 0.17, 0.03],
	"chest_rich": [0.0, 0.45, 0.45, 0.10],
}


static func affix_text(a: Dictionary, signed: bool = false) -> String:
	var info: Dictionary = AFFIXES.get(a["stat"], {"text": a["stat"] + " %d"})
	var v := float(a["value"])
	var txt: String = info["text"]
	if signed and v < 0.0:
		txt = txt.replace("+", "-").replace("--", "+")
		v = -v
	return txt % v


static func usable_by(it: Item, class_id: String) -> bool:
	var cls := HeroClasses.get_data(class_id)
	if it.slot == "arma":
		return it.weapon_type in cls["weapons"]
	if it.slot == "secondaria":
		return it.weapon_type in cls["offhands"]
	return true


static func _new_uid() -> String:
	return "%d_%d" % [Time.get_ticks_usec(), randi() % 100000]


## Oggetto comune di una base precisa (equipaggiamento iniziale).
static func make_basic(base_id: String, ilvl: int = 1) -> Item:
	return _build(base_id, ilvl, Item.Rarity.COMUNE, "")


static func _build(base_id: String, ilvl: int, rarity: int, main_stat: String) -> Item:
	var b: Dictionary = BASES[base_id]
	var it := Item.new()
	it.uid = _new_uid()
	it.base_id = base_id
	it.slot = b["slot"]
	it.weapon_type = b.get("type", "")
	it.rarity = rarity
	it.ilvl = ilvl
	var sc := 1.0 + 0.15 * (ilvl - 1)
	if b.has("dmg"):
		it.dmg_min = roundf(float(b["dmg"][0]) * sc * randf_range(0.9, 1.1))
		it.dmg_max = maxf(it.dmg_min + 1.0, roundf(float(b["dmg"][1]) * sc * randf_range(0.9, 1.1)))
		it.attack_speed = float(b.get("aps", 0.0))
	if b.has("armor"):
		it.armor = roundf(float(b["armor"]) * sc * randf_range(0.9, 1.15))
	var n := 0
	match rarity:
		Item.Rarity.MAGICO: n = randi_range(1, 2)
		Item.Rarity.RARO: n = randi_range(3, 4)
	it.affixes = _roll_affixes(it.slot, n, ilvl, main_stat)
	match rarity:
		Item.Rarity.MAGICO:
			it.item_name = "%s %s" % [b["name"], SUFFIXES.get(it.affixes[0]["stat"], "")]
		Item.Rarity.RARO:
			it.item_name = "%s %s" % [RARE_A.pick_random(), RARE_B.pick_random()]
		_:
			it.item_name = b["name"]
	return it


static func _roll_affixes(slot: String, n: int, ilvl: int, main_stat: String) -> Array:
	var pool: Array = []
	for k: String in AFFIXES:
		var slots: Array = AFFIXES[k]["slots"]
		if slots.is_empty() or slot in slots:
			pool.append(k)
	pool.shuffle()
	# Loot intelligente: spesso la statistica principale della classe esce per prima
	if main_stat != "" and randf() < 0.6 and main_stat in pool:
		pool.erase(main_stat)
		pool.push_front(main_stat)
	var out: Array = []
	for i in mini(n, pool.size()):
		out.append({"stat": pool[i], "value": _roll_value(pool[i], ilvl)})
	return out


static func _roll_value(stat: String, ilvl: int) -> float:
	var info: Dictionary = AFFIXES[stat]
	var v := randf_range(info["min"], info["max"])
	if info["scale"]:
		v *= 1.0 + 0.2 * (ilvl - 1)
	return snappedf(v, 0.1) if v < 10.0 else roundf(v)


static func _legendary(ilvl: int, class_id: String, smart: bool) -> Item:
	var options: Array = []
	for l: Dictionary in LEGENDARIES:
		var b: Dictionary = BASES[l["base"]]
		var probe := Item.new()
		probe.slot = b["slot"]
		probe.weapon_type = b.get("type", "")
		if not smart or usable_by(probe, class_id):
			options.append(l)
	if options.is_empty():
		options = LEGENDARIES.duplicate()
	var l: Dictionary = options.pick_random()
	var it := _build(l["base"], ilvl, Item.Rarity.LEGGENDARIO, "")
	it.item_name = l["name"]
	it.flavor = l["flavor"]
	it.power = String(l.get("power", ""))
	var sc := 1.0 + 0.1 * (ilvl - 1)
	for pair: Array in l["affixes"]:
		var stat: String = pair[0]
		var v := float(pair[1])
		if AFFIXES[stat]["scale"]:
			v *= sc
		it.affixes.append({"stat": stat, "value": roundf(v)})
	var main := String(HeroClasses.get_data(class_id)["main_stat"])
	it.affixes.append_array(_roll_affixes(it.slot, 2, ilvl, main))
	return it


## Genera un oggetto casuale. smart = favorisce oggetti utilizzabili dalla classe.
static func generate(ilvl: int, rarity: int, class_id: String, smart: bool = true) -> Item:
	if rarity == Item.Rarity.LEGGENDARIO:
		return _legendary(ilvl, class_id, smart and randf() < 0.8)
	var candidates: Array = []
	var use_smart := smart and randf() < 0.7
	for k: String in BASES:
		var b: Dictionary = BASES[k]
		var probe := Item.new()
		probe.slot = b["slot"]
		probe.weapon_type = b.get("type", "")
		if not use_smart or usable_by(probe, class_id):
			candidates.append(k)
	var main := String(HeroClasses.get_data(class_id)["main_stat"])
	return _build(candidates.pick_random(), ilvl, rarity, main)


static func roll_rarity(source: String) -> int:
	var table: Array = RARITY_TABLE.get(source, RARITY_TABLE["normal"])
	var r := randf()
	var acc := 0.0
	for i in table.size():
		acc += float(table[i])
		if r <= acc:
			return i
	return 0


## Oggetti lasciati da una fonte: "normal", "elite", "unique", "chest", "chest_rich".
static func roll_drops(source: String, ilvl: int, class_id: String) -> Array:
	var count := 0
	match source:
		"normal": count = 1 if randf() < 0.12 else 0
		"elite": count = randi_range(1, 2)
		"unique": count = 3
		"chest": count = randi_range(1, 2)
		"chest_rich": count = randi_range(2, 3)
	var out: Array = []
	for i in count:
		var r := roll_rarity(source)
		if source == "unique" and i == 0:
			r = maxi(r, Item.Rarity.RARO)
		out.append(generate(ilvl, r, class_id))
	return out


static func roll_gold(source: String, ilvl: int, gold_find: float) -> int:
	var chance := {"normal": 0.35, "elite": 1.0, "unique": 1.0, "chest": 1.0, "chest_rich": 1.0}.get(source, 0.3) as float
	if randf() > chance:
		return 0
	var mult := {"normal": 1.0, "elite": 4.0, "unique": 15.0, "chest": 3.0, "chest_rich": 6.0}.get(source, 1.0) as float
	return int(randi_range(3, 9) * ilvl * mult * (1.0 + gold_find / 100.0))


## Prezzo di vendita al mercante.
static func sell_value(it: Item) -> int:
	return int(SELL_VALUE[clampi(it.rarity, 0, 3)] * (1.0 + 0.25 * (it.ilvl - 1)))


static func buy_price(it: Item) -> int:
	return sell_value(it) * BUY_MULT


## Materiali ottenuti smontando un oggetto dal fabbro: {materiale: quantità}.
static func salvage_yield(it: Item) -> Dictionary:
	match it.rarity:
		Item.Rarity.COMUNE: return {"rottami": randi_range(2, 3)}
		Item.Rarity.MAGICO: return {"rottami": randi_range(1, 2), "essenza": 1}
		Item.Rarity.RARO: return {"essenza": randi_range(2, 3), "rottami": 1}
		Item.Rarity.LEGGENDARIO: return {"frammento": 1, "essenza": 3}
	return {}


## Ricette del fabbro: costo in sesterzi (per livello dell'eroe) e materiali.
const RECIPES := {
	"magico": {"name": "Forgia un oggetto magico", "gold_per_level": 25, "mats": {"rottami": 4}, "rarity": Item.Rarity.MAGICO},
	"raro": {"name": "Forgia un oggetto raro", "gold_per_level": 80, "mats": {"rottami": 8, "essenza": 4}, "rarity": Item.Rarity.RARO},
	"leggendario": {"name": "Invoca un leggendario", "gold_per_level": 300, "mats": {"frammento": 2, "essenza": 10}, "rarity": Item.Rarity.LEGGENDARIO},
}


## Oggetto forgiato dal fabbro: rarità della ricetta, slot scelto (i leggendari ignorano lo slot).
static func craft(recipe_id: String, slot: String, ilvl: int, class_id: String) -> Item:
	var rarity: int = RECIPES[recipe_id]["rarity"]
	if rarity == Item.Rarity.LEGGENDARIO:
		return _legendary(ilvl, class_id, true)
	var candidates: Array = []
	for k: String in BASES:
		var b: Dictionary = BASES[k]
		if b["slot"] != slot:
			continue
		var probe := Item.new()
		probe.slot = b["slot"]
		probe.weapon_type = b.get("type", "")
		if usable_by(probe, class_id):
			candidates.append(k)
	if candidates.is_empty():
		return null
	var main := String(HeroClasses.get_data(class_id)["main_stat"])
	return _build(candidates.pick_random(), ilvl, rarity, main)


## Potere di un leggendario dal nome (per i salvataggi fatti prima che esistessero i poteri).
static func power_for_name(item_name: String) -> String:
	for l: Dictionary in LEGENDARIES:
		if l["name"] == item_name:
			return String(l.get("power", ""))
	return ""
