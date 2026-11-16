@tool
class_name MapShape
extends Node3D
## FORMA del livello: contenitore delle strade (MapRoad), aree (MapArea) e poligoni (MapPolygon)
## che definiscono dove si può camminare, le zone del terreno, l'acqua.
## Modificala nell'editor e premi "Ricostruisci terreno" nel pannello Mappa (plugin Legio Map):
## vengono rigenerati SOLO terreno, confini, strade, acqua, vegetazione, lampioni e navmesh
## (tools/map_builder.gd). Tutto il resto del livello (luoghi, nemici, NPC...) resta com'è.
## In gioco questo nodo viene eliminato: serve solo nell'editor.

## Lato delle celle del terreno (m). Più piccolo = bordi più precisi ma più nodi.
@export var cell_size := 8.0
## Seme della vegetazione casuale (stesso seme + stessa forma = stesso risultato).
@export var seed := 3000
## Zona usata dove nessun elemento ne indica una (né aree, né poligoni, né la strada principale).
@export var default_zone := "fattoria"
## Piano di sfondo sotto tutto (fuori dall'area giocabile): colore e altezza.
@export var background_color := Color(0.1, 0.14, 0.09)
@export var background_y := -0.05
@export var water_color := Color(0.15, 0.38, 0.58)
## Distanza minima della vegetazione dal bordo delle strade lastricate (m).
@export var scatter_road_margin := 1.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()


## Elementi della forma (anche annidati in sottogruppi).
func roads() -> Array:
	return find_children("*", "MapRoad", true, false)


func areas() -> Array:
	return find_children("*", "MapArea", true, false)


func polygons() -> Array:
	return find_children("*", "MapPolygon", true, false)


## La strada principale: la prima con "zone_breaks" (le zone cambiano lungo il percorso).
func main_road() -> MapRoad:
	for r: MapRoad in roads():
		if not r.zone_breaks.is_empty():
			return r
	return null
