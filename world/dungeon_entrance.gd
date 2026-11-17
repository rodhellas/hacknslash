class_name DungeonEntrance
extends StaticBody3D
## Entrata di un dungeon generato (data/dungeon_db.gd). Si clicca per scendere; all'uscita del
## dungeon si torna qui davanti. Si mette nei livelli come oggetto di scena "ingresso_catacombe".

## Chiave di DungeonDB.DUNGEONS.
@export var dungeon_id := "catacombe"


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.WORLD | Layers.INTERACT
	if Engine.is_editor_hint():
		return
	Fx.minimap_icon(self, Color(0.85, 0.4, 1.0), 2.5, "square")


func interact_name() -> String:
	return "Entra: %s" % DungeonDB.get_data(dungeon_id)["title"]


func can_interact() -> bool:
	return true


## Punto davanti all'entrata (dove si ricompare uscendo dal dungeon).
func return_point() -> Vector3:
	return global_position + global_basis.z * 4.0


func interact(p: Player) -> void:
	if Game.hero == null or Game.level == null or p.dead:
		return
	var back := return_point()
	Game.hero.flags["dungeon"] = {"id": dungeon_id, "return_level": Game.level.level_id, "x": back.x, "z": back.z}
	Sfx.play("portal")
	Game.travel("dungeon")
