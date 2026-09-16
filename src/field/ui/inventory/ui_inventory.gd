## An exceptionally simple item inventory that tracks which items the player has picked up.
## Normally, inventory design would be more complex. In particular, you would want to separate the
## inventory data structures from the UI implementation, as should be done in a future update to
## the OpenRPG project.
## In this case, we just want to show the player which items have been picked up so that we can demo
## a variety of RPG events.
##
## Also drives the "item detail panel" (see [code]%DetailIcon[/code]/[code]%DetailNameLabel[/code]/
## [code]%DetailDescriptionLabel[/code] in character_menu.tscn): [kbd]Left[/kbd]/[kbd]Right[/kbd]
## move a selection highlight across the currently-held items, and the panel always shows the
## selected item's icon, name and description.
class_name UIInventory extends HBoxContainer

# Keep track of the inventory item packed scene to easily instantiate new items.
var _ITEM_SCENE: = preload("res://src/field/ui/inventory/ui_inventory_item.tscn")

var _selected_index: = -1

@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_name_label: Label = %DetailNameLabel
@onready var _detail_description_label: Label = %DetailDescriptionLabel


func _ready() -> void:
	var inventory: = Inventory.restore()

	for item_name in Inventory.ItemTypes:
		_update_item(Inventory.ItemTypes[item_name], inventory)
	inventory.item_changed.connect(_on_inventory_item_changed.bind(inventory))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	var items: = _get_items()
	if items.is_empty():
		return

	if event.is_action_pressed(&"ui_right"):
		get_viewport().set_input_as_handled()
		_selected_index = (_selected_index + 1) % items.size()
		_update_selection()
	elif event.is_action_pressed(&"ui_left"):
		get_viewport().set_input_as_handled()
		_selected_index = (_selected_index - 1 + items.size()) % items.size()
		_update_selection()


func get_ui_item(item_id: Inventory.ItemTypes) -> UIInventoryItem:
	for child in get_children():
		var item: = child as UIInventoryItem
		if item and item.ID == item_id:
			return item
	return null


func _get_items() -> Array[UIInventoryItem]:
	var items: Array[UIInventoryItem] = []
	for child in get_children():
		var item: = child as UIInventoryItem
		if item:
			items.append(item)
	return items


func _update_item(item_id: Inventory.ItemTypes, inventory: Inventory) -> void:
	var amount: = inventory.get_item_count(item_id)
	var item: = get_ui_item(item_id)

	if amount > 0:
		if not item:
			item = _ITEM_SCENE.instantiate() as UIInventoryItem
			item.ID = item_id
			item.texture = Inventory.get_item_icon(item_id)
			add_child(item)

		item.count = amount

	else:
		if item:
			remove_child(item)
			item.queue_free()

	_update_selection()


func _on_inventory_item_changed(item_type: Inventory.ItemTypes, inventory: Inventory) -> void:
	_update_item(item_type, inventory)


## Clamps the selection to the current item list, refreshes the highlight, and refreshes the
## detail panel to match. Safe to call any time the item list may have changed size.
func _update_selection() -> void:
	var items: = _get_items()

	if items.is_empty():
		_selected_index = -1
		_detail_icon.texture = null
		_detail_name_label.text = ""
		_detail_description_label.text = "Nessun oggetto posseduto."
		return

	_selected_index = clampi(_selected_index, 0, items.size() - 1)

	for i in items.size():
		items[i].selected = i == _selected_index

	var selected_item: = items[_selected_index]
	_detail_icon.texture = selected_item.texture
	_detail_name_label.text = "%s (x%d)" % [
		Inventory.get_item_name(selected_item.ID), selected_item.count
	] if selected_item.count > 1 else Inventory.get_item_name(selected_item.ID)
	_detail_description_label.text = Inventory.get_item_description(selected_item.ID)
