# Effetti visivi degli attacchi

Come per i modelli (docs/MODELLI_TRIPO.md), gli effetti sono un **kit riutilizzabile**: pochi shader,
poche mesh, poche texture, combinati e colorati per **elemento**. Il codice è in `core/vfx.gd`
(kit nuovo) e `core/fx.gd` (particelle semplici e funzioni storiche, che ora passano da Vfx).

Stato: **implementato con le texture** (19-11-2026): 14 immagini in scala di grigi in `textures/vfx/`
(sezione 4), collegate agli shader da `Vfx.TEXTURES`; il rumore procedurale è stato sostituito da `rumore.png`.
Non è ancora stato visto a schermo: i test girano senza scheda video, quindi gli shader vanno
controllati su Windows (se uno shader ha un errore, Godot lo scrive nella console all'avvio dell'effetto).

## 1. Il kit

### Shader (`Vfx.SHADER_CODE`, uno di ciascuno, condivisi da tutti gli effetti)

| Shader | Cosa fa | Usato per |
|---|---|---|
| `glow` | bagliore morbido rivolto alla telecamera | lampi dei colpi, nuclei dei proiettili, stelline dello stordimento, lampi delle esplosioni |
| `fire` | fiamma procedurale che sale | fuoco dei colpi, palle di fuoco, nemici in fiamme, pozze di fuoco, meteore |
| `ring` | anello d'urto a terra che si allarga | onde d'urto, critici, aree attorno all'eroe |
| `telegraph` | disco a terra che **si riempie fino al momento del colpo**, con bordo pulsante e tratteggio che gira | aree della mira, attacchi dei boss, pericoli delle elite, potenziamenti |
| `scorch` | macchia irregolare che svanisce | bruciature (fuoco), brina (freddo), crepe (fisico), segni dei fulmini |
| `pool` | pozza animata | pozze di fuoco e ghiaccio, gelo sotto i nemici rallentati |
| `slash` | falce del fendente con scia | tutti gli attacchi in mischia |
| `fresnel` | bolla luminosa sui bordi | scudi (eroe, elite Scudate, boss protetti), immagini fantasma |
| `dissolve` | dissolvenza con bordo incandescente | morte dei nemici |
| `distort` | distorsione dell'aria | esplosioni e atterraggi grandi (raggio ≥ 4 m) |

Il colore di ogni effetto è un *instance uniform* (`tint`, `fade`...): lo stesso materiale serve
per migliaia di effetti diversi senza crearne di nuovi.

### Mesh (create da codice)
Quadrato (per gli effetti rivolti alla telecamera), piano 2 × 2 (effetti a terra), falce ad arco
(generata per angolo e portata, in cache), segmenti del fulmine, schegge allungate.
Tripo **non** serve per gli effetti.

### Funzioni (`core/vfx.gd`)
`glow`, `fire`, `shockwave`, `telegraph`, `scorch`, `pool`, `distortion`, `slash`, `lightning`,
`hit` (colpo per elemento), `explosion` (esplosione per elemento), `strike` (dal cielo),
`make_bubble`, `dissolve`, `afterimage` (immagine fantasma), `hitstop` (micro-pausa).

## 2. Catalogo: forma × elemento

| | Fisico (avorio) | Fuoco (arancio) | Freddo (azzurro) | Fulmine (viola-bianco) |
|---|---|---|---|---|
| **Colpo** (`Vfx.hit`) | lampo + scintille allungate | lampo + braci che salgono + fiammata | lampo + schegge di ghiaccio + nebbiolina | lampo + 1-3 piccoli fulmini |
| **Critico** | colpo più grande + anello a terra + numero più grande; micro-pausa se toglie ≥ 25% di vita | | | |
| **Proiettile** | asta + punta (pilum, frecce, scure) | sfera con fiamma e alone | cristallo appuntito con alone | nucleo luminoso + saetta; i rimbalzi disegnano il fulmine |
| **Esplosione** (`Vfx.explosion`) | lampo, anello, crepa a terra | lampo, anello, 6 fiammate, bruciatura | schegge, brina a terra | 6 fulmini dall'alto, segno scuro |
| **Dal cielo** (`Vfx.strike`) | (come fuoco) | meteora con fiamma e scia | — | saetta da 18 m |
| **Area attorno all'eroe** | anello + schegge | anello di fiamme | brina a terra | fulmini a raggiera |
| **Stato sul nemico** | — | fiamme addosso finché brucia | pozza di gelo sotto i piedi finché è rallentato | — |

