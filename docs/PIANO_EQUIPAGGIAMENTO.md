# Piano: equipaggiamento visibile sui personaggi

Obiettivo: quando l'eroe indossa un'arma, un elmo o un'armatura, si vede addosso, come in Diablo 3,
**senza un modello completo per ogni combinazione**. Si fa con **un corpo base animato + pezzi separati**
agganciati alle ossa.

## Decisioni prese (17-11-2026)

- **Due corpi per classe** (maschile e femminile): 8 corpi in tutto, ognuno con il suo rig Mixamo.
  I pezzi rigidi sono condivisi tra tutti i corpi (si adattano con le prese); le vesti con pesi vanno
  adattate a ogni corpo che le può indossare.
- **Sesso scelto alla creazione** dell'eroe (`HeroData.sex`, "m"/"f"; i vecchi salvataggi sono maschili).
- **Stile Diablo 3**: realistico ma non spinto all'inverosimile. Proporzioni credibili, un po' eroiche
  (spalle e armi leggermente più grandi del vero, per leggerle dalla telecamera lontana), materiali
  dipinti/leggibili, niente iperrealismo. Prompt base per Tripo: *"stylized realistic, Diablo 3 style,
  hand-painted textures, game asset, low poly"*.

## L'idea in breve

```
Corpo base (2 per classe, M/F, riggati con Mixamo, animazioni condivise)
 ├─ Testa / capelli (pochi, per varietà)
 ├─ Arma          → agganciata all'osso della mano destra          (pezzo rigido)
 ├─ Mano secondaria→ mano sinistra / avambraccio sinistro           (pezzo rigido)
 ├─ Elmo          → osso della testa                                (pezzo rigido)
 ├─ Armatura      → busto (piastre rigide) o veste con pesi (toga)  (rigido o "skinned")
 ├─ Guanti        → avambracci + mani                               (rigidi)
 ├─ Gambali       → stinchi e cosce                                 (rigidi)
 └─ Calzari       → piedi                                           (rigidi)
```

Combinazioni possibili = prodotto dei pezzi; modelli da fare = **somma** dei pezzi.
Con 4 classi e i 28 oggetti base attuali bastano **circa 30-35 pezzi piccoli + 8 corpi**,
invece di centinaia di personaggi completi.

## Perché funziona bene per Legio 3000

- **L'armatura romana è fatta di piastre**: lorica segmentata, galea, ocreae (schinieri), manicae.
  Le piastre rigide agganciate a un osso si muovono in modo credibile, e con la telecamera
  isometrica lontana le piccole compenetrazioni non si notano.
- **Tripo è bravo con gli oggetti singoli** (un elmo, uno scudo, una spada); molto meno con
  personaggi completi già divisi in pezzi.
- Le **animazioni Mixamo** si fanno una volta sola sul corpo base e valgono per tutte le classi.

## Tre tipi di pezzo

| Tipo | Esempi | Come si fa | Costo |
|---|---|---|---|
| **Rigido** | armi, scudi, elmi, schinieri, bracciali, spallacci, piastre del busto | Tripo → Blender: scala, posiziona sul corpo, origine sull'osso → .glb | basso |
| **Con pesi (skinned)** | toga, tunica, bracae, mantello | Tripo o Blender → trasferimento dei pesi dal corpo base (modificatore *Data Transfer*) → .glb con lo stesso scheletro | medio |
| **Solo materiale** | varianti bronzo/ferro/oro/plasma, rarità, set | stesso pezzo, materiale o tinta diversa (shader con maschera colore) | quasi zero |

Regola pratica: **tutto rigido tranne i vestiti di stoffa**. Per l'Augure (toga) e le bracae serve
il trasferimento dei pesi; il resto no.

## Come si collega al codice (già pronto a riceverlo)

1. **Prese (socket) con nomi fissi nel modello di ogni classe**: `Presa_Testa`, `Presa_Busto`,
   `Presa_ManoDx`, `Presa_ManoSx`, `Presa_AvambraccioSx`, `Presa_StincoDx/Sx`, `Presa_PiedeDx/Sx`...
   - Adesso (grayboxing): sono semplici `Marker3D` nelle scene `scenes/characters/*.tscn`.
   - Con il modello Mixamo: diventano `BoneAttachment3D` con lo stesso nome, agganciati alle ossa
     (`mixamorig_Head`, `mixamorig_RightHand`...). Il codice non cambia.
2. **Dati**: in `data/item_db.gd` ogni base ha una voce `"visual"` (es. `"lorica" → "busto_segmentata"`);
   un nuovo dizionario `VISUALS` dice per ogni aspetto: scena .glb/.tscn, presa (o prese, per i pezzi doppi
   come gli schinieri), parti del corpo da nascondere sotto (es. il busto nudo sotto la lorica),
   e se è "skinned". Leggendari e set possono avere un aspetto proprio o solo una tinta.
