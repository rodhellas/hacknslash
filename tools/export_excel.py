# Crea docs/Legio3000_dati.xlsx dai dati del gioco esportati da tools/export_dati.gd.
# Uso:  python3 tools/export_excel.py "<cartella user:// di Godot>/dati.json" docs/Legio3000_dati.xlsx
# (su Windows la cartella è %APPDATA%/Godot/app_userdata/Legio 3000; serve openpyxl: pip install openpyxl)
import json, sys
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

d = json.load(open(sys.argv[1]))
out = sys.argv[2]
wb = Workbook()
wb.remove(wb.active)
F = Font(name="Arial", size=10)
FB = Font(name="Arial", size=10, bold=True)
FIN = Font(name="Arial", size=10, color="0000FF")
HEAD = PatternFill("solid", start_color="D9D9D9")

def sheet(name, headers, rows, widths=None):
    ws = wb.create_sheet(name)
    ws.append(headers)
    for c in ws[1]:
        c.font = FB; c.fill = HEAD
    for r in rows:
        ws.append(r)
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.font = F
            c.alignment = Alignment(vertical="top", wrap_text=isinstance(c.value, str) and len(c.value) > 50)
    ws.freeze_panes = "A2"
    if rows:
        ws.auto_filter.ref = ws.dimensions
    for i, h in enumerate(headers, 1):
        w = len(str(h)) + 2
        for r in rows:
            v = r[i - 1] if i - 1 < len(r) else ""
            w = max(w, min(len(str(v)) + 2, 60))
        ws.column_dimensions[get_column_letter(i)].width = widths[i - 1] if widths and i - 1 < len(widths) else w
    return ws

def fmt_mod(m):
    parts = []
    for k, v in m.get("mods", {}).items():
        if k == "color": continue
        parts.append(f"{k} = {v}")
    for k, v in m.get("add", {}).items():
        parts.append(f"{k} {'+' if float(v) >= 0 else ''}{v}")
    for k, v in m.get("mul", {}).items():
        parts.append(f"{k} ×{v}")
    return "; ".join(parts)

C = d["classes"]; order = d["order"]
SLOTN = {"lmb": "Clic sx", "rmb": "Clic dx", "1": "1-4", "2": "1-4", "3": "1-4", "4": "1-4"}

# --- Leggimi
ws = sheet("Leggimi", ["Foglio", "Contenuto"], [
    ["Classi", "Le 4 classi: statistiche, risorsa, armi, equipaggiamento iniziale"],
    ["Abilità", "Tutte le 40 abilità (6 base + 4 alternative per classe) con numeri"],
    ["Varianti", "Le 3 varianti (rune) di ogni abilità e cosa cambiano"],
    ["Passive", "6 passive per classe; caselle ai livelli 10, 20, 30"],
    ["Oggetti base", "Basi degli oggetti (armi, armature, gioielli)"],
    ["Affissi", "Proprietà casuali degli oggetti"],
    ["Leggendari", "24 leggendari con il loro potere"],
    ["Set", "8 set con pezzi e bonus"],
    ["Gemme", "Gemme normali e gemme leggendarie"],
    ["Loot", "Probabilità di rarità per fonte, valori di vendita, ricette del fabbro"],
    ["Nemici", "Tutti i nemici e i boss (valori a livello 1)"],
    ["Boss", "Attacchi speciali e fasi dei boss"],
    ["Affissi elite", "Affissi di Campioni e capi rari"],
    ["Difficoltà", "Normale → Tormento X"],
    ["Labirinti", "Labirinti di Dedalo: parametri e scala per grado (formule)"],
    ["Scala livelli", "Esperienza per livello e crescita dei nemici (formule)"],
    ["Dungeon", "Dungeon generati con seme fisso"],
    ["Mondo", "Santuari, piloni, eventi casuali"],
    ["Taglie", "Atti, luoghi e boss delle taglie"],
    ["Missioni", "Missioni e loro obiettivi"],
    ["NPC", "Personaggi non giocanti"],
    ["", ""],
    ["Nota", "Generato dai file in data/ del progetto (17-11-2026). Cambiando i dati del gioco il foglio non si aggiorna: va rigenerato."],
    ["Nota", "Nei fogli con formule (Labirinti, Scala livelli) i numeri in blu sono parametri copiati dal codice: cambiandoli si aggiorna la tabella, non il gioco."],
], [18, 110])

