class_name NpcDB
extends RefCounted
## Personaggi non giocanti (città di Ostia Nova e futuri hub).
## Tutti i DIALOGHI stanno qui: quando scriverai la trama basta cambiare i testi
## (cerca "[TRAMA]"). Nessun testo di storia è scritto dentro le scene.
##
##   role     "vendor" (mercante: apre il negozio), "smith" (fabbro: smonta/forgia), "talk" (solo dialogo)
##   title    mestiere mostrato sotto il nome
##   text     dialogo principale (finestra con il testo). Può contenere BBCode ([b], [i], [color]).
##   lines    frasi brevi casuali dette passandoci vicino o cliccando (al posto di text se text è vuoto)
##   model    scena del modello 3D (sostituibile con un modello Tripo, rivolto verso −Z)

const DATA := {
	"mercante": {
		"name": "Tito Mercatore", "role": "vendor", "title": "Mercante",
		"model": "res://scenes/npcs/mercante.tscn",
		"lines": ["Merce fresca dai cantieri orbitali!", "Si paga in sesterzi, non in promesse.",
			"Questa? Appartenne a un tribuno. Più o meno.", "Comprare, vendere... è tutto commercio, amico."],
		"text": "",
	},
	"fabbro": {
		"name": "Decimo Ferrario", "role": "smith", "title": "Fabbro",
		"model": "res://scenes/npcs/fabbro.tscn",
		"lines": ["Portami ferraglia e ti restituisco un'arma.", "Il plasma si tempera come il ferro: col fuoco e con la pazienza.",
			"Smonto tutto. Anche i ricordi, se paghi abbastanza."],
		"text": "",
	},
	"prefetto": {
		"name": "Aulo Vetranio", "role": "talk", "title": "Prefetto di Ostia Nova",
		"model": "res://scenes/npcs/prefetto.tscn",
		"lines": [],
		"text": "Sei arrivato dalla campagna? Allora hai visto con i tuoi occhi cosa sta succedendo là fuori.\n\n[TRAMA: il prefetto spiega la situazione della città e affida all'eroe la prossima missione (atto 2: il porto).]",
	},
	"vestale": {
		"name": "Lucilla", "role": "talk", "title": "Vestale del tempio",
		"model": "res://scenes/npcs/vestale.tscn",
		"lines": [],
		"text": "Il fuoco sacro trema da giorni, come se avesse paura di qualcosa.\n\n[TRAMA: presagi, leggende sugli dèi, indizi sul nemico principale.]",
	},
	"guardia": {
		"name": "Guardia urbana", "role": "talk", "title": "Vigiles",
		"model": "res://scenes/npcs/guardia.tscn",
		"lines": ["Il porto è chiuso per ordine del prefetto.", "Tieni il gladio nel fodero, in città.",
			"Hai visto Brenno, fuori dalle mura? Dicono che sia stato un centurione, una volta.",
			"Di notte si sentono i lemuri cantare lungo la Via dei Sepolcri."],
		"text": "",
	},
	"cittadino": {
		"name": "Cittadino", "role": "talk", "title": "",
		"model": "res://scenes/npcs/cittadino.tscn",
		"lines": ["Le navette non arrivano più da Nova Roma da tre settimane.", "Il pane costa il doppio. E i droni del grano sono spariti.",
			"Mio cugino è partito per le colonie di Marte. Fortunato lui.", "Hai l'aria di uno che sa usare quell'arma.",
			"Il mercante Tito vende di tutto. Il fabbro Decimo aggiusta di tutto."],
		"text": "",
	},
}

const ROLE_COLORS := {"vendor": Color(1.0, 0.85, 0.3), "smith": Color(1.0, 0.55, 0.2), "talk": Color(0.9, 0.9, 0.9)}


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["cittadino"])