3. **`core/appearance.gd`** (nuovo, ~150 righe): dato `hero.equipment`, toglie i pezzi vecchi e
   istanzia quelli nuovi nelle prese; si aggiorna con il segnale `inventory_changed`.
   Lo usa `Player`, ma anche i **nemici umani** (legionari rinnegati, pirati) possono riusare gli stessi
   pezzi per avere varietà gratis.
4. **Anteprima nello zaino**: una piccola `SubViewport` con il personaggio che gira (come D3), facoltativa.

## Pipeline degli asset (Tripo → Mixamo → Godot)

1. **Corpo base**: Tripo genera un corpo in posa A/T con abiti minimi (tunica corta) → Mixamo
   auto-rig → scarica FBX con pelle → Blender → .glb. Uno maschile e uno femminile, oppure uno solo.
2. **Animazioni**: da Mixamo, sullo stesso personaggio, "senza pelle" (idle, corsa, attacchi con spada e
   scudo, arco, lancio di incantesimi, colpito, morte). In Godot: import con `BoneMap` +
   `SkeletonProfileHumanoid`, un'unica `AnimationLibrary` condivisa da tutte le classi.
   Per classe cambia solo quali animazioni usare (scudo, arco, due mani...).
3. **Pezzi**: Tripo, un oggetto per volta ("roman galea helmet, game asset, low poly"). In Blender si
   appoggiano sul corpo base in posa T, si mette l'origine nel punto dell'osso, si esportano in .glb.
   Una **scena di prova** (`scenes/tools/prova_equipaggiamento.tscn`) col corpo base e tutte le prese serve
   per sistemare posizione e scala dall'editor; gli scostamenti si salvano nella scena del pezzo.
4. **Varianti**: materiali per livello/rarità (bronzo → ferro → oro → plasma con emissione).

## Quanti modelli servono (stima)

| Gruppo | Pezzi |
|---|---|
| Corpi base | 8 (4 classi × M/F) |
| Teste / capelli | 4-6 |
| Armi (gladio, spatha, scure, arco, manuballista, lituo, bastone) | 7 |
| Mano secondaria (scutum, parma, pugio, faretra, sfera) | 5 |
| Elmi (galea, elmo da centurione, cappuccio) | 3 |
| Busto (segmentata, hamata, toga) | 3 (+ spallacci 1) |
| Guanti (manicae, guanti) | 2 |
| Gambe (ocreae, bracae) | 2 |
| Calzari (caligae, calcei) | 2 |
| **Totale** | **circa 30-35**, poi 1-2 pezzi unici per set/leggendario quando si vuole |

## Fasi

1. ✅ **FATTO** — **Sistema in grayboxing**: `data/visual_db.gd` (VISUALS, PRESE, MATERIALS), `core/appearance.gd`,
   corpi `scenes/characters/<classe>.tscn` e `<classe>_f.tscn` con il nodo `Prese` (12 `Marker3D`),
   scelta Uomo/Donna nel menu, test `tools/test_equipaggiamento.gd`. Dettagli originali:
   **Sistema in grayboxing** (si può fare subito, senza asset): prese `Marker3D` nelle 4 scene delle classi,
   `VISUALS` con pezzi graybox (scatole/cilindri colorati per rarità), `core/appearance.gd`, test automatico
   (equipaggia → il pezzo compare nella presa giusta; togli → sparisce). Così il gioco mostra già l'equipaggiamento.
2. **Prova con un solo personaggio vero**: corpo base Tripo + Mixamo per il Legionario, 3 animazioni,
   gladio + scutum + galea. Serve a verificare scala, orientamento (−Z), prese sulle ossa e animazioni.
3. **Pezzi rigidi** di tutte le basi (armi, scudi, elmi, schinieri, bracciali, piastre).
4. **Vesti con pesi** (toga, bracae) e nascondere le parti del corpo sotto l'armatura.
5. **Rifiniture**: tinte per rarità/set, effetti sulle armi leggendarie (bagliore, particelle),
   anteprima nello zaino, nemici umani vestiti con gli stessi pezzi.

## Come sostituire un pezzo graybox con un modello vero

1. Metti il .glb del pezzo in una scena (es. `scenes/equip/galea.tscn`), con l'origine nel punto della presa.
2. In `VisualDB.VISUALS["galea"]` aggiungi `"scene": "res://scenes/equip/galea.tscn", "socket": "Presa_Testa"`
   (per i pezzi doppi anche `"mirror": "Presa_StincoSx"`): `"parts"` viene ignorato.
3. Corpo vero: sostituisci `Graybox` col .glb Mixamo e trasforma ogni `Marker3D` di `Prese` in un
   `BoneAttachment3D` con lo **stesso nome**, agganciato all'osso giusto (`mixamorig_RightHand`...).
   Le parti del corpo che un pezzo nasconde (es. `Capelli`) hanno il metadato `body_part`.
