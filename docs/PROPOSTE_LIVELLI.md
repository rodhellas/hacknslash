# Proposte per i livelli – Legio 3000

Revisione di level design (20-11-2026) delle tre mappe fatte a mano (Campagna di Lazio Prime, Ostia Nova, Porto di Ostia Nova)
e dei tre dungeon generati (Catacombe, Caverne del Clan, Cisterne). Il documento contiene solo proposte: nessun file di gioco è stato modificato.

Convenzioni:
- Coordinate in metri `(x, z)` sul piano; **nord = −Z**. `s` = distanza percorsa sulla strada principale dalla partenza.
- **Priorità**: alta / media / bassa. **Costo**: piccolo (solo nodi o numeri, meno di 1 ora), medio (nodi + Forma + navmesh, oppure poche righe di codice), grande (codice nuovo e test).
- Dati letti da: `tools/build_world.gd`, `tools/build_porto.gd`, `tools/build_ostia.gd`, i nodi `Incontri` dei `.tscn` (coincidono con i generatori), `world/encounter_zone.gd`, `world/level.gd`, `world/dungeon_gen.gd`, `world/dungeon_level.gd`, `data/*.gd`, piante in `docs/mappe/`.

## Stato (20-11-2026): applicate

Tutte le proposte sono state applicate con `tools/applica_proposte_livelli.gd` (livelli) e nel codice dei dungeon,
**tranne D7** (vedi sotto). Verifiche: `tools/test_livelli.gd` (20 controlli), `tools/test_dungeon.gd` (44),
più i controlli di raggiungibilità a piedi dello script prima di salvare. **Provato a schermo dall'utente (20-11-2026)**:
palizzate al varco di Brenno, soglia del faro, imbocchi dei segreti nella nebbia, santuari ed eventi ai punti fissi: tutto a posto.
Differenze rispetto al testo:

- **Sentieri dei segreti larghi 9 m** (mezza larghezza 4.5) invece di 5: il terreno è fatto a celle di 8 m e un
  sentiero più stretto a volte non ne copre nessuna (il segreto resterebbe isolato). Restano senza lastricato.
