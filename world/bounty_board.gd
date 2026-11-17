class_name BountyBoard
extends StaticBody3D
## Tabula delle taglie (foro di Ostia Nova): mostra le taglie di ogni atto e dà la Cassa del Prefetto
## quando un atto è completato. Solo livello "interagibile": non tocca la navmesh.


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.INTERACT
	collision_mask = 0
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.4, 2.6, 0.6)
		shape.shape = bs
		shape.position.y = 1.3
		add_child(shape)
		for x: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.15, 2.6, 0.15)
			post.mesh = pm
			post.material_override = Fx.mat(Color(0.4, 0.28, 0.16))
			post.position = Vector3(x, 1.3, 0)
			add_child(post)
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.2, 1.4, 0.08)
		board.mesh = bm
		board.material_override = Fx.mat(Color(0.82, 0.74, 0.55))
		board.position = Vector3(0, 1.7, 0)
		add_child(board)
		for i in 4:
			var paper := MeshInstance3D.new()
			var qm := BoxMesh.new()
			qm.size = Vector3(0.4, 0.5, 0.02)
			paper.mesh = qm
			paper.material_override = Fx.mat(Color(0.95, 0.92, 0.8), 0.3)
			paper.position = Vector3(-0.75 + i * 0.5, 1.7, -0.06)
			add_child(paper)
	if Engine.is_editor_hint():
		return
	Fx.minimap_icon(self, Color(1.0, 0.85, 0.3), 1.6, "square")


func interact_name() -> String:
	return "Tabula delle taglie"


func can_interact() -> bool:
	return true


func interact(_p: Player) -> void:
	if Game.level == null or Game.hero == null:
		return
	var body := ""
	var opts: Array = []
	for act: int in WorldDB.ACTS:
		body += "%s\n" % WorldDB.ACTS[act]["name"]
		for b: Dictionary in Bounties.act_list(act):
			body += "   %s\n" % Bounties.text(b)
		if Bounties.act_done(act):
			opts.append(["Ritira la Cassa del Prefetto (%s)" % WorldDB.ACTS[act]["name"], claim.bind(act)])
	body += "\nCompleta tutte le taglie di un atto per la Cassa del Prefetto. I boss delle taglie ricompaiono."
	Game.level.hud.show_choice("Tabula delle taglie", body, opts)


func claim(act: int) -> void:
	if Bounties.claim_cache(act, global_position + global_basis.z * 2.0):
		Sfx.play("legendary", global_position)
		Game.level.hud.show_banner("Cassa del Prefetto!")
	Game.level.hud.hide_choice()
