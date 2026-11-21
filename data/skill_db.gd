class_name SkillDB
extends RefCounted
## Abilità alternative, varianti (rune, come in Diablo 3), passive e poteri leggendari che modificano
## le abilità. Le abilità base sono in data/hero_classes.gd ("abilities"); qui ci sono le alternative.
##
## Gruppi: "lmb" (clic sinistro) accetta solo abilità primarie, "rmb" solo secondarie, i tasti 1-4
## accettano qualunque abilità tattica (quelle con "slot" 1..4). L'eroe sceglie abilità e variante per
## ogni tasto nella finestra Abilità (K), salvate in HeroData.skills.
##
## Variante (rune): {"id", "name", "desc", "unlock" (facoltativo), "mods" (sostituisce chiavi),
##   "add" (somma a chiavi numeriche), "mul" (moltiplica chiavi numeriche)}.
##   Senza "unlock": livello dell'abilità + RUNE_UNLOCK_OFFSET[indice].
## Chiavi di effetto in più rispetto a hero_classes.gd (eseguite da core/abilities.gd):
##   dot, dot_time  – brucia: % del danno dell'arma al secondo per dot_time secondi
##   stun           – stordisce per N secondi (elite e boss la metà)
##   heal_hit       – ti cura di questa frazione dei danni inflitti
##   gain_hit       – risorsa guadagnata per ogni nemico colpito
##   pull           – (aree) attira i nemici verso il centro invece di respingerli
##   echo           – (area su punto) colpisce di nuovo dopo N secondi
##   self_buff      – potenziamento all'uso: {duration, damage, aspd, dr, move, crit, lifesteal}
##   crit_bonus     – +% probabilità di critico solo per questa abilità
##   move (buff)    – +% velocità di movimento (0.2 = 20%);  crit (buff) – +% critico (10 = 10%)

const RUNE_UNLOCK_OFFSET := [6, 14, 24]
## Livelli a cui si sbloccano le 3 caselle delle passive.
const PASSIVE_SLOTS := [10, 20, 30]

