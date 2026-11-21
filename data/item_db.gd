class_name ItemDB
extends RefCounted
## Database oggetti: basi, affissi, leggendari e generazione casuale del loot (stile Diablo).
## Rarità: Comune (bianco, 0 affissi), Magico (blu, 1-2), Raro (giallo, 3-4), Leggendario (arancione, fissi + 2),
## Set (verde, fissi + 2, bonus indossando più pezzi). Gemme e orbite: vedi GEMS.

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
	# --- Spallacci, cinture, bracciali ---
	"humeralia": {"name": "Humeralia", "slot": "spalle", "armor": 5.0},
	"spallacci_bronzo": {"name": "Spallacci di bronzo", "slot": "spalle", "armor": 6.0},
	"cingulum": {"name": "Cingulum militare", "slot": "cintura", "armor": 3.0},
	"balteo": {"name": "Balteo", "slot": "cintura", "armor": 2.0},
	"armillae": {"name": "Armillae", "slot": "bracciali", "armor": 3.0},
	"bracciali_cuoio": {"name": "Bracciali di cuoio", "slot": "bracciali", "armor": 2.0},
}

## Tipi di danno. Ogni abilità ne ha uno (SkillDB.ELEMENTS); gli affissi "<tipo>_pct" lo aumentano.
## Il freddo rallenta un po' i nemici colpiti.
const ELEMENTS := {
	"fisico": {"name": "fisico", "color": Color(1.0, 0.95, 0.85)},
	"fuoco": {"name": "da fuoco", "color": Color(1.0, 0.55, 0.15)},
	"freddo": {"name": "da freddo", "color": Color(0.55, 0.85, 1.0)},
	"fulmine": {"name": "da fulmine", "color": Color(0.85, 0.75, 1.0)},
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
	"cdr_pct": {"text": "-%d%% Tempo di ricarica", "min": 3.0, "max": 6.0, "scale": false, "slots": ["elmo", "amuleto", "anello", "secondaria", "spalle"]},
	"fisico_pct": {"text": "+%d%% Danni fisici", "min": 4.0, "max": 10.0, "scale": false, "slots": ["amuleto", "bracciali", "secondaria"]},
	"fuoco_pct": {"text": "+%d%% Danni da fuoco", "min": 4.0, "max": 10.0, "scale": false, "slots": ["amuleto", "bracciali", "secondaria"]},
	"freddo_pct": {"text": "+%d%% Danni da freddo", "min": 4.0, "max": 10.0, "scale": false, "slots": ["amuleto", "bracciali", "secondaria"]},
	"fulmine_pct": {"text": "+%d%% Danni da fulmine", "min": 4.0, "max": 10.0, "scale": false, "slots": ["amuleto", "bracciali", "secondaria"]},
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
	# --- Leggendari che cambiano un'abilità (SkillDB.POWER_MODS) ---
	{"base": "spatha", "name": "Spatha di Gaio Mario", "affixes": [["forza", 22.0], ["damage_pct", 15.0], ["crit_chance", 4.0]], "flavor": "Riformò le legioni. Poi le legioni riformarono Roma.", "power": "mario"},
	{"base": "parma", "name": "Parma di Orazio Coclite", "affixes": [["armor", 35.0], ["vitalita", 18.0], ["cdr_pct", 8.0]], "flavor": "Un uomo, un ponte, un esercito dall'altra parte.", "power": "orazio"},
	{"base": "elmo_centurione", "name": "Elmo di Germanico", "affixes": [["forza", 20.0], ["crit_chance", 4.0], ["life", 45.0]], "flavor": "Rendetemi le mie aquile.", "power": "germanico"},
	{"base": "scure", "name": "Scure di Flamma il Siriano", "affixes": [["forza", 22.0], ["attack_speed_pct", 8.0], ["life_on_hit", 6.0]], "flavor": "Rifiutò la libertà quattro volte.", "power": "flamma"},
	{"base": "pugio", "name": "Pugio di Prisco", "affixes": [["forza", 18.0], ["crit_damage", 30.0], ["damage_pct", 10.0]], "flavor": "Il duello finì pari. L'imperatore li liberò entrambi.", "power": "prisco"},
	{"base": "calcei", "name": "Calcei di Vero", "affixes": [["forza", 16.0], ["move_speed_pct", 12.0], ["vitalita", 14.0]], "flavor": "L'altro campione di quel giorno.", "power": "vero"},
	{"base": "faretra", "name": "Faretra di Teucro", "affixes": [["destrezza", 20.0], ["attack_speed_pct", 8.0], ["crit_chance", 4.0]], "flavor": "Dietro lo scudo del fratello, mai una freccia sprecata.", "power": "teucro"},
	{"base": "manuballista", "name": "Manuballista di Archimede", "affixes": [["destrezza", 24.0], ["crit_damage", 40.0], ["damage_pct", 12.0]], "flavor": "Datemi un punto d'appoggio.", "power": "archimede"},
	{"base": "cappuccio", "name": "Cappuccio del Cacciatore Numida", "affixes": [["destrezza", 20.0], ["crit_chance", 4.0], ["cdr_pct", 6.0]], "flavor": "Nel deserto la pioggia è un dono degli dèi.", "power": "cacciatore"},
	{"base": "sfera_oracolo", "name": "Sfera della Sibilla Cumana", "affixes": [["intelligenza", 22.0], ["cdr_pct", 8.0], ["crit_chance", 4.0]], "flavor": "Nove libri. Ne restano tre.", "power": "sibilla"},
	{"base": "bastone_giove", "name": "Bastone di Vulcano", "affixes": [["intelligenza", 24.0], ["damage_pct", 15.0], ["crit_damage", 35.0]], "flavor": "Forgiato sotto l'Etna, ancora caldo.", "power": "vulcano"},
	{"base": "caligae", "name": "Caligae di Numa", "affixes": [["intelligenza", 18.0], ["move_speed_pct", 12.0], ["life", 40.0]], "flavor": "Il re che parlava con la ninfa.", "power": "numa"},
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
	"mario": "Pilum lancia tre pila a ventaglio.",
	"orazio": "Testuggine dura 4 s in più e la sua onda d'urto stordisce per 1,5 s.",
	"germanico": "Fulmine di Giove colpisce una seconda volta.",
	"flamma": "Turbine ha 2 m di raggio in più e incendia i nemici.",
	"prisco": "Rete del reziario stordisce per 2 s e ha 1,5 m di raggio in più.",
	"vero": "Balzo si ricarica in metà tempo e infligge il doppio dei danni.",
	"teucro": "Ventaglio di dardi lancia 4 dardi in più.",
	"archimede": "Freccia esplosiva: +2,5 m di raggio e +50% danni.",
	"cacciatore": "Pioggia di frecce dura il doppio.",
	"sibilla": "Fulmine di Giove rimbalza su 4 nemici in più.",
	"vulcano": "Sfera di Vulcano costa 10 in meno e incendia i nemici colpiti.",
	"numa": "Meteora cade due volte.",
}

