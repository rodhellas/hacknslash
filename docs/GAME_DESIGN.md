# Game design – Legio 3000

## Concept
- Genere: action RPG / hack n slash isometrico, **come Diablo 3** (mappe grandi quasi a percorso ma esplorabili, nemici a gruppi in zone, loot casuale, classi).
- **Niente roguelike**: i livelli sono fatti a mano.
- Ambientazione: l'**Impero Romano nel 3000 d.C.** L'Impero non è mai caduto. Tecnologia sci-fi con estetica romana: gladi al plasma, scuta a campo di forza, pila elettromagnetici, droni, navette, legionari cyborg, culti degli dèi come forze "divine".
- L'idea iniziale (Bud Spencer e Terence Hill nel mondo di Star Wars) è stata **scartata**: tutto deve restare originale.

## Trama
**Da scrivere.** I testi delle missioni sono in `data/quest_db.gd`. Per ora c'è solo lo spunto: il protagonista parte dalla villa di famiglia e deve raggiungere **Ostia Nova**, la città più vicina, per fare qualcosa (ancora da decidere).
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
- **Forziere personale** (in città, accanto all'altare del Foro): 60 caselle per scheda, condiviso da tutti gli eroi (`user://stash.json`).
- **Forziere a schede**: 60 caselle per scheda, fino a 5 schede (5.000 / 25.000 / 75.000 / 200.000 sesterzi).
- **Mercante**: vendita in blocco fino ai comuni, ai magici o ai rari (leggendari e set mai).
- **Fabbro, scheda Aspetto**: ogni base raccolta o indossata sblocca il suo aspetto; cambiare aspetto costa 50 × livello sesterzi, tornare all'originale è gratis; tinte gratuite (rosso, porpora, verde, oro, acciaio, bronzo, cuoio, stoffa).

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
- Elite: i gruppi elite sono **Campioni** (tutti blu, stessi affissi, vita ×3, danni ×1,4) oppure un **capo raro** (giallo, vita ×4, nome proprio) con 2 servitori in più normali. Affissi (`EnemyDB.ELITE_AFFIXES`, quanti dipende dalla difficoltà): Rapido (+35% velocità), Corazzato (-35% danni, niente spinta), Vampirico (si cura del 30% dei danni), Scudato (3 s invulnerabile ogni 10 s), Incendiario (pozze di fuoco), Gelido (sfere che esplodono e rallentano), Teletrasporto, Esplosivo (esplode morendo), Elettrico (scariche in 6 direzioni), Orda (+3 nemici).
- Stordimento e fiamme (varianti delle abilità): elite e boss restano storditi la metà.
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

## Missioni (data/quest_db.gd)
| Missione | Atto | Chi la affida | Obiettivi | Ricompensa |
|---|---|---|---|---|
| Verso Ostia Nova | 1 | (automatica) | uccidi Brenno → entra a Ostia Nova → parla col prefetto | 400 PE, 300 sesterzi |
| Ferri del mestiere | 1 | fabbro | smonta 3 oggetti → torna dal fabbro | 150 sesterzi, 3 essenze |
| Il fuoco tremante | 1 | vestale | 12 lemuri → torna dalla vestale | 350 PE, oggetto raro |
| Il porto sbarrato | 2 | prefetto | entra nel porto → altare dei cantieri → uccidi Vulso → torna dal prefetto | 1500 PE, 800 sesterzi, leggendario |
| Merce rubata | 2 | mercante | forziere del magazzino del sale → torna dal mercante | 600 sesterzi, oggetto raro |
| Ripulire i moli | 2 | guardia | 30 pirati → torna da una guardia | 800 PE, 400 sesterzi |

## Livello 3 – Porto di Ostia Nova (scenes/levels/level_03_porto.tscn, atto 2)
Generato da `tools/build_porto.gd`. Nord = −Z, il mare è a est. Percorso di circa 560 m, nemici di livello 6-9, 20 zone, 6 forzieri, 3 altari.
1. **Porta del porto** (arrivo dal cancello nord di Ostia Nova; l'uscita riporta in città). Altare di Nettuno.
2. **Magazzini** lungo la strada; deviazione a ovest: **magazzino del sale** (forziere della missione "Merce rubata", Campioni). A est il primo **molo** con nave ormeggiata.
3. **Cantieri navali**: gru sulla riva, **Altare di Minerva**; deviazione a ovest: nave in costruzione e automi. Secondo molo con forziere in punta.
4. **Spazioporto**: piattaforme di atterraggio, navetta corsara, droni, **Altare di Mercurio**. Terzo molo con granchi meccanici.
5. **Faro**: covo di **Vulso il Corsaro** (carica, colpo ad area, ogni 14 s chiama 3 pirati).

Nuovi nemici: Pirata cilicio (mischia), Arpionatore (a distanza), Granchio meccanico (piccolo e veloce, in gruppo), Automa portuale (pesante, colpo ad area).

## Effetti e audio (segnaposto)
- `core/fx.gd`: particelle CPU (`burst`, `explosion`, `pillar`, `trail`) e fumetti degli NPC (`popup_speech`).
- `core/sfx.gd`: 24 effetti sonori **sintetizzati da codice** (nessun file). Per usare un suono vero basta mettere `res://audio/sfx/<nome>.wav` (o `.ogg`): ha la precedenza. Nomi: swing, hit, crit, enemy_die, player_hurt, enemy_attack, cast, projectile, dash, explosion, gold, pickup, rare_drop, legendary, levelup, potion, chest, break, checkpoint, portal, ui_click, coins, anvil, talk. Volume nel menu di pausa (salvato in `user://settings.cfg`).
- **Musica**: nessun brano incluso. Basta mettere `audio/music/<id livello>.ogg` (vedi `audio/music/LEGGIMI.txt`); dissolvenza tra i livelli, volume in Opzioni.

## Gemme e set
- **Gemme** (5 tipi × 5 gradi: scheggiato, grezzo, levigato, imperiale, divino). Effetto per grado 1, moltiplicato ×1 / 2 / 3,5 / 5,5 / 8:

| Gemma | Arma | Elmo | Altro |
|---|---|---|---|
| Rubino | +4% danni | +25 vita | +6 Forza |
| Smeraldo | +10% danno critico | +10% sesterzi | +6 Destrezza |
| Topazio | +2% velocità d'attacco | +1 vita/s | +6 Intelligenza |
| Ametista | +3 vita per colpo | +25 vita | +6 Vitalità |
| Diamante | +0,8% critico | -2% ricarica | +12 armatura |

- Orbite: arma, elmo, amuleto, anello fino a 1; gambali 2; armatura 3. Gioielliere (dal fabbro): 3 gemme uguali → 1 del grado dopo (60 sesterzi × grado); togliere una gemma costa 40 sesterzi × grado.
- Gemme dai nemici (2,5% normali, 25% elite, sempre dai boss) e dai forzieri.
- **Set** (verdi, un set per classe, 4 pezzi): Panoplia del Primo Pilo (Legionario), Paramenti del Reziario (Gladiatore), Insegne dei Saettatori di Creta (Sagittario), Paramenti dell'Augure Massimo (Augure). Bonus a 2 e 3 pezzi = statistiche; a 4 pezzi = +200% danni di due abilità e +100/150% di una terza.

## Dungeon generati
- Le mappe sono fatte a mano, i dungeon sono procedurali: generati con **seme fisso** (stessa mappa ogni volta, scelta provando i semi con `tools/export_dungeons.gd`).
- **Catacombe del Mausoleo** (entrata accanto al Mausoleo, livello 1): 11 stanze su una griglia di 56 × 56 celle da 3 m, nemici di livello 5 (lemuri, predoni, Campioni), boss **il Custode delle Ossa** (colpo ad area, chiama lemuri). Pianta: `docs/mappe/dungeon_catacombe.png`.
- **Caverne del Clan** (entrata nell'accampamento barbaro, livello 1): stile caverna, 9 grotte, nemici di livello 4 (barbari, frombolieri, lupi, bruti), boss **Tharvo Mangiaferro** (carica, chiama barbari).
- **Cisterne del Porto** (entrata al magazzino del sale, livello 3): 12 stanze, molte sale a colonne, nemici di livello 8 (granchi, pirati, arpionatori, automi), boss **la Madre dei Granchi** (colpo ad area, chiama granchi).
- Tipi di stanza: sala a colonne, cripta (file di sarcofagi), stanza del tesoro (forziere decorato + Campioni). Piante in `docs/mappe/dungeon_*.png`.
- Nemici e forzieri ricompaiono a ogni ingresso; il boss è unico per partita.

## Forma dei livelli (editor)
- Nodo `Forma` in ogni livello: **strade** (curve con fascia calpestabile e lastricato), **aree** (radure circolari), **poligoni** (terra, acqua, buchi). Ogni elemento indica una **zona** (`data/map_zones.gd`: colore del suolo, bordo decorato, vegetazione sparsa).
- Pannello **Mappa** (plugin Legio Map): *Ricostruisci terreno* rigenera solo terreno, confini, strade, acqua, vegetazione, lampioni e navmesh; il resto del livello resta com'è. Il resoconto segnala gli oggetti finiti fuori dall'area calpestabile.
- Piante PNG (2 px = 1 m, nord in alto) in `docs/mappe/`, da pannello o con `tools/export_maps.gd`.

## Abilità, varianti e passive (data/skill_db.gd)
- 10 abilità per classe: le 6 base + 4 alternative (primaria liv. 9, secondaria 11, tattiche 13 e 16). Clic sinistro solo primarie, clic destro solo secondarie, tasti 1-4 qualunque tattica.
- Ogni abilità ha 3 **varianti** (rune), sbloccate a livello abilità + 6 / + 14 / + 24. Effetti nuovi: fiamme nel tempo, stordimento, cura sui colpi, attirare i nemici, seconda esplosione, potenziamento all'uso.
- **Passive**: 6 per classe, 3 caselle (liv. 10, 20, 30).
- Cambiare abilità la mette in ricarica.
- 12 **leggendari** cambiano un'abilità (`SkillDB.POWER_MODS`), 4 **set** nuovi (uno in più per classe) potenziano anche le abilità alternative.

## Difficoltà ed endgame (data/difficulty_db.gd)
- Normale, Esperto, Maestro (liv. 10), Tormento I-X (liv. 30): vita nemici da ×1 a ×76, danni da ×1 a ×15,5, esperienza fino a ×15, leggendari fino a ×6, affissi delle elite 1 → 4. Da Esperto i nemici hanno almeno il livello dell'eroe.
- **Labirinti di Dedalo**: Obelisco nel foro di Ostia Nova. Grado da 1 al massimo sbloccato; seme nuovo a ogni tentativo (stile stanze o caverna, aspetto di uno dei dungeon della campagna). Barra riempita uccidendo (normale 1, elite 4) fino al 75% dei nemici attesi → compare il Guardiano (un boss ingrandito, vita ×3). Sconfitto entro 15 minuti: +1 grado (+2 sotto 7,5 minuti). Ricompensa: 4-6 oggetti (il primo leggendario), gemma, molti sesterzi, +1 leggendario ogni 10 gradi. Scala: vita ×1,4 × 1,17^(grado−1), danni ×1,3 × 1,1^(grado−1).

## Interfaccia
- Finestra Abilità (K), anteprima 3D nello zaino, ordina zaino, statistiche dettagliate, barra del boss in alto, affissi nel riquadro del bersaglio, numeri di danno più grandi per critici e colpi forti.
- Nebbia di guerra (celle da 8 m, salvata per livello in `hero.flags["fog"]`; niente nebbia in città) e segnalini delle missioni (fuori mappa: freccia sul bordo).
- Filtro del loot e nomi a terra (Opzioni > Gioco; Alt per vederli tutti).
- Schermata di caricamento con il nome del luogo e un consiglio.
- Controller: mira automatica, navigazione dei pannelli (vedi README).

## Modalità avventura e mondo vivo (data/world_db.gd)
- **Taglie**: Tabula nel foro di Ostia Nova. Atto I (livello 1, Catacombe, Caverne) e atto II (porto, Cisterne): 4 taglie per atto (un boss + uccisioni / elite / eventi). Ognuna: 60 PE e 40 sesterzi × livello. Tutte finite: **Cassa del Prefetto** (1 leggendario, 2 forzieri decorati di loot, 5 essenze, 1 frammento, 200 sesterzi × livello) e taglie nuove. I boss delle taglie ricompaiono.
- **Santuari** (3 per mappa, 2 per dungeon, 120 s): Fortuna (+25% sesterzi, +50% leggendari), Marte (+25% danni), Mercurio (+25% movimento, +15% velocità d'attacco), Minerva (-25% danni subiti), Apollo (+25% esperienza).
- **Piloni** (Labirinti, 2 per labirinto, 15-30 s): Potenza (+300% danni), Flusso (niente costi, ricariche ×0,25), Egida (invulnerabile), Vento.
- **Eventi** (2 per mappa): forziere maledetto (30 s di ondate), stendardo del clan (3 ondate, l'ultima con un'elite), prigionieri (3 da liberare, arrivano le guardie). Ricompensa: forziere decorato + PE.

## Boss
- Attacchi speciali ogni 6 s (4 con la furia): nova (16 proiettili), pioggia di fuoco (6 zone attorno all'eroe), onda (7 m attorno al boss), salto (piomba sull'eroe). Fasi: Brenno (66% rinnegati, 33% furia + salto), Custode (66% scudo finché vivono 4 lemuri, 33% furia + nova), Tharvo (50% furia + onda), Vulso (66% scudo con 4 pirati, 33% furia + pioggia), Madre dei Granchi (66% 6 granchi, 33% furia + pioggia).

## Equipaggiamento, danni, gemme leggendarie
- 13 caselle: elmo, spallacci, amuleto, armatura, guanti, bracciali, due anelli, cintura, arma, gambali, mano secondaria, calzari. Doppia arma per il Gladiatore (+15% velocità d'attacco).
- Tipi di danno: fisico, fuoco, freddo (rallenta del 25%), fulmine; affissi +4-10% per tipo su amuleto, bracciali e mano secondaria.
- Gemme leggendarie (solo amuleto e anelli, grado 1-50): Cuore di Marte (+10% danni +1%/grado), Occhio di Giano (+20% danno critico +2%/grado), Pietra di Vesta (-10% danni subiti +0,3%/grado, max 25%), Lacrima di Niobe (cura 1% dei danni +0,1%/grado), Scintilla di Vulcano (15% di incendiare), Dente di Cerbero (+20% contro elite e boss +1%/grado). Potenziamento: 100% se il labirinto è 10 gradi sopra la gemma, 60% a pari grado, meno sotto.

## Hardcore
- Scelto alla creazione. Alla morte l'eroe resta nello slot come "caduto" e non si può più giocare. Forziere personale separato.

## Idee / prossimi passi
- Scrivere la trama (dialoghi in `data/npc_db.gd`) e le missioni.
- Atto 3 (dopo il faro).
- Sostituire i modelli segnaposto con quelli di Tripo + animazioni Mixamo.
- Musica, suoni veri, effetti con shader.
- Bilanciamento fino al livello 60 e ai Tormenti alti.