const RUNES := {
	# ---------------------------------------------------------------- Legionario
	"colpo_gladio": [
		{"id": "ardente", "name": "Lama ardente", "desc": "I colpi incendiano i nemici: 30% del danno dell'arma al secondo per 3 s.",
			"mods": {"dot": 0.3, "dot_time": 3.0, "color": Color(1.0, 0.5, 0.15)}},
		{"id": "centurione", "name": "Colpo del centurione", "desc": "Arco di 160° e +30% danni.",
			"mods": {"arc": 160.0}, "mul": {"dmg": 1.3}},
		{"id": "ferrea", "name": "Disciplina ferrea", "desc": "+4 Disciplina per colpo e ti cura del 2% dei danni.",
			"add": {"gain": 4.0}, "mods": {"heal_hit": 0.02}},
	],
	"pilum": [
		{"id": "esplosivo", "name": "Pilum esplosivo", "desc": "Il pilum esplode all'impatto in un raggio di 3 m.",
			"mods": {"explode_radius": 3.0, "pierce": false, "color": Color(1.0, 0.5, 0.15)}},
		{"id": "tre_pila", "name": "Tre pila", "desc": "Lancia tre pila a ventaglio (60% danni ciascuno).",
			"mods": {"count": 3, "spread": 30.0}, "mul": {"dmg": 0.6}},
		{"id": "stordente", "name": "Pilum stordente", "desc": "Stordisce per 1 s e costa 5 Disciplina in meno.",
			"mods": {"stun": 1.0}, "add": {"cost": -5.0}},
	],
	"testuggine": [
		{"id": "muro", "name": "Muro di scudi", "desc": "La riduzione dei danni dura 3 s in più.", "add": {"duration": 3.0}},
		{"id": "rovente", "name": "Testuggine rovente", "desc": "L'onda d'urto infligge il 250% e incendia i nemici.",
			"mul": {"dmg": 2.5}, "mods": {"dot": 0.5, "dot_time": 3.0, "color": Color(1.0, 0.5, 0.15)}},
		{"id": "contrattacco", "name": "Contrattacco", "desc": "Durante la Testuggine infliggi il 25% di danni in più.",
			"mods": {"damage": 0.25}},
	],
	"carica": [
		{"id": "cavalleria", "name": "Carica di cavalleria", "desc": "+6 m di distanza e +50% danni.",
			"add": {"distance": 6.0}, "mul": {"dmg": 1.5}},
		{"id": "stordente", "name": "Carica stordente", "desc": "I nemici travolti restano storditi per 1,5 s.", "mods": {"stun": 1.5}},
		{"id": "seconda", "name": "Seconda carica", "desc": "Tempo di ricarica dimezzato.", "mul": {"cooldown": 0.5}},
	],
	"grido_marte": [
		{"id": "guerra", "name": "Grido di guerra", "desc": "+15% danni in più (45% in tutto).", "add": {"damage": 0.15}},
		{"id": "medico", "name": "Grido del medico", "desc": "Cura il 30% della vita invece del 15%.", "add": {"heal_pct": 0.15}},
		{"id": "marcia", "name": "Grido di marcia", "desc": "+25% velocità d'attacco e +20% velocità di movimento.",
			"mods": {"aspd": 0.25, "move": 0.2}},
	],
	"bombardamento": [
		{"id": "salva_doppia", "name": "Doppia folgore", "desc": "Una seconda folgore colpisce 1 s dopo.", "mods": {"echo": 1.0}},
		{"id": "incendiario", "name": "Folgore incendiaria", "desc": "L'area brucia: 100% del danno dell'arma al secondo per 4 s.",
			"mods": {"dot": 1.0, "dot_time": 4.0}},
		{"id": "precisione", "name": "Folgore mirata", "desc": "Raggio di 3,5 m ma +80% danni e 10 Disciplina in meno.",
			"mods": {"radius": 3.5}, "mul": {"dmg": 1.8}, "add": {"cost": -10.0}},
	],
	"affondo": [
		{"id": "profondo", "name": "Affondo profondo", "desc": "+1,2 m di portata.", "add": {"range": 1.2}},
		{"id": "vampiro", "name": "Affondo vampiro", "desc": "Ti cura del 4% dei danni inflitti.", "mods": {"heal_hit": 0.04}},
		{"id": "rapido", "name": "Affondo rapido", "desc": "Colpisce il 30% più velocemente.", "mods": {"speed": 1.3}},
	],
	"colpo_scudo": [
		{"id": "rovente", "name": "Scudo rovente", "desc": "Incendia i nemici colpiti.", "mods": {"dot": 0.6, "dot_time": 3.0, "color": Color(1.0, 0.5, 0.15)}},
		{"id": "spinta", "name": "Spinta della legione", "desc": "Arco di 140° e spinta molto più forte.", "mods": {"arc": 140.0, "knock": 25.0}},
		{"id": "riparo", "name": "Riparo", "desc": "Dopo il colpo subisci il 30% di danni in meno per 3 s.",
			"mods": {"self_buff": {"duration": 3.0, "dr": 0.3}}},
	],
	"granata": [
		{"id": "incendiaria", "name": "Granata incendiaria", "desc": "L'area brucia per 4 s.", "mods": {"dot": 0.8, "dot_time": 4.0}},
		{"id": "stordente", "name": "Granata stordente", "desc": "Stordisce i nemici per 1,5 s.", "mods": {"stun": 1.5, "color": Color(0.8, 0.9, 1.0)}},
		{"id": "grappolo", "name": "Grappolo", "desc": "Una seconda esplosione 0,6 s dopo.", "mods": {"echo": 0.6}},
	],
	"terremoto_legione": [
		{"id": "scossa", "name": "Scossa", "desc": "Stordisce per 1 s.", "mods": {"stun": 1.0}},
		{"id": "ondate", "name": "Ondate", "desc": "Tre ondate da 60% (180% in tutto).", "mods": {"ticks": 3, "interval": 0.6}, "mul": {"dmg": 0.6}},
		{"id": "calpestio", "name": "Calpestio", "desc": "Attira i nemici verso di te.", "mods": {"pull": true}},
	],
	# ---------------------------------------------------------------- Gladiatore
	"doppio_fendente": [
		{"id": "fuoco", "name": "Fendenti di fuoco", "desc": "Incendiano i nemici per 3 s.", "mods": {"dot": 0.3, "dot_time": 3.0, "color": Color(1.0, 0.5, 0.15)}},
		{"id": "tre", "name": "Tre fendenti", "desc": "Tre colpi da 75%.", "mods": {"hits": 3}, "mul": {"dmg": 0.75}},
		{"id": "vampiro", "name": "Fendente vampiro", "desc": "Ti cura del 3% dei danni inflitti.", "mods": {"heal_hit": 0.03}},
	],
	"colpo_arena": [
		{"id": "stordente", "name": "Colpo stordente", "desc": "Stordisce per 1 s.", "mods": {"stun": 1.0}},
		{"id": "travolgente", "name": "Colpo travolgente", "desc": "Arco di 220° e +1 m di portata.", "mods": {"arc": 220.0}, "add": {"range": 1.0}},
		{"id": "sangue", "name": "Colpo del sangue", "desc": "+50% danni, costa 10 Furia in più.", "mul": {"dmg": 1.5}, "add": {"cost": 10.0}},
	],
	"balzo": [
		{"id": "terremoto", "name": "Balzo del terremoto", "desc": "+2,5 m di raggio e +50% danni.", "add": {"radius": 2.5}, "mul": {"dmg": 1.5}},
		{"id": "stordente", "name": "Atterraggio stordente", "desc": "Stordisce per 1,5 s.", "mods": {"stun": 1.5}},
		{"id": "leggero", "name": "Balzo leggero", "desc": "Tempo di ricarica dimezzato.", "mul": {"cooldown": 0.5}},
	],
	"turbine": [
		{"id": "sangue", "name": "Turbine di sangue", "desc": "Ti cura del 2% dei danni inflitti.", "mods": {"heal_hit": 0.02}},
		{"id": "fuoco", "name": "Turbine infuocato", "desc": "Incendia i nemici.", "mods": {"dot": 0.4, "dot_time": 2.0, "color": Color(1.0, 0.5, 0.15)}},
		{"id": "tornado", "name": "Tornado", "desc": "+1,5 m di raggio e attira i nemici.", "add": {"radius": 1.5}, "mods": {"pull": true}},
	],
	"rete": [
		{"id": "pesante", "name": "Rete pesante", "desc": "Stordisce per 1,5 s.", "mods": {"stun": 1.5}},
		{"id": "ampia", "name": "Rete ampia", "desc": "+2,5 m di raggio.", "add": {"explode_radius": 2.5}},
		{"id": "chiodata", "name": "Rete chiodata", "desc": "Triplica i danni.", "mul": {"dmg": 3.0}},
	],
	"favore_folla": [
		{"id": "ovazione", "name": "Ovazione", "desc": "Dura 4 s in più.", "add": {"duration": 4.0}},
		{"id": "furia", "name": "Furia della folla", "desc": "+25% danni durante l'effetto.", "mods": {"damage": 0.25}},
		{"id": "visibilio", "name": "Folla in visibilio", "desc": "Cura subito il 25% della vita.", "mods": {"heal_pct": 0.25}},
	],
	"tridente": [
		{"id": "stordente", "name": "Tridente stordente", "desc": "Stordisce per 0,3 s.", "mods": {"stun": 0.3}},
		{"id": "avido", "name": "Tridente avido", "desc": "+6 Furia per colpo.", "add": {"gain": 6.0}},
		{"id": "fiamma", "name": "Tridente fiammeggiante", "desc": "Incendia i nemici.", "mods": {"dot": 0.4, "dot_time": 3.0, "color": Color(1.0, 0.5, 0.15)}},
	],
	"scure_rotante": [
		{"id": "due", "name": "Due scuri", "desc": "Lancia due scuri.", "mods": {"count": 2, "spread": 20.0}},
		{"id": "esplosiva", "name": "Scure esplosiva", "desc": "Esplode all'impatto (3 m).", "mods": {"explode_radius": 3.0, "pierce": false}},
		{"id": "sanguinaria", "name": "Scure sanguinaria", "desc": "Ti cura del 4% dei danni.", "mods": {"heal_hit": 0.04}},
	],
	"grido_arena": [
		{"id": "intimidatorio", "name": "Grido intimidatorio", "desc": "Stordisce per 1 s.", "mods": {"stun": 1.0}},
		{"id": "vittoria", "name": "Grido di vittoria", "desc": "+20% danni per 6 s.",
			"mods": {"self_buff": {"duration": 6.0, "damage": 0.2, "dr": 0.2}}},
		{"id": "rigenerante", "name": "Grido rigenerante", "desc": "Cura il 15% della vita.", "mods": {"heal_pct": 0.15}},
	],
	"terremoto": [
		{"id": "faglia", "name": "Faglia ardente", "desc": "Incendia il terreno.", "mods": {"dot": 0.6, "dot_time": 3.0, "color": Color(1.0, 0.45, 0.1)}},
		{"id": "scossa", "name": "Scossa stordente", "desc": "Ogni scossa stordisce per 0,6 s.", "mods": {"stun": 0.6}},
		{"id": "sisma", "name": "Sisma", "desc": "+3 m di raggio.", "add": {"radius": 3.0}},
	],
	# ---------------------------------------------------------------- Sagittario
	"dardo": [
		{"id": "incendiario", "name": "Dardo incendiario", "desc": "Incendia i nemici.", "mods": {"dot": 0.4, "dot_time": 3.0, "color": Color(1.0, 0.55, 0.2)}},
		{"id": "doppio", "name": "Dardo doppio", "desc": "Due dardi da 70%.", "mods": {"count": 2, "spread": 10.0}, "mul": {"dmg": 0.7}},
		{"id": "perforante", "name": "Dardo perforante", "desc": "Trapassa i nemici.", "mods": {"pierce": true}},
	],
	"freccia_esplosiva": [
		{"id": "grappolo", "name": "Grappolo", "desc": "+2 m di raggio dell'esplosione.", "add": {"explode_radius": 2.0}},
		{"id": "stordente", "name": "Freccia stordente", "desc": "Stordisce per 1 s.", "mods": {"stun": 1.0}},
		{"id": "economica", "name": "Freccia economica", "desc": "Costa 10 Concentrazione in meno.", "add": {"cost": -10.0}},
	],
	"capriola": [
		{"id": "difensiva", "name": "Capriola difensiva", "desc": "Dopo la capriola subisci il 40% di danni in meno per 3 s.",
			"mods": {"self_buff": {"duration": 3.0, "dr": 0.4}}},
		{"id": "veloce", "name": "Capriola veloce", "desc": "Tempo di ricarica dimezzato.", "mul": {"cooldown": 0.5}},
		{"id": "esplosiva", "name": "Capriola esplosiva", "desc": "Colpisce i nemici sul percorso (150%).", "mods": {"dmg": 1.5, "knock": 6.0}},
	],
	"ventaglio": [
		{"id": "ampio", "name": "Ventaglio ampio", "desc": "Nove dardi su 90°.", "mods": {"count": 9, "spread": 90.0}},
		{"id": "perforante", "name": "Ventaglio perforante", "desc": "I dardi trapassano i nemici.", "mods": {"pierce": true}},
		{"id": "fuoco", "name": "Ventaglio di fuoco", "desc": "I dardi incendiano.", "mods": {"dot": 0.4, "dot_time": 3.0, "color": Color(1.0, 0.55, 0.2)}},
	],
	"trappola": [
		{"id": "stordente", "name": "Trappola stordente", "desc": "Stordisce per 2 s.", "mods": {"stun": 2.0}},
		{"id": "doppia", "name": "Doppia trappola", "desc": "Esplode due volte.", "mods": {"echo": 1.5}},
		{"id": "fuoco", "name": "Trappola di fuoco", "desc": "Incendia l'area per 4 s.", "mods": {"dot": 1.0, "dot_time": 4.0, "color": Color(1.0, 0.5, 0.15)}},
	],
	"pioggia_frecce": [
		{"id": "diluvio", "name": "Diluvio", "desc": "Dura 2 s in più.", "add": {"ticks": 4}},
		{"id": "fuoco", "name": "Pioggia di fuoco", "desc": "Incendia i nemici.", "mods": {"dot": 0.5, "dot_time": 2.0, "color": Color(1.0, 0.55, 0.2)}},
		{"id": "gelida", "name": "Pioggia gelida", "desc": "Rallenta del 60%.", "mods": {"slow": 0.6, "slow_time": 2.0, "color": Color(0.6, 0.85, 1.0)}},
	],
	"colpo_rapido": [
		{"id": "scarica", "name": "Scarica", "desc": "Tre dardi.", "mods": {"count": 3, "spread": 14.0}},
		{"id": "veleno", "name": "Dardi velenosi", "desc": "Avvelenano: 30% al secondo per 4 s.", "mods": {"dot": 0.3, "dot_time": 4.0, "color": Color(0.5, 1.0, 0.3)}},
		{"id": "rubavita", "name": "Dardi rubavita", "desc": "Ti curano del 2% dei danni.", "mods": {"heal_hit": 0.02}},
	],
	"freccia_catena": [
		{"id": "lunga", "name": "Catena lunga", "desc": "Rimbalza 3 volte in più.", "add": {"chain": 3}},
		{"id": "stordente", "name": "Catena stordente", "desc": "Stordisce per 0,5 s.", "mods": {"stun": 0.5}},
		{"id": "incendiaria", "name": "Catena incendiaria", "desc": "Incendia i nemici.", "mods": {"dot": 0.5, "dot_time": 3.0}},
	],
	"bolas": [
		{"id": "pesanti", "name": "Bolas pesanti", "desc": "Stordiscono per 1,5 s.", "mods": {"stun": 1.5}},
		{"id": "tripla", "name": "Bolas triple", "desc": "Lancia tre bolas.", "mods": {"count": 3, "spread": 30.0}},
		{"id": "esplosive", "name": "Bolas esplosive", "desc": "+100% danni e +1,5 m di raggio.", "mul": {"dmg": 2.0}, "add": {"explode_radius": 1.5}},
	],
	"mira_falco": [
		{"id": "occhio", "name": "Occhio di falco", "desc": "+10% probabilità di critico.", "mods": {"crit": 10.0}},
		{"id": "respiro", "name": "Respiro trattenuto", "desc": "+20% velocità d'attacco.", "mods": {"aspd": 0.2}},
		{"id": "lunga", "name": "Lunga mira", "desc": "Dura 6 s in più.", "add": {"duration": 6.0}},
	],
	# ---------------------------------------------------------------- Augure
	"fulmine": [
		{"id": "ramificato", "name": "Fulmine ramificato", "desc": "Rimbalza 3 volte in più.", "add": {"chain": 3}},
		{"id": "stordente", "name": "Fulmine stordente", "desc": "Stordisce per 0,3 s.", "mods": {"stun": 0.3}},
		{"id": "vampiro", "name": "Fulmine vampiro", "desc": "Ti cura del 2% dei danni.", "mods": {"heal_hit": 0.02}},
	],
	"sfera_vulcano": [
		{"id": "gemella", "name": "Sfera gemella", "desc": "Due sfere.", "mods": {"count": 2, "spread": 25.0}},
		{"id": "ardente", "name": "Sfera ardente", "desc": "L'esplosione incendia per 3 s.", "mods": {"dot": 1.0, "dot_time": 3.0}},
		{"id": "rapida", "name": "Sfera rapida", "desc": "Più veloce e costa 10 in meno.", "mods": {"speed": 28.0}, "add": {"cost": -10.0}},
	],
	"egida": [
		{"id": "riflettente", "name": "Egida riflettente", "desc": "Un'onda d'urto respinge i nemici (200%).",
			"mods": {"shockwave": 5.0, "dmg": 2.0, "knock": 12.0}},
		{"id": "duratura", "name": "Egida duratura", "desc": "Dura 4 s in più.", "add": {"duration": 4.0}},
		{"id": "cura", "name": "Egida della cura", "desc": "Cura il 40% della vita.", "add": {"heal_pct": 0.2}},
	],
	"passo_mercurio": [
		{"id": "tonante", "name": "Passo tonante", "desc": "All'arrivo colpisce i nemici vicini (200%).", "mods": {"dmg": 2.0, "radius": 4.0, "knock": 8.0}},
		{"id": "rapido", "name": "Passo rapido", "desc": "Si ricarica in meno della metà del tempo.", "mul": {"cooldown": 0.4}},
		{"id": "protetto", "name": "Passo protetto", "desc": "Dopo il teletrasporto subisci la metà dei danni per 2 s.",
			"mods": {"self_buff": {"duration": 2.0, "dr": 0.5}}},
	],
	"ira_nettuno": [
		{"id": "maremoto", "name": "Maremoto", "desc": "+3 m di raggio.", "add": {"radius": 3.0}},
		{"id": "gorgo", "name": "Gorgo", "desc": "Attira i nemici verso di te.", "mods": {"pull": true}},
		{"id": "gelida", "name": "Onda gelida", "desc": "Stordisce per 1 s.", "mods": {"stun": 1.0, "color": Color(0.7, 0.9, 1.0)}},
	],
	"meteora": [
		{"id": "pioggia", "name": "Pioggia di meteore", "desc": "Una seconda meteora 0,8 s dopo.", "mods": {"echo": 0.8}},
		{"id": "ardente", "name": "Meteora ardente", "desc": "L'area brucia: 200% al secondo per 4 s.", "mods": {"dot": 2.0, "dot_time": 4.0}},
		{"id": "gigante", "name": "Meteora gigante", "desc": "+3 m di raggio e +30% danni, costa 20 in più.",
			"add": {"radius": 3.0, "cost": 20.0}, "mul": {"dmg": 1.3}},
	],
	"dardo_arcano": [
		{"id": "gemello", "name": "Dardo gemello", "desc": "Due dardi.", "mods": {"count": 2, "spread": 12.0}},
		{"id": "ardente", "name": "Dardo ardente", "desc": "Incendia i nemici.", "mods": {"dot": 0.4, "dot_time": 3.0, "color": Color(1.0, 0.5, 0.2)}},
		{"id": "stordente", "name": "Dardo stordente", "desc": "Stordisce per 0,4 s.", "mods": {"stun": 0.4}},
	],
	"saetta": [
		{"id": "doppia", "name": "Doppia saetta", "desc": "Colpisce due volte.", "mods": {"echo": 0.4}},
		{"id": "stordente", "name": "Saetta stordente", "desc": "Stordisce per 1 s.", "mods": {"stun": 1.0}},
		{"id": "ampia", "name": "Saetta ampia", "desc": "+2 m di raggio.", "add": {"radius": 2.0}},
	],
	"anello_fuoco": [
		{"id": "inferno", "name": "Inferno", "desc": "+2 m di raggio.", "add": {"radius": 2.0}},
		{"id": "fenice", "name": "Fenice", "desc": "Ti cura del 3% dei danni inflitti.", "mods": {"heal_hit": 0.03}},
		{"id": "vortice", "name": "Vortice di fiamme", "desc": "Attira i nemici verso di te.", "mods": {"pull": true}},
	],
	"sciame_corvi": [
		{"id": "beccata", "name": "Beccate", "desc": "Rallentano del 50%.", "mods": {"slow": 0.5, "slow_time": 2.0}},
		{"id": "stormo", "name": "Stormo", "desc": "+2 m di raggio.", "add": {"radius": 2.0}},
		{"id": "presagio", "name": "Cattivo presagio", "desc": "+60% danni.", "mul": {"dmg": 1.6}},
	],
}

