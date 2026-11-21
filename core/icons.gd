class_name Icons
extends RefCounted
## Icone dell'interfaccia (set "Grafite e braci", generate con l'AI: vedi docs/ICONE_AI.md e docs/GRAFICA_2D_AI.md).
## textures/icone/abilita/<id abilità>.png, textures/icone/passive/<id passiva>.png, textures/icone/pozione.png,
## textures/icone/oggetti/<id base>.png, gemme/<tipo>.png, gemme_leggendarie/<id>.png, materiali/<id>.png
## (anche materiali/sesterzi.png). Le icone degli oggetti non hanno la rarità: la colora l'interfaccia.
## Se un'icona manca si ritorna null e chi disegna usa la sigla (come prima).

const DIR := "res://textures/icone/"

static var _cache: Dictionary = {}


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Icona di un'abilità (le varianti usano quella dell'abilità).
static func ability(id: String) -> Texture2D:
	return _load(DIR + "abilita/" + id + ".png") if id != "" else null


static func passive(id: String) -> Texture2D:
	return _load(DIR + "passive/" + id + ".png") if id != "" else null


static func potion() -> Texture2D:
	return _load(DIR + "pozione.png")


## Icona di un oggetto (una per base: tutte le rarità usano la stessa).
static func item(it: Item) -> Texture2D:
	return _load(DIR + "oggetti/" + it.base_id + ".png") if it != null and it.base_id != "" else null


## Icona di una gemma: chiave "tipo:grado" oppure "leg:<id>:<grado>" (gemme leggendarie).
static func gem(key: String) -> Texture2D:
	if key.begins_with("leg:"):
		return _load(DIR + "gemme_leggendarie/" + key.get_slice(":", 1) + ".png")
	return _load(DIR + "gemme/" + key.get_slice(":", 0) + ".png") if key != "" else null


## Materiali del fabbro (rottami, essenza, frammento) e "sesterzi".
static func material(id: String) -> Texture2D:
	return _load(DIR + "materiali/" + id + ".png")


## Percorso del file (per le immagini dentro i testi BBCode, es. [img=20]percorso[/img]).
static func material_path(id: String) -> String:
	return DIR + "materiali/" + id + ".png"
