## An inventory item, tracking both it's UI representation and underlying data.
## Will be replaced in future iterations of the OpenRPG project.
## Please see UIInventory for additional information.
class_name UIInventoryItem extends TextureRect

const SELECTED_MODULATE: = Color(1.3, 1.3, 1.0, 1.0)
const NORMAL_MODULATE: = Color(1, 1, 1, 1)

var ID: = Inventory.ItemTypes.KEY

var count: = 0:
	set = set_count

## Highlights this item to indicate it's the one the item detail panel is describing.
var selected: = false:
	set(value):
		selected = value
		modulate = SELECTED_MODULATE if selected else NORMAL_MODULATE

@onready var _count_label: = $Count as Label


func set_count(value: int) -> void:
	count = max(value, 0)
	if count == 0:
		queue_free()
	
	elif count > 1:
		_count_label.show()
		_count_label.text = str(count)
	
	else:
		_count_label.hide()