## Abilità alternative per classe (stesso formato di hero_classes.gd). "slot" = gruppo (vedi sopra).
const EXTRA := {
	"legionario": [
		{"id": "affondo", "name": "Affondo", "slot": "lmb", "unlock": 9, "kind": "melee",
			"dmg": 1.6, "range": 3.6, "arc": 45.0, "gain": 8.0, "color": Color(0.6, 0.95, 1.0),
			"desc": "Un affondo lungo e preciso con il gladio."},
		{"id": "colpo_scudo", "name": "Colpo di scudo", "slot": "rmb", "unlock": 11, "kind": "melee",
			"dmg": 3.0, "range": 2.6, "arc": 80.0, "cost": 20.0, "knock": 14.0, "stun": 0.8, "color": Color(1.0, 0.85, 0.4),
			"desc": "Colpisce con lo scutum: respinge e stordisce i nemici davanti."},
		{"id": "granata", "name": "Granata a frammentazione", "slot": "2", "unlock": 13, "kind": "aoe_point",
			"cost": 15.0, "cooldown": 6.0, "radius": 4.0, "delay": 0.6, "dmg": 3.2, "max_range": 14.0, "color": Color(1.0, 0.6, 0.2),
			"visual": "granata_energia", "desc": "Lancia una sfera di energia instabile che esplode dopo un istante."},
		{"id": "terremoto_legione", "name": "Passo della legione", "slot": "3", "unlock": 16, "kind": "aoe_self",
			"cost": 30.0, "cooldown": 12.0, "radius": 7.0, "dmg": 3.0, "knock": 10.0, "slow": 0.4, "slow_time": 3.0,
			"color": Color(0.9, 0.75, 0.4), "desc": "Batte il piede a terra: un'onda che respinge e rallenta tutti attorno."},
	],
	"gladiatore": [
		{"id": "tridente", "name": "Colpo di tridente", "slot": "lmb", "unlock": 9, "kind": "melee",
			"dmg": 1.5, "range": 3.4, "arc": 60.0, "gain": 10.0, "slow": 0.3, "slow_time": 2.0, "color": Color(0.7, 0.9, 1.0),
			"desc": "Colpo lungo di tridente che rallenta i nemici."},
		{"id": "scure_rotante", "name": "Scure rotante", "slot": "rmb", "unlock": 11, "kind": "projectile",
			"dmg": 2.8, "cost": 20.0, "speed": 20.0, "pierce": true, "max_range": 14.0, "length": 0.6, "thickness": 0.5,
			"color": Color(0.9, 0.8, 0.6), "visual": "scure_energia", "desc": "Lancia la scure avvolta dall'energia: trapassa i nemici."},
		{"id": "grido_arena", "name": "Grido dell'arena", "slot": "3", "unlock": 13, "kind": "aoe_self",
			"cooldown": 10.0, "radius": 7.0, "dmg": 0.5, "knock": 4.0, "slow": 0.5, "slow_time": 4.0, "gain": 40.0,
			"color": Color(1.0, 0.5, 0.2), "desc": "Un urlo che rallenta i nemici e genera 40 Furia."},
		{"id": "terremoto", "name": "Terremoto", "slot": "4", "unlock": 16, "kind": "aoe_self",
			"cost": 40.0, "cooldown": 12.0, "radius": 6.0, "ticks": 4, "interval": 0.5, "dmg": 1.2, "knock": 3.0,
			"color": Color(0.75, 0.55, 0.35), "desc": "Squassa il terreno attorno a te per 2 secondi."},
	],
	"sagittario": [
		{"id": "colpo_rapido", "name": "Colpo rapido", "slot": "lmb", "unlock": 9, "kind": "projectile",
			"dmg": 0.6, "count": 2, "spread": 8.0, "speed": 38.0, "gain": 6.0, "max_range": 22.0, "length": 0.8,
			"color": Color(0.8, 1.0, 0.5), "visual": "dardo_energia", "desc": "Due dardi di energia rapidissimi."},
		{"id": "freccia_catena", "name": "Freccia a catena", "slot": "rmb", "unlock": 11, "kind": "projectile",
			"dmg": 2.0, "cost": 25.0, "chain": 4, "speed": 30.0, "max_range": 22.0, "length": 1.0,
			"color": Color(0.5, 0.9, 1.0), "visual": "dardo_energia", "desc": "Un dardo di energia che rimbalza su 4 nemici."},
		{"id": "bolas", "name": "Bolas", "slot": "3", "unlock": 13, "kind": "projectile",
			"cooldown": 5.0, "dmg": 1.5, "speed": 20.0, "explode_radius": 2.5, "slow": 0.8, "slow_time": 2.5,
			"max_range": 16.0, "length": 0.5, "thickness": 0.5, "color": Color(0.9, 0.7, 0.4),
			"visual": "bolas_energia", "desc": "Bolas di energia che esplodono e quasi bloccano i nemici."},
		{"id": "mira_falco", "name": "Mira del falco", "slot": "4", "unlock": 16, "kind": "buff",
			"cooldown": 20.0, "duration": 8.0, "damage": 0.25, "color": Color(0.9, 0.95, 0.5),
			"desc": "+25% danni per 8 s."},
	],
	"augure": [
		{"id": "dardo_arcano", "name": "Dardo arcano", "slot": "lmb", "unlock": 9, "kind": "projectile",
			"dmg": 1.3, "speed": 30.0, "explode_radius": 1.5, "max_range": 20.0, "length": 0.6, "thickness": 0.3,
			"color": Color(0.8, 0.5, 1.0), "desc": "Un dardo arcano che esplode piano."},
		{"id": "saetta", "name": "Saetta di Giove", "slot": "rmb", "unlock": 11, "kind": "aoe_point",
			"cost": 25.0, "radius": 2.5, "delay": 0.2, "dmg": 3.5, "max_range": 20.0, "strike": true,
			"color": Color(0.7, 0.85, 1.0), "desc": "Una saetta dal cielo sul punto indicato."},
		{"id": "anello_fuoco", "name": "Anello di fuoco", "slot": "3", "unlock": 13, "kind": "aoe_self",
			"cost": 30.0, "cooldown": 10.0, "radius": 5.0, "ticks": 5, "interval": 0.6, "dmg": 0.8, "knock": 1.0,
			"color": Color(1.0, 0.45, 0.1), "desc": "Un anello di fiamme ti circonda per 3 secondi."},
		{"id": "sciame_corvi", "name": "Sciame di corvi", "slot": "4", "unlock": 16, "kind": "aoe_point",
			"cost": 35.0, "cooldown": 6.0, "radius": 4.0, "delay": 0.2, "ticks": 6, "interval": 0.4, "dmg": 0.7,
			"max_range": 18.0, "color": Color(0.55, 0.4, 1.0), "visual": "corvi_energia",
			"desc": "Evoca uno sciame di corvi di energia che si avventano sull'area."},
	],
}