# ==================================================================================================
#  GEMME (come in Diablo 3): si incastonano negli oggetti con orbite. L'effetto dipende da dove
#  si incastona: arma, elmo o altro (armatura, gambali, gioielli...). Valori di grado 1 × GEM_TIER_MULT.
#  Si raccolgono passandoci sopra e finiscono nel sacchetto delle gemme (hero.gems), non nello zaino.
# ==================================================================================================
const GEMS := {
	"rubino": {"name": "Rubino", "color": Color(0.95, 0.15, 0.2),
		"arma": ["damage_pct", 4.0], "elmo": ["life", 25.0], "altro": ["forza", 6.0]},
	"smeraldo": {"name": "Smeraldo", "color": Color(0.2, 0.9, 0.35),
		"arma": ["crit_damage", 10.0], "elmo": ["gold_find", 10.0], "altro": ["destrezza", 6.0]},
	"topazio": {"name": "Topazio", "color": Color(1.0, 0.8, 0.15),
		"arma": ["attack_speed_pct", 2.0], "elmo": ["life_regen", 1.0], "altro": ["intelligenza", 6.0]},
	"ametista": {"name": "Ametista", "color": Color(0.7, 0.3, 1.0),
		"arma": ["life_on_hit", 3.0], "elmo": ["life", 25.0], "altro": ["vitalita", 6.0]},
	"diamante": {"name": "Diamante", "color": Color(0.85, 0.95, 1.0),
		"arma": ["crit_chance", 0.8], "elmo": ["cdr_pct", 2.0], "altro": ["armor", 12.0]},
}
const GEM_TIERS := ["scheggiato", "grezzo", "levigato", "imperiale", "divino"]
const GEM_TIER_MULT := [1.0, 2.0, 3.5, 5.5, 8.0]
## Orbite massime per tipo di oggetto (gli altri tipi non ne hanno).
const MAX_SOCKETS := {"arma": 1, "elmo": 1, "armatura": 3, "gambali": 2, "amuleto": 1, "anello": 1, "bracciali": 1}
## Probabilità che un oggetto abbia orbite, per rarità [comune, magico, raro, leggendario, set].
const SOCKET_CHANCE := [0.08, 0.18, 0.3, 0.5, 0.35]
## Gioielliere (pannello del fabbro): costo per combinare 3 gemme in una di grado superiore
## e per togliere una gemma da un oggetto (sesterzi × grado della gemma).
const GEM_COMBINE_COST := 3
const GEM_COMBINE_GOLD := 60
const GEM_REMOVE_GOLD := 40