Il **tipo di danno** viene da `ab["element"]` (SkillDB.ELEMENTS e le varianti), quindi una variante
che passa al fuoco (es. Lama ardente) cambia da sola anche l'aspetto dei colpi.

## 3. Effetti per tipo di abilità e altri

| Cosa | Effetto |
|---|---|
| Mischia (`melee`) | falce `slash` che segue l'arco; il colore si mescola con l'elemento; giro completo per i colpi rotanti |
| Area su punto (`aoe_point`) | avviso che si riempie → colpo (esplosione per elemento); a più colpi: piccoli impatti sparsi |
| Area su di sé (`aoe_self`) | anello d'urto + effetto dell'elemento |
| Scatto / carica (`dash`) | immagini fantasma ogni 0,05 s; teletrasporto: fantasma + saetta tra partenza e arrivo |
| Balzo (atterraggio) | anello, crepa a terra, distorsione |
| Potenziamento (`buff`) | lampo + cerchio a terra; bolla `fresnel` mentre riduce i danni |
| Stordimento | tre stelline che girano sopra la testa |
| Scudo (elite Scudate, boss protetti) | bolla `fresnel` |
| Morte dei nemici | cade, poi si dissolve con bordo incandescente (arancio scuro per i boss) |
| Boss | furia: fiammata; nova: lampo viola; salto: immagine fantasma; pioggia/onda: avvisi che si riempiono |
| Pericoli delle elite | pozze animate (fuoco con fiamme, ghiaccio) e avvisi che si riempiono |

Opzione **Effetti ridotti** (Opzioni > Video): niente distorsioni, segni a terra, immagini fantasma
e micro-pause, meno particelle. Utile sui PC lenti.

## 4. Texture (fatte, in `textures/vfx/`)

Tutte **in scala di grigi** (il colore lo mette il codice), 256 × 256 o 512 × 512, sfondo nero o trasparente.
Fonti: pacchetti gratuiti CC0 (es. *Kenney Particle Pack*), generatori di immagini AI, o disegnate.
Testi pronti per generarle con un'AI: `docs/TEXTURE_AI.md`.

| ✓ | Texture | Sostituisce nello shader | Note |
|---|---|---|---|
| [x] | Bagliore morbido | `glow` (cerchio calcolato) | quasi uguale all'attuale: priorità bassa |
| [x] | Scintilla / stella | `glow` per i critici | 4-8 punte |
| [x] | Fiamma (sequenza 4 × 4 fotogrammi) | `fire` (rumore) | il miglioramento più visibile |
| [x] | Fumo (sequenza 4 × 4) | nuovo: fumo dopo esplosioni e incendi | |
| [x] | Fulmine (striscia) | segmenti di `lightning` | 2-3 varianti |
| [x] | Anello d'urto | `ring` | bordo morbido |
| [x] | Falce del fendente | `slash` (sfumatura) | con striature |
| [x] | Rumore (Perlin/Voronoi) | `fbm` di tutti gli shader | uno solo, riusato ovunque |
| [x] | Crepa nel terreno | `scorch` fisico | decal |
| [x] | Bruciatura | `scorch` fuoco | decal |
| [x] | Brina / cristalli | `scorch` e `pool` freddo | decal |
| [x] | Cerchio di rune | `telegraph` | stile romano/augurale |

**Totale: 12 texture** (14 file: i fulmini sono 3) per tutto il gioco. Per cambiarne una basta sostituire il PNG
con lo stesso nome. Fiamma e fumo sono immagini singole: lo shader le fa guizzare/girare col rumore.
La falce `fendente.png` è un piano a terra davanti all'eroe sopra la scia ad arco (`Vfx.slash`, archi < 300°);
la stella compare sui critici (`glow:stella`); il fumo dopo le esplosioni di fuoco e la polvere dopo quelle fisiche.

## 5. Futuro

- Effetti propri per abilità speciali dove serve (campo `"vfx"` nei dati dell'abilità, letto da
  `core/abilities.gd`): es. Fulmine di Giove con colonna di luce dal cielo, Pioggia di frecce con
  frecce che cadono, Sciame di corvi con corvi (questi ultimi sì, modellini Tripo piccoli).
- Scia sull'arma quando ci saranno i modelli veri (nastro che segue la `Presa_ManoDx`).
- Particelle GPU al posto delle CPU se gli effetti diventano tanti.
- Suoni diversi per elemento (oggi i suoni sono per azione, non per elemento).