## Passive: 3 caselle (PASSIVE_SLOTS). "stats" si sommano in HeroData.compute_stats
## (oltre agli affissi esistono armor_pct, life_pct, dr_pct, resource_regen_pct).
## Le passive con "special" sono eseguite da player.gd / abilities.gd (cerca has_passive).
const PASSIVES := {
	"legionario": [
		{"id": "veterano", "name": "Veterano", "unlock": 10, "desc": "+15% vita massima.", "stats": [["life_pct", 15.0]]},
		{"id": "disciplina_ferro", "name": "Disciplina di ferro", "unlock": 12, "desc": "+25% armatura.", "stats": [["armor_pct", 25.0]]},
		{"id": "furia_legione", "name": "Furia della legione", "unlock": 15, "desc": "+10% danni.", "stats": [["damage_pct", 10.0]]},
		{"id": "baluardo", "name": "Ultimo baluardo", "unlock": 20, "special": true,
			"desc": "Sotto il 35% di vita subisci il 25% di danni in meno."},
		{"id": "rifornimento", "name": "Rifornimento", "unlock": 25, "desc": "+30% rigenerazione di Disciplina.", "stats": [["resource_regen_pct", 30.0]]},
		{"id": "gloria", "name": "Gloria in battaglia", "unlock": 30, "special": true, "desc": "Ogni nemico ucciso ti cura del 2% della vita."},
	],
	"gladiatore": [
		{"id": "brutalita", "name": "Brutalità", "unlock": 10, "desc": "+30% danno critico.", "stats": [["crit_damage", 30.0]]},
		{"id": "ritmo", "name": "Ritmo dell'arena", "unlock": 12, "desc": "+8% velocità d'attacco.", "stats": [["attack_speed_pct", 8.0]]},
		{"id": "pelle_dura", "name": "Pelle dura", "unlock": 15, "desc": "Subisci il 10% di danni in meno.", "stats": [["dr_pct", 10.0]]},
		{"id": "rabbia", "name": "Rabbia inesauribile", "unlock": 20, "desc": "Generi 3 Furia al secondo.", "stats": [["resource_regen_flat", 3.0]]},
		{"id": "sete", "name": "Sete di sangue", "unlock": 25, "special": true, "desc": "Ogni nemico ucciso ti cura del 3% della vita."},
		{"id": "favorito", "name": "Favorito del pubblico", "unlock": 30, "desc": "+30% sesterzi trovati e +8% velocità di movimento.",
			"stats": [["gold_find", 30.0], ["move_speed_pct", 8.0]]},
	],
	"sagittario": [
		{"id": "occhio_aquila", "name": "Occhio d'aquila", "unlock": 10, "desc": "+6% probabilità di critico.", "stats": [["crit_chance", 6.0]]},
		{"id": "passo_leggero", "name": "Passo leggero", "unlock": 12, "desc": "+12% velocità di movimento.", "stats": [["move_speed_pct", 12.0]]},
		{"id": "cecchino", "name": "Cecchino", "unlock": 15, "special": true, "desc": "+20% danni ai nemici a più di 10 m."},
		{"id": "concentrazione", "name": "Concentrazione", "unlock": 20, "desc": "+30% rigenerazione di Concentrazione.", "stats": [["resource_regen_pct", 30.0]]},
		{"id": "arciere_esperto", "name": "Arciere esperto", "unlock": 25, "desc": "+10% velocità d'attacco.", "stats": [["attack_speed_pct", 10.0]]},
		{"id": "sangue_freddo", "name": "Sangue freddo", "unlock": 30, "desc": "-10% tempo di ricarica.", "stats": [["cdr_pct", 10.0]]},
	],
	"augure": [
		{"id": "favore", "name": "Favore degli dèi", "unlock": 10, "desc": "+35% rigenerazione di Favore divino.", "stats": [["resource_regen_pct", 35.0]]},
		{"id": "saggezza", "name": "Saggezza", "unlock": 12, "desc": "-12% tempo di ricarica.", "stats": [["cdr_pct", 12.0]]},
		{"id": "furore", "name": "Furore celeste", "unlock": 15, "desc": "+35% danno critico.", "stats": [["crit_damage", 35.0]]},
		{"id": "protezione", "name": "Protezione divina", "unlock": 20, "desc": "Subisci il 12% di danni in meno.", "stats": [["dr_pct", 12.0]]},
		{"id": "sapienza", "name": "Sapienza antica", "unlock": 25, "desc": "+12% danni.", "stats": [["damage_pct", 12.0]]},
		{"id": "ultraterreno", "name": "Vita ultraterrena", "unlock": 30, "desc": "+15% vita massima.", "stats": [["life_pct", 15.0]]},
	],
}

