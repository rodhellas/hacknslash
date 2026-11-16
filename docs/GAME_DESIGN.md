# Game design – Legio 3000

## Concept
- Genere: action RPG / hack n slash isometrico, **come Diablo 3** (mappe grandi quasi a percorso ma esplorabili, nemici a gruppi in zone, loot casuale, classi).
- **Niente roguelike**: i livelli sono fatti a mano.
- Ambientazione: l'**Impero Romano nel 3000 d.C.** L'Impero non è mai caduto. Tecnologia sci-fi con estetica romana: gladi al plasma, scuta a campo di forza, pila elettromagnetici, droni, navette, legionari cyborg, culti degli dèi come forze "divine".
- L'idea iniziale (Bud Spencer e Terence Hill nel mondo di Star Wars) è stata **scartata**: tutto deve restare originale.

## Trama
**Da scrivere.** Per ora c'è solo lo spunto: il protagonista parte dalla villa di famiglia e deve raggiungere **Ostia Nova**, la città più vicina, per fare qualcosa (ancora da decidere).
Tutti i punti in cui inserire la storia sono segnati con `[TRAMA]`:
- **dialoghi degli NPC**: tutti in `data/npc_db.gd` (un solo file da modificare);
- cartelli del livello 1 e della città (`LoreSign`, testo nell'Inspector);
- `intro_text` del nodo radice di `level_02_ostia.tscn` (mostrato alla prima visita della città).

## Classi (data/hero_classes.gd)
| Classe | Statistica | Risorsa | Stile |
|---|---|---|---|
| Legionario | Forza | Disciplina (si rigenera) | tank in mischia, scudo, pilum, bombardamento orbitale |
| Gladiatore | Forza | Furia (si accumula colpendo) | mischia veloce, balzo, turbine, rete |
| Sagittario | Destrezza | Concentrazione | a distanza, arco al plasma, trappole, pioggia di frecce |
| Augure | Intelligenza | Favore divino | incantatore: fulmine a catena, meteora, teletrasporto |

Abilità: clic sinistro (primaria, genera risorsa), clic destro (secondaria), tasti 1-4. Si sbloccano ai livelli 1/1/2/3/4/6.

## Statistiche e formule (core/hero_data.gd)
- Danno = danno arma × (1 + statistica principale/100) × (1 + %danni) × moltiplicatore abilità × buff; critico ×(1 + danno critico).
- Vita = 60 + 12×livello + 6×Vitalità + bonus.
- Riduzione armatura = armatura / (armatura + 50 × livello attaccante), massimo 75%.
- La Forza dà anche armatura (0,5 per punto).
- PE per livello: 80 × livello^1,6.

## Loot (data/item_db.gd)
- Rarità: Comune (bianco), Magico (blu, 1-2 affissi), Raro (giallo, 3-4), Leggendario (arancione, affissi fissi + 2 casuali + frase).
- Probabilità per fonte: nemico normale, elite, boss unico, forziere, forziere decorato.
- Loot intelligente: il 70% degli oggetti è utilizzabile dalla classe e la statistica principale esce più spesso.
- Restrizioni armi: Legionario gladio/spatha + scudo; Gladiatore gladio/ascia/spatha + pugnale/scudo; Sagittario arco + faretra; Augure scettro + focus.
- Globi di vita (20% vita) e sesterzi (oro, raccolti automaticamente).
- **Poteri leggendari** (`ItemDB.POWERS`): ogni leggendario ha un potere mostrato in arancione nel tooltip. I salvataggi vecchi ricevono il potere in base al nome.

| Leggendario | Slot | Potere |
|---|---|---|
| Gladio di Spartaco | arma | uccisione: cura 3% e +5% danni per 5 s (max 5) |
| Scure di Commodo | arma | i critici esplodono (60% danno arma, 3 m) |
| Arco di Diana Stellare | arma | i proiettili trapassano tutti i nemici |
| Lituo di Romolo | arma | uccisione: −1 s a tutte le ricariche |
| Scutum dell'Ultima Legione | secondaria | sotto il 30% vita: scudo del 30% vita (ogni 60 s) |
| Elmo di Scipione | elmo | +50% danni contro Campioni e boss |
| Anello di Cesare | anello | raccogliere sesterzi cura il 2% |
| Calzari di Mercurio | calzari | dopo un movimento: +30% velocità d'attacco per 4 s |
| Toga del Pontefice | armatura | 25% di non consumare risorsa |
| Manicae di Ercole | guanti | attacco principale: 15% onda d'urto (150%) |
| Bulla di Vesta | amuleto | globi di vita doppi + 20% risorsa |
| Ocreae di Achille | gambali | pozione: metà ricarica + 2 s di invulnerabilità |

## Economia (data/item_db.gd)
- **Mercante**: vende 16 oggetti del livello dell'eroe (4 rari, 12 magici), rinnovati a ogni ingresso in città. Prezzo = valore × 5. Valore di vendita = [5, 15, 40, 120] per rarità × (1 + 0,25 × (liv. oggetto − 1)). Riacquisto degli ultimi 12 oggetti venduti allo stesso prezzo di vendita.
- **Fabbro**: smonta gli oggetti in materiali (comune → rottami di bronzo, magico → rottami + essenza arcana, raro → essenze, leggendario → frammento divino + essenze) e forgia oggetti del livello dell'eroe per la propria classe:
  magico = 25 sesterzi × livello + 4 rottami; raro = 80 × livello + 8 rottami + 4 essenze; leggendario (casuale) = 300 × livello + 2 frammenti + 10 essenze.
- **Da fare**: gemme, set, forziere personale (stash).

## Viaggi
- **Altari**: si attivano avvicinandosi (salvano e diventano il punto di rinascita del loro livello). Cliccandoli si apre il **viaggio rapido** verso tutti gli altari attivati, anche di altri livelli.
- **Portale cittadino** (T, 1,5 s di canalizzazione, si interrompe muovendosi o subendo danni): porta a Ostia Nova; in città compare il portale per tornare nel punto esatto di partenza. Disponibile dopo aver visitato la città.
- **Uscite** (`LevelExit`): con `target_level` + `target_spawn` portano a un altro livello (nel Marker3D indicato).

## Livello 2 – Ostia Nova (scenes/levels/level_02_ostia.tscn, città-hub)
Generata da `tools/build_ostia.gd`. Nord = −Z.
- **Porta sud** (arrivo dalla campagna; l'uscita riporta al livello 1, vicino alla porta).
- **Cardo** fino al **Foro**: fontana, portici, **Altare del Foro** (viaggio rapido), **mercato** a ovest (Tito Mercatore), **fucina** a est (Decimo Ferrario).
- **Basilica** del prefetto Aulo Vetranio a nord del foro; **tempio di Vesta** a nord-est (vestale Lucilla).
- **Porta del porto** a nord: sbarrata (atto 2).
- Guardie e cittadini con frasi casuali.

## Nemici (data/enemy_db.gd)
Predone, Lupo cibernetico, Drone ribelle (a distanza), Barbaro, Frombolier (a distanza), Bruto (colpo ad area), Lemure (spettro), Legionario rinnegato, **Brenno il Rinnegato** (boss unico: carica + colpo ad area).
- Elite "Campioni": vita ×3, danni ×1,4, nome blu, aura blu.
- Ogni attacco ha un tempo di carica (il nemico si illumina di arancione): si può schivare, e i nemici leggeri vengono interrotti se colpiti.

## Livello 1 – Campagna di Lazio Prime (scenes/levels/level_01.tscn)
Percorso sud → nord, circa 1150 m. Nord = asse −Z.
1. **Villa di famiglia** (partenza, altare dei Lari, campi coltivati).
2. **Campi** e **fattoria razziata** dai predoni (deviazione a ovest, forziere).
3. **Bosco** con lupi cibernetici; deviazione a est verso il **relitto di una navetta** imperiale (droni, forziere decorato).
4. **Fiume** con **ponte** e altare di Portuno. A ovest c'è un **guado** verso il **boschetto sacro** (lemuri elite, forziere).
5. **Bivio del tempio**: deviazione a ovest verso il **tempio di Saturno in rovina** (forziere).
6. **Accampamento barbaro** e cava (barbari, frombolieri, bruto, campioni).
7. **Via dei Sepolcri** (necropoli tipo Via Appia: tombe, cipressi, lemuri), altare di Proserpina; a est c'è il **mausoleo** (forziere).
8. **Acquedotto** e periferia: altare di Giano, legionari rinnegati.
9. **Porta di Ostia Nova** con il boss **Brenno il Rinnegato** → uscita del livello.

Livello dei nemici: da 1 a 5 lungo il percorso. Ci sono 24 zone di nemici e 8 forzieri.

## Grafica / tecnica in stile D3
- Telecamera prospettica fissa (pitch circa 54°, guarda a nord), zoom leggero.
- Gli oggetti che coprono l'eroe diventano trasparenti (OcclusionFader).
- Minimappa (telecamera ortografica) + mappa grande con TAB; le icone sono sul livello visivo 11.
- Barre della vita sopra i nemici, riquadro del bersaglio in alto, nomi del loot colorati, colonne di luce per rari e leggendari.

## Effetti e audio (segnaposto)
- `core/fx.gd`: particelle CPU (`burst`, `explosion`, `pillar`, `trail`) e fumetti degli NPC (`popup_speech`).
- `core/sfx.gd`: 24 effetti sonori **sintetizzati da codice** (nessun file). Per usare un suono vero basta mettere `res://audio/sfx/<nome>.wav` (o `.ogg`): ha la precedenza. Nomi: swing, hit, crit, enemy_die, player_hurt, enemy_attack, cast, projectile, dash, explosion, gold, pickup, rare_drop, legendary, levelup, potion, chest, break, checkpoint, portal, ui_click, coins, anvil, talk. Volume nel menu di pausa (salvato in `user://settings.cfg`).
- Manca la **musica**.

## Idee / prossimi passi
- Scrivere la trama (dialoghi in `data/npc_db.gd`) e le missioni.
- Atto 2: il porto di Ostia Nova.
- Sostituire i modelli segnaposto con quelli di Tripo + animazioni Mixamo.
- Musica, suoni veri, effetti con shader.
- Nebbia di guerra sulla mappa, skill alternative/rune come in D3, opzioni grafiche e di rimappatura dei tasti.
