# Modelli da fare con Tripo 3D (pensati per il riuso)

Obiettivo: **il minor numero di modelli, usati il più possibile**. Invece di un modello per ogni
personaggio o edificio si fanno dei **kit**: corpi, teste, pezzi di equipaggiamento, moduli di
edifici, pochi elementi naturali. Poi si combinano, si scalano, si ruotano e si **tingono**.
Segna `[x]` quando un pezzo è fatto.

## Regole per tutti i modelli

- **Stile** (deciso): Diablo 3, realistico ma non esagerato; materiali leggibili da lontano.
- **Prompt base** sempre davanti (in inglese Tripo rende meglio):
  `stylized realistic, Diablo 3 style, hand-painted textures, game asset, low poly, roman empire in the year 3000, sci-fi roman,`
- **Colori neutri** (grigio, bronzo, cuoio, tela chiara): il colore finale si dà in Godot con una **tinta**.
  Così lo stesso pezzo serve per più personaggi, rarità, set e per la scheda Aspetto. Le parti che devono
  brillare (plasma, cristalli) vanno in un **materiale separato** (si colorano da sole).
- **Armi = metallo + energia**: Tripo fa solo il **corpo in metallo** (elsa, lama, testa della scure), senza
  bagliori; il **guscio di energia** attorno alla lama lo aggiunge Godot (materiale `"energia"` in `data/visual_db.gd`,
  un pezzo un po' più grande della lama). Così l'energia scorre, si anima e prende il colore della rarità.
- **Scala** 1 unità = 1 m (eroe circa 1,85 m), **origine a terra al centro**, davanti verso **−Z**.
- **Un oggetto per generazione.** Personaggi in posa **T**, senza armi in mano.
- **Animazioni**: un'unica libreria Mixamo per **tutti** gli umanoidi (eroi, nemici umani, NPC):
  `idle`, `run`, `attack`, `cast`, `hit`, `death` (+ varianti per scudo, arco, due mani).

Priorità: **P1** subito (prova del flusso), **P2** gioco attuale, **P3** rifiniture, **F** futuro.

---

## Kit 1 – Corpi umanoidi (8) → servono anche a nemici e NPC

Gli 8 corpi degli eroi (2 per classe, come deciso) sono **anche** i corpi di tutti gli umani del gioco.
Consiglio: generare prima il corpo maschile e quello femminile del Legionario, riggarli su Mixamo, poi
fare gli altri 6 **partendo da quelli** (stesso scheletro e stesse proporzioni di base, cambia la corporatura):
le animazioni e i pezzi di equipaggiamento vanno su tutti senza ritocchi.

| ✓ | Pr. | Corpo | Corporatura | Riusato anche per |
|---|---|---|---|---|
| [ ] | P1 | Legionario M | robusto | guardia, legionario rinnegato, prefetto, Brenno (×1,3) |
| [ ] | P2 | Legionario F | atletica | guardia donna, cittadina |
| [ ] | P2 | Gladiatore M | muscoloso, più grosso | barbaro, bruto (×1,4), Tharvo (×1,6), fabbro |
| [ ] | P2 | Gladiatore F | muscolosa | barbara, pirata donna |
| [ ] | P2 | Sagittario M | snello | predone, frombolier, pirata, arpionatore, cittadino |
| [ ] | P2 | Sagittario F | snella | predona, cittadina |
| [ ] | P2 | Augure M | normale, più anziano | mercante, Vulso (con cappotto), cittadino anziano |
| [ ] | P2 | Augure F | normale | vestale, sacerdotessa |

Prompt: `<descrizione corpo>, simple short neutral grey tunic, bare arms, sandals, no hair, T-pose, full body`
(senza capelli: li mette il kit 2). Il **lemure** e il **Custode** possono essere il corpo Augure / Gladiatore
con un materiale spettrale semitrasparente o scheletrico: niente modello nuovo.

## Kit 2 – Teste, capelli, barbe (pezzi sulla presa della testa)

| ✓ | Pr. | Pezzo | Usi |
|---|---|---|---|
| [ ] | P2 | Testa maschile giovane / anziana / segnata | eroi, NPC, nemici |
| [ ] | P2 | Testa femminile giovane / anziana | eroi, NPC, nemiche |
| [ ] | P2 | Capelli: corti, rasati, lunghi, coda, treccia, chignon | tutti (tinta per il colore) |
| [ ] | P2 | Barba corta, barba lunga, baffi | barbari, pirati, NPC |
| [ ] | P3 | Teschio (testa scheletrica), visore luminoso, maschera da predone | lemuri, Custode, predoni, rinnegati |

Circa **15 pezzi** per centinaia di combinazioni.

## Kit 3 – Equipaggiamento (pezzi rigidi o con pesi) → eroi, nemici, NPC, Aspetto

Ogni pezzo vale tre volte: **loot dell'eroe**, **aspetto per la scheda Aspetto** e **vestito dei nemici/NPC**.
Pezzi doppi (schinieri, calzari, bracciali, spallacci, guanti) si fanno **una volta**: l'altro è lo specchio.

| ✓ | Pr. | Id | Prompt | Lo indossano anche |
|---|---|---|---|---|
| [ ] | P1 | galea | `roman galea helmet, iron, cheek guards, crest` | guardie, rinnegati |
| [ ] | P2 | elmo_centurione | `roman centurion helmet, transverse crest` | Brenno, prefetto (cerimonia) |
| [ ] | P2 | cappuccio | `cloth hood with trim` | predoni, frombolieri, augure |
| [ ] | P2 | lorica | `roman lorica segmentata chest armor, plates` | guardie, rinnegati |
| [ ] | P2 | lorica_hamata | `chainmail shirt` (pesi) | pirati, barbari, arpionatori |
| [ ] | P2 | toga | `draped roman toga` (pesi) | prefetto, mercante, cittadini, vestale (tinta bianca) |
| [ ] | P2 | humeralia | `single segmented shoulder pauldron` | guardie, bruto |
| [ ] | P2 | spallacci_bronzo | `single round shoulder guard` | gladiatori, Tharvo |
| [ ] | P2 | cingulum | `military belt with hanging straps` | quasi tutti i soldati |
| [ ] | P2 | balteo | `leather baldric strap` | pirati, arcieri |
| [ ] | P2 | manicae | `segmented arm guard` | gladiatori, bruto |
| [ ] | P2 | guanti_cuoio | `leather glove` | predoni, fabbro |
| [ ] | P2 | armillae | `gold arm ring` | NPC ricchi, Vulso |
| [ ] | P2 | bracciali_cuoio | `leather bracer` | arcieri, pirati |
| [ ] | P2 | ocreae | `bronze greave` | guardie, rinnegati |
| [ ] | P2 | bracae | `wool trousers` (pesi) | barbari, predoni, cittadini |
| [ ] | P2 | caligae | `hobnailed military sandal boot` | soldati |
| [ ] | P2 | calcei | `closed leather shoe` | cittadini, NPC |

Pezzi **solo per nemici/NPC**, che diventano anche aspetti sbloccabili per l'eroe (P3):
[ ] pelliccia sulle spalle (barbari) · [ ] elmo cornuto (barbari) · [ ] bandana (pirati) · [ ] cappotto lungo
(Vulso, arpionatore) · [ ] grembiule di cuoio (fabbro) · [ ] velo (vestale) · [ ] corona d'alloro (prefetto) ·
[ ] mantello (riusabile da tutti).

**Totale kit 3: 18 + 8 = 26 pezzi.**

## Kit 4 – Armi (anche per nemici e NPC)

| ✓ | Pr. | Id | Prompt | Lo usano anche |
|---|---|---|---|---|
| [ ] | P1 | gladio_plasma | `roman gladius, metal blade with engraved energy channels, no glow` (energia da Godot) | guardie, rinnegati |
| [ ] | P1 | scutum | `roman scutum curved shield, eagle emblem, force field edge` | guardie, rinnegati |
| [ ] | P2 | spatha | `long roman spatha sword, engraved energy channels, no glow` (energia da Godot) | Brenno (×1,4), pirati |
| [ ] | P2 | scure | `heavy one-handed battle axe, engraved energy channels, no glow` (energia da Godot) | barbari, Tharvo (×1,5), gladiatore doppia arma |
| [ ] | P2 | arco_plasma | `recurve bow, glowing string (separate material)` | arcieri nemici |
| [ ] | P2 | manuballista | `hand crossbow with rail` | arpionatore (con rampino) |
| [ ] | P2 | lituo | `curved augur staff` | NPC sacerdoti |
| [ ] | P2 | bastone_giove | `long staff with crystal orb` | vestale, sacerdoti |
| [ ] | P2 | parma | `small round shield` | barbari, pirati |
| [ ] | P2 | pugio | `roman dagger` | predoni, NPC (alla cintura) |
| [ ] | P2 | faretra | `quiver with arrows` | arcieri nemici, frombolieri |
| [ ] | P2 | sfera_oracolo | `floating glass orb` | vestale |
| [ ] | P3 | fionda, lancia, clava, rampino | per frombolieri, guardie, barbari, arpionatore | anche come basi future |

**Totale kit 4: 12 (+4).**

## Kit 5 – Non umani (pochi, con varianti)

| ✓ | Pr. | Modello | Prompt | Varianti senza modelli nuovi |
|---|---|---|---|---|
| [ ] | P2 | Lupo cibernetico | `cybernetic wolf, metal plates` | elite (×1,25), tinte diverse |
| [ ] | P2 | Granchio meccanico | `mechanical crab robot` | Madre dei Granchi = stesso modello ×3,2 + uova (pezzo) |
| [ ] | P2 | Drone | `hovering spherical drone` | tinte; un pezzo "cannone" opzionale |
| [ ] | P2 | Automa | `bronze worker automaton, humanoid` | se umanoide, prende le animazioni Mixamo |

Rig: lupo e granchio con l'auto-rig di Tripo o in Blender (Mixamo non li gestisce); drone senza scheletro.

## Kit 6 – Natura (pochi elementi, tanta varietà)

| ✓ | Pr. | Pezzo | Sostituisce |
|---|---|---|---|
| [ ] | P2 | Tronco + 3 chiome (pino, latifoglia, cipresso) | albero_pino, albero_quercia, pino_marittimo, cipresso, olivo (chioma latifoglia piccola, tinta), bosco_fitto (gruppo) |
| [ ] | P2 | 3 rocce (piccola, media, grande) | roccia_piccola, roccia_grande, scogliera (rocce grandi ruotate), sassi dei dungeon caverna |
| [ ] | P2 | Cespuglio, ciuffo d'erba, canne | cespuglio, canne, vegetazione sparsa |
| [ ] | P2 | Tronco caduto | tronco |

**Totale: circa 11 pezzi** per tutta la vegetazione.

## Kit 7 – Architettura romana modulare (città, rovine, porto, dungeon)

Moduli a misura di griglia (**3 m**, come le celle dei dungeon). Con questi si montano casa, insula,
isolato, basilica, magazzino, fienile, porta della città, torre, muri e rovine. La versione "rovina" è lo
stesso modulo con un materiale rovinato o un pezzo spezzato.

| ✓ | Pr. | Modulo | Usato per |
|---|---|---|---|
| [ ] | P2 | Muro dritto 3 m (intonaco) + versione pietra | case, insulae, muri della città, magazzini, dungeon |
| [ ] | P2 | Muro con porta / con finestra | edifici |
| [ ] | P2 | Angolo, muro basso, muro spezzato | rovine, recinti, dungeon (lato sud) |
| [ ] | P2 | Tetto di tegole (falda) + colmo | tutti gli edifici, fienile (tinta legno) |
| [ ] | P2 | Colonna intera + capitello + base; colonna rotta | portici, basilica, tempio, foro, rovine, sale a colonne dei dungeon |
| [ ] | P2 | Arco (con pilastri) | arco dell'acquedotto, porta della città, uscite, porte dei dungeon |
| [ ] | P2 | Gradini, pavimento a lastre, pavimento di mosaico | tempio, basilica, foro, scala dei dungeon |
| [ ] | P3 | Torre (base + piano) | torre di guardia, faro (più piani + lanterna luminosa) |
| [ ] | P3 | Palo/trave di legno, tavolato | palizzata, staccionata, molo, piattaforma, bancarella, gru |

**Totale: circa 15 moduli** al posto di una ventina di edifici separati.

## Kit 8 – Oggetti piccoli (riusati ovunque)

| ✓ | Pr. | Pezzo | Usi |
|---|---|---|---|
| [ ] | P2 | Cassa, barile, anfora, sacco | rompibili, pila_casse (casse impilate), carro, porto, bancarella, magazzino |
| [ ] | P2 | Forziere | forziere normale e decorato (tinta oro), scrigno personale (tinta blu), forziere maledetto (tinta viola + catene) |
| [ ] | P2 | Altare/piedistallo + sfera luminosa | altare-checkpoint, santuario (sfera colorata), pilone (cristallo al posto della sfera), base dell'obelisco |
| [ ] | P2 | Statua (posa neutra) | statue, monumento; con tinta bronzo/marmo |
| [ ] | P2 | Sarcofago, tomba | cripte, necropoli |
| [ ] | P2 | Stendardo (palo + drappo) | stendardo, stendardo del clan (tinta + teschio), insegne |
| [ ] | P2 | Lampada/torcia + braciere + falò | lampione al plasma, torce dei dungeon, falò, fucina |
| [ ] | P2 | Gabbia, cartello, pozzo, fontana | eventi, cartelli, campagna, foro |
| [ ] | P3 | Ruota, carro, nave, gru, relitto | porto e campagna (la nave e il relitto riusano tavolato e vele) |

**Totale: circa 25 pezzi.**

## Kit 9 – Oggetti di gioco (piccoli, molti con effetti)

[ ] sacchetto del loot (uno, colore per rarità) · [ ] monete · [ ] globo di vita · [ ] 1 gemma tagliata (5 tinte) +
montatura d'oro (gemma leggendaria) · [ ] anello del portale (portale cittadino e uscita del labirinto, tinta) ·
proiettili: **nessuno** (pilum, dardi, rete, bolas, granata, trappola e corvi sono energia fatta da Godot; la
Scure rotante usa il modello della scure del kit 4). Fuoco, fulmini, sfere e meteore sono **effetti** (shader). **Circa 5 pezzi.**

---

## Chi si costruisce con cosa (nessun modello nuovo)

| Personaggio | Corpo (kit 1) | Testa (kit 2) | Equipaggiamento (kit 3-4) | Tinta |
|---|---|---|---|---|
| Guardia | Legionario M/F | qualsiasi | galea, lorica, ocreae, caligae, gladio, scutum | rosso città |
| Legionario rinnegato | Legionario M | visore luminoso | galea, lorica, ocreae, gladio | nero/rosso spento |
| Predone | Sagittario M/F | maschera | cappuccio, bracae, guanti, pugio | marrone |
| Frombolier | Sagittario M | capelli lunghi | bracae, faretra, fionda | ocra |
| Barbaro | Gladiatore M/F | barba lunga | pelliccia, elmo cornuto, bracae, scure, parma | pelli |
| Bruto | Gladiatore M ×1,4 | segnata | humeralia, manicae, clava | ferro scuro |
| Lemure | Augure M | teschio | toga strappata | spettrale (semitrasparente) |
| Pirata cilicio | Sagittario M/F | bandana + barba | lorica_hamata, balteo, spatha | blu mare |
| Arpionatore | Sagittario M | barba | cappotto, bracciali, rampino | grigio |
| Brenno (boss) | Legionario M ×1,3 | barba | elmo_centurione, lorica, mantello, spatha ×1,4 | nero e oro |
| Vulso (boss) | Augure M | barba + bandana | cappotto, armillae, spatha | rosso corsaro |
| Custode (boss) | Gladiatore M ×1,4 | teschio | lorica rotta, ocreae | osso |
| Tharvo (boss) | Gladiatore M ×1,6 | elmo cornuto | pelliccia, spallacci, scure ×1,5 | ferro |
| Mercante | Augure M | anziana | toga colorata, calcei | giallo |
| Fabbro | Gladiatore M | barba | grembiule, guanti | cuoio |
| Prefetto | Legionario M | anziana | toga bianca, corona d'alloro | bianco/porpora |
| Vestale | Augure F | velo | toga bianca, bastone | bianco |
| Cittadini | qualsiasi | qualsiasi | toga o tunica, calcei | casuale |

Lato codice servirà far usare a nemici e NPC lo stesso sistema dell'eroe (`core/appearance.gd`):
in `EnemyDB`/`NpcDB` un "corpo" + elenco di pezzi + tinte invece di un modello unico. È già pensato per
questo; si fa quando arrivano i primi modelli veri.

## Totale

| Kit | Pezzi |
|---|---|
| 1 Corpi | 8 |
| 2 Teste e capelli | ~15 |
| 3 Equipaggiamento | 26 |
| 4 Armi | 12 (+4) |
| 5 Non umani | 4 |
| 6 Natura | ~11 |
| 7 Architettura | ~15 |
| 8 Oggetti piccoli | ~25 |
| 9 Oggetti di gioco | ~9 |
| **Totale** | **circa 125-130 pezzi** per **tutto** il gioco attuale **e** gran parte del futuro |

Con i kit, **l'atto 3 e i nuovi dungeon costano pochissimo**: nuovi nemici umani = corpo + pezzi + tinta;
nuovi edifici = moduli del kit 7; un nuovo stile di dungeon = 5-6 moduli di muro/pavimento.
Serviranno modelli nuovi solo per creature non umane e per i boss davvero speciali.

## Ordine consigliato

1. **P1**: corpo Legionario M + galea + gladio + scutum → prova del flusso Tripo → Blender → Mixamo → Godot.
2. Gli altri 7 corpi + teste e capelli (kit 1-2): da qui escono anche tutti i nemici umani e gli NPC.
3. Kit 3-4 (equipaggiamento e armi): riempie eroi, nemici, NPC e la scheda Aspetto in un colpo.
4. Kit 6-7-8 (natura, architettura, oggetti): rifà l'aspetto di tutte le mappe.
5. Kit 5 e 9, poi i pezzi P3 e F.