## Poteri leggendari che modificano un'abilità (stesso formato delle varianti).
const POWER_MODS := {
	"mario": {"ability": "pilum", "mods": {"count": 3, "spread": 25.0}},
	"orazio": {"ability": "testuggine", "add": {"duration": 4.0}, "mods": {"stun": 1.5}},
	"germanico": {"ability": "bombardamento", "mods": {"echo": 0.8}},
	"flamma": {"ability": "turbine", "add": {"radius": 2.0}, "mods": {"dot": 0.6, "dot_time": 2.0}},
	"prisco": {"ability": "rete", "add": {"explode_radius": 1.5}, "mods": {"stun": 2.0}},
	"vero": {"ability": "balzo", "mul": {"cooldown": 0.5, "dmg": 2.0}},
	"teucro": {"ability": "ventaglio", "add": {"count": 4, "spread": 30.0}},
	"archimede": {"ability": "freccia_esplosiva", "add": {"explode_radius": 2.5}, "mul": {"dmg": 1.5}},
	"cacciatore": {"ability": "pioggia_frecce", "mul": {"ticks": 2.0}},
	"sibilla": {"ability": "fulmine", "add": {"chain": 4}},
	"vulcano": {"ability": "sfera_vulcano", "add": {"cost": -10.0}, "mods": {"dot": 1.5, "dot_time": 3.0}},
	"numa": {"ability": "meteora", "mods": {"echo": 0.6}},
}