## Chiave di una gemma: "rubino:2" (tipo:grado, grado 1-5).
static func gem_key(type: String, tier: int) -> String:
	return "%s:%d" % [type, tier]


static func gem_type(key: String) -> String:
	return key.get_slice(":", 0)


static func gem_tier(key: String) -> int:
	return clampi(int(key.get_slice(":", 1)), 1, GEM_TIERS.size())


static func gem_name(key: String) -> String:
	if is_legendary_gem(key):
		return "%s (grado %d)" % [LEGENDARY_GEMS.get(leg_gem_id(key), {"name": key})["name"], leg_gem_rank(key)]
	var g: Dictionary = GEMS.get(gem_type(key), {"name": key})
	return "%s %s" % [g["name"], GEM_TIERS[gem_tier(key) - 1]]


static func gem_color(key: String) -> Color:
	if is_legendary_gem(key):
		return Color(1.0, 0.55, 0.1)
	return (GEMS.get(gem_type(key), {"color": Color.WHITE}) as Dictionary)["color"]


static func gem_category(slot: String) -> String:
	return slot if slot == "arma" or slot == "elmo" else "altro"


## Statistica data da una gemma incastonata in un oggetto di quello slot: {"stat", "value"}.
static func gem_affix(key: String, slot: String) -> Dictionary:
	if is_legendary_gem(key):
		var lg: Dictionary = LEGENDARY_GEMS.get(leg_gem_id(key), {})
		if not lg.has("stat"):
			return {}
		var r := leg_gem_rank(key)
		return {"stat": lg["stat"], "value": minf(float(lg["base"]) + float(lg["per_rank"]) * r, float(lg.get("max", 1e9)))}
	var g: Dictionary = GEMS.get(gem_type(key), {})
	if g.is_empty():
		return {}
	var pair: Array = g[gem_category(slot)]
	var v := float(pair[1]) * float(GEM_TIER_MULT[gem_tier(key) - 1])
	return {"stat": pair[0], "value": snappedf(v, 0.1) if v < 10.0 else roundf(v)}


## Gemma casuale adatta al livello: gradi più alti più avanti nel gioco.
static func roll_gem(ilvl: int) -> String:
	var top := clampi(1 + ilvl / 12, 1, GEM_TIERS.size())
	var tier := top if randf() < 0.6 else maxi(1, top - 1)
	return gem_key(GEMS.keys().pick_random(), tier)


## Probabilità che un nemico o un forziere lasci una gemma.
const GEM_DROP_CHANCE := {"normal": 0.025, "elite": 0.25, "rare": 0.4, "unique": 1.0, "chest": 0.15, "chest_rich": 0.4, "rift": 1.0}


static func roll_gem_drop(source: String, ilvl: int) -> String:
	return roll_gem(ilvl) if randf() < float(GEM_DROP_CHANCE.get(source, 0.0)) else ""


