class_name DungeonDB
extends RefCounted
## Dungeon generati proceduralmente (world/dungeon_gen.gd). Con lo stesso seme la mappa è sempre
## la stessa: cambia "seed" per avere un'altra pianta (anteprima: tools/export_dungeons.gd).
## Le entrate sono oggetti di scena "ingresso_catacombe" (world/dungeon_entrance.gd) messi nei livelli
## a mano, con dungeon_id = chiave di DUNGEONS.
##   seed          seme della generazione (stesso seme = stessa mappa)
##   rooms         numero di stanze cercate (ne entrano quante ci stanno nella griglia)
##   grid          lato della griglia in celle; tile = lato di una cella in metri
##   room_min/max  lato delle stanze in celle;  corridor = larghezza dei corridoi in celle
##   loops         collegamenti in più tra stanze vicine (percorsi ad anello, come in D3)
##   enemy_level   livello dei nemici;  enemies / elites = tipi di nemici;  boss = id in EnemyDB (unico)
##   floor, wall   colori del pavimento e dei muri;  light = colore delle torce
##   props         oggetti di scena sparsi nelle stanze: [nome prop, probabilità per stanza]

const DUNGEONS := {
	"catacombe": {
		"title": "Catacombe del Mausoleo", "seed": 3000,
		"rooms": 11, "grid": 56, "tile": 3.0, "room_min": 5, "room_max": 9, "corridor": 2, "loops": 2,
		"enemy_level": 5, "enemies": ["lemure", "predone"], "elites": ["lemure", "rinnegato"], "boss": "custode",
		"floor": Color(0.27, 0.25, 0.23), "wall": Color(0.36, 0.33, 0.3), "light": Color(1.0, 0.55, 0.25),
		"props": [["sarcofago", 0.6], ["anfora", 0.8], ["colonna_rotta", 0.4], ["cassa", 0.3]],
		"intro": "Sotto il mausoleo si apre una rete di gallerie scavate nel tufo. L'aria sa di ozono e di cera.\n\n[TRAMA]",
	},
}


static func get_data(id: String) -> Dictionary:
	return DUNGEONS.get(id, DUNGEONS["catacombe"])
