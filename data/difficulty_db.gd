class_name DifficultyDB
extends RefCounted
## Livelli di difficoltà (come in Diablo 3) e scala dei Labirinti di Dedalo (endgame).
## La difficoltà si cambia dal menu di pausa e vale per i nemici che compaiono da quel momento.
##   hp, dmg   moltiplicatori di vita e danni dei nemici
##   xp, gold  moltiplicatori di esperienza e sesterzi
##   leg       moltiplicatore della probabilità di leggendari e pezzi di set
##   affixes   numero di affissi delle elite
##   unlock    livello dell'eroe necessario
## Da Esperto in su i nemici hanno almeno il livello dell'eroe (anche nelle zone già superate).

const LEVELS := [
	{"name": "Normale", "hp": 1.0, "dmg": 1.0, "xp": 1.0, "gold": 1.0, "leg": 1.0, "affixes": 1, "unlock": 1},
	{"name": "Esperto", "hp": 1.6, "dmg": 1.35, "xp": 1.5, "gold": 1.5, "leg": 1.25, "affixes": 2, "unlock": 1},
	{"name": "Maestro", "hp": 2.5, "dmg": 1.8, "xp": 2.2, "gold": 2.0, "leg": 1.6, "affixes": 2, "unlock": 10},
	{"name": "Tormento I", "hp": 4.0, "dmg": 2.4, "xp": 3.0, "gold": 2.5, "leg": 2.0, "affixes": 3, "unlock": 30},
	{"name": "Tormento II", "hp": 5.6, "dmg": 3.0, "xp": 3.6, "gold": 2.8, "leg": 2.3, "affixes": 3, "unlock": 30},
	{"name": "Tormento III", "hp": 7.8, "dmg": 3.7, "xp": 4.3, "gold": 3.1, "leg": 2.6, "affixes": 3, "unlock": 30},
	{"name": "Tormento IV", "hp": 11.0, "dmg": 4.6, "xp": 5.2, "gold": 3.4, "leg": 3.0, "affixes": 3, "unlock": 30},
	{"name": "Tormento V", "hp": 15.0, "dmg": 5.7, "xp": 6.2, "gold": 3.7, "leg": 3.4, "affixes": 3, "unlock": 30},
	{"name": "Tormento VI", "hp": 21.0, "dmg": 7.0, "xp": 7.4, "gold": 4.0, "leg": 3.8, "affixes": 4, "unlock": 30},
	{"name": "Tormento VII", "hp": 29.0, "dmg": 8.6, "xp": 8.8, "gold": 4.4, "leg": 4.3, "affixes": 4, "unlock": 30},
	{"name": "Tormento VIII", "hp": 40.0, "dmg": 10.5, "xp": 10.5, "gold": 4.8, "leg": 4.8, "affixes": 4, "unlock": 30},
	{"name": "Tormento IX", "hp": 55.0, "dmg": 12.8, "xp": 12.5, "gold": 5.2, "leg": 5.4, "affixes": 4, "unlock": 30},
	{"name": "Tormento X", "hp": 76.0, "dmg": 15.5, "xp": 15.0, "gold": 5.6, "leg": 6.0, "affixes": 4, "unlock": 30},
]


static func get_data(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


static func level_name(index: int) -> String:
	return String(get_data(index)["name"])


static func is_unlocked(index: int, hero_level: int) -> bool:
	return index >= 0 and index < LEVELS.size() and hero_level >= int(LEVELS[index]["unlock"])


# --------------------------------------------------------------------------------------------------
#  Labirinti di Dedalo: dungeon generati con un seme nuovo a ogni tentativo, grado da 1 in su.
#  Riempi la barra uccidendo nemici, poi compare il Guardiano. Sconfiggilo entro il tempo limite
#  per sbloccare il grado successivo. Il grado sostituisce la difficoltà.
# --------------------------------------------------------------------------------------------------
const RIFT_TIME := 900.0          # secondi per battere il guardiano e salire di grado
const RIFT_FAST := 450.0          # sotto questo tempo si sale di 2 gradi
const RIFT_PROGRESS := 0.75       # frazione dei nemici "attesi" da uccidere perché compaia il guardiano
const RIFT_GUARDIANS := ["custode", "tharvo", "madre_granchi"]
const RIFT_ENEMIES := [
	["predone", "lupo", "drone"], ["barbaro", "frombolier", "lupo"], ["lemure", "rinnegato", "bruto"],
	["pirata", "arpionatore", "granchio"], ["lemure", "drone", "rinnegato"], ["barbaro", "bruto", "frombolier"],
]


## Moltiplicatori di un grado del labirinto (stesso formato di LEVELS).
static func rift_scaling(grade: int) -> Dictionary:
	var g := maxi(1, grade)
	return {
		"name": "Labirinto grado %d" % g, "hp": 1.4 * pow(1.17, g - 1), "dmg": 1.3 * pow(1.1, g - 1),
		"xp": 1.5 + 0.2 * g, "gold": 1.5 + 0.1 * g, "leg": 1.5 + 0.15 * g, "affixes": clampi(2 + g / 5, 2, 4),
	}


## Configurazione del dungeon di un labirinto (formato di DungeonDB): grado e seme decidono tutto.
static func rift_config(grade: int, seed_value: int, hero_level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cave := rng.randf() < 0.5
	# Aspetto (colori, torce, oggetti di scena) preso da uno dei dungeon della campagna
	var looks: Array = DungeonDB.DUNGEONS.values()
	var cfg: Dictionary = (looks[rng.randi() % looks.size()] as Dictionary).duplicate(true)
	cfg.erase("entrance")
	cfg.erase("intro")
	cfg.merge({
		"title": "Labirinto di Dedalo – grado %d" % maxi(1, grade),
		"seed": seed_value, "style": "caverna" if cave else "stanze",
		"grid": 58, "rooms": clampi(9 + grade / 3, 9, 14), "room_min": 5, "room_max": 9,
		"corridor": 3 if cave else 2, "loops": 2,
		"room_kinds": [["colonne", 0.25], ["cripta", 0.2], ["tesoro", 0.1]],
		"enemies": RIFT_ENEMIES[rng.randi() % RIFT_ENEMIES.size()],
		"enemy_level": hero_level, "boss": "", "rift": maxi(1, grade),
		"guardian": RIFT_GUARDIANS[rng.randi() % RIFT_GUARDIANS.size()], "tile": 3.0,
	}, true)
	cfg["elites"] = cfg["enemies"]
	return cfg
