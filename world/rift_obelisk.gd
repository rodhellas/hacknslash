class_name RiftObelisk
extends StaticBody3D
## Obelisco di Dedalo (in città): apre i Labirinti di Dedalo, l'endgame. Si sceglie il grado
## (da 1 al massimo sbloccato, hero.flags["rift_max"]) e si entra in un dungeon generato con un seme
## nuovo. Non blocca il passaggio (solo livello "interagibile"), quindi non tocca la navmesh.


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.INTERACT
	collision_mask = 0
	if get_child_count() == 0:
		_build()
	if Engine.is_editor_hint():
		return
	Fx.minimap_icon(self, Color(0.7, 0.4, 1.0), 1.6, "square")


func _build() -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 4.0, 1.6)
	shape.shape = bs
	shape.position.y = 2.0
	add_child(shape)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.4, 2.2)
	base.mesh = bm
	base.material_override = Fx.mat(Color(0.25, 0.22, 0.28))
	base.position.y = 0.2
	add_child(base)
	var ob := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.7
	cm.height = 4.2
	cm.radial_segments = 4
	ob.mesh = cm
	ob.material_override = Fx.mat(Color(0.15, 0.13, 0.18))
	ob.position.y = 2.5
	ob.rotation_degrees.y = 45.0
	add_child(ob)
	var rune := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.9
	rm.outer_radius = 1.05
	rune.mesh = rm
	rune.material_override = Fx.mat(Color(0.7, 0.4, 1.0), 4.0, false, true)
	rune.position.y = 2.2
	add_child(rune)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.4, 1.0)
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position.y = 3.0
	add_child(light)


func interact_name() -> String:
	return "Obelisco di Dedalo"


func can_interact() -> bool:
	return true


func interact(_p: Player) -> void:
	if Game.level == null or Game.hero == null:
		return
	var mx := max_grade()
	var opts: Array = []
	for g in range(mx, maxi(0, mx - 8), -1):
		opts.append(["Grado %d" % g, start.bind(g)])
	var body := "Uccidi abbastanza nemici per evocare il Guardiano, poi sconfiggilo entro %d minuti per salire di grado.\nGrado massimo sbloccato: %d" % [
			int(DifficultyDB.RIFT_TIME / 60.0), mx]
	var recs: Array = Game.hero.flags.get("rift_records", [])
	if not recs.is_empty():
		body += "\n\nI tuoi record:"
		for r: Dictionary in recs.slice(0, 5):
			body += "\n  Grado %d – %d:%02d – %d uccisioni%s" % [int(r["grade"]), int(r["time"]) / 60, int(r["time"]) % 60,
				int(r["kills"]), "" if bool(r["ok"]) else " (fuori tempo)"]
	Game.level.hud.show_choice("Labirinti di Dedalo", body, opts)


static func max_grade() -> int:
	return maxi(1, int(Game.hero.flags.get("rift_max", 1)))


## Entra in un labirinto del grado dato con un seme nuovo.
static func start(grade: int) -> void:
	var runs := int(Game.hero.flags.get("rift_runs", 0)) + 1
	Game.hero.flags["rift_runs"] = runs
	var seed_value := absi(hash("%s|%d|%d" % [Game.hero.hero_name, grade, runs])) % 1000000 + 1
	var back := Vector3.ZERO
	if Game.level and Game.level.player:
		back = Game.level.player.global_position + Vector3(0, 0, 3)
	Game.hero.flags["dungeon"] = {"id": "labirinto", "rift": grade, "seed": seed_value,
		"return_level": Game.level.level_id if Game.level else Game.HUB, "x": back.x, "z": back.z}
	if Game.level:
		Game.level.hud.hide_choice()
	Game.travel("dungeon")
