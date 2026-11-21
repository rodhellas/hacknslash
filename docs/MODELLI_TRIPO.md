# Modelli da fare con Tripo 3D (pensati per il riuso)

Obiettivo: **il minor numero di modelli, usati il più possibile**. Invece di un modello per ogni
personaggio o edificio si fanno dei **kit**: corpi, teste, pezzi di equipaggiamento, moduli di
edifici, pochi elementi naturali. Poi si combinano, si scalano, si ruotano e si **tingono**.
Segna `[x]` quando un pezzo è fatto.

## Regole per tutti i modelli

- **Stile** (deciso): Diablo 3, realistico ma non esagerato; materiali leggibili da lontano.
- **Flusso deciso: prima l'immagine, poi il modello** (image-to-3D, vedi sotto "Flusso immagine → modello").
  I prompt nelle tabelle dei kit sono il **soggetto** da mettere nei modelli di prompt delle immagini.
  Testo diretto su Tripo solo per prove veloci o oggetti semplicissimi (sasso, barile), con davanti:
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

## Stato e cartelle (21-11-2026)

- `arte/concept/` immagini di concept (e fogli multivista divisi), `arte/tripo/` GLB come escono da Tripo,
  `arte/modelli/<nome>/<nome>.blend` file Blender sistemati (con `arte/.gdignore`: Godot non li importa).