# --- Classi
rows = []
for cid in order:
    c = C[cid]
    rows.append([c["name"], cid, c["main_stat"], c["resource"], c["resource_max"], c["resource_regen"],
        "sì" if c.get("resource_starts_full", True) else "no",
        ", ".join(f"{k} {v}" for k, v in c["base"].items()), ", ".join(f"{k} +{v}" for k, v in c["per_level"].items()),
        ", ".join(c["weapons"]), ", ".join(c["offhands"]), ", ".join(c["start_items"]), c["desc"]])
sheet("Classi", ["Classe", "Id", "Stat. principale", "Risorsa", "Risorsa max", "Rigenerazione/s", "Parte piena",
    "Statistiche base", "Per livello", "Armi", "Mano secondaria", "Equip. iniziale", "Descrizione"], rows)

# --- Abilità
KEYS = ["dmg", "cost", "gain", "cooldown", "range", "arc", "radius", "duration", "count", "chain", "ticks"]
rows = []
for cid in order:
    base_ids = [a["id"] for a in C[cid]["abilities"]]
    for a in C[cid]["abilities"] + d["extra"][cid]:
        el = d["elements"].get(a["id"], "fisico")
        rows.append([C[cid]["name"], a["name"], a["id"], "base" if a["id"] in base_ids else "alternativa",
            SLOTN[a["slot"]], a["unlock"], a["kind"], el,
            round(a["dmg"] * 100) if "dmg" in a else None, a.get("cost"), a.get("gain"), a.get("cooldown"),
            a.get("radius") or a.get("range") or a.get("explode_radius") or a.get("distance"), a.get("duration"),
            a.get("count"), a.get("chain"), a.get("ticks"), a["desc"]])
sheet("Abilità", ["Classe", "Abilità", "Id", "Tipo", "Tasto", "Sblocco liv.", "Meccanica", "Elemento", "Danno % arma",
    "Costo", "Genera", "Ricarica s", "Raggio/portata m", "Durata s", "Proiettili", "Rimbalzi", "Colpi", "Descrizione"], rows)

# --- Varianti
rows = []
for cid in order:
    for a in C[cid]["abilities"] + d["extra"][cid]:
        for i, r in enumerate(d["runes"].get(a["id"], [])):
            el = d["rune_elements"].get(f"{a['id']}:{r['id']}", "")
            rows.append([C[cid]["name"], a["name"], r["name"], r["id"], d["rune_unlocks"][a["id"]][i], el, r["desc"], fmt_mod(r)])
sheet("Varianti", ["Classe", "Abilità", "Variante", "Id", "Sblocco liv.", "Cambia elemento", "Effetto", "Modifiche tecniche"], rows)

# --- Passive
rows = []
for cid in order:
    for p in d["passives"][cid]:
        rows.append([C[cid]["name"], p["name"], p["id"], p["unlock"], p["desc"],
            "; ".join(f"{s} +{v}" for s, v in p.get("stats", [])) if p.get("stats") else ("effetto speciale" if p.get("special") else "")])
sheet("Passive", ["Classe", "Passiva", "Id", "Sblocco liv.", "Effetto", "Statistiche"], rows)

# --- Oggetti base
rows = []
for bid, b in d["item_BASES"].items():
    dmg = b.get("dmg")
    rows.append([b["name"], bid, b["slot"], b.get("type", ""), dmg[0] if dmg else None, dmg[1] if dmg else None, b.get("aps"),
        b.get("armor"), d["item_MAX_SOCKETS"].get(b["slot"], 0), "sì" if bid in d["visuals"] else "no"])