# --------------------------------------------------------------------------------------------------
#  GEMME LEGGENDARIE: si trovano sconfiggendo i Guardiani dei Labirinti di Dedalo, vanno solo nei
#  gioielli (amuleto, anelli) e si potenziano completando i labirinti (più il grado è alto rispetto
#  al grado della gemma, più è probabile). Chiave: "leg:<id>:<grado>". Gli effetti con "stat" sono
#  statistiche; gli altri sono in player.gd (legendary_gem_rank).
# --------------------------------------------------------------------------------------------------
const LEGENDARY_GEMS := {
	"cuore_marte": {"name": "Cuore di Marte", "stat": "damage_pct", "base": 10.0, "per_rank": 1.0, "desc": "+%d%% danni"},
	"occhio_giano": {"name": "Occhio di Giano", "stat": "crit_damage", "base": 20.0, "per_rank": 2.0, "desc": "+%d%% danno critico"},
	"pietra_vesta": {"name": "Pietra di Vesta", "stat": "dr_pct", "base": 10.0, "per_rank": 0.3, "max": 25.0, "desc": "Subisci il %d%% di danni in meno"},
	"lacrima_niobe": {"name": "Lacrima di Niobe", "desc": "Ti cura dell'%.1f%% dei danni inflitti", "base": 1.0, "per_rank": 0.1},
	"scintilla_vulcano": {"name": "Scintilla di Vulcano", "desc": "I colpi hanno il 15%% di probabilità di incendiare: %d%% del danno dell'arma al secondo per 3 s", "base": 100.0, "per_rank": 10.0},
	"dente_cerbero": {"name": "Dente di Cerbero", "desc": "+%d%% danni a Campioni, capi rari e boss", "base": 20.0, "per_rank": 1.0},
}
const LEG_GEM_MAX := 50
const LEG_GEM_SLOTS := ["amuleto", "anello"]
## Potenziamenti per labirinto completato in tempo.
const LEG_GEM_UPGRADES := 3


static func is_legendary_gem(key: String) -> bool:
	return key.begins_with("leg:")


static func leg_gem_key(id: String, rank: int) -> String:
	return "leg:%s:%d" % [id, rank]


static func leg_gem_id(key: String) -> String:
	return key.get_slice(":", 1)


static func leg_gem_rank(key: String) -> int:
	return int(key.get_slice(":", 2))


static func leg_gem_text(key: String) -> String:
	var lg: Dictionary = LEGENDARY_GEMS.get(leg_gem_id(key), {})
	if lg.is_empty():
		return key
	var v := minf(float(lg["base"]) + float(lg["per_rank"]) * leg_gem_rank(key), float(lg.get("max", 1e9)))
	return String(lg["desc"]) % v


## Probabilità di potenziare una gemma di grado `rank` completando un labirinto di grado `grade`.
static func leg_gem_upgrade_chance(rank: int, grade: int) -> float:
	if rank >= LEG_GEM_MAX:
		return 0.0
	var diff := grade - rank
	if diff >= 10:
		return 1.0
	if diff >= 0:
		return 0.6 + 0.04 * diff
	return clampf(0.6 + 0.1 * diff, 0.05, 0.6)


static func _roll_sockets(it: Item) -> void:
	var mx: int = MAX_SOCKETS.get(it.slot, 0)
	if mx == 0 or randf() > float(SOCKET_CHANCE[clampi(it.rarity, 0, SOCKET_CHANCE.size() - 1)]):
		return
	it.gems.resize(randi_range(1, mx))
	it.gems.fill("")