## Tipo di danno di ogni abilità (ItemDB.ELEMENTS); quelle non elencate sono "fisico".
const ELEMENTS := {
	"pilum": "fulmine", "bombardamento": "fuoco", "granata": "fuoco",
	"rete": "fulmine",
	"dardo": "fulmine", "freccia_esplosiva": "fuoco", "ventaglio": "fulmine", "trappola": "freddo", "freccia_catena": "fulmine",
	"fulmine": "fulmine", "sfera_vulcano": "fuoco", "passo_mercurio": "fulmine", "ira_nettuno": "freddo", "meteora": "fuoco",
	"dardo_arcano": "fulmine", "saetta": "fulmine", "anello_fuoco": "fuoco",
}
## Varianti che cambiano il tipo di danno ("abilità:variante").
const RUNE_ELEMENTS := {
	"colpo_gladio:ardente": "fuoco", "pilum:esplosivo": "fuoco", "testuggine:rovente": "fuoco", "colpo_scudo:rovente": "fuoco",
	"doppio_fendente:fuoco": "fuoco", "turbine:fuoco": "fuoco", "tridente:fiamma": "fuoco", "terremoto:faglia": "fuoco",
	"dardo:incendiario": "fuoco", "ventaglio:fuoco": "fuoco", "trappola:fuoco": "fuoco", "pioggia_frecce:fuoco": "fuoco",
	"pioggia_frecce:gelida": "freddo", "freccia_catena:incendiaria": "fuoco", "ira_nettuno:gelida": "freddo",
	"dardo_arcano:ardente": "fuoco", "granata:stordente": "freddo", "sfera_vulcano:rapida": "fuoco",
}


