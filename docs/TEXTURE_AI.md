# Testi per generare le texture degli effetti con un'AI

Le 12 texture della sezione 4 di `docs/EFFETTI_VISIVI.md`. I testi sono **in inglese** perché i generatori
di immagini (Midjourney, DALL·E, Stable Diffusion, Flux...) lo capiscono meglio.

## Regole comuni (valgono per tutte)

- **Scala di grigi**: il **bianco** è dove c'è l'effetto, il **nero** è vuoto. Il colore lo mette il codice
  (per elemento), quindi niente colori nell'immagine. Se l'AI la fa colorata, basta desaturarla.
- **Sfondo nero pieno**, soggetto **centrato** e **intero** (non tagliato dai bordi), con margine attorno.
- **Quadrata** (proporzione 1:1). Poi si riduce a 512 × 512 (o 256 × 256 le più semplici).
- Vista **dall'alto** per i segni a terra, **di fronte** per fiamme, fulmini e scintille.
- Si salvano in `textures/vfx/` con il nome indicato (PNG).
- In fondo a ogni testo c'è già la parte comune; con Midjourney aggiungi `--ar 1:1 --style raw`,
  con Stable Diffusion metti nel negativo: `color, text, watermark, frame, border, background details, cropped`.

Parte comune (già inclusa sotto):
`grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges`

---

## 1. Bagliore morbido — `glow.png` (256) · priorità bassa

> A single soft radial glow, bright white core fading smoothly to black at the edges, perfectly round and symmetrical, like a light bloom sprite. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 2. Scintilla / stella — `stella.png` (256)

> A sharp star-shaped light flare with 6 thin pointed rays of different lengths, small intense white core, rays fading to black, sparkle for a critical hit. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 3. Fiamma — `fiamma.png` (512) · il miglioramento più visibile

> A single stylized flame shape rising upward, wispy tongues of fire with soft inner gradients, brightest at the bottom center, licking tips fading to black at the top, hand-painted ARPG style. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

Nota: la versione definitiva sarebbe una **sequenza 4 × 4** (16 fotogrammi), ma le AI non tengono la
coerenza tra un fotogramma e l'altro. Soluzione: una fiamma singola come questa, che lo shader `fire`
fa muovere deformandola col rumore (texture 9). Variante da provare per la sequenza:

> Sprite sheet of a looping fire animation, 4 by 4 grid of 16 frames, same flame in each cell with slightly different shape, evenly spaced cells, grayscale, white on black, no color, no text, game VFX flipbook.

## 4. Fumo — `fumo.png` (512)

> A soft puffy cloud of smoke, billowing rounded volumes with wispy edges, subtle internal shading, fading to black at the borders. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

(Stesso discorso della fiamma: un fiocco singolo, lo shader lo fa girare e svanire.)

## 5. Fulmine — `fulmine_1.png`, `fulmine_2.png`, `fulmine_3.png` (512)

> A jagged lightning bolt running horizontally from the left edge to the right edge, thin bright white core with a soft glow, a few small branching forks, energy strip texture. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

Genera 3 varianti. Qui il fulmine **deve** toccare i bordi sinistro e destro (diventa una striscia
che si allunga tra due punti).

## 6. Anello d'urto — `anello.png` (512)

> A thin circular shockwave ring seen from directly above, soft glowing edge on the outside, slightly fuzzy and energetic, empty black center, perfectly round. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 7. Falce del fendente — `fendente.png` (512)

> A curved sword slash arc, crescent shape sweeping from left to right, bright sharp leading edge fading into a streaky motion trail with fine speed lines, anime/ARPG weapon trail. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 8. Rumore — `rumore.png` (512) · uno solo, usato da tutti gli shader

> Seamless tileable cloudy noise texture, mix of Perlin and Voronoi patterns, soft organic variations of gray covering the whole image, no subject, no focal point, uniform detail. Grayscale, no color, no text, game VFX texture.

Questa NON va su sfondo nero e deve essere **ripetibile senza cuciture** (con Stable Diffusion: opzione
*tiling*). In alternativa si genera in Godot (`NoiseTexture2D`, *Seamless*) senza AI.

## 9. Crepa nel terreno — `crepa.png` (512)

> Top-down view of cracks in stone ground from a heavy impact, radial fractures spreading from the center, thin branching crack lines, decal texture. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 10. Bruciatura — `bruciatura.png` (512)

> Top-down view of a scorch mark on the ground after an explosion, irregular burnt splotch with ragged edges and small splatter specks around it, denser in the center, decal texture. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 11. Brina / cristalli — `brina.png` (512)

> Top-down view of frost spreading on the ground, feathery ice crystal patterns growing outward from the center, delicate fractal frost edges, decal texture. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

## 12. Cerchio di rune — `rune.png` (512)

> Top-down magical summoning circle in ancient Roman augural style: two thin concentric rings, between them a band of carved Latin-like glyphs and small laurel motifs, a simple geometric pattern inside, thin elegant lines. Grayscale, pure white on pure black background, centered, isolated, no color, no text, game VFX texture, high contrast, clean edges.

(Qui le "lettere" sono decorative: se l'AI scrive parole leggibili o inventa scritte strane, rigenera.)

---

## Dopo averle generate

1. Desaturale se serve e controlla che lo sfondo sia **nero pieno** (alza un po' i livelli del nero).
2. Riducile a 512 o 256 e mettile in `textures/vfx/` con i nomi sopra.
3. Avvisa Claude: le collega agli shader di `core/vfx.gd` al posto del rumore procedurale.