# ==================================================================================================
#  SET (verdi): pezzi con statistiche fisse + 2 affissi casuali. Indossando più pezzi dello stesso
#  set si attivano i bonus (2, 3, 4 pezzi). "skills" = +% danni di quelle abilità (id in hero_classes).
#  I valori dei bonus crescono col livello dell'eroe come gli affissi ("scale" in AFFIXES).
# ==================================================================================================
const SETS := {
	"primo_pilo": {"name": "Panoplia del Primo Pilo", "class": "legionario",
		"pieces": [
			{"base": "elmo_centurione", "name": "Elmo del Primo Pilo", "affixes": [["forza", 14.0], ["armor", 15.0]]},
			{"base": "lorica", "name": "Lorica del Primo Pilo", "affixes": [["forza", 14.0], ["vitalita", 12.0]]},
			{"base": "manicae", "name": "Manicae del Primo Pilo", "affixes": [["forza", 12.0], ["crit_chance", 3.0]]},
			{"base": "ocreae", "name": "Ocreae del Primo Pilo", "affixes": [["vitalita", 12.0], ["life", 40.0]]},
		],
		"bonus": {
			2: {"stats": [["armor", 60.0], ["vitalita", 20.0]]},
			3: {"stats": [["life_regen", 5.0], ["cdr_pct", 10.0]]},
			4: {"skills": {"pilum": 200.0, "bombardamento": 200.0, "colpo_gladio": 100.0},
				"text": "+200% danni di Pilum e Fulmine di Giove, +100% danni di Colpo di gladio."},
		}},
	"reziario": {"name": "Paramenti del Reziario", "class": "gladiatore",
		"pieces": [
			{"base": "galea", "name": "Galea del Reziario", "affixes": [["forza", 14.0], ["crit_damage", 20.0]]},
			{"base": "lorica_hamata", "name": "Maglia del Reziario", "affixes": [["forza", 14.0], ["life", 40.0]]},
			{"base": "guanti_cuoio", "name": "Fasce del Reziario", "affixes": [["attack_speed_pct", 6.0], ["crit_chance", 3.0]]},
			{"base": "calcei", "name": "Calcei del Reziario", "affixes": [["forza", 12.0], ["move_speed_pct", 8.0]]},
		],
		"bonus": {
			2: {"stats": [["attack_speed_pct", 8.0], ["life_on_hit", 6.0]]},
			3: {"stats": [["crit_damage", 40.0], ["vitalita", 20.0]]},
			4: {"skills": {"turbine": 200.0, "doppio_fendente": 150.0, "rete": 150.0},
				"text": "+200% danni di Turbine, +150% danni di Doppio fendente e Rete del reziario."},
		}},
	"saettatori_creta": {"name": "Insegne dei Saettatori di Creta", "class": "sagittario",
		"pieces": [
			{"base": "cappuccio", "name": "Cappuccio del Saettatore", "affixes": [["destrezza", 14.0], ["crit_chance", 3.0]]},
			{"base": "lorica_hamata", "name": "Corsaletto del Saettatore", "affixes": [["destrezza", 14.0], ["vitalita", 12.0]]},
			{"base": "guanti_cuoio", "name": "Guanti del Saettatore", "affixes": [["destrezza", 12.0], ["attack_speed_pct", 6.0]]},
			{"base": "caligae", "name": "Caligae del Saettatore", "affixes": [["destrezza", 12.0], ["move_speed_pct", 8.0]]},
		],
		"bonus": {
			2: {"stats": [["crit_chance", 5.0], ["destrezza", 20.0]]},
			3: {"stats": [["crit_damage", 40.0], ["life_on_hit", 5.0]]},
			4: {"skills": {"ventaglio": 200.0, "pioggia_frecce": 200.0, "dardo": 100.0},
				"text": "+200% danni di Ventaglio di dardi e Pioggia di frecce, +100% danni di Dardo al plasma."},
		}},
	"augure_massimo": {"name": "Paramenti dell'Augure Massimo", "class": "augure",
		"pieces": [
			{"base": "cappuccio", "name": "Cappuccio dell'Augure Massimo", "affixes": [["intelligenza", 14.0], ["cdr_pct", 5.0]]},
			{"base": "toga", "name": "Toga dell'Augure Massimo", "affixes": [["intelligenza", 14.0], ["life", 40.0]]},
			{"base": "manicae", "name": "Manicae dell'Augure Massimo", "affixes": [["intelligenza", 12.0], ["crit_chance", 3.0]]},
			{"base": "bracae", "name": "Bracae dell'Augure Massimo", "affixes": [["vitalita", 12.0], ["intelligenza", 12.0]]},
		],
		"bonus": {
			2: {"stats": [["intelligenza", 20.0], ["life_regen", 4.0]]},
			3: {"stats": [["cdr_pct", 10.0], ["crit_damage", 35.0]]},
			4: {"skills": {"meteora": 200.0, "ira_nettuno": 200.0, "fulmine": 100.0},
				"text": "+200% danni di Meteora e Ira di Nettuno, +100% danni di Fulmine di Giove."},
		}},
	# --- Secondi set di classe ---
	"fulminata": {"name": "Armi della Legio XII Fulminata", "class": "legionario",
		"pieces": [
			{"base": "galea", "name": "Galea della Fulminata", "affixes": [["forza", 14.0], ["life", 40.0]]},
			{"base": "lorica_hamata", "name": "Maglia della Fulminata", "affixes": [["forza", 14.0], ["armor", 20.0]]},
			{"base": "guanti_cuoio", "name": "Guanti della Fulminata", "affixes": [["attack_speed_pct", 6.0], ["crit_chance", 3.0]]},
			{"base": "caligae", "name": "Caligae della Fulminata", "affixes": [["forza", 12.0], ["move_speed_pct", 8.0]]},
		],
		"bonus": {
			2: {"stats": [["armor", 40.0], ["life", 60.0]]},
			3: {"stats": [["damage_pct", 10.0], ["life_on_hit", 5.0]]},
			4: {"skills": {"carica": 300.0, "colpo_scudo": 250.0, "testuggine": 200.0},
				"text": "+300% danni di Carica, +250% di Colpo di scudo, +200% di Testuggine."},
		}},
	"mirmillone": {"name": "Armatura del Mirmillone", "class": "gladiatore",
		"pieces": [
			{"base": "elmo_centurione", "name": "Elmo del Mirmillone", "affixes": [["forza", 14.0], ["vitalita", 12.0]]},
			{"base": "lorica", "name": "Pettorale del Mirmillone", "affixes": [["forza", 14.0], ["armor", 20.0]]},
			{"base": "manicae", "name": "Manica del Mirmillone", "affixes": [["forza", 12.0], ["crit_damage", 20.0]]},
			{"base": "ocreae", "name": "Ocrea del Mirmillone", "affixes": [["vitalita", 12.0], ["life", 40.0]]},
		],
		"bonus": {
			2: {"stats": [["vitalita", 20.0], ["armor", 40.0]]},
			3: {"stats": [["crit_chance", 5.0], ["life_regen", 4.0]]},
			4: {"skills": {"balzo": 300.0, "colpo_arena": 250.0, "terremoto": 250.0},
				"text": "+300% danni di Balzo, +250% di Colpo dell'arena e Terremoto."},
		}},
	"numidi": {"name": "Equipaggiamento dei Cacciatori Numidi", "class": "sagittario",
		"pieces": [
			{"base": "galea", "name": "Elmo del Cacciatore Numida", "affixes": [["destrezza", 14.0], ["crit_damage", 20.0]]},
			{"base": "lorica", "name": "Corazza del Cacciatore Numida", "affixes": [["destrezza", 14.0], ["life", 40.0]]},
			{"base": "manicae", "name": "Bracciali del Cacciatore Numida", "affixes": [["destrezza", 12.0], ["crit_chance", 3.0]]},
			{"base": "bracae", "name": "Bracae del Cacciatore Numida", "affixes": [["vitalita", 12.0], ["destrezza", 12.0]]},
		],
		"bonus": {
			2: {"stats": [["destrezza", 20.0], ["move_speed_pct", 8.0]]},
			3: {"stats": [["attack_speed_pct", 8.0], ["cdr_pct", 8.0]]},
			4: {"skills": {"freccia_esplosiva": 300.0, "trappola": 300.0, "freccia_catena": 250.0},
				"text": "+300% danni di Freccia esplosiva e Trappola a rete, +250% di Freccia a catena."},
		}},
	"vestali": {"name": "Vesti delle Vestali", "class": "augure",
		"pieces": [
			{"base": "galea", "name": "Diadema della Vestale", "affixes": [["intelligenza", 14.0], ["crit_chance", 3.0]]},
			{"base": "toga", "name": "Stola della Vestale", "affixes": [["intelligenza", 14.0], ["vitalita", 12.0]]},
			{"base": "guanti_cuoio", "name": "Guanti della Vestale", "affixes": [["intelligenza", 12.0], ["attack_speed_pct", 6.0]]},
			{"base": "calcei", "name": "Calcei della Vestale", "affixes": [["intelligenza", 12.0], ["move_speed_pct", 8.0]]},
		],
		"bonus": {
			2: {"stats": [["intelligenza", 20.0], ["life", 60.0]]},
			3: {"stats": [["crit_chance", 5.0], ["cdr_pct", 8.0]]},
			4: {"skills": {"sfera_vulcano": 300.0, "saetta": 300.0, "anello_fuoco": 250.0},
				"text": "+300% danni di Sfera di Vulcano e Saetta di Giove, +250% di Anello di fuoco."},
		}},
}
## Quando esce un leggendario, probabilità che sia invece un pezzo di set.
const SET_CHANCE := 0.35