## Tutte le abilità della classe (base + alternative).
static func all_abilities(class_id: String) -> Array:
	return (HeroClasses.get_data(class_id)["abilities"] as Array) + (EXTRA.get(class_id, []) as Array)


static func find_ability(class_id: String, id: String) -> Dictionary:
	for ab: Dictionary in all_abilities(class_id):
		if ab["id"] == id:
			return ab
	return {}


## Abilità che si possono mettere su un tasto ("lmb", "rmb" o "1".."4").
static func pool_for_slot(class_id: String, slot: String) -> Array:
	var out: Array = []
	for ab: Dictionary in all_abilities(class_id):
		var g := String(ab["slot"])
		if g == slot or (slot in ["1", "2", "3", "4"] and g in ["1", "2", "3", "4"]):
			out.append(ab)
	return out


static func runes(ability_id: String) -> Array:
	return RUNES.get(ability_id, [])


static func rune_unlock(ab: Dictionary, index: int) -> int:
	var r: Dictionary = runes(String(ab["id"]))[index]
	return int(r.get("unlock", int(ab.get("unlock", 1)) + RUNE_UNLOCK_OFFSET[mini(index, 2)]))


static func find_rune(ability_id: String, rune_id: String) -> Dictionary:
	for r: Dictionary in runes(ability_id):
		if r["id"] == rune_id:
			return r
	return {}


