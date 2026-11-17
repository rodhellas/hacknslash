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
##   style         "stanze" (rettangoli e corridoi dritti) o "caverna" (grotte irregolari e gallerie tortuose)
##   room_kinds    tipi di stanza con probabilità: "colonne" (sala a colonne), "cripta" (file di sarcofagi),
##                 "tesoro" (forziere decorato + Campioni); il resto è "normale"
##   column        oggetto di scena usato per le sale a colonne (predefinito "colonna")
##   entrance      dove sta l'entrata: [id livello, percorso del nodo] (solo documentazione e test)

const DUNGEONS := {
	"catacombe": {
		"title": "Catacombe del Mausoleo", "seed": 3000,
		"rooms": 11, "grid": 56, "tile": 3.0, "room_min": 5, "room_max": 9, "corridor": 2, "loops": 2,
		"enemy_level": 5, "enemies": ["lemure", "predone"], "elites": ["lemure", "rinnegato"], "boss": "custode",
		"floor": Color(0.27, 0.25, 0.23), "wall": Color(0.36, 0.33, 0.3), "light": Color(1.0, 0.55, 0.25),
		"props": [["sarcofago", 0.6], ["anfora", 0.8], ["colonna_rotta", 0.4], ["cassa", 0.3]],
		"style": "stanze", "room_kinds": [["cripta", 0.35], ["colonne", 0.2], ["tesoro", 0.1]],
		"entrance": ["level_01", "World/Luoghi/Mausoleo/IngressoCatacombe"],
		"intro": "Sotto il mausoleo si apre una rete di gallerie scavate nel tufo. L'aria sa di ozono e di cera.\n\n[TRAMA]",
	},
	"caverne_clan": {
		"title": "Caverne del Clan", "seed": 4100,
		"rooms": 9, "grid": 52, "tile": 3.0, "room_min": 6, "room_max": 10, "corridor": 3, "loops": 1,
		"enemy_level": 4, "enemies": ["barbaro", "frombolier", "lupo"], "elites": ["bruto", "barbaro"], "boss": "tharvo",
		"floor": Color(0.3, 0.26, 0.2), "wall": Color(0.38, 0.32, 0.26), "light": Color(1.0, 0.5, 0.2),
		"props": [["falo", 0.5], ["roccia_grande", 0.6], ["roccia_piccola", 0.8], ["cassa", 0.4], ["tenda", 0.3]],
		"style": "caverna", "room_kinds": [["tesoro", 0.15]],
		"entrance": ["level_01", "World/Luoghi/AccampamentoBarbaro/IngressoCaverne"],
		"intro": "Dietro l'accampamento la roccia si apre in una grotta. Dentro, tamburi e odore di carne bruciata.\n\n[TRAMA]",
	},
	"cisterne": {
		"title": "Cisterne del Porto", "seed": 5207,
		"rooms": 12, "grid": 60, "tile": 3.0, "room_min": 6, "room_max": 11, "corridor": 2, "loops": 3,
		"enemy_level": 8, "enemies": ["granchio", "pirata", "arpionatore"], "elites": ["automa", "pirata"], "boss": "madre_granchi",
		"floor": Color(0.22, 0.27, 0.28), "wall": Color(0.3, 0.36, 0.37), "light": Color(0.45, 0.85, 1.0),
		"props": [["barile", 0.6], ["pila_casse", 0.4], ["cassa", 0.5], ["anfora", 0.4]],
		"style": "stanze", "room_kinds": [["colonne", 0.5], ["tesoro", 0.12]],
		"entrance": ["level_03_porto", "World/Luoghi/Magazzini/IngressoCisterne"],
		"intro": "Sotto i magazzini del sale corrono le vecchie cisterne della città. L'acqua è sparita; i granchi no.\n\n[TRAMA]",
	},
}


static func get_data(id: String) -> Dictionary:
	return DUNGEONS.get(id, DUNGEONS["catacombe"])
