class_name SoundDB
extends RefCounted
## Catalogo dei suoni (vedi docs/AUDIO_AI.md per i testi con cui generarli).
## Ogni suono è un nome; i file vanno in res://audio/sfx/ come <nome>.ogg / .wav, oppure in più versioni
## <nome>_1.ogg, <nome>_2.ogg... (il gioco ne sceglie una a caso ogni volta: niente "mitragliatrice").
## Finché un file manca si sente il suono sintetizzato di riserva ("fallback", core/sfx.gd); "" = silenzio
## (es. i passi: meglio niente che un bip).
##   SOUNDS[nome] = [fallback sintetizzato, volume in dB da aggiungere]

const SOUNDS := {
	# --- Combattimento dell'eroe ---
	"fendente": ["swing", -6.0], "fendente_pesante": ["swing", -4.0], "turbine": ["swing", -4.0],
	"colpo_fisico": ["hit", -3.0], "colpo_fuoco": ["hit", -3.0], "colpo_freddo": ["hit", -3.0], "colpo_fulmine": ["hit", -3.0],
	"critico": ["crit", 0.0], "colpo_scudo": ["hit", -2.0],
	# --- Abilità ---
	"pilum": ["projectile", -4.0], "dardo": ["projectile", -7.0], "sfera_fuoco": ["projectile", -4.0],
	"lancio_fulmine": ["projectile", -5.0], "rete": ["projectile", -4.0], "bolas": ["projectile", -4.0],
	"scure_lancio": ["projectile", -4.0], "granata": ["projectile", -4.0], "trappola": ["cast", -4.0],
	"raggio_orbitale": ["cast", -2.0], "meteora": ["cast", -3.0], "saetta": ["explosion", -2.0],
	"pioggia_dardi": ["cast", -4.0], "corvi": ["cast", -4.0], "terremoto": ["explosion", -3.0],
	"onda_urto": ["explosion", -4.0], "ondata": ["explosion", -4.0], "anello_fuoco": ["explosion", -4.0],
	"grido_guerra": ["cast", -2.0], "folla": ["cast", -4.0], "scudo": ["cast", -4.0], "concentrazione": ["cast", -5.0],
	"carica": ["dash", -3.0], "capriola": ["dash", -5.0], "balzo": ["dash", -4.0], "atterraggio": ["explosion", -3.0],
	"teletrasporto": ["portal", -8.0], "lancio_magia": ["cast", -5.0],
	# --- Esplosioni ---
	"esplosione_fisico": ["explosion", -4.0], "esplosione_fuoco": ["explosion", -3.0],
	"esplosione_freddo": ["explosion", -4.0], "esplosione_fulmine": ["explosion", -3.0],
	# --- Eroe ---
	"passo_terra": ["", -16.0], "passo_pietra": ["", -16.0],
	"eroe_ferito_m": ["player_hurt", -3.0], "eroe_ferito_f": ["player_hurt", -3.0],
	"eroe_morte_m": ["enemy_die", 0.0], "eroe_morte_f": ["enemy_die", 0.0],
	"pozione": ["potion", 0.0], "globo_vita": ["potion", -6.0], "livello": ["levelup", 0.0],
	# --- Nemici (per famiglia: vedi ENEMY_FAMILY) ---
	"umano_attacco": ["enemy_attack", -8.0], "umano_morte": ["enemy_die", -3.0],
	"lupo_attacco": ["enemy_attack", -8.0], "lupo_morte": ["enemy_die", -3.0],
	"macchina_attacco": ["enemy_attack", -8.0], "macchina_morte": ["enemy_die", -3.0],
	"spettro_attacco": ["enemy_attack", -8.0], "spettro_morte": ["enemy_die", -3.0],
	"granchio_attacco": ["enemy_attack", -8.0], "granchio_morte": ["enemy_die", -3.0],
	"proiettile_nemico": ["projectile", -8.0], "boss_ruggito": ["enemy_die", 0.0], "boss_attacco": ["explosion", -4.0],
	# --- Mondo ---
	"forziere": ["chest", 0.0], "rottura": ["break", 0.0], "altare": ["checkpoint", 0.0], "santuario": ["checkpoint", 0.0],
	"portale": ["portal", 0.0], "ingresso_dungeon": ["portal", 0.0], "cancello": ["portal", 0.0],
	"evento_inizio": ["portal", 0.0], "evento_fine": ["levelup", 0.0], "missione_nuova": ["checkpoint", -6.0],
	"missione_compiuta": ["legendary", -4.0], "ricompensa": ["legendary", 0.0], "guardiano": ["portal", 0.0],
	# --- Bottino ---
	"monete": ["gold", 0.0], "raccogli": ["pickup", 0.0], "gemma": ["pickup", 0.0],
	"drop_raro": ["rare_drop", 0.0], "drop_leggendario": ["legendary", 0.0],
	# --- Città e interfaccia ---
	"npc_saluto": ["talk", 0.0], "monete_borsa": ["coins", 0.0], "fabbro": ["anvil", 0.0], "smonta": ["anvil", -4.0],
	"incastona": ["anvil", -8.0], "potenziamento_ok": ["anvil", 0.0], "potenziamento_fallito": ["hit", 0.0],
	"clic": ["ui_click", 0.0], "zaino": ["ui_click", -4.0], "equipaggia": ["pickup", -2.0], "errore": ["ui_click", -6.0],
}