sheet("Oggetti base", ["Nome", "Id", "Slot", "Tipo arma", "Danno min (liv.1)", "Danno max (liv.1)", "Attacchi/s", "Armatura (liv.1)",
    "Orbite max", "Si vede addosso"], rows)

# --- Affissi
rows = []
for k, a in d["item_AFFIXES"].items():
    rows.append([a["text"].replace("%d", "X").replace("%.1f", "X").replace("%%", "%"), k, a["min"], a["max"],
        "sì" if a["scale"] else "no", ", ".join(a["slots"]) if a["slots"] else "tutti"])
sheet("Affissi", ["Affisso", "Id", "Min (liv.1)", "Max (liv.1)", "Cresce col livello", "Slot"], rows)

# --- Leggendari
rows = []
for l in d["item_LEGENDARIES"]:
    pm = d["power_mods"].get(l["power"])
    rows.append([l["name"], l["base"], d["item_BASES"][l["base"]]["slot"], d["item_POWERS"].get(l["power"], ""),
        pm["ability"] if pm else "", "; ".join(f"{s} +{v}" for s, v in l["affixes"]), l["flavor"]])
sheet("Leggendari", ["Nome", "Base", "Slot", "Potere", "Abilità modificata", "Affissi fissi (liv.1)", "Frase"], rows)

# --- Set
rows = []
for sid, s in d["item_SETS"].items():
    pieces = "; ".join(f"{p['name']} ({p['base']})" for p in s["pieces"])
    def btxt(n):
        b = s["bonus"].get(str(n), {})
        if "text" in b: return b["text"]
        return "; ".join(f"{x} +{v}" for x, v in b.get("stats", []))
    rows.append([s["name"], sid, C[s["class"]]["name"], pieces, btxt(2), btxt(3), btxt(4)])
sheet("Set", ["Set", "Id", "Classe", "Pezzi", "Bonus 2 pezzi", "Bonus 3 pezzi", "Bonus 4 pezzi"], rows)

# --- Gemme
ws = sheet("Gemme", ["Gemma", "Id", "In arma", "In elmo", "Altrove", "Note"], [
    [g["name"], gid, f"{g['arma'][0]} +{g['arma'][1]}", f"{g['elmo'][0]} +{g['elmo'][1]}", f"{g['altro'][0]} +{g['altro'][1]}", "valori di grado 1"]
    for gid, g in d["item_GEMS"].items()])
r0 = ws.max_row + 2
ws.cell(r0, 1, "Grado").font = FB
ws.cell(r0, 2, "Moltiplicatore").font = FB
for i, (t, m) in enumerate(zip(d["item_GEM_TIERS"], d["item_GEM_TIER_MULT"])):
    ws.cell(r0 + 1 + i, 1, f"{i + 1} – {t}").font = F
    ws.cell(r0 + 1 + i, 2, m).font = F
r1 = r0 + 7
for j, h in enumerate(["Gemma leggendaria", "Id", "Effetto", "Base", "Per grado", "Max", "Note"], 1):
    c = ws.cell(r1, j, h); c.font = FB; c.fill = HEAD
for i, (gid, g) in enumerate(d["item_LEGENDARY_GEMS"].items()):
    vals = [g["name"], gid, g["desc"].replace("%d", "X").replace("%.1f", "X").replace("%%", "%"), g["base"], g["per_rank"], g.get("max", ""),
        f"statistica {g['stat']}" if "stat" in g else "effetto speciale"]
    for j, v in enumerate(vals, 1):
        ws.cell(r1 + 1 + i, j, v).font = F
ws.cell(r1 + 8, 1, "Solo in amuleto e anelli; grado massimo 50; potenziamento dopo un Labirinto in tempo (3 tentativi).").font = F

# --- Loot
ws = sheet("Loot", ["Fonte", "Comune", "Magico", "Raro", "Leggendario", "Prob. gemma"],
    [[src, *t, d["item_GEM_DROP_CHANCE"].get(src, 0)] for src, t in d["item_RARITY_TABLE"].items()])
