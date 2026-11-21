extends SceneTree
## Crea la scena di un corpo vero (Tripo + Mixamo) con le 12 prese agganciate alle ossa.
##   Godot --headless --path . --script res://tools/build_corpo_vero.gd -- <glb> <scena .tscn>
##   es. -- res://modelli/corpi/legionario_m.glb res://scenes/characters/legionario_vero.tscn
## Il GLB (vedi docs/MODELLI_TRIPO.md) guarda verso +Z (Mixamo): qui si gira di 180° (gioco: davanti = -Z).
## Ogni presa = BoneAttachment3D (scheletro esterno) "Osso_<nome>" + Marker3D "Presa_<nome>" figlio, messo in
## modo che nella posa a T abbia la stessa orientazione delle prese del graybox: i pezzi (VisualDB) valgono
## per tutti e due i corpi. Mani: lama verso -Z, piatto in alto (palmo in giù). Avambracci: "alto" del pezzo
## verso il gomito, "fuori" verso il dorso dell'avambraccio.

var _model: Node3D
var _skel: Skeleton3D


var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_build()
	return false


func _build() -> void:
	var args := OS.get_cmdline_user_args()
	var glb := args[0] if args.size() > 0 else "res://modelli/corpi/legionario_m.glb"
	var out := args[1] if args.size() > 1 else "res://scenes/characters/legionario_vero.tscn"
	_model = Node3D.new()
	_model.name = "Model"
	root.add_child(_model)
	var corpo := (load(glb) as PackedScene).instantiate() as Node3D
	corpo.name = "Corpo"
	corpo.rotation_degrees.y = 180.0
	_model.add_child(corpo)
	corpo.owner = _model
	for n: Node in corpo.find_children("*", "Skeleton3D", true, false):
		_skel = n
	if _skel == null:
		push_error("nessuno Skeleton3D in " + glb)
		quit(1)
		return

	var head_c := _head_center()
	var R := Basis(Vector3.BACK, deg_to_rad(90.0))    # rotazione attorno a Z (+90°)
	var L := Basis(Vector3.BACK, deg_to_rad(-90.0))
	var hand_r := _pos("RightHand")
	var hand_l := _pos("LeftHand")
	var sockets := [
		["Testa", "Head", Transform3D(Basis(), Vector3(0, 1.74, head_c.z))],
		["Busto", "Spine2", Transform3D(Basis(), Vector3(0, _pos("Spine2").y, _pos("Spine2").z))],
		["Schiena", "Spine2", Transform3D(Basis(), Vector3(0, _pos("Spine2").y, _pos("Spine2").z + 0.18))],
		["Bacino", "Hips", Transform3D(Basis(), Vector3(0, _pos("Hips").y, _pos("Hips").z))],
		["ManoDx", "RightHand", Transform3D(Basis(), hand_r + (_pos("RightHandMiddle1") - hand_r) * 0.55 + Vector3(0, -0.03, 0))],
		["ManoSx", "LeftHand", Transform3D(Basis(), hand_l + (_pos("LeftHandMiddle1") - hand_l) * 0.55 + Vector3(0, -0.03, 0))],
		["AvambraccioDx", "RightForeArm", Transform3D(R, (_pos("RightForeArm") + hand_r) * 0.5)],
		["AvambraccioSx", "LeftForeArm", Transform3D(L, (_pos("LeftForeArm") + hand_l) * 0.5)],
		["StincoDx", "RightLeg", Transform3D(Basis(), (_pos("RightLeg") + _pos("RightFoot")) * 0.5)],
		["StincoSx", "LeftLeg", Transform3D(Basis(), (_pos("LeftLeg") + _pos("LeftFoot")) * 0.5)],
		["PiedeDx", "RightFoot", Transform3D(Basis(), Vector3(_pos("RightFoot").x, 0.06, _pos("RightFoot").z - 0.04))],
		["PiedeSx", "LeftFoot", Transform3D(Basis(), Vector3(_pos("LeftFoot").x, 0.06, _pos("LeftFoot").z - 0.04))],
	]
	var prese := Node3D.new()
	prese.name = "Prese"
	_model.add_child(prese)
	prese.owner = _model
	for s: Array in sockets:
		var bi := _bone(String(s[1]))
		var ba := BoneAttachment3D.new()
		ba.name = "Osso_" + String(s[0])
		prese.add_child(ba)
		ba.owner = _model
		ba.use_external_skeleton = true
		ba.external_skeleton = ba.get_path_to(_skel)
		ba.bone_name = _skel.get_bone_name(bi)
		var m := Marker3D.new()
		m.name = "Presa_" + String(s[0])
		m.transform = _bone_model(bi).affine_inverse() * (s[2] as Transform3D)
		ba.add_child(m)
		m.owner = _model
		print("  %-14s osso %-22s in %s" % [m.name, ba.bone_name, (s[2] as Transform3D).origin.snappedf(0.01)])
	print("  mano destra a x = %.2f (deve essere > 0), testa a z = %.3f" % [hand_r.x, head_c.z])
	var ps := PackedScene.new()
	ps.pack(_model)
	var err := ResourceSaver.save(ps, out)
	print("salvato ", out, ": ", error_string(err))
	quit(0 if err == OK and hand_r.x > 0.0 else 1)


func _bone(suffix: String) -> int:
	for i in _skel.get_bone_count():
		var n := _skel.get_bone_name(i)
		if n == suffix or n.ends_with("_" + suffix) or n.ends_with(":" + suffix):
			return i
	push_error("osso mancante: " + suffix)
	return 0


## Posa a riposo dell'osso nello spazio del modello.
func _bone_model(i: int) -> Transform3D:
	return _model.global_transform.affine_inverse() * _skel.global_transform * _skel.get_bone_global_rest(i)


func _pos(suffix: String) -> Vector3:
	return _bone_model(_bone(suffix)).origin


## Centro della testa nello spazio del modello: 2,8 cm davanti all'osso Head (misurato in Blender sulla mesh
## "Testa" del Legionario M: fetta tra 8 e 16 cm sotto la cima). I vertici di una mesh con scheletro qui non
## sono nello spazio del modello, per questo non si misurano in Godot.
const HEAD_FORWARD := 0.028


func _head_center() -> Vector3:
	return Vector3(0, 1.74, _pos("Head").z - HEAD_FORWARD)