## Famiglia di suoni di ogni nemico (EnemyDB): <famiglia>_attacco, <famiglia>_morte.
const ENEMY_FAMILY := {
	"predone": "umano", "barbaro": "umano", "frombolier": "umano", "bruto": "umano", "rinnegato": "umano",
	"pirata": "umano", "arpionatore": "umano", "vulso": "umano", "tharvo": "umano", "brenno": "umano",
	"lupo": "lupo", "drone": "macchina", "automa": "macchina", "lemure": "spettro", "custode": "spettro",
	"granchio": "granchio", "madre_granchi": "granchio",
}

## Suono al lancio di un'abilità (id -> suono). Le abilità non elencate usano il suono del loro tipo (cast_sound).
const ABILITY := {
	"colpo_gladio": "fendente", "affondo": "fendente", "doppio_fendente": "fendente",
	"colpo_arena": "fendente_pesante", "tridente": "fendente_pesante", "colpo_scudo": "colpo_scudo",
	"pilum": "pilum", "dardo": "dardo", "colpo_rapido": "dardo", "ventaglio": "dardo", "freccia_catena": "dardo",
	"freccia_esplosiva": "dardo", "sfera_vulcano": "sfera_fuoco", "fulmine": "lancio_fulmine", "dardo_arcano": "lancio_fulmine",
	"rete": "rete", "bolas": "bolas", "scure_rotante": "scure_lancio", "granata": "granata", "trappola": "trappola",
	"bombardamento": "raggio_orbitale", "meteora": "meteora", "saetta": "lancio_magia", "pioggia_frecce": "pioggia_dardi",
	"sciame_corvi": "corvi", "terremoto": "terremoto", "terremoto_legione": "terremoto", "ira_nettuno": "ondata",
	"anello_fuoco": "anello_fuoco", "turbine": "turbine", "grido_arena": "grido_guerra", "grido_marte": "grido_guerra",
	"favore_folla": "folla", "testuggine": "scudo", "egida": "scudo", "mira_falco": "concentrazione",
	"carica": "carica", "capriola": "capriola", "balzo": "balzo", "passo_mercurio": "teletrasporto",
}
## Suono dell'impatto per le aree a colpo singolo che non esplodono "per elemento".
const IMPACT := {"saetta": "saetta", "terremoto_legione": "terremoto", "testuggine": "onda_urto"}


static func cast_sound(ab: Dictionary) -> String:
	var id := String(ab.get("id", ""))
	if ABILITY.has(id):
		return ABILITY[id]
	match String(ab.get("kind", "")):
		"melee": return "fendente"
		"projectile": return "lancio_fulmine" if String(ab.get("element", "")) == "fulmine" else "dardo"
		"dash": return "carica"
	return "lancio_magia"


static func hit_sound(element: String, crit: bool = false) -> String:
	if crit:
		return "critico"
	return "colpo_" + (element if element in ["fuoco", "freddo", "fulmine"] else "fisico")


static func explosion_sound(element: String) -> String:
	return "esplosione_" + (element if element in ["fuoco", "freddo", "fulmine"] else "fisico")


static func enemy_family(enemy_id: String) -> String:
	return ENEMY_FAMILY.get(enemy_id, "umano")


## Volume aggiuntivo del suono (dB).
static func volume(sound: String) -> float:
	return float((SOUNDS.get(sound, ["", 0.0]) as Array)[1])


## Suono sintetizzato di riserva ("" = nessuno). Un nome non nel catalogo usa sé stesso (suoni vecchi).
static func fallback(sound: String) -> String:
	return String((SOUNDS[sound] as Array)[0]) if SOUNDS.has(sound) else sound