for row in ws.iter_rows(min_row=2, min_col=2, max_col=6):
    for c in row: c.number_format = "0.0%"
r0 = ws.max_row + 2
names = ["Comune", "Magico", "Raro", "Leggendario", "Set"]
ws.cell(r0, 1, "Rarità").font = FB; ws.cell(r0, 2, "Vendita base").font = FB
for i, v in enumerate(d["item_SELL_VALUE"]):
    ws.cell(r0 + 1 + i, 1, names[i]).font = F; ws.cell(r0 + 1 + i, 2, v).font = F
ws.cell(r0 + 7, 1, "Vendita = base × (1 + 0,25 × (liv. oggetto − 1)); prezzo del mercante = vendita × 5. Leggendario: 35% di uscire come pezzo di set.").font = F
r1 = r0 + 9
for j, h in enumerate(["Ricetta del fabbro", "Sesterzi × livello", "Materiali"], 1):
    c = ws.cell(r1, j, h); c.font = FB; c.fill = HEAD
for i, (rid, r) in enumerate(d["item_RECIPES"].items()):
    ws.cell(r1 + 1 + i, 1, r["name"]).font = F
    ws.cell(r1 + 1 + i, 2, r["gold_per_level"]).font = F
    ws.cell(r1 + 1 + i, 3, ", ".join(f"{d['item_MATERIALS'][m]['name']} ×{n}" for m, n in r["mats"].items())).font = F

# --- Nemici
rows = []
for eid, e in d["enemies"].items():
    tipo = "boss" if e.get("unique") else "normale"
    rows.append([e["name"], eid, tipo, e["hp"], e["damage"], e["speed"], e["range"], e["windup"], e["cooldown"], e["aggro"], e["xp"],
        "a distanza" if e.get("ranged") else "mischia", e.get("special", ""), e.get("summon", ""), e.get("model_scale", 1.0)])
sheet("Nemici", ["Nemico", "Id", "Tipo", "Vita (liv.1)", "Danno (liv.1)", "Velocità m/s", "Portata m", "Carica s", "Pausa s",
    "Ti nota a m", "PE (liv.1)", "Attacco", "Speciale", "Rinforzi", "Scala modello"], rows)

# --- Boss
rows = []
for bid, b in d["bosses"].items():
    ph = []
    for p in b["phases"]:
        acts = ", ".join(p["do"]) + (f" ({p['n']} × {p['type']})" if "type" in p else "")
        ph.append(f"{int(float(p['at']) * 100)}%: {acts}")
    rows.append([d["enemies"][bid]["name"], bid, d["enemies"][bid]["hp"], ", ".join(b["attacks"]), " | ".join(ph),
        " | ".join(p.get("say", "") for p in b["phases"])])
sheet("Boss", ["Boss", "Id", "Vita (liv.1)", "Attacchi iniziali", "Fasi (soglia di vita: azioni)", "Frasi"], rows)

# --- Affissi elite
sheet("Affissi elite", ["Affisso", "Id", "Effetto"], [[a["name"], k, a["desc"]] for k, a in d["elite_affixes"].items()])

# --- Difficoltà
ws = sheet("Difficoltà", ["Difficoltà", "Vita nemici ×", "Danni nemici ×", "Esperienza ×", "Sesterzi ×", "Leggendari ×", "Affissi elite", "Sblocco liv."],
    [[x["name"], x["hp"], x["dmg"], x["xp"], x["gold"], x["leg"], x["affixes"], x["unlock"]] for x in d["difficulty"]])
ws.cell(ws.max_row + 2, 1, "Da Esperto in su i nemici hanno almeno il livello dell'eroe.").font = F

