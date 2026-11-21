class_name HeroClasses
extends RefCounted
## Le 4 classi giocabili e le loro abilità. Tutto è guidato dai dati:
## per bilanciare il gioco basta cambiare i numeri qui sotto.
##
## Slot delle abilità: "lmb" (clic sinistro), "rmb" (clic destro), "1".."4" (tasti numerici).
## "unlock" = livello a cui l'abilità si sblocca.
## "dmg" = moltiplicatore del danno dell'arma (1.0 = 100% danno arma).
##
## Tipi di abilità ("kind"), eseguiti da core/abilities.gd:
##   melee      – colpo ad arco davanti (range, arc, hits, combo, knock)
##   projectile – proiettili (speed, count, spread, pierce, chain, explode_radius, slow)
##   aoe_point  – area sul punto del mouse (radius, delay, ticks, interval, max_range, strike)
##   aoe_self   – area attorno all'eroe (radius, ticks, interval, knock, slow, spin)
##   dash       – spostamento rapido (mode: forward / leap / teleport, distance, dmg, radius)
##   buff       – potenziamento (duration, dr, damage, aspd, lifesteal, heal_pct, shockwave)

const ORDER := ["legionario", "gladiatore", "sagittario", "augure"]

const SLOT_KEYS := {"lmb": "Clic sx", "rmb": "Clic dx", "1": "1", "2": "2", "3": "3", "4": "4"}
const SLOT_ORDER := ["lmb", "rmb", "1", "2", "3", "4"]

const STAT_NAMES := {"forza": "Forza", "destrezza": "Destrezza", "intelligenza": "Intelligenza", "vitalita": "Vitalità"}