- `modelli/equipaggiamento/<id base>.glb`: pezzi pronti per il gioco, collegati in `data/visual_db.gd` (`"scene"`).
- Fatti: **gladio_plasma** (1.202 tri + guscio `gladio_plasma_energia.glb`), **scutum** (1.783 tri), **galea**
  (2.032 tri). **Legionario M** (in gioco dal 21-11): 13.122 tri in 6 parti, scheletro Mixamo da 65 ossa,
  28 animazioni → `modelli/corpi/legionario_m.glb`, scena `scenes/characters/legionario_vero.tscn`
  (`HeroClasses` "model"; il graybox `legionario.tscn` resta per i test e il generatore). Il viso è debole (Tripo
  l'ha visto a ~60 px nel foglio): si rifà con una testa a parte (Kit 2) da un'immagine di solo busto.

## Corpo con Mixamo (fatto per il Legionario M, da ripetere per gli altri corpi)

1. Blender: corpo sistemato come sopra, davanti verso **−Y**, piedi a z = 0 → `<nome>_mixamo.fbx`.
2. mixamo.com: Upload Character, segnaposto, Skeleton **Standard (65)**. Scarica il personaggio **senza
   animazione** (Pose: T-pose: contiene già la pelle) → `mixamo/<nome>_skin.fbx`; poi le animazioni
   **Without Skin** nella stessa cartella `mixamo/`.
3. Blender (`legionario_m_rig.blend` come esempio): importa la pelle, poi ogni animazione come traccia NLA col nome
   del gioco (`idle`, `run`, `walk`, `attack`, `cast`, `hit`, `death`, varianti `_2`, `_3`..., `block`, `dodge`).
   Lo spostamento orizzontale del bacino si azzera **solo** nelle animazioni che avanzano più di 30 cm (il gioco
   muove l'eroe da codice); quelle già sul posto restano intatte (ondeggiano). Le morti lo tengono.
4. Pesi limitati a 4 ossa per vertice; normali copiate dai vertici (custom normals) e corpo diviso per osso
   dominante in `Testa`, `Busto`, `Braccia`, `Mani`, `Gambe`, `Piedi` (nessuna cucitura di luce ai tagli).
5. Export GLB con pelle e animazioni (`export_animation_mode='NLA_TRACKS'`, campionate) in `modelli/corpi/`.
6. Godot: `--script res://tools/build_corpo_vero.gd -- <glb> <scena>` crea la scena: GLB girato di 180°,
   12 prese = `BoneAttachment3D` "Osso_*" (scheletro esterno) + `Marker3D` "Presa_*" messo in modo che nella posa
   a T abbia l'orientazione delle prese graybox (i pezzi di `VisualDB` valgono per tutti e due i corpi).
   Il Player mette in ciclo idle/run/walk, sfuma 0,15 s, accelera l'attacco alla cadenza dei colpi.

## Come si sistema un GLB di Tripo (Blender)

Strumenti nella skill `blender-game-assets` (`scripts/blender_exec_addon.py` + `bpy_lib.py` + `tripo_lib.py`).
Cosa arriva da Tripo: modello normalizzato a **~100 unità** di altezza, Z in alto, **vertici spezzati lungo le
cuciture UV** (centinaia di "parti sciolte"), solo la texture del **colore** 2048, materiale HASHED, troppi
triangoli (corpo 36k, armi/elmo ~6k). Passi:

1. Importa, togli il nodo vuoto, applica le trasformazioni, **unisci i vertici sovrapposti** (le UV restano).
2. Se Tripo ha fatto più oggetti (es. lo scutum: le 3 viste del foglio = 3 scudi) tieni quello giusto per parti
   connesse.
3. **Orienta e scala per la presa** (assi di Godot; in Blender davanti = +Y): origine nel punto della presa.
   Armi: impugnatura all'origine, lama verso −Z, piatto della lama in alto. Scudi: davanti verso −X (fuori dal
   braccio sinistro), cinghie a 4 cm dall'avambraccio. Elmi: provati sulla testa del corpo vero (scala minima
   senza che il cranio buchi l'elmo, controllata con raggi), origine nel punto della presa (y = 1,74 su 1,85 m).
4. **Riduzione** (Decimate collapse, le UV restano): armi ~1.200, scudo ~1.800, elmo ~2.000, corpo ~13.000 con
   la **testa esclusa** (ridotta crea segni sul viso lungo le cuciture della texture).
5. Materiale opaco, texture 1024 per i pezzi (2048 il corpo), export GLB con texture JPEG, verifica reimportando.
6. Armi: il **guscio di energia** è la lama copiata e gonfiata di 7 mm (`<id>_energia.glb`, chiave `"energy"`).

Finché i corpi sono graybox, `Appearance` ingrandisce gli elmi veri sulla sfera della testa
(`VisualDB.HEAD_WIDTH`); col corpo vero la scala torna 1.

---

## Flusso immagine → modello

Perché: lo **stile resta uguale** su ~130 pezzi (stesso generatore + stessa immagine di riferimento), le prove
in 2D costano poco (i crediti Tripo si spendono solo sull'immagine giusta) e posa, colori neutri, niente armi
in mano, niente bagliori si controllano **prima** di generare il modello.

1. **Immagine di riferimento dello stile.** La prima immagine approvata (il Legionario M) diventa il riferimento
   di stile di tutte le altre: Midjourney `--sref <link>`, ChatGPT/Gemini "same art style as the attached image".
   Non cambiare generatore a metà kit. Candidati per il generatore principale (rispettano posa, viste e sfondo
   bianco): **Nano Banana Pro** e **GPT Image 2.5**; si sceglie con una prova sui 4 pezzi P1. Midjourney (v8.2)
   solo per esplorare lo stile, poi la sua immagine fa da riferimento al generatore principale.
2. **Immagine del pezzo** con i modelli di prompt qui sotto: un oggetto per immagine, intero, sfondo bianco.
3. **Controllo prima di Tripo** (se fallisce, rifai l'immagine, non il modello):
   - oggetto intero, non tagliato dai bordi, niente testo/scritte/firme, niente secondo oggetto;
   - luce piatta, **nessuna ombra marcata o riflesso dipinto** (finirebbero nella texture);
   - colori neutri (grigio, bronzo, cuoio, tela chiara), niente bagliori, energia, plasma, fiamme;
   - personaggi: posa a T, braccia orizzontali, dita aperte, gambe un po' divaricate, mani vuote, testa rasata;
     nel foglio multivista le 3 viste alla stessa altezza e con le stesse proporzioni.
4. **Tripo**: corpi = **multi-view** (fronte, lato, retro tagliate dal foglio); tutto il resto = **image-to-3D**
   con una sola immagine. Attiva la versione **low poly / retopologia** (indicativo: corpo 8-15k triangoli,
   pezzi di equipaggiamento 1-3k, armi 1-2k, moduli di edificio 1-4k, piccoli oggetti < 1k) e texture PBR.
5. **Blender**: scala (1 unità = 1 m, eroe 1,85 m), origine a terra al centro, davanti verso −Z, nome dei
   materiali; parti luminose (corda dell'arco, cristalli, sfere) in un materiale separato; corpi divisi in parti
   (`body_part`) e pezzi morbidi con i pesi copiati dal corpo (vedi Kit 1).
6. **Mixamo** (solo umanoidi): scheletro + `idle`, `run`, `attack`, `cast`, `hit`, `death`.
7. **Godot**: .glb al posto del nodo `Graybox` della scena; per i corpi le prese diventano BoneAttachment3D.

### Prompt delle immagini (in inglese)

**Stile** (sempre davanti, uguale per tutti):

```
Game asset concept for a 3D model, stylized realistic, Diablo 3 art style, hand-painted look, Roman Empire in the year 3000, sci-fi Roman, clean readable shapes, neutral colors (grey, bronze, leather, off-white cloth), flat even studio lighting, no cast shadows, plain pure white background, entire object visible and centered, no text, no watermark,
```

**Negativo** (dove il generatore lo accetta; in Midjourney con `--no`):

```
glow, energy, plasma, fire, particles, dramatic lighting, rim light, strong shadows, reflections, background scenery, floor, cropped, cut off, multiple objects, text, logo, watermark, blurry, photo
```

**Corpi (kit 1) – foglio multivista** (formato 16:9, Midjourney `--ar 16:9`):

```
[STILE] character turnaround sheet, three views side by side of the same character: front view, left side view, back view, orthographic, same scale, aligned at the feet, full body from head to toe, T-pose with arms straight and horizontal, palms facing down, fingers slightly spread, legs straight and vertical, feet about hip width apart (not wide), knees straight, empty hands, shaved bald head, no hair, no beard, neutral expression, mouth closed, wearing only a skin-tight neutral grey sleeveless undershirt and tight short undershorts that follow the body shape, no loose cloth, no belt, bare arms, bare legs, barefoot, [CORPORATURA]
```
(Gambe **dritte**: col Legionario M le gambe larghe del concept sono finite nello scheletro e Mixamo le ha passate a
tutte le animazioni; sistemato ruotando le cosce di 5,6° e applicando la posa come riposo, vedi sotto.)

`[CORPORATURA]`: Legionario M `adult man, sturdy soldier build, broad shoulders` · Legionario F `adult woman,
athletic soldier build` · Gladiatore M `adult man, very muscular, heavy build, thick arms` · Gladiatore F `adult
woman, muscular, strong build` · Sagittario M `adult man, lean, slender agile build` · Sagittario F `adult woman,
slender, agile build` · Augure M `older man around 55, average build, slightly thin` · Augure F `adult woman,
average build, calm posture`. Per i corpi dal 2° in poi allega anche l'immagine del Legionario M: "same body
proportions and same T-pose as the attached character, only the build changes".

**Teste, capelli, barbe (kit 2)** (vista di 3/4, una per immagine):

```
[STILE] single head bust only, no body below the neck, three-quarter front view, [SOGGETTO]
```
Capelli e barbe da soli: `single hairpiece only, no head, no face, [SOGGETTO], seen from three-quarter view`.

**Equipaggiamento (kit 3)** (pezzo da solo, non indossato):

```
[STILE] single piece of armor only, not worn, no mannequin, no body, floating, three-quarter front view, [SOGGETTO], worn but well kept, simple engraved details
```
Pezzi doppi (spallacci, schinieri, bracciali, guanti, calzari): `only the right one`.

**Armi (kit 4)**:

```
[STILE] single weapon only, lying flat seen from the side, full length visible, [SOGGETTO], metal only, engraved empty channels along the blade, absolutely no glow and no energy effects
```
Scudi: `single shield only, front three-quarter view, [SOGGETTO]`.

**Oggetti in multivista** (armi, scudi: Tripo ricostruisce meglio spessore e retro). Foglio 16:9, poi si taglia
in 3 come i corpi:

```
[STILE] orthographic turnaround sheet, three views side by side of the same object, same scale, same height, aligned at the bottom, evenly spaced with wide white gaps between views: front view, left side view, back view, [SOGGETTO]
```
Armi in piedi con la punta in alto; scudi con l'impugnatura dietro descritta nel soggetto (vista da dietro).

**Non umani (kit 5)**:

```
[STILE] single creature, full body, side three-quarter view, neutral standing pose, legs straight, mouth closed, [SOGGETTO]
```

**Natura (kit 6)**:

```
[STILE] single isolated [SOGGETTO], whole object from base to top, three-quarter view, no ground, no other plants
```

**Architettura (kit 7)** (moduli dritti, misura nel prompt):

```
[STILE] single modular building piece for a game kit, isolated, straight and square, front three-quarter view, [SOGGETTO], 3 meters wide, no ground, no other buildings
```

**Oggetti piccoli e di gioco (kit 8-9)**:

```
[STILE] single isolated [SOGGETTO], three-quarter top view, whole object visible
```

---

## Kit 1 – Corpi umanoidi (8) → servono anche a nemici e NPC

Gli 8 corpi degli eroi (2 per classe, come deciso) sono **anche** i corpi di tutti gli umani del gioco.
Consiglio: generare prima il corpo maschile e quello femminile del Legionario, riggarli su Mixamo, poi
fare gli altri 6 **partendo da quelli** (stesso scheletro e stesse proporzioni di base, cambia la corporatura):
le animazioni e i pezzi di equipaggiamento vanno su tutti senza ritocchi.

| ✓ | Pr. | Corpo | Corporatura | Riusato anche per |
|---|---|---|---|---|
| [x] | P1 | Legionario M (viso da rifare: testa del Kit 2) | robusto | guardia, legionario rinnegato, prefetto, Brenno (×1,3) |
| [ ] | P2 | Legionario F | atletica | guardia donna, cittadina |
| [ ] | P2 | Gladiatore M | muscoloso, più grosso | barbaro, bruto (×1,4), Tharvo (×1,6), fabbro |
| [ ] | P2 | Gladiatore F | muscolosa | barbara, pirata donna |
| [ ] | P2 | Sagittario M | snello | predone, frombolier, pirata, arpionatore, cittadino |
| [ ] | P2 | Sagittario F | snella | predona, cittadina |
| [ ] | P2 | Augure M | normale, più anziano | mercante, Vulso (con cappotto), cittadino anziano |
| [ ] | P2 | Augure F | normale | vestale, sacerdotessa |

Prompt: `<descrizione corpo>, skin-tight neutral grey undershirt and undershorts, bare arms and legs, barefoot, no hair, T-pose, full body`
(senza capelli: li mette il kit 2). **Niente tunica larga né sandali sul corpo**: sotto l'armatura o gli stivali
sbucherebbero fuori nelle animazioni. Il corpo porta solo un sottovestito aderente (si comporta come la pelle);
la tunica è un pezzo del kit 3 come gli altri.

**Corpo diviso in parti (come Diablo 3).** In Blender il corpo si taglia in `Testa`, `Busto`, `Braccia`, `Mani`,
`Gambe`, `Piedi` (stesso scheletro, stessi pesi, tagli lungo i bordi dell'armatura: collo, spalle, polsi, vita,
ginocchia/caviglie). Ogni parte ha il metadato `body_part` e un pezzo indossato la nasconde con `"hide"` in
`data/visual_db.gd` (come già fa l'elmo coi `Capelli`): lorica → `Busto`, manicae → `Braccia`, guanti → `Mani`,
bracae/ocreae → `Gambe`, caligae/calcei → `Piedi`. Sotto l'armatura non resta niente che possa bucarla, e si
disegnano meno triangoli.

**Pezzi morbidi** (toga, tunica, bracae, cotta di maglia, mantello: quelli segnati "pesi") non vanno su una presa
rigida: in Blender si appoggiano sul corpo e si copiano i pesi dal corpo (Data Transfer), così si piegano con lo
stesso scheletro. I pezzi rigidi (elmi, spallacci, schinieri, armi) restano sulle prese. Il **lemure** e il **Custode** possono essere il corpo Augure / Gladiatore
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
| [x] | P1 | galea | `roman galea helmet, iron, cheek guards, crest` | guardie, rinnegati |
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
| [x] | P1 | gladio_plasma | `roman gladius, metal blade with engraved energy channels, no glow` (energia da Godot) | guardie, rinnegati |
| [x] | P1 | scutum | `roman scutum curved shield, eagle emblem, force field edge` | guardie, rinnegati |
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

1. **P1**: corpo Legionario M + galea + gladio + scutum → prova del flusso immagine → Tripo → Blender → Mixamo → Godot
   (l'immagine approvata del Legionario M diventa il riferimento di stile di tutto il resto).
2. Gli altri 7 corpi + teste e capelli (kit 1-2): da qui escono anche tutti i nemici umani e gli NPC.
3. Kit 3-4 (equipaggiamento e armi): riempie eroi, nemici, NPC e la scheda Aspetto in un colpo.
4. Kit 6-7-8 (natura, architettura, oggetti): rifà l'aspetto di tutte le mappe.
5. Kit 5 e 9, poi i pezzi P3 e F.