## Pezzo di set: smart = del set della classe dell'eroe (quasi sempre).
static func make_set_piece(ilvl: int, class_id: String, smart: bool = true, set_id: String = "", piece: int = -1) -> Item:
	if set_id == "":
		var ids: Array = []
		for k: String in SETS:
			if not smart or SETS[k]["class"] == class_id:
				ids.append(k)
		if ids.is_empty():
			ids = SETS.keys()
		set_id = ids.pick_random()
	var st: Dictionary = SETS[set_id]
	var pieces: Array = st["pieces"]
	var pd: Dictionary = pieces[piece if piece >= 0 else randi() % pieces.size()]
	var it := _build(pd["base"], ilvl, Item.Rarity.SET, "")
	it.item_name = pd["name"]
	it.set_id = set_id
	var sc := 1.0 + 0.1 * (ilvl - 1)
	for pair: Array in pd["affixes"]:
		var stat: String = pair[0]
		var v := float(pair[1])
		if AFFIXES[stat]["scale"]:
			v *= sc
		it.affixes.append({"stat": stat, "value": snappedf(v, 0.1) if v < 10.0 else roundf(v)})
	var main := String(HeroClasses.get_data(class_id)["main_stat"])
	it.affixes.append_array(_roll_affixes(it.slot, 2, ilvl, main))
	return it