- **Arena di Brenno**: la fila di palizzate va da x 16 a x 124 (non 36-100: l'area calpestabile è più larga) con una
  palizzata anche dietro l'arco dell'acquedotto (50, −824), sotto cui si passava. Varco di 12 m sulla strada (x 62-74).
- **Soglia del faro**: un muro in più a ovest (−12, −515), stesso motivo.
- **Strada_faro** tolto del tutto (non le sentinelle sopra la soglia: sarebbero state a 16 m dall'altare).
- **Porto, pirati**: per tenere fattibile "Ripulire" (30 pirati) `Pirati_strada` è `pirata, pirata, granchio` e
  `Pirati_curva` `pirata, pirata, arpionatore`: 31 pirati più i rinforzi di Vulso.
- **Forziere del molo 3** a (78, −382): a (84, −381) cadeva nel muro invisibile in fondo al molo.
- **Ricordo di famiglia (Ostia)** a (−43, −40): (−42, −54) era contro le mura.
- **Dungeon**: il sacello è garantito (se i pesi non ne danno nessuno, diventa sacello la stanza normale a metà strada
  verso il boss) e anche la scelta della stanza del boss (D5 facoltativa) è fatta: Catacombe ora 7×7. Pianta invariata.
- **D7 non applicata**: misurato col generatore, il percorso partenza → boss delle Caverne è già di **201 m** (non
  115): la premessa non regge e cambiare la pianta fissa non serve.
- I generatori (`build_world.gd`, `build_porto.gd`, `build_ostia.gd`) **non** sono stati aggiornati: rigenerare un
  livello perde queste modifiche (avviso in testa ai file). Lo script si può rilanciare senza duplicare nulla.

## 0. Come implementare (per l'agente che applicherà le proposte)

1. **Non rigenerare i livelli** con `build_world.gd`, `build_ostia.gd` o `build_porto.gd`: sovrascriverebbero i `.tscn`. Modifica i `.tscn` (nodi sotto `Incontri`, `World/Luoghi`, `Forma`).
2. Per i cambiamenti alla **Forma** (nuove `MapArea`, sentieri `MapRoad`), lancia poi *Ricostruisci terreno* (`tools/map_builder.gd`), da pannello Mappa oppure da uno script headless che carica il livello, imposta prima `load("res://world/map_shape.gd").keep_in_game = true`, chiama `build(root, true)` e risalva. Il resoconto segnala gli oggetti finiti fuori dall'area calpestabile.
3. Tutto ciò che deve bloccare il movimento (muri, barricate) va **sotto `World`** con collider sul livello 1, poi va ricalcolata la navmesh.
4. Per coerenza, riporta le stesse modifiche nelle costanti dei generatori (`ROAD`, `SIDE`, `PATHS`, liste degli incontri), **senza rilanciarli**.
5. Nuovi forzieri: `flag_id` univoco (`chest_<luogo>`), `item_level` uguale a quello delle zone vicine, `rich = true` solo per le ricompense dei segreti veri.
6. Test da rilanciare: `test_mappa.gd` (Forma), `test_ostia.gd`, `test_atto2.gd` (percorre il porto a piedi fino al faro: **spostare altari o zone del porto può richiedere di aggiornarlo**), `test_dungeon.gd` (impronte delle piante), `test_avventura.gd` (santuari ed eventi nel livello 1).

---

## 1. Diagnosi

### 1.1 Livello 1 – Campagna di Lazio Prime (`scenes/levels/level_01.tscn`)

**Percorso principale.** `ViaPrincipale`: villa (0, 0) → porta di Ostia Nova (50, −895), **circa 1150 m**. A 6 m/s sono circa 3 minuti di sola camminata; con i combattimenti il percorso principale richiede **15-20 minuti**, e **30-35 minuti** con le deviazioni.

| s (m) | Luogo | Cosa c'è |
|---|---|---|
| 0 | Villa (0, 0) | Altare dei Lari, cartello |
| ~90-125 | Campi | `Predoni_campi` (3); deviazione `FattoriaRazziata` (−58, −98): `Predoni_fattoria` (5), forziere |
| ~205-355 | Bosco | `Lupi_margine` (4), `Lupi_bosco` (5), `Banditi_bosco` (5); deviazione `RelittoNavetta` (205, −250): droni elite + normali, forziere decorato |
| ~400 | Prima del ponte | `Predoni_ponte` (4) |
| ~427 | Ponte (≈82, −335) | **Altare di Portuno** (≈79, −353) |
| ~470-515 | Dopo il ponte | `Imboscata_nord` (6) a 20 m dall'altare, `Barbari_avanguardia` (5) |
| ~550 | Bivio del tempio (−8, −428) | Deviazione `TempioInRovina` (−115, −410): elite + rinnegati, forziere decorato; da lì il guado porta al `BoschettoSacro` (−110, −292): lemuri elite, forziere decorato |
| ~595-750 | Colline e campo | `Lupi_colline` (5), `Barbari_strada` (6), `AccampamentoBarbaro` (−118, −548): `Campo_barbaro` (8) + `Campioni_campo` (elite), entrata delle Caverne; `Bruto_cava` (4) |
| ~769 | Necropoli | **Altare di Proserpina** (≈−41, −600) |
| ~818-875 | Via dei Sepolcri | `Lemuri_sepolcri` (5), `Lemuri_sepolcri2` (6); deviazione `Mausoleo` (150, −662): lemuri elite, forziere, entrata delle Catacombe |
| ~960 | Acquedotto | `Rinnegati_acquedotto` (5) |
| ~980 | | **Altare di Giano** (≈100, −742) |
| ~1030 | | `Rinnegati_porta` (6) |
| ~1110 | Porta (62, −852) | **Boss Brenno** + 3 rinnegati, uscita (50, −905) |

**Numeri.** 24 zone, circa 105 nemici, 8 forzieri, 4 altari, 4 cartelli, 2 entrate di dungeon.

**Punti deboli:**
1. **Ritmo a metronomo.** Sul percorso principale ci sono 15 gruppi quasi equidistanti (uno ogni 70-80 m) di 3-6 nemici. La tensione resta piatta e non c'è un picco a metà livello.
2. **Nessuna elite sul percorso principale.** Le 5 zone elite (relitto, boschetto, tempio, campo, mausoleo) sono tutte in deviazioni. Chi segue solo la strada arriva a Brenno senza aver mai visto un'elite o un affisso.
3. **Nessuna pausa dopo gli altari.** `Imboscata_nord` (68, −372) si attiva a circa 20 m dall'Altare di Portuno: l'altare non funziona da punto di riposo.
4. **Brenno combatte in mezzo alla strada.** È in un tratto largo 68 m (mezza larghezza 34), senza soglia né cornice, e si vede da lontano solo la porta. Lo scontro principale dell'atto non ha uno spazio suo.
5. **Il ponte, un collo di bottiglia naturale, non viene sfruttato.** `Predoni_ponte` sta 30 m prima del ponte, in campo aperto.
6. **Nessun segreto.** Tutte le deviazioni sono radure grandi e visibili dalla strada (sentieri lastricati larghi 9-10 m). I forzieri sono tutti "in vista" e nessun luogo premia chi esplora a fondo.
7. **Deviazioni tutte a vicolo cieco.** Per tempio e boschetto si fa avanti e indietro per circa 300 m, senza un anello di ritorno.
8. **Santuari ed eventi messi a caso** (`Level._place_world_extras`): vengono messi vicino a una zona qualunque. Possono finire tutti nelle deviazioni oppure ammucchiati, e a volte accanto a un altare.

**Curva del ritmo (attuale)**
```
tensione
 alta |                                                                     [Brenno]
      |        LLB  B  P I  A    L  B [campo]  b      lem lem        R    R    ##
 med  |   p p  ###########  ####   ######  ####  ###  #########     ###   ###  ##
 bassa|###                ^Port                 ^Pros               ^Giano
      +------------------------------------------------------------------------- s
      0    100   200   300   400   500   600   700   800   900   1000  1100
```
La linea è quasi sempre "media" e c'è un solo picco, alla fine.

### 1.2 Ostia Nova (`scenes/levels/level_02_ostia.tscn`, città hub)

- Mura di 96 × 110 m. Si arriva da `DaLazio` (0, 42) e dal portale (`PortaleArrivo` (−6, 18)). Altare (8, 8), Obelisco (0, 10), forziere personale (−8, 9), Tabula (5, −9), mercante (−12.8, −2) e fabbro (12.8, −1.5) stanno tutti entro **20 m**: un'ottima concentrazione di servizi, come in D3.
- **Punti deboli:**
  1. La **basilica (0, −30)** è sull'asse del cardo e copre la vista della porta del porto (0, −58). Chi arriva da `DalPorto` (0, −49) deve girarci intorno senza indicazioni (circa 70 m fino ai servizi).
  2. Nell'atto 1 il cancello del porto è chiuso e non promette niente: si vede solo un cartello.
  3. I quartieri NO, SO ed SE sono vuoti e non danno nessun motivo per andarci (va bene per un hub, ma si perde un piccolo premio all'esplorazione).
- Tempo per attraversarla: meno di 30 s. **La città funziona: le modifiche sono di rifinitura.**

### 1.3 Porto di Ostia Nova (`scenes/levels/level_03_porto.tscn`)

**Percorso principale.** `ViaDelPorto`: porta (0, 14) → faro (18, −525), **circa 560 m**; **10-12 minuti** sul percorso principale, 18-20 con i moli e le deviazioni.

| s (m) | Luogo | Cosa c'è |
|---|---|---|
| ~20 | Porta | **Altare di Nettuno** (−9, −6) |
| ~56-130 | Strada | `Pirati_ingresso` (4), `Granchi_strada` (6), `Pirati_strada` (5) |
| ~180 | Magazzini | `Magazzini_1` (6); deviazione ovest al magazzino del sale (−64, −160): `Sale_campioni` (elite), `Sale_ciurma` (4), forziere della missione, entrata delle Cisterne; molo 1 (62, −140): `Molo_1` (5) |
| ~230-275 | | `Automa_magazzini` (3), `Pirati_curva` (6); molo 2 (66, −284): `Molo_2` (5), forziere in punta (88, −284) |
| ~330 | Cantieri | **Altare di Minerva** (−6, −304, obiettivo della missione); `Gru_pirati` (6) a 36 m; deviazione ovest al cantiere (−60, −320): elite + operai, forziere decorato; molo 3 (60, −380): `Molo_3` (7 granchi), **nessuna ricompensa** |
| ~428-470 | Spazioporto | `Strada_spazioporto` (6), **Altare di Mercurio** (−4, −418), `Droni_spazioporto` (5), `Spazioporto_ciurma` (6), `Spazioporto_campioni` (elite): **4 gruppi nel raggio di 40 m** |
| ~500 | | `Strada_faro` (6) |
| ~559 | Faro (20, −550) | **Vulso** + 4 pirati, forziere decorato |

**Numeri.** 20 zone, circa 96 nemici (oltre a quelli in più delle elite): la densità è **il doppio del livello 1** (una zona ogni 28 m).

**Punti deboli:**
1. **Nessun riposo.** Dall'ingresso al boss non c'è un tratto senza nemici più lungo di circa 40 m. Dopo i primi 5 minuti la fatica abbassa la tensione invece di alzarla.
2. **Altari sbilanciati.** I primi due sono a 310 m l'uno dall'altro, poi la distanza scende a 117 m. Mercurio è a circa 110 m da Vulso, con 2 grandi scontri in mezzo: se l'eroe muore contro Vulso, deve rifare la strada e gli scontri, che ricompaiono.
3. **Scontro di Vulso senza soglia.** La strada (mezza larghezza 24) sfocia direttamente nel piazzale. `Strada_faro` (−8, −485) è attaccato all'arena e può unirsi allo scontro del boss.
4. **Moli ripetitivi.** Tre pontili identici a vicolo cieco; il molo 3 ha 7 granchi e nessun premio (vicolo cieco "punitivo").
5. **Magazzini in serie.** Lungo la strada (s 64-230) i magazzini si ripetono ogni 24 m alternando i lati, con composizioni pirata/arpionatore quasi identiche.
6. **Nessun segreto e nessun anello.** Tutte le deviazioni (sale, cantiere) sono vicoli ciechi di andata e ritorno.

**Curva del ritmo (attuale)**
```
 alta |                                          ####(spazioporto)  ##[Vulso]
 med  | ###########################  ###############################
 bassa|#^Nett                       ^Min        ^Merc
      +--------------------------------------------------------------------- s
      0         100        200        300        400        500       560
```

### 1.4 Dungeon generati

| Dungeon | Stanze | Partenza → boss (stima dalla pianta) | Tempo | Note |
|---|---|---|---|---|
| Catacombe (seme 3000) | 11, 56×56 celle da 3 m | circa 175 m lungo il lato est | 8-10 min | 5 cripte, 1 sala a colonne; vicoli ciechi a ovest con buone ricompense potenziali |
| Caverne del Clan (seme 4100) | 9 richieste, ne entrano meno | circa 115 m per il ramo est, 180 m per l'anello | 5-7 min | 2 stanze del tesoro; partenza e boss vicini in linea d'aria (anello) |
| Cisterne (seme 5207) | 12, 60×60 | circa 200 m | 9-11 min | molte sale a colonne, una stanzetta 3×3 al centro senza funzione |

**Diagnosi comune** (codice in `dungeon_level.gd`):
1. **Ogni stanza tranne la partenza ha un gruppo** (`count = clamp(area/10, 3, 8)`): non esistono stanze di riposo.
2. **I forzieri normali sono casuali e possono mancare**: 2 tentativi su stanze a caso, scartati se cadono nel boss o nel tesoro. Non premiano i vicoli ciechi.
3. **Uscita solo nella stanza di partenza**: dopo il boss si torna indietro a piedi per 115-200 m in stanze ormai vuote. In D3 dopo il boss compare un'uscita.
4. **Il boss ha 4 nemici normali in più** (`count = 4`), che si sommano a quelli chiamati dalle fasi (`summon` e `shield`). L'arena diventa caotica e il boss perde leggibilità.
5. Le Caverne hanno solo il tipo "tesoro": stanze tutte uguali.

**Cosa si può cambiare senza cambiare la pianta (importante):**
- I parametri usati da `DungeonGen` **prima** dei tipi (`seed`, `rooms`, `grid`, `tile`, `room_min/max`, `corridor`, `loops`, `style`) **cambiano la pianta**.
- `room_kinds` **non cambia la pianta**: il passo 4 consuma esattamente un `rng.randf()` per stanza, quali che siano i pesi. Cambia solo il tipo delle stanze. Anche la scelta della stanza del boss (passo 3) non tocca le celle.
- Tutto ciò che sta in `DungeonLevel` (props, forzieri, incontri, santuari) usa un altro generatore (`seed*7+1`): cambia arredi e assegnazione delle elite, mai la pianta.

---

## 2. Proposte – Livello 1 (Campagna di Lazio Prime)

### Percorsi

**L1-P1. Anello tempio → colline.** Priorità **media**, costo **medio**.
- Luogo: tra `TempioInRovina` (−115, −410) e la strada (−45, −458).
- Modifica: nuovo `MapRoad` `Sentiero_TempioColline` sotto `Forma` da (−100, −428) a (−48, −456), mezza larghezza 8, `paved_width` 3.5, `paved_color` come gli altri sentieri (0.5, 0.4, 0.28). Poi Ricostruisci terreno.
- Motivo: tempio e boschetto diventano un giro (entri dal bivio, esci verso le colline) invece di 300 m di andata e ritorno. Chi esplora non viene punito, e chi resta sulla strada vede l'uscita del sentiero come invito.
- Controlla: `Lupi_colline` (−40, −455) diventa la "guardia" dell'uscita del sentiero; va bene così.

**L1-P2. Leggibilità del bivio verso il mausoleo.** Priorità **bassa**, costo **piccolo**.
- Luogo: imbocco di `Sentiero_4` (88, −692).
- Modifica: 2 `stendardo` o `lampione_plasma` sotto `World/Luoghi/Mausoleo` a (92, −688) e (96, −698), più un cartello (`LoreSign`) "Mausoleo dei Vetranii [TRAMA]" a (100, −690).
- Motivo: l'entrata delle Catacombe è un contenuto importante, ma la deviazione si distingue poco dalla fila di tombe.

### Arene

**L1-A1. Arena di Brenno: imbuto e piazzale.** Priorità **alta**, costo **medio**.
- Luogo: la porta tra (60, −826) e (50, −890); Brenno (`Incontri/Boss_Brenno`) a (62, −852).
- Modifica:
  1. **Imbuto**: a z ≈ −826, sotto `World/Luoghi/OstiaNova/Barricate` (nuovo gruppo), una fila di barricate (`palizzata` o `muro_rovina` + `cassa`) da x = 36 a x = 62 e da x = 74 a x = 100. Restano un **varco di 12 m** sulla strada (x 62-74) e i bordi della Forma come limiti.
  2. **Piazzale**: nuova `MapArea` `ArenaBrenno` al centro (58, −858), raggio 24, `zone = "citta"`, `scatter = false`, così il terreno è sgombro e la forma si legge circolare. Lascia gli archi dell'acquedotto a ovest come quinta.
  3. 2 `falo` a (46, −850) e (72, −866) come punti luminosi ai lati (riferimento visivo per schivare il salto).
  4. Ricalcolo della navmesh.
- Motivo: modello D3 "corridoio → soglia → arena". Il varco annuncia lo scontro, il piazzale libero dà spazio per schivare l'onda (7 m) e il salto. Le barricate spiegano anche perché "le guardie sono sparite".
- Controlla: `Rinnegati_porta` (100, −790) resta 40 m prima del varco (vedi L1-R4). Brenno ha leash 40 m: il piazzale di raggio 24 lo tiene nell'arena.

**L1-A2. Il ponte come posto di blocco.** Priorità **media**, costo **piccolo**.
- Luogo: testa sud del ponte (≈ 88, −322).
- Modifica: sposta `Incontri/Predoni_ponte` da (100, −305) a (88, −318); `enemy_types` = `["predone", "drone"]`, `count` 5. Aggiungi 2-3 `cassa`/`barile` sotto `World/Luoghi/Ponte` a (82, −316) e (94, −320) come barricata bassa (lasciando libero il passaggio largo 3.6 m del ponte).
- Motivo: si combatte davanti al collo di bottiglia, poi si attraversa e si trova l'altare sull'altra sponda (scontro, poi ricompensa e riposo).

**L1-A3. L'accampamento barbaro come picco di metà livello.** Priorità **media**, costo **piccolo**.
- Luogo: `AccampamentoBarbaro` (−118, −548), palizzata di raggio 20 con due varchi (a est verso la strada e a sud-ovest).
- Modifica: sposta `Campo_barbaro` (8 nemici) al varco est (−100, −546) come "guardia della porta" con `count` 6; `Campioni_campo` resta al centro (−122, −566). Aggiungi una terza zona `Campo_frombolieri` (3 `frombolier`, livello 4, raggio 4) a (−104, −538), vicino alle torri di guardia: tirano sopra la porta mentre si combatte al varco.
- Motivo: oggi i due gruppi si attivano insieme al centro, in un ammasso confuso. Così si sfonda la porta e poi si affronta l'elite dentro il recinto: due tempi, un picco chiaro a metà livello (s ≈ 700), seguito dall'Altare di Proserpina (s ≈ 769) come riposo.

### Segreti

Per tutti i segreti: radura piccola (`MapArea`, `scatter = false`) raggiunta da un **sentiero stretto senza lastricato** (`MapRoad`, mezza larghezza 2.5, `paved_width = 0`), così da lontano sembra solo un varco tra la vegetazione. La nebbia di guerra la nasconde finché non ci si avvicina.

**L1-S1. Il capanno del traghettatore (sponda sud del fiume).** Priorità **media**, costo **medio**.
- Luogo: radura `Segreto_Traghetto` a (150, −320), raggio 9, `zone = "fiume"`; sentiero da (112, −306) (dietro il capanno esistente: `tenda` (112, −316)) a (144, −318).
- Contenuto (sotto `World/Luoghi/Segreti/Traghetto`): `forziere` `flag_id = "chest_segreto_traghetto"`, `item_level` 2, `rich = true`; `cartello` "Il traghettatore [TRAMA]"; 3 `anfora` (breakable); `canne` lungo l'acqua.
- Motivo: premia chi segue la riva invece del ponte; il capanno già esistente fa da indizio.

**L1-S2. La radura del pastore (bosco).** Priorità **bassa**, costo **medio**.
- Luogo: radura `Segreto_Pastore` a (60, −178), raggio 9, `zone = "bosco"`; sentiero da (80, −150) a (64, −172).
- Contenuto: forziere `chest_segreto_bosco` (livello 2, normale), cartello di storia, un santuario fisso (vedi L1-R5) oppure 1 `statua` piccola.
- Motivo: un secondo premio nella parte iniziale, dove oggi ci sono solo lupi.

**L1-S3. La tomba aperta (necropoli, lato ovest).** Priorità **alta**, costo **medio**.
- Luogo: radura `Segreto_TombaAperta` a (−30, −662), raggio 10, `zone = "necropoli"`; sentiero da (−14, −642) a (−26, −656), passando tra due tombe della Via dei Sepolcri.
- Contenuto: `tomba` scala 1.5 aperta (grayboxing: tomba + `sarcofago` ruotato), forziere `chest_segreto_tomba` `rich = true` livello 5, nuova zona `Lemuri_tomba` (`lemure`, `count` 2, `elite = true`, livello 5, raggio 4), cartello `[TRAMA]` (indizio sulle Catacombe o su Brenno).
- Motivo: mini-sfida con ricompensa nella zona più adatta all'esplorazione; conta anche per "Il fuoco tremante" (12 lemuri).

**L1-S4. Il deposito dei rinnegati (dietro l'acquedotto).** Priorità **media**, costo **medio**.
- Luogo: radura `Segreto_Deposito` a (58, −760), raggio 9, `zone = "citta"`; sentiero da (80, −748) passando tra due `arco_acquedotto` (togliere un arco o usarne il varco: gli archi sono a 17 m dalla strada, uno ogni 10 m).
- Contenuto: casse, `barile`, forziere `chest_segreto_deposito` livello 5 normale, cartello "Ordini di Brenno [TRAMA]".
- Motivo: storia raccontata dall'ambiente prima del boss (chi è Brenno, perché la porta è sbarrata) e ultimo premio prima dello scontro.

**L1-S5. Cartelli di storia nelle deviazioni.** Priorità **media**, costo **piccolo**.
- Luogo e testo (`LoreSign`, testi `[TRAMA]`): Fattoria (−48, −90) "Diario del fattore"; Relitto (195, −240) "Registro di volo"; Accampamento (−104, −548) "Totem del clan"; Mausoleo (140, −670) "Epigrafe".
- Motivo: oggi ci sono solo 4 cartelli in 1150 m. Ogni deviazione deve dare anche storia, non solo loot.

### Ritmo degli incontri

**L1-R1. Un'elite sul percorso principale a ogni terzo.** Priorità **alta**, costo **piccolo**.
- `Incontri/Banditi_bosco` (128, −282): `elite = true`, `enemy_types = ["predone", "lupo"]`, `count` 3 (capo raro con servitori, oppure 3 Campioni). È la prima elite (s ≈ 355), seguita dall'Altare di Portuno.
- `Incontri/Barbari_strada` (−82, −500): `elite = true`, `enemy_types = ["barbaro", "frombolier"]`, `count` 3. Seconda elite (s ≈ 660), prima del campo e dell'altare.
- `Incontri/Lemuri_sepolcri2` (42, −662): resta normale (le elite della necropoli sono già in L1-S3 e al mausoleo).
- Motivo: chi segue solo la strada impara gli affissi prima di Brenno; la curva ha 3 picchi crescenti (s 355, 700, 1110).

**L1-R2. Riposo dopo l'Altare di Portuno.** Priorità **alta**, costo **piccolo**.
- Elimina `Incontri/Imboscata_nord` (68, −372). `Barbari_avanguardia` (30, −405): `count` 5 → 7, `enemy_types = ["barbaro", "predone", "drone"]`.
- Motivo: circa 90 m di quiete dopo l'altare (s 427 → 515). Il primo barbaro arriva da solo, come "introduzione" del nuovo nemico.

**L1-R3. Variare la sequenza del bosco.** Priorità **bassa**, costo **piccolo**.
- `Lupi_margine` (110, −160): `count` 4 → 3. `Lupi_bosco` (160, −218): `enemy_types = ["lupo"]`, `count` 5 → 7, `radius` 9 (un branco grande che carica).
- Motivo: piccolo, grande, elite (L1-R1) invece di tre gruppi medi uguali.

**L1-R4. Calma prima di Brenno.** Priorità **media**, costo **piccolo**.
- `Rinnegati_porta` (100, −790): `count` 6 → 4, spostalo a (96, −800). Tra la zona e il varco dell'arena (z −826) restano circa 30 m vuoti, con le barricate visibili.
- Motivo: in D3 c'è sempre un momento di quiete tra l'ultimo gruppo e il boss. Brenno chiama già 3 rinnegati a 2/3 della vita.

**L1-R5. Punti fissi per santuari ed eventi.** Priorità **media**, costo **medio** (codice).
- Codice: in `Level._place_world_extras`, se esistono nodi nel gruppo `punti_extra` (Marker3D sotto `World/Luoghi/PuntiExtra`), scegli tra quelli invece che tra le zone. I santuari vanno su marker con metadato `tipo = "santuario"`, gli eventi su `tipo = "evento"`. Il tipo scelto resta casuale.
- Marker santuario (livello 1): (10, −70) campi; (−20, −440) bivio del tempio; (20, −640) inizio necropoli; (60, −178) radura del pastore (L1-S2).
- Marker evento: (175, −235) sentiero del relitto; (−60, −520) colline; (110, −760) acquedotto.
- Motivo: i santuari cadono nei tratti di riposo e mai accanto agli altari; gli eventi cadono in spazi abbastanza larghi per le ondate.

**Curva del ritmo (proposta)**
```
 alta |                 E                          E [campo]                 [Brenno]
 med  |   p   L  LLL ## #  P        B ##   L   ##   ## #  ####  lem T lem  R  R   ##
 bassa|###            ^Port  ......        S       ^Pros  ....   S  ....^Giano ....
      +----------------------------------------------------------------------------- s
       E = elite sul percorso, S = santuario fisso, T = tomba segreta, .... = riposo voluto
```

---

## 3. Proposte – Ostia Nova

**O-P1. Linea guida intorno alla basilica.** Priorità **media**, costo **piccolo**.
- Luogo: tra il foro (0, −18) e la porta nord (0, −58).
- Modifica: sotto `World/Luoghi/Quartieri`, 4 `lampione_plasma` sul lato est della basilica a (12, −22), (14, −32), (12, −42), (6, −50), allineati verso il cancello, più uno `stendardo` a (−6, −52) accanto al cancello.
- Motivo: dalla città si vede la strada per il porto e, tornando da `DalPorto` (0, −49), una scia di luci porta al foro.

**O-P2. Promessa del porto nell'atto 1.** Priorità **bassa**, costo **piccolo**.
- Luogo: piazzale nord (0, −64), fuori dal cancello.
- Modifica: 2 `gru` o un albero di nave (`nave` scala 0.5) visibili oltre il cancello a (−10, −72) e (12, −74), fuori da `World` (solo decorazione; nessun collider sulla navmesh).
- Motivo: ciò che si vede oltre il cancello chiuso fa da gancio per l'atto 2.

**O-S1. Piccolo segreto nel quartiere nord-ovest.** Priorità **bassa**, costo **piccolo**.
- Luogo: dietro `insula` (−31, −47), a (−42, −54).
- Modifica: forziere una tantum `chest_ostia_eredita` (livello 3, normale), 3 `anfora`, cartello `[TRAMA]` (un ricordo di famiglia). Sotto `World/Luoghi/Quartieri`.
- Motivo: un premio per la prima esplorazione della città, che dà senso ai quartieri vuoti.

**O-A1. Nessuna arena.** È un hub, i servizi entro 20 m vanno bene così. Non spostare Obelisco, Tabula, altare e forziere: sono già raggruppati come in D3.

---

## 4. Proposte – Porto di Ostia Nova

### Percorsi

**P-P1. Anello del cantiere.** Priorità **media**, costo **medio**.
- Modifica: nuovo `MapRoad` `Sentiero_CantiereNord` sotto `Forma` da (−50, −298) a (−22, −262), mezza larghezza 6, `paved_width` 8, colore come gli altri sentieri del porto. Ricostruisci terreno; controlla che non attraversi un `magazzino` (sono a 18 m dalla strada, uno ogni 24 m: se collide, sposta l'estremo nord di 6-8 m).
- Motivo: il cantiere diventa un giro (si può entrare prima dell'Altare di Minerva e uscire dopo) invece di un vicolo cieco.

**P-P2. Un premio per ogni molo.** Priorità **media**, costo **piccolo**.
- Molo 3 (punta ≈ 74, −380): forziere `chest_porto_molo3` livello 8, normale, sotto `World/Luoghi/Moli`; `Molo_3` `count` 7 → 5.
- Molo 1 (punta ≈ 78, −140): 4 `anfora` + cartello "Bolla di carico [TRAMA]" (storia sulla merce rubata di Tito).
- Motivo: nessun vicolo cieco "punitivo"; ogni deviazione restituisce qualcosa.

### Arene

**P-A1. Soglia del faro e altare prima del boss.** Priorità **alta**, costo **medio**.
- Modifica:
  1. Sposta **Altare di Mercurio** (`checkpoint_id = "porto_spazioporto"`) da (−4, −418) a (−2, −500), circa 25 m prima dell'arena. L'id resta uguale (i salvataggi non si rompono; anche il titolo può restare).
  2. **Soglia**: a z ≈ −515, sotto `World/Luoghi/Faro`, `muro` / `muro_rovina` da x = −8 a x = 10 e da x = 22 a x = 40, con un **varco di 12 m** (x 10-22) sulla strada. 2 `stendardo` di Vulso ai lati del varco (12, −514) e (20, −514). Ricalcolo della navmesh.
  3. Arena: `Area_faro` (20, −550, raggio 30) resta; sposta le `tenda` (6, −558) e (34, −542) verso il bordo, a (−2, −562) e (42, −548), per liberare un cerchio di circa 18 m (la pioggia di fuoco della fase 3 ha bisogno di spazio).
- Motivo: se l'eroe muore contro Vulso, rinasce a 25 m dall'arena invece di rifare 110 m e 2 scontri. La soglia separa l'ultimo gruppo dall'arena.
- Attenzione: `test_atto2.gd` cammina fino al faro e usa gli altari; va aggiornato se controlla la posizione dell'altare di Mercurio.

**P-A2. Lo spazioporto come picco voluto.** Priorità **media**, costo **piccolo**.
- Modifica: `Strada_spazioporto` (−12, −398) `count` 6 → 4; `Droni_spazioporto` (22, −432) resta; `Spazioporto_ciurma` (34, −458) `count` 6 → 5; `Spazioporto_campioni` (14, −455) resta elite. Così, con l'altare spostato (P-A1), lo spazioporto è "lo scontro grande di metà livello" e non si somma più all'altare.
- Motivo: oggi 4 gruppi entro 40 m si attivano insieme proprio sull'altare.

### Segreti

**P-S1. Il nascondiglio dei contrabbandieri.** Priorità **media**, costo **medio**.
- Luogo: radura `Segreto_Contrabbandieri` a (−58, −236), raggio 9, `zone = "magazzini"`; vicolo stretto (mezza larghezza 2.5, `paved_width` 0) da (−30, −228) a (−52, −234), tra due magazzini sul lato ovest.
- Contenuto: forziere `chest_segreto_contrabbando` livello 7 `rich = true`, `pila_casse`, `barile`, cartello "Il tunnel [TRAMA]" (indizio che le cisterne sotto i magazzini sono un covo: lega il segreto al dungeon).
- Motivo: nel tratto più ripetitivo (i magazzini) c'è una sorpresa, e la storia rimanda alle Cisterne.

**P-S2. La lanterna del faro.** Priorità **bassa**, costo **piccolo**.
- Luogo: dietro il faro, (20, −578) (il faro è a (20, −570)).
- Contenuto: cartello `[TRAMA: atto 3]` + 4 `anfora`. Si scopre solo dopo Vulso.
- Motivo: un premio narrativo che passa all'atto 3.

### Ritmo degli incontri

**P-R1. Tre tratti di riposo.** Priorità **alta**, costo **piccolo**.
- Elimina `Granchi_strada` (−12, −82) e alza `Pirati_strada` (−20, −120) a `count` 6 con `["pirata", "granchio"]`: dopo l'altare di Nettuno ci sono circa 100 m di quiete (porta → primo vero scontro), con `Pirati_ingresso` ridotto a `count` 3 come assaggio.
- Elimina `Gru_pirati` (12, −335): dopo l'Altare di Minerva (obiettivo della missione) ci sono circa 80 m di quiete.
- Elimina `Strada_faro` (−8, −485), oppure riducilo a 3 `arpionatore` sopra la soglia a (14, −508) come "sentinelle": prima dell'arena di Vulso c'è un momento di calma.
- Totale: da 20 a 17 zone, circa 80 nemici. "Ripulire i moli" (30 pirati) resta fattibile: i pirati sul percorso principale e sui moli sono ancora più di 40.

**P-R2. Varietà nei magazzini.** Priorità **bassa**, costo **piccolo**.
- `Magazzini_1` (−22, −170): `elite = true`, `enemy_types = ["pirata", "arpionatore"]`, `count` 3. È la prima elite sul percorso principale del porto, prima della deviazione del sale.
- `Automa_magazzini` (−12, −215): tieni l'automa da solo con 4 granchi (`["automa", "granchio", "granchio", "granchio", "granchio"]`, `count` 5): un "nemico grande" che si legge bene.

**P-R3. Punti fissi per santuari ed eventi** (dipende da L1-R5). Priorità **media**, costo **piccolo** una volta fatto L1-R5.
- Santuari: (−10, −100), (−20, −330), (20, −480). Eventi: (−40, −200), (0, −370).

**Curva del ritmo (proposta)**
```
 alta |                   E                         ####(spazioporto)        [Vulso]
 med  |  p     ####  ######  ##  ##                ##                  
 bassa|##^Nett.....          ....^Min......              ...........^Merc|soglia
      +------------------------------------------------------------------------ s
```

---

## 5. Proposte – Dungeon generati

**D1. Uscita dopo il boss.** Priorità **alta**, costo **medio** (codice).
- Dove: `world/dungeon_level.gd`. Quando muore il boss della campagna (`unique_id` della stanza del boss, fuori dai labirinti), crea una `LevelExit` "Uscita" (come fa `_complete_rift` con "UscitaLabirinto") al centro della stanza del boss, con scala e luce come `_build_exit`. Riusa `on_exit_reached`.
- Motivo: evita 115-200 m di ritorno nelle stanze vuote. In D3 si esce dopo il boss. La pianta non cambia.

**D2. Stanze di riposo con santuario (nuovo tipo "sacello").** Priorità **alta**, costo **medio** (codice) + **piccolo** (dati).
- Codice: in `_build_encounters`, `kinds[i] == "sacello"` → nessuna zona di nemici (non conta per `rift_target`); in `_build_shrines` il primo santuario va sempre in una stanza "sacello" (se c'è), al centro. In `_build_rooms`: 2 `lampione_plasma` o `falo` ai lati.
- Dati (`room_kinds`, **la pianta non cambia**):
  - catacombe: `[["cripta", 0.3], ["colonne", 0.2], ["tesoro", 0.1], ["sacello", 0.12]]`
  - caverne_clan: `[["tesoro", 0.15], ["sacello", 0.12], ["colonne", 0.2]]` (vedi D4)
  - cisterne: `[["colonne", 0.45], ["tesoro", 0.12], ["sacello", 0.12]]`
- Motivo: oggi tutte le stanze tranne la partenza hanno nemici; servono pause nel ritmo stanza dopo stanza.
- Attenzione: cambiare i pesi cambia **quali** stanze sono cripte o sale a colonne. Se `fingerprint()` include `kinds`, aggiorna i valori attesi in `test_dungeon.gd`; le celle restano identiche.

**D3. Forzieri nei vicoli ciechi.** Priorità **media**, costo **medio** (codice).
- Codice: al posto dei 2 tentativi casuali (`for k in 2`), calcola per ogni stanza quanti sbocchi ha (celle di pavimento appena fuori dal rettangolo, raggruppate) e metti un forziere normale in **ogni stanza con un solo sbocco** che non sia partenza, boss o tesoro (massimo 3). Se non ce ne sono, metti i forzieri nelle stanze più lontane dal percorso partenza → boss (`dist` di `_flood`).
- Motivo: esplorare i rami morti (es. il lato ovest delle Catacombe) deve pagare sempre, non a caso.

**D4. Caverne: "colonne" di roccia.** Priorità **bassa**, costo **piccolo**.
- Dati: in `caverne_clan` aggiungi `"column": "roccia_grande"` e `["colonne", 0.2]` in `room_kinds` (già in D2). `_room_columns` controlla `is_open` tramite `_prop`, quindi le rocce non finiscono nella parete.
- Motivo: grotte con stalagmiti a griglia rompono la monotonia delle stanze tutte uguali. La pianta non cambia.

**D5. Arena del boss più leggibile.** Priorità **media**, costo **piccolo**.
- Codice: in `_build_encounters`, nella stanza del boss della campagna `count = 2` (invece di 4), nei labirinti resta 7. Le fasi dei boss chiamano già 3-6 rinforzi.
- Opzionale (costo medio, la pianta non cambia): in `DungeonGen._build`, passo 3, scegli come boss la stanza più lontana **tra quelle di almeno 7×7 celle** e con distanza ≥ 80% della massima; se non ce ne sono, la più lontana come oggi. Cambiano solo il tipo delle stanze (da riverificare in `test_dungeon.gd`), non le celle. Va controllato sulle piante attuali con `export_dungeons.gd`: Catacombe e Cisterne sembrano già andare bene, le Caverne vanno verificate.

**D6. Anticamera del boss.** Priorità **bassa**, costo **medio** (codice).
- Codice: la stanza collegata a quella del boss più vicina alla partenza (`dist` minore) non ha nemici normali ma un gruppo elite (`count` 3) e un cartello `[TRAMA]` davanti allo sbocco verso il boss.
- Motivo: il classico "ultimo guardiano, poi il boss": un picco prima del picco e un avviso per il giocatore.

**D7. (Solo se l'utente accetta una pianta nuova) Caverne più profonde.** Priorità **bassa**, costo **medio**.
- Dati: `rooms` 9 → 11, `grid` 52 → 58; scegli un seme nuovo con `--script res://tools/export_dungeons.gd -- <seme>` cercando un percorso partenza → boss di almeno 160 m e un anello. Aggiorna `test_dungeon.gd`.
- Motivo: oggi il percorso breve (ramo est) è di circa 115 m, il dungeon più corto. **Cambia la pianta fissa**: serve la decisione dell'utente.

---

## 6. Tabella riassuntiva – le modifiche da fare per prime

| # | Proposta | Livello | Cosa toccare | Priorità | Costo |
|---|---|---|---|---|---|
| 1 | **L1-R1** Elite sul percorso principale (`Banditi_bosco`, `Barbari_strada`) | Livello 1 | `Incontri/*`: `elite`, `enemy_types`, `count` | alta | piccolo |
| 2 | **L1-R2** Riposo dopo l'Altare di Portuno (togli `Imboscata_nord`) | Livello 1 | `Incontri/Imboscata_nord`, `Barbari_avanguardia.count` | alta | piccolo |
| 3 | **P-R1** Tre tratti di riposo nel porto (togli `Granchi_strada`, `Gru_pirati`, `Strada_faro`) | Porto | `Incontri/*` | alta | piccolo |
| 4 | **P-A1** Altare di Mercurio prima di Vulso + soglia del faro | Porto | `World/Luoghi/Spazioporto/<altare>`, muri sotto `World/Luoghi/Faro`, navmesh, `test_atto2.gd` | alta | medio |
| 5 | **L1-A1** Arena di Brenno (varco di 12 m + piazzale `ArenaBrenno`) | Livello 1 | barricate sotto `World/Luoghi/OstiaNova`, `Forma/ArenaBrenno`, navmesh | alta | medio |
| 6 | **D1** Uscita dopo il boss nei dungeon | Dungeon | `world/dungeon_level.gd` | alta | medio |
| 7 | **D2** Stanze "sacello" senza nemici con santuario | Dungeon | `dungeon_level.gd` + `room_kinds` (pianta invariata) | alta | medio |
| 8 | **L1-S3** Tomba aperta nella necropoli (primo segreto vero) | Livello 1 | `Forma` (radura + sentiero stretto), forziere, `Lemuri_tomba` | alta | medio |

Subito dopo: L1-R5 / P-R3 (punti fissi per santuari ed eventi), L1-P1 (anello del tempio), P-S1 (contrabbandieri), D3 (forzieri nei vicoli ciechi), L1-A2 (posto di blocco del ponte).
