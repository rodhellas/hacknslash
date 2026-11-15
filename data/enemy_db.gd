class_name EnemyDB
extends RefCounted
## Tipi di nemico. I valori sono quelli di livello 1: crescono col livello del nemico.
##   hp, damage      vita e danno base
##   speed           velocità di movimento (m/s)
##   range           distanza da cui attacca
##   windup          secondi di "carica" prima del colpo (il nemico si illumina: puoi schivare)
##   cooldown        pausa dopo l'attacco
##   aggro           distanza a cui ti nota
##   ranged          spara proiettili invece di colpire in mischia
##   special         "slam" (colpo ad area), "charge" (carica a distanza)
##   model           scena del modello 3D (sostituibile con quello di Tripo)

const DATA := {
	"predone": {
		"name": "Predone", "hp": 32.0, "damage": 6.0, "speed": 4.6, "range": 1.8, "windup": 0.45, "cooldown": 1.1,
		"radius": 0.45, "height": 1.7, "xp": 10, "aggro": 11.0, "model": "res://scenes/enemies/predone.tscn",
	},
	"lupo": {
		"name": "Lupo cibernetico", "hp": 22.0, "damage": 5.0, "speed": 6.8, "range": 1.6, "windup": 0.3, "cooldown": 0.9,
		"radius": 0.5, "height": 1.0, "xp": 8, "aggro": 13.0, "model": "res://scenes/enemies/lupo.tscn",
	},
	"drone": {
		"name": "Drone ribelle", "hp": 20.0, "damage": 6.0, "speed": 3.6, "range": 11.0, "windup": 0.6, "cooldown": 1.8,
		"radius": 0.45, "height": 1.6, "xp": 12, "aggro": 14.0, "ranged": true, "proj_speed": 12.0,
		"proj_color": Color(1.0, 0.2, 0.9), "model": "res://scenes/enemies/drone.tscn",
	},
	"barbaro": {
		"name": "Barbaro", "hp": 45.0, "damage": 9.0, "speed": 4.3, "range": 2.0, "windup": 0.5, "cooldown": 1.1,
		"radius": 0.5, "height": 1.9, "xp": 14, "aggro": 11.0, "model": "res://scenes/enemies/barbaro.tscn",
	},
	"frombolier": {
		"name": "Frombolier barbaro", "hp": 28.0, "damage": 7.0, "speed": 4.0, "range": 12.0, "windup": 0.7, "cooldown": 1.6,
		"radius": 0.45, "height": 1.7, "xp": 12, "aggro": 14.0, "ranged": true, "proj_speed": 15.0,
		"proj_color": Color(0.8, 0.7, 0.5), "model": "res://scenes/enemies/frombolier.tscn",
	},
	"bruto": {
		"name": "Bruto", "hp": 170.0, "damage": 20.0, "speed": 2.8, "range": 2.8, "windup": 0.85, "cooldown": 1.6,
		"radius": 0.85, "height": 2.7, "xp": 40, "aggro": 10.0, "special": "slam", "slam_radius": 3.2,
		"knock_resist": 0.25, "interruptible": false, "model": "res://scenes/enemies/bruto.tscn",
	},
	"lemure": {
		"name": "Lemure", "hp": 34.0, "damage": 8.0, "speed": 5.2, "range": 1.8, "windup": 0.4, "cooldown": 1.0,
		"radius": 0.45, "height": 1.8, "xp": 13, "aggro": 12.0, "model": "res://scenes/enemies/lemure.tscn",
	},
	"rinnegato": {
		"name": "Legionario rinnegato", "hp": 70.0, "damage": 12.0, "speed": 4.2, "range": 2.2, "windup": 0.55, "cooldown": 1.2,
		"radius": 0.5, "height": 1.9, "xp": 22, "aggro": 12.0, "knock_resist": 0.6, "model": "res://scenes/enemies/rinnegato.tscn",
	},
	"brenno": {
		"name": "Brenno il Rinnegato", "hp": 900.0, "damage": 24.0, "speed": 3.6, "range": 3.2, "windup": 0.8, "cooldown": 1.4,
		"radius": 1.0, "height": 3.3, "xp": 400, "aggro": 16.0, "unique": true, "special": "charge", "slam_radius": 3.8,
		"knock_resist": 0.05, "interruptible": false, "model": "res://scenes/enemies/brenno.tscn",
	},
}


static func get_data(type_id: String) -> Dictionary:
	return DATA.get(type_id, DATA["predone"])
