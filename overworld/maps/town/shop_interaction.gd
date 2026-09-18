@tool
## Opens a [ShopMenu] when the player interacts with a vendor NPC.
##
## The shop scene is instantiated on demand and freed once the player closes it, rather than kept
## as a permanent hidden sibling the way [CharacterMenu]/[PauseMenu] are — a shop belongs to one
## specific NPC, not the whole field scene.
extends Interaction

@export var shop_scene: PackedScene
## Item ids (see [ItemDatabase]) this vendor offers to sell to the player.
@export var buy_item_ids: Array[String] = []
## Optional short greeting played before the shop opens, e.g. smith.dtl. Left empty, the shop
## opens immediately with no dialogue.
@export var greeting_timeline: DialogicTimeline


func _execute() -> void:
	if greeting_timeline:
		Dialogic.start_timeline(greeting_timeline)
		await Dialogic.timeline_ended

	var shop: = shop_scene.instantiate()
	shop.buy_item_ids = buy_item_ids
	get_tree().root.add_child(shop)

	await shop.closed
	shop.queue_free()
