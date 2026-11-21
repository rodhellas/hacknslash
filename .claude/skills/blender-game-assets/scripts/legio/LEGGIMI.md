# Script Blender usati per Legio 3000 (21-11-2026)

Si eseguono nel Blender aperto con `../blender_exec_addon.py`, concatenando: un file di parametri
(es. `RIG="corpo_f_Rig"; KIND="ocrea"; SRC="ocrea.glb"`), `../bpy_lib.py`, `../tripo_lib.py`, `fit_lib.py`, lo script.
`SCRATCH` nei percorsi dei render = una cartella temporanea a scelta. Flusso completo in `docs/MODELLI_TRIPO.md`.

- Corpo con Mixamo: `skin1.py` (importa la pelle), `anims.py` (animazioni come tracce NLA, nomi del gioco),
  `narrow.py` (gambe dritte nella posa di riposo), `split.py` (6 parti), `rig_exp.py` (GLB).
- Armature con pelle: `mkbase.py` (pezzo ripulito), `lorica_fit5.py` (lorica; `FLARE` per i fianchi),
  `lorica_skin.py` (pesi + pose), `limb_fit.py` (calzari; schinieri con `NO_TIGHT=True`), `shell_fit.py` (spallacci),
  `reskin.py` (pesi dei pezzi doppi per lato), `pose_all.py` (controllo nelle animazioni), `arm_export.py` (GLB per corpo).