## Pezzi indossati per set: {set_id: quantità}.
static func set_counts(equipment: Dictionary) -> Dictionary:
	var out := {}
	for slot: String in equipment:
		var it: Item = equipment[slot]
		if it != null and it.set_id != "":
			out[it.set_id] = int(out.get(it.set_id, 0)) + 1
	return out


## Bonus attivi dei set indossati: {"stats": [{stat, value}], "skills": {id abilità: %}}.
static func set_bonuses(equipment: Dictionary, hero_level: int) -> Dictionary:
	var stats: Array = []
	var skills := {}
	var sc := 1.0 + 0.1 * (hero_level - 1)
	var counts := set_counts(equipment)
	for sid: String in counts:
		if not SETS.has(sid):
			continue
		var bonus: Dictionary = SETS[sid]["bonus"]
		for n: int in bonus:
			if int(counts[sid]) < n:
				continue
			var b: Dictionary = bonus[n]
			for pair: Array in b.get("stats", []):
				var v := float(pair[1])
				if AFFIXES[pair[0]]["scale"]:
					v = roundf(v * sc)
				stats.append({"stat": pair[0], "value": v})
			var sk: Dictionary = b.get("skills", {})
			for id: String in sk:
				skills[id] = float(skills.get(id, 0.0)) + float(sk[id])
	return {"stats": stats, "skills": skills}


## Testo di un bonus di set (per il tooltip).
static func set_bonus_text(b: Dictionary) -> String:
	if b.has("text"):
		return String(b["text"])
	var parts: Array = []
	for pair: Array in b.get("stats", []):
		parts.append(affix_text({"stat": pair[0], "value": float(pair[1])}))
	return ", ".join(parts)


## Materiali del fabbro (si ottengono smontando gli oggetti).
const MATERIALS := {
	"rottami": {"name": "Rottami di bronzo", "color": Color(0.85, 0.6, 0.35)},
	"essenza": {"name": "Essenza arcana", "color": Color(0.45, 0.62, 1.0)},
	"frammento": {"name": "Frammento divino", "color": Color(1.0, 0.55, 0.1)},
}
## Valore di vendita di base per rarità (cresce col livello dell'oggetto). Il mercante vende a ×BUY_MULT.
const SELL_VALUE := [5, 15, 40, 120, 150]
const BUY_MULT := 5

