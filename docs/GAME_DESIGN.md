# Game design – Legio 3000

## Concept
- Genere: action RPG / hack n slash isometrico, **come Diablo 3** (mappe grandi quasi a percorso ma esplorabili, nemici a gruppi in zone, loot casuale, classi).
- **Niente roguelike**: i livelli sono fatti a mano.
- Ambientazione: l'**Impero Romano nel 3000 d.C.** L'Impero non è mai caduto. Tecnologia sci-fi con estetica romana: gladi al plasma, scuta a campo di forza, pila elettromagnetici, droni, navette, legionari cyborg, culti degli dèi come forze "divine".
- L'idea iniziale (Bud Spencer e Terence Hill nel mondo di Star Wars) è stata **scartata**: tutto deve restare originale.

## Trama
**Da scrivere.** Per ora c'è solo lo spunto: il protagonista parte dalla villa di famiglia e deve raggiungere **Ostia Nova**, la città più vicina, per fare qualcosa (ancora da decidere).
Tutti i punti in cui inserire la storia sono segnati con `[TRAMA]` nei testi dei cartelli del livello 1 e nel testo di fine livello (`exit_text` del nodo radice di `level_01.tscn`).

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
- **Da fare**: venditori, fabbro, gemme, set, poteri leggendari veri (ora sono solo statistiche).

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

## Idee / prossimi passi
- Scrivere la trama e il livello 2 (Ostia Nova: città hub con NPC, venditori, missioni).
- Sostituire i modelli segnaposto con quelli di Tripo + animazioni Mixamo.
- Effetti (particelle, shader), audio e musica.
- Nebbia di guerra sulla mappa, skill alternative/rune come in D3, opzioni grafiche e di rimappatura dei tasti.