# --- Labirinti (formule)
ws = wb.create_sheet("Labirinti")
params = [("Tempo limite (s)", d["rift"]["time"]), ("Tempo per +2 gradi (s)", d["rift"]["fast"]),
    ("Barra: frazione dei nemici attesi", d["rift"]["progress"]), ("Vita: base", 1.4), ("Vita: crescita per grado", 1.17),
    ("Danni: base", 1.3), ("Danni: crescita per grado", 1.1)]
ws["A1"] = "Parametro"; ws["B1"] = "Valore"
for c in ws[1]: c.font = FB; c.fill = HEAD
for i, (n, v) in enumerate(params, 2):
    ws.cell(i, 1, n).font = F
    c = ws.cell(i, 2, v); c.font = FIN
ws.cell(10, 1, "Guardiani").font = FB; ws.cell(10, 2, ", ".join(d["rift"]["guardians"])).font = F
ws.cell(11, 1, "Gruppi di nemici").font = FB; ws.cell(11, 2, " | ".join(", ".join(g) for g in d["rift"]["enemies"])).font = F
hdr = ["Grado", "Vita nemici ×", "Danni nemici ×", "Esperienza ×", "Sesterzi ×", "Leggendari ×", "Affissi elite", "Stanze"]
for j, h in enumerate(hdr, 1):
    c = ws.cell(13, j, h); c.font = FB; c.fill = HEAD
for g in range(1, 31):
    r = 13 + g
    ws.cell(r, 1, g)
    ws.cell(r, 2, f"=$B$5*$B$6^(A{r}-1)")
    ws.cell(r, 3, f"=$B$7*$B$8^(A{r}-1)")
    ws.cell(r, 4, f"=1.5+0.2*A{r}")
    ws.cell(r, 5, f"=1.5+0.1*A{r}")
    ws.cell(r, 6, f"=1.5+0.15*A{r}")
    ws.cell(r, 7, f"=MIN(4,MAX(2,2+INT(A{r}/5)))")
    ws.cell(r, 8, f"=MIN(14,MAX(9,9+INT(A{r}/3)))")
    for j in range(1, 9):
        ws.cell(r, j).font = F
        if 2 <= j <= 6: ws.cell(r, j).number_format = "0.00"
ws.cell(45, 1, "Formule uguali a DifficultyDB.rift_scaling e rift_config (data/difficulty_db.gd).").font = F
ws.column_dimensions["A"].width = 34; ws.column_dimensions["B"].width = 16
for col in "CDEFGH": ws.column_dimensions[col].width = 15
ws.freeze_panes = "A2"

# --- Scala livelli (formule)
ws = wb.create_sheet("Scala livelli")
ws["A1"] = "Parametro"; ws["B1"] = "Valore"
for c in ws[1]: c.font = FB; c.fill = HEAD
ps = [("PE: base", 80), ("PE: esponente", 1.6), ("Vita nemici: +per livello", 0.3), ("Danni nemici: +per livello", 0.2),
    ("PE nemici: +per livello", 0.25), ("Vita eroe: base", 60), ("Vita eroe: per livello", 12)]
for i, (n, v) in enumerate(ps, 2):
    ws.cell(i, 1, n).font = F
    ws.cell(i, 2, v).font = FIN
hdr = ["Livello", "PE per il livello dopo", "PE totali", "Vita nemici ×", "Danni nemici ×", "PE nemici ×", "Vita eroe (senza Vitalità)"]
for j, h in enumerate(hdr, 1):
    c = ws.cell(10, j, h); c.font = FB; c.fill = HEAD
for L in range(1, 61):
    r = 10 + L
    ws.cell(r, 1, L)
    ws.cell(r, 2, f"=INT($B$2*A{r}^$B$3)")
    ws.cell(r, 3, f"=B{r}" if L == 1 else f"=C{r-1}+B{r}")
    ws.cell(r, 4, f"=1+$B$4*(A{r}-1)")
    ws.cell(r, 5, f"=1+$B$5*(A{r}-1)")
    ws.cell(r, 6, f"=1+$B$6*(A{r}-1)")
    ws.cell(r, 7, f"=$B$7+$B$8*A{r}")
    for j in range(1, 8):
        ws.cell(r, j).font = F
    for j in (2, 3, 7): ws.cell(r, j).number_format = "#,##0"
    for j in (4, 5, 6): ws.cell(r, j).number_format = "0.00"