## Probabilità di rarità per fonte: [comune, magico, raro, leggendario]
const RARITY_TABLE := {
	"normal": [0.70, 0.25, 0.045, 0.005],
	"elite": [0.25, 0.47, 0.23, 0.05],
	"rare": [0.05, 0.4, 0.43, 0.12],
	"unique": [0.0, 0.15, 0.6, 0.25],
	"chest": [0.35, 0.45, 0.17, 0.03],
	"chest_rich": [0.0, 0.45, 0.45, 0.10],
	"rift": [0.0, 0.2, 0.55, 0.25],
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
	_roll_sockets(it)
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
	if rarity == Item.Rarity.SET:
		return make_set_piece(ilvl, class_id, smart and randf() < 0.85)
	if rarity == Item.Rarity.LEGGENDARIO:
		if randf() < SET_CHANCE:
			return make_set_piece(ilvl, class_id, smart and randf() < 0.85)
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


## leg_mult: moltiplica la probabilità di leggendari (difficoltà, labirinti); il resto si riduce dai comuni.
static func roll_rarity(source: String, leg_mult: float = 1.0) -> int:
	var table: Array = (RARITY_TABLE.get(source, RARITY_TABLE["normal"]) as Array).duplicate()
	if leg_mult != 1.0:
		var extra := float(table[3]) * (leg_mult - 1.0)
		table[3] = float(table[3]) + extra
		for i in 3:
			var take := minf(extra, float(table[i]))
			table[i] = float(table[i]) - take
			extra -= take
	var r := randf()
	var acc := 0.0
	for i in table.size():
		acc += float(table[i])
		if r <= acc:
			return i
	return 0


## Oggetti lasciati da una fonte: "normal", "elite", "unique", "chest", "chest_rich".
static func roll_drops(source: String, ilvl: int, class_id: String, leg_mult: float = 1.0) -> Array:
	var count := 0
	match source:
		"normal": count = 1 if randf() < 0.12 else 0
		"elite": count = randi_range(1, 2)
		"rare": count = randi_range(2, 3)
		"rift": count = randi_range(4, 6)
		"unique": count = 3
		"chest": count = randi_range(1, 2)
		"chest_rich": count = randi_range(2, 3)
	var out: Array = []
	for i in count:
		var r := roll_rarity(source, leg_mult)
		if source == "unique" and i == 0:
			r = maxi(r, Item.Rarity.RARO)
		if source == "rift" and i == 0:
			r = Item.Rarity.LEGGENDARIO
		out.append(generate(ilvl, r, class_id))
	return out


static func roll_gold(source: String, ilvl: int, gold_find: float) -> int:
	var chance := {"normal": 0.35, "elite": 1.0, "rare": 1.0, "unique": 1.0, "chest": 1.0, "chest_rich": 1.0, "rift": 1.0}.get(source, 0.3) as float
	if randf() > chance:
		return 0
	var mult := {"normal": 1.0, "elite": 4.0, "rare": 6.0, "unique": 15.0, "chest": 3.0, "chest_rich": 6.0, "rift": 30.0}.get(source, 1.0) as float
	return int(randi_range(3, 9) * ilvl * mult * (1.0 + gold_find / 100.0))


## Prezzo di vendita al mercante.
static func sell_value(it: Item) -> int:
	return int(SELL_VALUE[clampi(it.rarity, 0, SELL_VALUE.size() - 1)] * (1.0 + 0.25 * (it.ilvl - 1)))


static func buy_price(it: Item) -> int:
	return sell_value(it) * BUY_MULT


## Materiali ottenuti smontando un oggetto dal fabbro: {materiale: quantità}.
static func salvage_yield(it: Item) -> Dictionary:
	match it.rarity:
		Item.Rarity.COMUNE: return {"rottami": randi_range(2, 3)}
		Item.Rarity.MAGICO: return {"rottami": randi_range(1, 2), "essenza": 1}
		Item.Rarity.RARO: return {"essenza": randi_range(2, 3), "rottami": 1}
		Item.Rarity.LEGGENDARIO: return {"frammento": 1, "essenza": 3}
		Item.Rarity.SET: return {"frammento": 1, "essenza": 2}
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
		if randf() < SET_CHANCE:
			return make_set_piece(ilvl, class_id, true)
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
