class_name MapZones
extends RefCounted
## Zone del terreno usate dalla Forma dei livelli (world/map_*.gd) e da tools/map_builder.gd.
##   texture  texture del suolo (textures/terreno/<nome>.png, core/terrain.gd); il colore la tinge un poco
##   color    colore del suolo (anche quello che si vede nell'editor finché il terreno non ha le texture)
##   border   oggetto di scena (scenes/props) messo sulle celle di confine; "" = muro invisibile
##   scatter  oggetti sparsi a caso: [nome prop, probabilità per cella 8×8 m]
## Per creare una zona nuova aggiungila qui e scrivi il suo nome nel campo "zone" di strade/aree/poligoni.

const ZONES := {
	# --- Livello 1: Campagna di Lazio Prime ---
	"fattoria": {"texture": "erba", "color": Color(0.42, 0.5, 0.26), "border": "bosco_fitto",
		"scatter": [["olivo", 0.22], ["cespuglio", 0.2], ["pino_marittimo", 0.08], ["roccia_piccola", 0.05], ["covone", 0.04]]},
	"bosco": {"texture": "sottobosco", "color": Color(0.22, 0.36, 0.18), "border": "bosco_fitto",
		"scatter": [["albero_pino", 0.55], ["albero_quercia", 0.35], ["cespuglio", 0.4], ["roccia_piccola", 0.1], ["tronco", 0.06], ["roccia_grande", 0.04]]},
	"fiume": {"texture": "erba", "color": Color(0.3, 0.42, 0.24), "border": "bosco_fitto",
		"scatter": [["albero_quercia", 0.2], ["canne", 0.35], ["cespuglio", 0.3], ["roccia_piccola", 0.12]]},
	"boschetto": {"texture": "erba", "color": Color(0.26, 0.4, 0.22), "border": "bosco_fitto",
		"scatter": [["cipresso", 0.2], ["albero_quercia", 0.3], ["cespuglio", 0.35]]},
	"tempio": {"texture": "erba", "color": Color(0.36, 0.42, 0.28), "border": "bosco_fitto",
		"scatter": [["cipresso", 0.15], ["albero_quercia", 0.25], ["colonna_rotta", 0.04], ["cespuglio", 0.3], ["roccia_piccola", 0.08]]},
	"relitto": {"texture": "terra_battuta", "color": Color(0.32, 0.34, 0.26), "border": "scogliera",
		"scatter": [["albero_pino", 0.3], ["roccia_piccola", 0.2], ["cassa", 0.05], ["cespuglio", 0.2]]},
	"campo": {"texture": "terra_battuta", "color": Color(0.45, 0.38, 0.27), "border": "scogliera",
		"scatter": [["roccia_grande", 0.12], ["roccia_piccola", 0.22], ["albero_pino", 0.1], ["tronco", 0.05], ["cespuglio", 0.1]]},
	"necropoli": {"texture": "ghiaia", "color": Color(0.34, 0.36, 0.3), "border": "scogliera",
		"scatter": [["cipresso", 0.28], ["cespuglio", 0.15], ["colonna_rotta", 0.03], ["sarcofago", 0.03]]},
	"citta": {"texture": "erba_secca", "color": Color(0.5, 0.47, 0.4), "border": "scogliera",
		"scatter": [["pino_marittimo", 0.15], ["cipresso", 0.1], ["cespuglio", 0.2], ["cassa", 0.03]]},
	# --- Ostia Nova (città) ---
	"urbe": {"texture": "lastricato", "color": Color(0.55, 0.52, 0.47), "border": "", "scatter": []},
	"foro": {"texture": "marmo_foro", "color": Color(0.78, 0.76, 0.71), "border": "", "scatter": []},
	"piazzale": {"texture": "lastricato", "color": Color(0.6, 0.57, 0.52), "border": "", "scatter": []},
	# --- Livello 3: Porto ---
	"strada": {"texture": "lastricato", "color": Color(0.52, 0.5, 0.46), "border": "isolato",
		"scatter": [["cassa", 0.06], ["barile", 0.06], ["anfora", 0.05], ["cipresso", 0.03]]},
	"magazzini": {"texture": "lastricato", "color": Color(0.47, 0.45, 0.41), "border": "isolato",
		"scatter": [["pila_casse", 0.08], ["cassa", 0.08], ["barile", 0.08], ["anfora", 0.04], ["bitta", 0.02]]},
	"cantieri": {"texture": "terra_battuta", "color": Color(0.44, 0.39, 0.32), "border": "isolato",
		"scatter": [["tronco", 0.07], ["cassa", 0.07], ["barile", 0.05], ["pila_casse", 0.04]]},
	"spazioporto": {"texture": "piastre_metallo", "color": Color(0.38, 0.4, 0.44), "border": "isolato",
		"scatter": [["cassa", 0.05], ["pila_casse", 0.05], ["barile", 0.04]]},
	"faro": {"texture": "ghiaia", "color": Color(0.5, 0.48, 0.4), "border": "scogliera",
		"scatter": [["roccia_piccola", 0.1], ["roccia_grande", 0.03], ["cespuglio", 0.1], ["pino_marittimo", 0.03]]},
	"sale": {"texture": "saline", "color": Color(0.62, 0.6, 0.55), "border": "isolato", "scatter": [["pila_casse", 0.12], ["barile", 0.08], ["anfora", 0.05]]},
	"cantiere": {"texture": "terra_battuta", "color": Color(0.45, 0.38, 0.3), "border": "isolato", "scatter": [["tronco", 0.1], ["cassa", 0.06]]},
	"molo": {"texture": "assi_molo", "color": Color(0.42, 0.3, 0.2), "border": "", "scatter": [["bitta", 0.06], ["barile", 0.05], ["cassa", 0.04]]},
}

## Oggetti grandi: stanno più lontani dalle strade e tra loro.
const BIG_PROPS := ["albero_pino", "albero_quercia", "pino_marittimo", "cipresso", "olivo", "roccia_grande",
	"colonna_rotta", "sarcofago", "covone", "tronco", "pila_casse"]
## Oggetti che crescono solo accanto all'acqua.
const WATER_EDGE_PROPS := ["canne"]

const DEFAULT := {"color": Color(0.4, 0.4, 0.35), "border": "", "scatter": []}


static func get_zone(zone_name: String) -> Dictionary:
	return ZONES.get(zone_name, DEFAULT)


static func names() -> Array:
	return ZONES.keys()
