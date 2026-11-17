# Piano: equipaggiamento visibile sui personaggi

Obiettivo: quando l'eroe indossa un'arma, un elmo o un'armatura, si vede addosso, come in Diablo 3,
**senza un modello completo per ogni combinazione**. Si fa con **un corpo base animato + pezzi separati**
agganciati alle ossa.

## L'idea in breve

```
Corpo base (1 per sesso, riggato con Mixamo, animazioni condivise)
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
Con 4 classi e i 28 oggetti base attuali bastano **circa 30-35 pezzi piccoli + 2 corpi**,
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
| Corpi base | 1-2 |
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

1. **Sistema in grayboxing** (si può fare subito, senza asset): prese `Marker3D` nelle 4 scene delle classi,
   `VISUALS` con pezzi graybox (scatole/cilindri colorati per rarità), `core/appearance.gd`, test automatico
   (equipaggia → il pezzo compare nella presa giusta; togli → sparisce). Così il gioco mostra già l'equipaggiamento.
2. **Prova con un solo personaggio vero**: corpo base Tripo + Mixamo per il Legionario, 3 animazioni,
   gladio + scutum + galea. Serve a verificare scala, orientamento (−Z), prese sulle ossa e animazioni.
3. **Pezzi rigidi** di tutte le basi (armi, scudi, elmi, schinieri, bracciali, piastre).
4. **Vesti con pesi** (toga, bracae) e nascondere le parti del corpo sotto l'armatura.
5. **Rifiniture**: tinte per rarità/set, effetti sulle armi leggendarie (bagliore, particelle),
   anteprima nello zaino, nemici umani vestiti con gli stessi pezzi.

## Decisioni da prendere

- **Un corpo per tutte le classi** (più semplice, la classe si riconosce dall'equipaggiamento) oppure
  **un corpo per classe** (più carattere, 4 rig invece di 1)? Consiglio: un corpo (o due, M/F) + teste diverse.
- **Sesso dell'eroe** scelto alla creazione? Se sì, servono 2 corpi e i pezzi con pesi vanno adattati a entrambi.
- **Stile grafico**: più realistico o più stilizzato? Conviene fissarlo prima di generare decine di pezzi
  con Tripo, perché tutti i prompt devono dare lo stesso stile.
