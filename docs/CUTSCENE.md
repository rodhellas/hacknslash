# Cutscene

Motore: `core/cutscene.gd` (classe `Cutscene`). Catalogo: `data/cutscene_db.gd`. Test: `tools/test_cutscene.gd`.

## Come funziona
- Una cutscene è una sequenza di **inquadrature**. Mentre gira il gioco è in pausa e l'HUD è nascosto: si muovono solo
  gli attori delle scene nel motore.
- **Controlli:**
  - avanti: clic, Spazio, Invio, A del controller, tocco. Se il testo si sta ancora scrivendo, il primo tocco lo completa.
  - saltare tutto: Esc, Start o B, oppure "Salta ▸▸" in alto a destra. Vale per le cutscene con `"skippable": true`, che è il valore predefinito.
- Ogni cutscene si vede **una volta per eroe** quando parte da sola (flag `cs_<id>` nel salvataggio). `Cutscene.play(id)` la fa
  partire sempre (es. per un futuro menu "rivedi").
- Se ne parte una mentre un'altra gira, va in coda.

## Quando partono (campo `trigger`)
| Trigger | Quando |
|---|---|
| `enter:<id livello>` | entrando nel livello (dopo la schermata di caricamento) |
| `quest_start:<id>` | missione affidata |
| `quest_done:<id>` | missione completata |
| `boss:<id nemico>` | boss unico sconfitto |
| `area:<nome nodo>` | l'eroe entra in un'area `CutsceneTrigger` (`world/cutscene_trigger.gd`) piazzata nel livello |
| `""` | solo a mano: `Cutscene.play("id")` |

L'area `CutsceneTrigger` (Area3D, cerchio viola nell'editor) può anche avere direttamente `cutscene_id`. Va messa **fuori dal
nodo `World`** e non tocca la navmesh.

## Tipi di inquadratura
Campi comuni:
- `text`: sottotitolo che si scrive.
- `speaker`: chi parla.
- `voice`: voce, che altrimenti si cerca in `audio/voci/<id>_<n>.ogg`, con n che parte da 1.
- `duration`: durata; senza, la decide la voce o la lunghezza del testo.
- `fade`: dissolvenza dal nero.
- `fx`: particelle (`braci`, `cenere`, `pioggia`, `energia`, `neve`).

- **`title`**: scritta grande al centro (`text` + `subtitle`). Per "ATTO I", luoghi, date.
- **`image`** (fumetto animato):
  - `image`: un'immagine;
  - `layers`: `[[immagine, profondità], ...]`, dallo sfondo (0) al primo piano (1). I livelli vicini si muovono di più, effetto parallasse;
  - `move`: `{"from": [zoom, x, y], "to": [zoom, x, y]}`. Zoom 1 = schermo pieno, x/y da -1 a 1 = panoramica.
  - Se l'immagine non c'è ancora compare un **segnaposto** con il suo nome: si può scrivere e provare la cutscene prima dei disegni.
- **`video`**: `video` = `res://video/<nome>.ogv` (Ogg Theora). Finisce col filmato.
- **`scene`** (nel motore, nel livello attuale):
  - `anchor`: `player`, il percorso di un nodo o `[x, y, z]`; tutto il resto è relativo a questo punto;
  - `camera`: `{"from": [x,y,z], "to": [x,y,z], "look": [x,y,z], "fov": 50}`;
  - `actions`: `{"at": secondi, "actor": "player" | percorso | nome di uno spawn, "move": [x,y,z], "time": durata, "anim": "cast", "face": [x,y,z]}`
    oppure `{"at": ..., "spawn": "res://scenes/....tscn", "name": "Nome", "move": [x,y,z]}`, che crea un attore e lo toglie alla fine.

Esempio completo: la cutscene `"prova"` in `data/cutscene_db.gd`, con tutti i tipi.

## File
- Immagini: `textures/cutscene/<id cutscene>/<nome>.png`, citate come `"<id>/<nome>"`.
  - Formato: **2560×1440** (16:9). Il motore le ingrandisce del 20% per zoom e panoramiche: tieni le cose importanti al centro.
  - Parallasse: 2-3 PNG della stessa misura, con trasparenza (sfondo pieno; piano medio e primo piano scontornati).
- Voci: `audio/voci/<id>_<n>.ogg`, con voce narrante e personaggi; si possono fare con un TTS AI.
- Video: `video/<nome>.ogv`. Pesano: su Android meglio le immagini animate.

## Testi per generare le immagini con l'AI (stile comune)
Stile da ripetere in ogni prompt, così le tavole sembrano della stessa serie:

> Illustrazione dipinta a mano per un videogioco ARPG cupo, stile tavola di fumetto epico, pennellate visibili, luce drammatica
> controluce, palette scura (grafite, rosso brace, oro antico) con accenti di energia azzurra; Roma nel 3000: architettura romana
> classica con tecnologia futura fatta di energia luminosa (lame avvolte di energia, rune luminose), niente metallo lucido
> fantascientifico. Inquadratura cinematografica 16:9, composizione con il soggetto al centro, senza testo, senza loghi.

Per i livelli in parallasse aggiungi: *"soggetto isolato su sfondo trasparente"* (piano medio/primo piano) oppure *"solo
paesaggio di sfondo, nessun personaggio"* (sfondo). Per tenere riconoscibili i personaggi tra una tavola e l'altra usa sempre
la stessa descrizione fissa del personaggio (abiti, colori, segni particolari) e, se lo strumento lo permette, un'immagine di
riferimento.
