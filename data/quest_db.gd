class_name QuestDB
extends RefCounted
## Missioni. Tutto è guidato dai dati: per scrivere la trama basta cambiare i TESTI qui sotto
## (cerca "[TRAMA]"); per aggiungere una missione aggiungi una voce a QUESTS.
##
##   title      nome mostrato nel diario e nel tracciatore
##   act        atto (1, 2...)
##   giver      id dell'NPC che la affida (data/npc_db.gd). "" = parte da sola appena i requisiti sono soddisfatti
##   requires   missioni da completare prima
##   offer      testo mostrato quando l'NPC la affida (la missione viene accettata subito, come in Diablo 3)
##   desc       descrizione nel diario (tasto J)
##   on_start   flag messo a true quando parte (es. "porto_aperto" apre il cancello del porto)
##   steps      obiettivi IN SEQUENZA. Tipi:
##                kill         uccidi `count` nemici di tipo `target` (id di enemy_db; "" = qualsiasi)
##                kill_unique  uccidi il boss `target`
##                enter        entra nel livello `target` (id di Game.LEVELS)
##                altar        attiva l'altare `target` (checkpoint_id)
##                talk         parla con l'NPC `target`; `say` = cosa risponde
##                salvage      smonta `count` oggetti dal fabbro
##                chest        apri il forziere con flag_id `target` ("" = qualsiasi forziere)
##   outro      testo mostrato al completamento (facoltativo)
##   reward     {"xp", "gold", "item": rarità 0-3, "mats": {materiale: quantità}}