ws.cell(72, 1, "Vita eroe completa = (60 + 12 × livello + 6 × Vitalità + vita dagli oggetti) × (1 + % vita). Livello massimo 60.").font = F
ws.column_dimensions["A"].width = 30
for col in "BCDEFG": ws.column_dimensions[col].width = 20
ws.freeze_panes = "A2"

# --- Dungeon
rows = []
for did, x in d["dungeons"].items():
    rows.append([x["title"], did, x["seed"], x.get("style", "stanze"), x["rooms"], x["grid"], x["enemy_level"], ", ".join(x["enemies"]),
        ", ".join(x["elites"]), x["boss"], ", ".join(f"{k} {int(v*100)}%" for k, v in x.get("room_kinds", [])), f"{x['entrance'][0]} – {x['entrance'][1]}"])
sheet("Dungeon", ["Dungeon", "Id", "Seme", "Stile", "Stanze", "Griglia (celle 3 m)", "Liv. nemici", "Nemici", "Elite", "Boss", "Tipi di stanza", "Entrata"], rows)

# --- Mondo
rows = []
for k, s in d["shrines"].items():
    rows.append(["Santuario", s["name"], k, s["desc"], s["duration"], "mappe e dungeon"])
for k, s in d["pylons"].items():
    rows.append(["Pilone", s["name"], k, s["desc"], s["duration"], "solo Labirinti"])
for k, e in d["events"].items():
    det = f"{e['time']} s" if "time" in e else (f"ondate {e['waves']}" if "waves" in e else f"{e.get('captives')} prigionieri")
    rows.append(["Evento", e["name"], k, e["desc"], det, "mappe all'aperto"])
ws = sheet("Mondo", ["Tipo", "Nome", "Id", "Effetto", "Durata / dettagli", "Dove"], rows)
ws.cell(ws.max_row + 2, 1, "Per visita: 3 santuari e 2 eventi nelle mappe, 2 santuari nei dungeon, 1 santuario + 2 piloni nei Labirinti.").font = F

# --- Taglie
rows = []
for act, a in d["acts"].items():
    rows.append([a["name"], ", ".join(a["levels"]), ", ".join(f"{d['enemies'][b]['name']} ({p})" for b, p in a["bosses"].items())])
ws = sheet("Taglie", ["Atto", "Luoghi", "Boss possibili"], rows)
ws.cell(ws.max_row + 2, 1, "4 taglie per atto: 1 boss + uccisioni (25), elite (3) o eventi (1). Ricompensa per taglia: 60 PE e 40 sesterzi × livello. Tutte finite: Cassa del Prefetto.").font = F

# --- Missioni
rows = []
for qid, q in d["quests"].items():
    steps = " → ".join(f"{s['type']}: {s.get('target','')}" for s in q["steps"])
    rew = q.get("reward", {})
    rows.append([q["act"], q["title"], qid, q.get("giver", "") or "automatica", ", ".join(q.get("requires", [])), steps,
        rew.get("xp"), rew.get("gold"), q.get("desc", "")])
sheet("Missioni", ["Atto", "Missione", "Id", "Chi la affida", "Richiede", "Obiettivi", "PE", "Sesterzi", "Descrizione"], rows)

# --- NPC
rows = []
for nid, n in d["npcs"].items():
    rows.append([n["name"], nid, n.get("title", ""), n["role"], len(n.get("lines", [])), (n.get("lines") or [""])[0]])
sheet("NPC", ["Nome", "Id", "Titolo", "Ruolo", "Frasi", "Prima frase"], rows)

from openpyxl.workbook.properties import CalcProperties
wb.calculation = CalcProperties(fullCalcOnLoad=True)
wb.save(out)
print("salvato", out, [ws.title for ws in wb.worksheets])
