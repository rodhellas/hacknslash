class_name WorldDB
extends RefCounted
## Contenuti "vivi" del mondo, piazzati a ogni visita (non fanno parte delle mappe fatte a mano):
## santuari, piloni (solo nei Labirinti), eventi casuali e taglie (modalità avventura).

## Santuari: potenziamento per "duration" secondi (chiavi dei buff di Player.add_buff).
##   xp = +% esperienza, fortune = +% sesterzi e leggendari, channel = niente costi e ricariche ×0,25
const SHRINES := {
	"fortuna": {"name": "Santuario della Fortuna", "desc": "+25% sesterzi e +50% leggendari", "duration": 120.0,
		"buff": {"fortune": 0.5}, "color": Color(1.0, 0.85, 0.3)},
	"furia": {"name": "Santuario di Marte", "desc": "+25% danni", "duration": 120.0, "buff": {"damage": 0.25}, "color": Color(1.0, 0.3, 0.2)},
	"celerita": {"name": "Santuario di Mercurio", "desc": "+25% movimento, +15% velocità d'attacco", "duration": 120.0,
		"buff": {"move": 0.25, "aspd": 0.15}, "color": Color(0.4, 1.0, 0.6)},
	"protezione": {"name": "Santuario di Minerva", "desc": "-25% danni subiti", "duration": 120.0, "buff": {"dr": 0.25}, "color": Color(0.5, 0.7, 1.0)},
	"sapienza": {"name": "Santuario di Apollo", "desc": "+25% esperienza", "duration": 120.0, "buff": {"xp": 0.25}, "color": Color(0.9, 0.6, 1.0)},
}
## Piloni: solo nei Labirinti di Dedalo, più forti e più brevi.
const PYLONS := {
	"potenza": {"name": "Pilone della Potenza", "desc": "+300% danni", "duration": 30.0, "buff": {"damage": 3.0}, "color": Color(1.0, 0.2, 0.1)},
	"canalizzazione": {"name": "Pilone del Flusso", "desc": "Abilità senza costo, ricariche ×0,25", "duration": 30.0,
		"buff": {"channel": 1.0}, "color": Color(0.3, 0.6, 1.0)},
	"egida": {"name": "Pilone dell'Egida", "desc": "Invulnerabile", "duration": 15.0, "buff": {"invuln": 1.0}, "color": Color(1.0, 1.0, 0.6)},
	"vento": {"name": "Pilone del Vento", "desc": "+80% movimento, +30% velocità d'attacco", "duration": 30.0,
		"buff": {"move": 0.8, "aspd": 0.3}, "color": Color(0.6, 1.0, 0.9)},
}
## Quanti ne compaiono: mappe all'aperto, dungeon, labirinti.
const SHRINES_PER_MAP := 3
const SHRINES_PER_DUNGEON := 2
const PYLONS_PER_RIFT := 2

## Eventi casuali nelle mappe all'aperto (EVENTS_PER_MAP per visita, vicino a zone di nemici).
##   maledetto  forziere maledetto: sopravvivi a ondate per "time" secondi, poi apri il forziere
##   assedio    stendardo nemico: "waves" ondate una dopo l'altra (l'ultima con un'elite)
##   prigionieri liberane "captives" (ognuno si clicca); le guardie arrivano al primo
const EVENTS := {
	"maledetto": {"name": "Il forziere maledetto", "desc": "Sopravvivi alle ondate finché la maledizione non si spezza.", "time": 30.0},
	"assedio": {"name": "Lo stendardo del clan", "desc": "Abbatti le ondate di nemici richiamate dallo stendardo.", "waves": [4, 6, 8]},
	"prigionieri": {"name": "Prigionieri dei predoni", "desc": "Libera i prigionieri e respingi le guardie.", "captives": 3},
}
const EVENTS_PER_MAP := 2

# --------------------------------------------------------------------------------------------------
#  TAGLIE (modalità avventura): dalla Tabula delle taglie nel foro di Ostia Nova. Ogni atto ha
#  BOUNTIES_PER_ACT taglie; finite tutte, la Cassa del Prefetto si ritira dalla tabula.
#  Tipi: boss (uccidi il boss: compare di nuovo anche se già sconfitto), kill (uccidi N nemici
#  nel livello), elite (uccidi N elite nel livello), event (completa un evento nel livello).
#  "levels": id dei livelli dell'atto; i dungeon si indicano "dungeon:<id>".
# --------------------------------------------------------------------------------------------------
const ACTS := {
	1: {"name": "Atto I – Lazio Prime", "levels": ["level_01", "dungeon:catacombe", "dungeon:caverne_clan"],
		"bosses": {"brenno": "level_01", "custode": "dungeon:catacombe", "tharvo": "dungeon:caverne_clan"}},
	2: {"name": "Atto II – Porto di Ostia Nova", "levels": ["level_03_porto", "dungeon:cisterne"],
		"bosses": {"vulso": "level_03_porto", "madre_granchi": "dungeon:cisterne"}},
}
const BOUNTIES_PER_ACT := 4
const BOUNTY_REWARD := {"xp_per_level": 60, "gold_per_level": 40}


## Nome leggibile di un luogo delle taglie.
static func place_name(key: String) -> String:
	if key.begins_with("dungeon:"):
		return String(DungeonDB.get_data(key.substr(8)).get("title", key))
	return Game.level_title(key)