const QUESTS := {
	# ===================================== ATTO 1 =====================================
	"verso_ostia": {
		"title": "Verso Ostia Nova", "act": 1, "giver": "", "requires": [],
		"desc": "Raggiungi Ostia Nova lungo la Via. [TRAMA: perché il protagonista lascia la villa.]",
		"offer": "",
		"steps": [
			{"type": "kill_unique", "target": "brenno", "text": "Sconfiggi chi blocca la porta di Ostia Nova"},
			{"type": "enter", "target": "ostia_nova", "text": "Entra a Ostia Nova"},
			{"type": "talk", "target": "prefetto", "text": "Parla con il prefetto davanti alla basilica",
				"say": "Hai sconfitto Brenno? Allora la Via è di nuovo libera. Ostia Nova ti deve un favore.\n\n[TRAMA: il prefetto racconta cosa sta succedendo e chi c'è dietro i rinnegati.]"},
		],
		"outro": "",
		"reward": {"xp": 400, "gold": 300},
	},
	"ferri_del_mestiere": {
		"title": "Ferri del mestiere", "act": 1, "giver": "fabbro", "requires": [],
		"desc": "Il fabbro Decimo vuole vedere se sai riconoscere il buon metallo.",
		"offer": "Nuovo in città? Portami qualcosa da smontare: tre oggetti qualsiasi. Ti insegno come si recupera il bronzo buono.\n\n[color=#c8a050]Clic destro su un oggetto dello zaino con il pannello del fabbro aperto.[/color]",
		"steps": [
			{"type": "salvage", "target": "", "count": 3, "text": "Smonta 3 oggetti dal fabbro"},
			{"type": "talk", "target": "fabbro", "text": "Torna dal fabbro Decimo",
				"say": "Visto? Niente si butta. Tieni, per il disturbo."},
		],
		"reward": {"gold": 150, "mats": {"essenza": 3}},
	},
	"fuoco_tremante": {
		"title": "Il fuoco tremante", "act": 1, "giver": "vestale", "requires": ["verso_ostia"],
		"desc": "La vestale Lucilla chiede di placare i lemuri che infestano la campagna.",
		"offer": "Il fuoco di Vesta trema ogni volta che un lemure cammina tra i vivi. Lungo la Via dei Sepolcri ce ne sono troppi.\n\nRiportali al loro riposo: dodici basteranno a calmare la fiamma.\n\n[TRAMA: legame tra i lemuri e il nemico principale.]",
		"steps": [
			{"type": "kill", "target": "lemure", "count": 12, "text": "Sconfiggi i lemuri nella campagna"},
			{"type": "talk", "target": "vestale", "text": "Torna dalla vestale Lucilla",
				"say": "La fiamma è tornata ferma. Che Vesta ti protegga, ovunque tu vada."},
		],
		"reward": {"xp": 350, "item": 2},
	},
	# ===================================== ATTO 2 =====================================
	"porto_sbarrato": {
		"title": "Il porto sbarrato", "act": 2, "giver": "prefetto", "requires": ["verso_ostia"],
		"desc": "Il porto di Ostia Nova è in mano ai pirati cilici. Il prefetto ha aperto il cancello nord per te.",
		"offer": "C'è un'altra cosa. Il porto è caduto: i pirati cilici hanno preso i moli e lo spazioporto, e nessuna nave arriva più da Nova Roma.\n\nHo fatto aprire il cancello nord. Trova il loro capo, Vulso il Corsaro, e restituisci il porto all'Impero.\n\n[TRAMA: chi ha mandato i pirati, cosa cercano.]",
		"on_start": "porto_aperto",
		"steps": [
			{"type": "enter", "target": "level_03_porto", "text": "Attraversa il cancello nord verso il porto"},
			{"type": "altar", "target": "porto_cantiere", "text": "Raggiungi i cantieri navali"},
			{"type": "kill_unique", "target": "vulso", "text": "Sconfiggi Vulso il Corsaro al faro"},
			{"type": "talk", "target": "prefetto", "text": "Torna dal prefetto a Ostia Nova",
				"say": "Il faro è di nuovo nostro! Le navi potranno tornare.\n\n[TRAMA: cosa avete scoperto sul faro; aggancio all'atto 3.]"},
		],
		"outro": "",
		"reward": {"xp": 1500, "gold": 800, "item": 3},
	},
	"casse_rubate": {
		"title": "Merce rubata", "act": 2, "giver": "mercante", "requires": ["verso_ostia"],
		"desc": "Il mercante Tito rivuole le casse che i pirati gli hanno rubato dai magazzini del porto.",
		"offer": "I pirati hanno svuotato il mio magazzino del sale! Le mie casse migliori sono finite nel loro covo, oltre i magazzini.\n\nRiportami ciò che è mio e saprò essere generoso. Più o meno.",
		"steps": [
			{"type": "chest", "target": "chest_porto_sale", "text": "Recupera le casse nel magazzino del sale (porto)"},
			{"type": "talk", "target": "mercante", "text": "Torna dal mercante Tito",
				"say": "Le mie casse! Beh, quasi tutte. Ecco la tua parte, e non dirlo a nessuno."},
		],
		"reward": {"gold": 600, "item": 2},
	},
	"pirati_cilici": {
		"title": "Ripulire i moli", "act": 2, "giver": "guardia", "requires": ["verso_ostia"],
		"desc": "Le guardie urbane chiedono aiuto contro i pirati del porto.",
		"offer": "Siamo troppo pochi per riprendere i moli. Se ci vai, abbattine quanti più puoi: trenta pirati e il porto respirerà.",
		"steps": [
			{"type": "kill", "target": "pirata", "count": 30, "text": "Sconfiggi i pirati cilici al porto"},
			{"type": "talk", "target": "guardia", "text": "Torna da una guardia a Ostia Nova",
				"say": "Trenta! Ne parleranno nelle taverne per settimane."},
		],
		"reward": {"xp": 800, "gold": 400},
	},
}

## Ordine in cui mostrare le missioni nel diario.
const ORDER := ["verso_ostia", "ferri_del_mestiere", "fuoco_tremante", "porto_sbarrato", "casse_rubate", "pirati_cilici"]


static func get_data(id: String) -> Dictionary:
	return QUESTS.get(id, {})
