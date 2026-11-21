class_name CutsceneDB
extends RefCounted
## CATALOGO DELLE CUTSCENE (le riproduce core/cutscene.gd; guida: docs/CUTSCENE.md).
##
## Ogni cutscene: {
##   "title":     nome (per l'elenco "rivedi" e i test),
##   "trigger":   quando parte da sola, UNA volta per eroe (flag "cs_<id>"); "" = solo a mano (Cutscene.play):
##                "enter:<id livello>"   prima visita/ogni ingresso finché non è vista
##                "quest_start:<id>" / "quest_done:<id>"   missione affidata / completata
##                "boss:<id nemico>"     boss unico sconfitto
##                "area:<nome>"          area CutsceneTrigger piazzata in un livello (world/cutscene_trigger.gd)
##   "music":     brano di audio/music/ durante la cutscene ("" = resta quello del luogo),
##   "skippable": si può saltare (predefinito true),
##   "shots":     inquadrature in ordine (sotto)
## }
##
## Inquadrature (campo "type"; campi comuni: "text" sottotitolo, "speaker" chi parla, "voice" file audio
## (predefinito audio/voci/<id cutscene>_<n>.ogg se esiste), "duration" secondi (predefinito: dalla voce o dalla
## lunghezza del testo), "fade" dissolvenza dal nero in secondi, "fx" particelle sopra: braci, cenere, pioggia,
## energia, neve):
##   "title"  scritta grande al centro: "text" (es. "ATTO I") + "subtitle".
##   "image"  fumetto animato: "image" (textures/cutscene/<nome>.png o percorso res://) oppure "layers"
##            [[immagine, profondità 0..1], ...] dal fondo al primo piano (parallasse: i livelli vicini si muovono di più);
##            "move": {"from": [zoom, x, y], "to": [zoom, x, y]} (zoom 1 = schermo pieno, x/y spostamento -1..1).
##            Immagine mancante = segnaposto con il suo nome (si può scrivere la cutscene prima dei disegni).
##   "video"  filmato: "video" (res://...ogv, Ogg Theora). Finisce col video (o "duration").
##   "scene"  nel motore, nel livello attuale (il gioco è fermo, si muovono solo gli attori):
##            "anchor": "player" | percorso di un nodo del livello | [x, y, z]  (centro della scena)
##            "camera": {"from": [x, y, z], "to": [x, y, z], "look": [x, y, z], "fov": 50}  (relativi all'ancora)
##            "actions": [{"at": secondi, "actor": "player" | percorso nodo | nome di uno "spawn",
##                         "move": [x, y, z] (relativo all'ancora), "time": durata del movimento,
##                         "anim": "cast", "face": [x, y, z] (relativo all'ancora),
##                         "spawn": "res://scenes/...tscn", "name": nome dell'attore creato (sparisce alla fine)}]

static var CUTSCENES: Dictionary = {
	# Cutscene di prova di tutti i tipi di inquadratura (non parte da sola: Cutscene.play("prova")).
	"prova": {
		"title": "Prova del motore",
		"trigger": "",
		"music": "",
		"shots": [
			{"type": "title", "text": "ATTO I", "subtitle": "Prova del motore delle cutscene", "duration": 3.0, "fade": 0.8},
			{"type": "image", "layers": [["prova/cielo", 0.0], ["prova/rovine", 0.5], ["prova/eroe", 1.0]],
				"move": {"from": [1.0, 0.0, 0.0], "to": [1.12, 0.3, -0.1]}, "fx": "braci",
				"speaker": "Narratore", "text": "Roma cadde nel 476. Nel fuoco della guerra di tutte le nazioni, una lupa allattò un bambino tra le rovine."},
			{"type": "image", "image": "prova/medaglione", "move": {"from": [1.2, 0.0, 0.0], "to": [1.0, 0.0, 0.0]}, "fx": "energia",
				"speaker": "Il senatore", "text": "Tienilo sempre con te. Ti proteggerà."},
			{"type": "scene", "anchor": "player", "camera": {"from": [6, 4, 8], "to": [3, 2.2, 4], "look": [0, 1.2, 0], "fov": 45},
				"actions": [{"at": 0.3, "actor": "player", "move": [2, 0, 0], "time": 1.5}, {"at": 1.9, "actor": "player", "anim": "cast"}],
				"text": "Il tuo eroe, nel livello, con la telecamera della cutscene.", "duration": 4.0},
			{"type": "video", "video": "res://video/prova.ogv", "duration": 2.0, "text": "(video mancante: segnaposto)"},
		],
	},
}


static func get_data(id: String) -> Dictionary:
	return CUTSCENES.get(id, {})


## Cutscene che partono con questo evento (nell'ordine del catalogo).
static func with_trigger(event: String) -> Array:
	var out: Array = []
	for id: String in CUTSCENES:
		if String(CUTSCENES[id].get("trigger", "")) == event:
			out.append(id)
	return out
