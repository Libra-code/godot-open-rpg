## A simple buy/sell shop UI for a vendor NPC (see [ShopInteraction]).
##
## Unlike [CharacterMenu]/[PauseMenu], which are permanent siblings in the field scene, a shop is
## content tied to a specific NPC: [ShopInteraction] instantiates this scene on demand and frees it
## once [signal closed] fires, rather than keeping a hidden copy around at all times.
extends CanvasLayer

## Emitted once the player closes the shop, so [ShopInteraction] knows to resume the field.
signal closed

## Item ids (see [ItemDatabase]) this shop offers to sell to the player. Selling items back to the
## shop is not restricted to this list — any database-backed item the player is carrying (see
## [method Inventory.get_all_item_ids]) can be sold.
@export var buy_item_ids: Array[String] = []

@onready var _coin_label: Label = %CoinLabel
@onready var _buy_list: VBoxContainer = %BuyList
@onready var _sell_list: VBoxContainer = %SellList

var _inventory: Inventory


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	_inventory = Inventory.restore()
	_inventory.item_changed.connect(func _on_item_changed(_type: Inventory.ItemTypes) -> void: _refresh())
	_inventory.generic_item_changed.connect(func _on_generic_item_changed(_id: String) -> void: _refresh())

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().paused = false
	closed.emit()


func _refresh() -> void:
	_coin_label.text = "Monete: %d" % _inventory.get_item_count(Inventory.ItemTypes.COIN)
	_rebuild_list(_buy_list, _get_buy_rows())
	_rebuild_list(_sell_list, _get_sell_rows())


func _get_buy_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in buy_item_ids:
		var item_row: = ItemDatabase.get_item(item_id)
		if item_row.is_empty():
			continue

		var price: int = item_row.get("value", 0)
		rows.append({
			"label": "%s — %d monete" % [item_row.display_name, price],
			"action_label": "Compra",
			"disabled": _inventory.get_item_count(Inventory.ItemTypes.COIN) < price,
			"on_pressed": func() -> void: _buy(item_id, price),
		})
	return rows


func _get_sell_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in _inventory.get_all_item_ids():
		var item_row: = ItemDatabase.get_item(item_id)
		if item_row.is_empty():
			continue

		var price: int = item_row.get("value", 0)
		var amount: = _inventory.get_item_amount(item_id)
		rows.append({
			"label": "%s x%d — %d monete l'uno" % [item_row.display_name, amount, price],
			"action_label": "Vendi",
			"disabled": false,
			"on_pressed": func() -> void: _sell(item_id, price),
		})
	return rows


func _rebuild_list(list: VBoxContainer, rows: Array[Dictionary]) -> void:
	for child in list.get_children():
		child.queue_free()

	if rows.is_empty():
		var empty_label: = Label.new()
		empty_label.text = "(nessun oggetto)"
		list.add_child(empty_label)
		return

	for row in rows:
		list.add_child(_build_row(row.label, row.action_label, row.disabled, row.on_pressed))


func _build_row(text: String, action_label: String, disabled: bool, on_pressed: Callable) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label: = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button: = Button.new()
	button.text = action_label
	button.disabled = disabled
	button.pressed.connect(on_pressed)
	row.add_child(button)

	return row


func _buy(item_id: String, price: int) -> void:
	if _inventory.get_item_count(Inventory.ItemTypes.COIN) < price:
		return

	_inventory.remove(Inventory.ItemTypes.COIN, price)
	_inventory.add_item(item_id, 1)
	_inventory.save()


func _sell(item_id: String, price: int) -> void:
	_inventory.remove_item(item_id, 1)
	_inventory.add(Inventory.ItemTypes.COIN, price)
	_inventory.save()