static func passives(class_id: String) -> Array:
	return PASSIVES.get(class_id, [])


static func find_passive(class_id: String, id: String) -> Dictionary:
	for p: Dictionary in passives(class_id):
		if p["id"] == id:
			return p
	return {}


## Applica una modifica (variante o potere) a una copia dell'abilità.
static func apply_mod(ab: Dictionary, m: Dictionary) -> void:
	var mods: Dictionary = m.get("mods", {})
	for k: String in mods:
		ab[k] = mods[k]
	var add: Dictionary = m.get("add", {})
	for k: String in add:
		var v: Variant = ab.get(k, 0)
		ab[k] = (int(v) + int(add[k])) if (v is int and add[k] is int) else float(v) + float(add[k])
	var mul: Dictionary = m.get("mul", {})
	for k: String in mul:
		var v: Variant = ab.get(k, 0)
		ab[k] = roundi(float(v) * float(mul[k])) if v is int else float(v) * float(mul[k])
	if ab.has("cost"):
		ab["cost"] = maxf(0.0, float(ab["cost"]))


## Abilità effettiva su un tasto: base + variante + poteri leggendari. slot = tasto a cui è assegnata.
static func resolve(class_id: String, slot: String, ability_id: String, rune_id: String, powers: Dictionary) -> Dictionary:
	var base := find_ability(class_id, ability_id)
	if base.is_empty():
		return {}
	var ab := base.duplicate(true)
	ab["group"] = base["slot"]
	ab["slot"] = slot
	ab["rune"] = ""
	ab["element"] = String(ELEMENTS.get(ability_id, "fisico"))
	if RUNE_ELEMENTS.has(ability_id + ":" + rune_id):
		ab["element"] = String(RUNE_ELEMENTS[ability_id + ":" + rune_id])
	if rune_id != "":
		var r := find_rune(ability_id, rune_id)
		if not r.is_empty():
			apply_mod(ab, r)
			ab["rune"] = rune_id
			ab["rune_name"] = r["name"]
	for pw: String in powers:
		var pm: Dictionary = POWER_MODS.get(pw, {})
		if not pm.is_empty() and pm["ability"] == ability_id:
			apply_mod(ab, pm)
	return ab


## Testo del potere di un leggendario che modifica un'abilità (per controllare i dati).
static func power_ability(power: String) -> String:
	return String((POWER_MODS.get(power, {}) as Dictionary).get("ability", ""))


## Nomi di ciò che si sblocca a un livello (abilità, varianti, caselle e passive), per il messaggio.
static func unlocks_at(class_id: String, lvl: int) -> Array:
	var out: Array = []
	for ab: Dictionary in all_abilities(class_id):
		if int(ab.get("unlock", 1)) == lvl:
			out.append(String(ab["name"]))
		var rs := runes(String(ab["id"]))
		for i in rs.size():
			if rune_unlock(ab, i) == lvl:
				out.append("%s: %s" % [ab["name"], rs[i]["name"]])
	if lvl in PASSIVE_SLOTS:
		out.append("casella passiva")
	for p: Dictionary in passives(class_id):
		if int(p.get("unlock", 1)) == lvl:
			out.append("passiva %s" % p["name"])
	return out
