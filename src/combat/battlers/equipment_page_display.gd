## Lets the player equip/unequip gear and unlock skills for whichever party members have content
## registered (see [method PartyLoadouts.get_managed_character_names]). Rebuilds its list after
## every change made through it, and once up front when the page first shows.
##
## Equipment isn't restricted per character — any registered [EquipmentItem] can be equipped by
## anyone with a managed loadout. That's a simplification, not a design decision: nothing in
## [EquipmentItem] models "this is a bear-only weapon" yet.
##
## Also drives the equipment detail panel ([code]%EquipmentDetailLabel[/code] in
## character_menu.tscn): focusing any row's button with [kbd]Up[/kbd]/[kbd]Down[/kbd] (Godot's
## default Control focus traversal) shows that item's or skill's full description there.
class_name EquipmentPageDisplay extends VBoxContainer

const LOCKED_COLOR: = Color(0.6, 0.55, 0.5, 1)
const UNLOCKED_COLOR: = Color(0.6, 0.85, 0.6, 1)
const AVAILABLE_COLOR: = Color(0.949, 0.929, 0.878, 1)

@onready var _detail_label: Label = %EquipmentDetailLabel

var _first_button: Button = null


func _ready() -> void:
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	_first_button = null

	var character_names: = PartyLoadouts.get_managed_character_names()
	if character_names.is_empty():
		_add_label("Nessun equipaggiamento o abilità disponibile.", LOCKED_COLOR)
		_detail_label.text = ""
		return

	for character_name in character_names:
		_build_character_section(character_name)

	if _first_button:
		_first_button.grab_focus()


func _build_character_section(character_name: String) -> void:
	_add_label(character_name, AVAILABLE_COLOR)

	var loadout: = PartyLoadouts.get_loadout(character_name)

	for item in PartyLoadouts.get_all_items():
		var is_equipped: bool = loadout.equipped_items.get(item.slot) == item
		var button: = _add_row(
			"%s%s" % [item.display_name, "  (equipaggiato)" if is_equipped else ""],
			"Disequipaggia" if is_equipped else "Equipaggia",
			UNLOCKED_COLOR if is_equipped else AVAILABLE_COLOR,
			"%s — %s" % [item.display_name, item.get_effective_description()]
		)
		if is_equipped:
			button.pressed.connect(_on_unequip_pressed.bind(character_name, item.slot))
		else:
			button.pressed.connect(_on_equip_pressed.bind(character_name, item))

	var skill_tree: = PartyLoadouts.get_skill_tree(character_name)
	if not skill_tree:
		return

	for skill in skill_tree.nodes:
		var is_unlocked: bool = loadout.unlocked_skill_ids.has(skill.id)
		var can_unlock: = skill_tree.can_unlock(skill.id, loadout.unlocked_skill_ids)

		var status_text: String
		var color: Color
		if is_unlocked:
			status_text = "Sbloccata"
			color = UNLOCKED_COLOR
		elif can_unlock:
			status_text = "Sblocca (costo %d)" % skill.cost
			color = AVAILABLE_COLOR
		else:
			status_text = "Richiede: %s" % _prerequisite_names(skill, skill_tree)
			color = LOCKED_COLOR

		var button: = _add_row(
			"%s — %s" % [skill.display_name, skill.description],
			status_text, color,
			"%s — %s" % [skill.display_name, skill.description]
		)
		button.disabled = is_unlocked or not can_unlock
		if not is_unlocked and can_unlock:
			button.pressed.connect(_on_unlock_pressed.bind(character_name, skill.id))


func _prerequisite_names(skill: SkillTreeNode, skill_tree: SkillTree) -> String:
	var names: PackedStringArray = []
	for prereq_id in skill.prerequisites:
		var prereq_node: = skill_tree.get_node_by_id(prereq_id)
		names.append(prereq_node.display_name if prereq_node else String(prereq_id))
	return ", ".join(names)


func _on_equip_pressed(character_name: String, item: EquipmentItem) -> void:
	PartyLoadouts.equip(character_name, item)
	refresh()


func _on_unequip_pressed(character_name: String, slot: StringName) -> void:
	PartyLoadouts.unequip(character_name, slot)
	refresh()


func _on_unlock_pressed(character_name: String, skill_id: StringName) -> void:
	PartyLoadouts.unlock_skill(character_name, skill_id)
	refresh()


func _add_label(text: String, color: Color) -> void:
	var label: = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)


func _add_row(text: String, button_text: String, color: Color, detail_text: String) -> Button:
	var row: = HBoxContainer.new()
	add_child(row)

	var label: = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)

	var button: = Button.new()
	button.text = button_text
	button.add_theme_font_size_override("font_size", 22)
	button.focus_entered.connect(_show_detail.bind(detail_text))
	row.add_child(button)

	if not _first_button:
		_first_button = button

	return button


func _show_detail(detail_text: String) -> void:
	_detail_label.text = detail_text
