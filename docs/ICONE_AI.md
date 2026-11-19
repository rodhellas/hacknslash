# Testi per generare le icone delle abilità con un'AI

Icone per le **40 abilità** (base e alternative), le **24 passive** e la **pozione**: 65 immagini.
Le varianti (rune) non hanno un'icona propria: usano quella dell'abilità.
Come in `docs/TEXTURE_AI.md`, i testi sono **in inglese** (i generatori lo capiscono meglio).

## Regole comuni

- **A colori** (a differenza delle texture degli effetti), quadrate 1:1, poi ridotte a **256 × 256** PNG.
- **Senza cornice e senza bordo**: la cornice la disegna il gioco (oro, e colorata per la rarità/ricarica).
- **Niente scritte, lettere o numeri** nell'immagine.
- Soggetto **unico, grande e centrato**, leggibile anche piccolo (sul telefono un pulsante è ~1 cm):
  sagome nette, forte contrasto, poco dettaglio fine.
- Stesso stile per tutte: genera prima 3-4 icone, scegli la migliore e usala come riferimento di stile per le
  altre (Midjourney: `--sref <link dell'immagine>`; altri generatori: "in the same style as the reference image").
- File: `textures/icone/abilita/<id>.png`, `textures/icone/passive/<id>.png`, `textures/icone/pozione.png`
  (l'`<id>` è quello indicato tra parentesi, uguale al codice).

## Stile (da aggiungere DOPO ogni soggetto)

Abilità:
> , game ability icon, ancient Roman empire in the year 3000, mix of Roman armor and bronze with glowing sci-fi technology, painterly digital art in the style of classic isometric action RPG skill icons, dramatic lighting, strong silhouette, centered single subject, dark vignette background tinted %COLORE%, no frame, no border, no text, square

Passive (più simboliche, per distinguerle dalle abilità):
> , game passive skill icon, emblem-like symbolic composition, ancient Roman empire in the year 3000, engraved bronze and gold relief with soft glowing accents, painterly digital art, centered, dark background tinted %COLORE%, no frame, no border, no text, square

Al posto di `%COLORE%` metti il colore della classe:

| Classe | %COLORE% |
|---|---|
| Legionario | `deep crimson red` |
| Gladiatore | `burnt orange and bronze` |
| Sagittario | `dark forest green` |
| Augure | `deep royal blue and violet` |

Con Midjourney aggiungi in fondo `--ar 1:1`; con Stable Diffusion, nel negativo:
`text, letters, watermark, frame, border, multiple subjects, cropped, blurry, photo`.

---

## Legionario (Disciplina) — colore `deep crimson red`

### Abilità
| File (`id`) | Tasto | Soggetto |
|---|---|---|
| `colpo_gladio` | primaria | A Roman gladius sword mid-swing leaving a bright circular slash trail, three overlapping arcs of light |
| `affondo` | primaria | A gladius thrusting straight forward toward the viewer, sharp point with a streak of light behind it |
| `pilum` | secondaria | A glowing electromagnetic javelin (pilum) flying diagonally, crackling blue energy coils along the shaft |
| `colpo_scudo` | secondaria | A large rectangular Roman scutum shield bashing forward, shockwave and stars of impact in front of it |
| `testuggine` | tattica | Several interlocked Roman shields forming a tortoise formation dome, a glowing energy barrier over them |
| `carica` | tattica | A Roman legionary charging forward with shield raised, motion streaks and dust behind him |
| `granata` | tattica | A bronze Roman-styled grenade with glowing red seams, about to explode, sparks flying |
| `grido_marte` | tattica | A shouting Roman legionary helmet with red crest, fiery red aura and sound waves bursting outward |
| `terremoto_legione` | tattica | A Roman military boot stomping the ground, cracks and a circular shockwave spreading from it |
| `bombardamento` | tattica | Beams of fire raining down from a starship fleet in a dark sky onto a targeted circle on the ground |

### Passive
| File (`id`) | Soggetto |
|---|---|
| `veterano` | A battered Roman legionary helmet with scars and laurel, glowing red heart emblem behind it |
| `disciplina_ferro` | A heavy Roman segmented armor (lorica segmentata) chest piece, iron and steel, sturdy |
| `furia_legione` | A Roman legion eagle standard (aquila) blazing with red fire |
| `baluardo` | A cracked Roman shield still standing, planted in the ground, defiant glow behind it |
| `rifornimento` | A Roman supply amphora and bread loaf with a glowing circular arrow of renewal |
| `gloria` | A golden laurel crown above a raised gladius, warm healing light |

---

## Gladiatore (Furia) — colore `burnt orange and bronze`

### Abilità
| File (`id`) | Tasto | Soggetto |
|---|---|---|
| `doppio_fendente` | primaria | Two crossed curved swords striking at once, two crossing orange slash trails |
| `tridente` | primaria | A gladiator trident thrusting forward, cold blue light on the three prongs |
| `colpo_arena` | secondaria | A heavy wide horizontal sword swing sending sand and debris flying in an arc |
| `scure_rotante` | secondaria | A spinning throwing axe with circular motion blur, bronze blade |
| `balzo` | tattica | A gladiator leaping high in the air with weapon raised, about to smash down, shadow on the ground below |
| `turbine` | tattica | A gladiator spinning like a whirlwind with two blades, swirling vortex of sand and orange light |
| `rete` | tattica | A thrown net of glowing electric cables spreading open, crackling sparks |
| `grido_arena` | tattica | A roaring gladiator face with open mouth, shockwave of sound rings and arena sand blowing |
| `terremoto` | tattica | The arena floor shattering with deep glowing cracks radiating from a central impact |
| `favore_folla` | tattica | A cheering arena crowd silhouette and a raised thumbs-up hand, golden spotlight |

### Passive
| File (`id`) | Soggetto |
|---|---|
| `brutalita` | A blood-red cracked gladiator helmet with spikes, savage expression |
| `ritmo` | Two blades crossed over a pulsing drum, rhythmic motion lines |
| `pelle_dura` | A muscular arm with bronze bracer deflecting a blade, sparks flying off |
| `rabbia` | A clenched fist wreathed in orange flames |
| `sete` | A golden goblet overflowing with glowing red liquid |
| `favorito` | A pile of sesterce coins under a laurel wreath, a winged sandal beside it |

---

## Sagittario (Concentrazione) — colore `dark forest green`

### Abilità
| File (`id`) | Tasto | Soggetto |
|---|---|---|
| `dardo` | primaria | A single plasma arrow bolt flying fast, bright green glowing tip and thin trail |
| `colpo_rapido` | primaria | Two plasma arrows flying side by side very fast, double green trails |
| `freccia_esplosiva` | secondaria | An arrow hitting the ground and exploding in a burst of fire and debris |
| `freccia_catena` | secondaria | An arrow trail bouncing between several points, a zigzag chain of light |
| `capriola` | tattica | An archer in mid-roll somersault dodging, curved motion arc, light green afterimage |
| `ventaglio` | tattica | Five arrows fanning outward from a single point in a spread |
| `trappola` | tattica | A circular mechanical trap on the ground with glowing net and spikes, armed |
| `bolas` | tattica | Bolas: two glowing weighted balls joined by a cord, spinning through the air |
| `mira_falco` | tattica | A hawk's eye close-up merged with a targeting reticle, sharp green glow |
| `pioggia_frecce` | tattica | Dozens of arrows raining down from the sky onto an area, seen at an angle |

### Passive
| File (`id`) | Soggetto |
|---|---|
| `occhio_aquila` | A stylized eagle head in profile with a glowing eye |
| `passo_leggero` | A winged sandal leaving faint green footprints |
| `cecchino` | A long arrow piercing the center of a distant target, long perspective line |
| `concentrazione` | A calm meditative face with closed eyes and a glowing circle on the forehead |
| `arciere_esperto` | A composite bow drawn at full tension with an arrow nocked |
| `sangue_freddo` | An hourglass with frosty green sand, a steady hand next to it |

---

## Augure (Favore divino) — colore `deep royal blue and violet`

### Abilità
| File (`id`) | Tasto | Soggetto |
|---|---|---|
| `fulmine` | primaria | A forked lightning bolt arcing between three points, violet-white electricity |
| `dardo_arcano` | primaria | A small glowing arcane missile with a swirling violet trail |
| `sfera_vulcano` | secondaria | A large slow ball of molten fire and magma, flames swirling around it |
| `saetta` | secondaria | A single massive lightning bolt striking down from dark clouds onto the ground |
| `egida` | tattica | The aegis: a round golden shield with a stylized gorgon face, protective blue light dome |
| `passo_mercurio` | tattica | A winged helmet and a blur of blue light, a figure vanishing and reappearing |
| `ira_nettuno` | tattica | A circular tidal wave of water erupting outward, a trident silhouette in the center |
| `anello_fuoco` | tattica | A ring of flames encircling a robed figure seen from above |
| `meteora` | tattica | A flaming meteor falling from the sky with a long fiery tail |
| `sciame_corvi` | tattica | A swarm of mechanical bronze ravens with glowing eyes diving down |

### Passive
| File (`id`) | Soggetto |
|---|---|
| `favore` | Two open hands raised toward a radiant divine light from above |
| `saggezza` | An owl perched on an ancient scroll, glowing eyes |
| `furore` | A stormy sky with a crackling thunderbolt held in a fist |
| `protezione` | A translucent glowing dome over a Roman temple |
| `sapienza` | An open ancient book with floating glowing runes rising from the pages |
| `ultraterreno` | A ghostly glowing figure rising from a Roman altar flame |

---

## Comune

| File | Soggetto (stile delle abilità, `%COLORE%` = `deep red`) |
|---|---|
| `pozione` | A Roman glass vial filled with glowing red healing liquid, bronze stopper |

## Dopo averle generate

1. Ritaglia e riduci a 256 × 256, controlla che non ci siano scritte o cornici.
2. Mettile nelle cartelle indicate con il nome esatto dell'`id`.
3. Avvisa Claude: le mostra sulla barra delle abilità, nei pulsanti touch, nella finestra Abilità (K) e
   nelle passive, al posto delle sigle (dove un'icona manca resta la sigla).