const DATA := {
	"legionario": {
		"name": "Legionario",
		"desc": "Veterano delle legioni stellari. Resistente e solido: protegge sé stesso con lo scutum a campo di forza e travolge i nemici in mischia.",
		"main_stat": "forza",
		"resource": "Disciplina", "resource_color": Color(0.95, 0.75, 0.25),
		"resource_max": 100.0, "resource_regen": 4.0, "resource_starts_full": true,
		"base": {"forza": 12, "destrezza": 8, "intelligenza": 8, "vitalita": 12},
		"per_level": {"forza": 3, "destrezza": 1, "intelligenza": 1, "vitalita": 2},
		"weapons": ["gladio", "spatha"], "offhands": ["scudo"],
		"start_items": ["gladio_plasma", "scutum", "galea"],
		"model": "res://scenes/characters/legionario_vero.tscn",   # corpo vero (graybox: legionario.tscn)
		"model_f": "res://scenes/characters/corpo_f_vero.tscn",   # corpo vero (graybox: legionario_f.tscn)
		"color": Color(0.7, 0.1, 0.1),
		"abilities": [
			{"id": "colpo_gladio", "name": "Colpo di gladio", "slot": "lmb", "unlock": 1, "kind": "melee",
				"dmg": 1.2, "range": 2.8, "arc": 110.0, "gain": 6.0, "combo": true, "color": Color(0.2, 0.9, 1.0),
				"desc": "Tre colpi in sequenza: il terzo è un fendente rotante a 360°."},
			{"id": "pilum", "name": "Pilum", "slot": "rmb", "unlock": 1, "kind": "projectile",
				"dmg": 2.4, "cost": 20.0, "speed": 26.0, "pierce": true, "length": 1.6, "max_range": 22.0,
				"color": Color(0.95, 0.75, 0.25), "visual": "lancia_energia",
				"desc": "Forgia un pilum di pura energia e lo scaglia: trapassa tutti i nemici sulla traiettoria."},
			{"id": "testuggine", "name": "Testuggine", "slot": "1", "unlock": 2, "kind": "buff",
				"cooldown": 12.0, "duration": 4.0, "dr": 0.6, "shockwave": 5.0, "dmg": 1.0, "knock": 14.0,
				"color": Color(1.0, 0.8, 0.3),
				"desc": "Onda d'urto che respinge i nemici vicini, poi subisci il 60% di danni in meno per 4 s."},
			{"id": "carica", "name": "Carica", "slot": "2", "unlock": 3, "kind": "dash", "mode": "forward",
				"distance": 12.0, "cooldown": 7.0, "dmg": 1.8, "knock": 10.0, "color": Color(0.9, 0.15, 0.1),
				"desc": "Carica verso il cursore travolgendo tutti i nemici sul percorso."},
			{"id": "grido_marte", "name": "Grido di Marte", "slot": "3", "unlock": 4, "kind": "buff",
				"cooldown": 20.0, "duration": 6.0, "damage": 0.3, "heal_pct": 0.15, "color": Color(1.0, 0.3, 0.2),
				"desc": "+30% danni per 6 s e cura il 15% della vita massima."},
			{"id": "bombardamento", "name": "Fulmine di Giove", "slot": "4", "unlock": 6, "kind": "aoe_point",
				"cost": 40.0, "cooldown": 10.0, "radius": 6.0, "delay": 0.8, "dmg": 4.5, "max_range": 18.0, "visual": "raggio_orbitale",
				"color": Color(1.0, 0.5, 0.1),
				"desc": "Un raggio della flotta in orbita colpisce l'area indicata dopo un breve ritardo."},
		],
	},
	"gladiatore": {
		"name": "Gladiatore",
		"desc": "Campione delle grandi arene. Veloce e brutale: accumula Furia colpendo e la scatena in attacchi devastanti.",
		"main_stat": "forza",
		"resource": "Furia", "resource_color": Color(0.9, 0.15, 0.1),
		"resource_max": 100.0, "resource_regen": 0.0, "resource_starts_full": false,
		"base": {"forza": 11, "destrezza": 10, "intelligenza": 7, "vitalita": 11},
		"per_level": {"forza": 3, "destrezza": 2, "intelligenza": 1, "vitalita": 1},
		"weapons": ["gladio", "ascia", "spatha"], "offhands": ["pugnale", "scudo", "gladio", "ascia"],
		"start_items": ["scure", "pugio", "galea"],
		"model": "res://scenes/characters/gladiatore.tscn",
		"model_f": "res://scenes/characters/gladiatore_f.tscn",
		"color": Color(0.75, 0.5, 0.3),
		"abilities": [
			{"id": "doppio_fendente", "name": "Doppio fendente", "slot": "lmb", "unlock": 1, "kind": "melee",
				"dmg": 0.7, "hits": 2, "range": 2.6, "arc": 100.0, "gain": 12.0, "speed": 1.25,
				"color": Color(1.0, 0.85, 0.6),
				"desc": "Due colpi rapidissimi. Genera molta Furia."},
			{"id": "colpo_arena", "name": "Colpo dell'arena", "slot": "rmb", "unlock": 1, "kind": "melee",
				"dmg": 3.2, "range": 3.3, "arc": 140.0, "cost": 25.0, "knock": 9.0,
				"color": Color(1.0, 0.4, 0.1),
				"desc": "Un fendente ampio e pesante che scaraventa via i nemici."},
			{"id": "balzo", "name": "Balzo", "slot": "1", "unlock": 2, "kind": "dash", "mode": "leap",
				"distance": 14.0, "cooldown": 8.0, "dmg": 2.0, "radius": 4.0, "knock": 8.0,
				"color": Color(0.9, 0.6, 0.2),
				"desc": "Salta sul punto indicato e colpisce i nemici all'atterraggio."},
			{"id": "turbine", "name": "Turbine", "slot": "2", "unlock": 3, "kind": "aoe_self",
				"cost": 30.0, "cooldown": 1.0, "radius": 3.6, "ticks": 6, "interval": 0.3, "dmg": 0.8, "knock": 2.0, "spin": true,
				"color": Color(1.0, 0.7, 0.4),
				"desc": "Ruota su sé stesso colpendo ripetutamente tutti i nemici attorno."},
			{"id": "rete", "name": "Rete del reziario", "slot": "3", "unlock": 4, "kind": "projectile",
				"cooldown": 6.0, "dmg": 1.0, "speed": 18.0, "explode_radius": 3.5, "slow": 0.6, "slow_time": 3.0,
				"length": 0.6, "thickness": 0.6, "max_range": 16.0, "color": Color(0.7, 0.9, 1.0), "visual": "rete_energia",
				"desc": "Lancia una rete di filamenti di energia che rallenta del 60% i nemici colpiti."},
			{"id": "favore_folla", "name": "Favore della folla", "slot": "4", "unlock": 6, "kind": "buff",
				"cooldown": 25.0, "duration": 8.0, "aspd": 0.4, "lifesteal": 0.06, "color": Color(1.0, 0.85, 0.3),
				"desc": "Per 8 s: +40% velocità d'attacco e recuperi il 6% dei danni inflitti."},
		],
	},
	"sagittario": {
		"name": "Sagittario",
		"desc": "Arciere scelto delle coorti ausiliarie. Colpisce da lontano con l'arco al plasma e non si fa mai raggiungere.",
		"main_stat": "destrezza",
		"resource": "Concentrazione", "resource_color": Color(0.3, 0.9, 0.5),
		"resource_max": 120.0, "resource_regen": 6.0, "resource_starts_full": true,
		"base": {"forza": 8, "destrezza": 12, "intelligenza": 9, "vitalita": 10},
		"per_level": {"forza": 1, "destrezza": 3, "intelligenza": 1, "vitalita": 2},
		"weapons": ["arco"], "offhands": ["faretra"],
		"start_items": ["arco_plasma", "faretra", "cappuccio"],
		"model": "res://scenes/characters/sagittario.tscn",
		"model_f": "res://scenes/characters/sagittario_f.tscn",
		"color": Color(0.25, 0.5, 0.25),
		"abilities": [
			{"id": "dardo", "name": "Dardo al plasma", "slot": "lmb", "unlock": 1, "kind": "projectile",
				"dmg": 1.1, "speed": 34.0, "gain": 4.0, "max_range": 24.0, "length": 1.0, "color": Color(0.4, 1.0, 0.6), "visual": "dardo_energia",
				"desc": "Un dardo di energia rapido e preciso."},
			{"id": "freccia_esplosiva", "name": "Freccia esplosiva", "slot": "rmb", "unlock": 1, "kind": "projectile",
				"dmg": 2.6, "cost": 25.0, "speed": 26.0, "explode_radius": 3.5, "max_range": 24.0, "length": 1.0,
				"color": Color(1.0, 0.6, 0.2), "visual": "dardo_energia",
				"desc": "Un dardo di energia instabile che esplode all'impatto danneggiando tutti i nemici vicini."},
			{"id": "capriola", "name": "Capriola", "slot": "1", "unlock": 2, "kind": "dash", "mode": "forward",
				"distance": 9.0, "cooldown": 4.0, "cost": 10.0, "dmg": 0.0, "color": Color(0.4, 1.0, 0.6),
				"desc": "Una capriola rapida verso il cursore. Sei invulnerabile durante il movimento."},
			{"id": "ventaglio", "name": "Ventaglio di dardi", "slot": "2", "unlock": 3, "kind": "projectile",
				"dmg": 1.0, "cost": 30.0, "cooldown": 2.0, "count": 5, "spread": 50.0, "speed": 30.0, "max_range": 20.0,
				"length": 1.0, "color": Color(0.6, 1.0, 0.4), "visual": "dardo_energia",
				"desc": "Cinque dardi di energia a ventaglio."},
			{"id": "trappola", "name": "Trappola a rete", "slot": "3", "unlock": 4, "kind": "aoe_point",
				"cooldown": 10.0, "radius": 4.0, "delay": 1.2, "dmg": 3.0, "slow": 0.5, "slow_time": 3.0, "max_range": 12.0,
				"color": Color(0.6, 0.9, 1.0), "visual": "trappola_energia",
				"desc": "Piazza una trappola di energia che esplode dopo 1 s rallentando i nemici."},
			{"id": "pioggia_frecce", "name": "Pioggia di frecce", "slot": "4", "unlock": 6, "kind": "aoe_point",
				"cost": 50.0, "cooldown": 8.0, "radius": 6.0, "delay": 0.3, "ticks": 6, "interval": 0.5, "dmg": 0.8,
				"max_range": 20.0, "color": Color(0.5, 1.0, 0.5), "visual": "dardi_energia",
				"desc": "Una pioggia di dardi di energia colpisce l'area per 3 secondi."},
		],
	},
	"augure": {
		"name": "Augure",
		"desc": "Sacerdote-scienziato che interpreta i segni degli dèi e ne scatena il potere. Fragile ma devastante.",
		"main_stat": "intelligenza",
		"resource": "Favore divino", "resource_color": Color(0.45, 0.5, 1.0),
		"resource_max": 150.0, "resource_regen": 7.0, "resource_starts_full": true,
		"base": {"forza": 7, "destrezza": 8, "intelligenza": 13, "vitalita": 10},
		"per_level": {"forza": 1, "destrezza": 1, "intelligenza": 3, "vitalita": 2},
		"weapons": ["scettro"], "offhands": ["focus"],
		"start_items": ["lituo", "sfera_oracolo", "cappuccio"],
		"model": "res://scenes/characters/augure.tscn",
		"model_f": "res://scenes/characters/augure_f.tscn",
		"color": Color(0.85, 0.85, 0.95),
		"abilities": [
			{"id": "fulmine", "name": "Fulmine di Giove", "slot": "lmb", "unlock": 1, "kind": "projectile",
				"dmg": 1.0, "speed": 40.0, "chain": 2, "max_range": 20.0, "length": 0.9, "color": Color(0.6, 0.8, 1.0),
				"desc": "Un fulmine che rimbalza su altri 2 nemici vicini."},
			{"id": "sfera_vulcano", "name": "Sfera di Vulcano", "slot": "rmb", "unlock": 1, "kind": "projectile",
				"dmg": 3.2, "cost": 30.0, "speed": 16.0, "explode_radius": 4.0, "max_range": 22.0,
				"length": 0.7, "thickness": 0.7, "color": Color(1.0, 0.4, 0.1),
				"desc": "Una sfera di fuoco lenta che esplode in un'ampia area."},
			{"id": "egida", "name": "Egida di Minerva", "slot": "1", "unlock": 2, "kind": "buff",
				"cooldown": 15.0, "duration": 5.0, "dr": 0.5, "heal_pct": 0.2, "color": Color(0.7, 0.8, 1.0),
				"desc": "Cura il 20% della vita e dimezza i danni subiti per 5 s."},
			{"id": "passo_mercurio", "name": "Passo di Mercurio", "slot": "2", "unlock": 3, "kind": "dash", "mode": "teleport",
				"distance": 14.0, "cooldown": 6.0, "color": Color(0.8, 0.8, 1.0),
				"desc": "Teletrasporto istantaneo verso il cursore."},
			{"id": "ira_nettuno", "name": "Ira di Nettuno", "slot": "3", "unlock": 4, "kind": "aoe_self",
				"cost": 25.0, "cooldown": 6.0, "radius": 6.0, "dmg": 2.2, "knock": 16.0, "slow": 0.5, "slow_time": 3.0,
				"color": Color(0.3, 0.6, 1.0),
				"desc": "Un'ondata che respinge e rallenta tutti i nemici attorno."},
			{"id": "meteora", "name": "Meteora", "slot": "4", "unlock": 6, "kind": "aoe_point",
				"cost": 60.0, "cooldown": 3.0, "radius": 5.0, "delay": 1.0, "dmg": 6.5, "max_range": 20.0, "strike": true,
				"color": Color(1.0, 0.35, 0.05),
				"desc": "Richiama una meteora dal cielo sul punto indicato."},
		],
	},
}


static func get_data(class_id: String) -> Dictionary:
	return DATA.get(class_id, DATA["legionario"])


static func ability_for_slot(class_id: String, slot: String) -> Dictionary:
	for ab: Dictionary in get_data(class_id)["abilities"]:
		if ab["slot"] == slot:
			return ab
	return {}
