## Lists every registered quest's title and progress, split into active and completed. Rebuilds
## itself whenever [QuestLog] reports a change, and once up front when the page first shows.
##
## Also drives the quest detail panel ([code]%QuestDetailTitleLabel[/code]/
## [code]%QuestDetailBodyLabel[/code] in character_menu.tscn): [kbd]Up[/kbd]/[kbd]Down[/kbd] move a
## selection highlight across the listed quests, and the panel always shows the selected quest's
## full objective breakdown.
class_name QuestLogDisplay extends VBoxContainer

const ACTIVE_COLOR: = Color(0.949, 0.929, 0.878, 1)
const COMPLETE_COLOR: = Color(0.6, 0.85, 0.6, 1)
const EMPTY_COLOR: = Color(0.7, 0.65, 0.55, 1)
const SELECTED_COLOR: = Color(1.0, 0.85, 0.4, 1)

# Parallel arrays: one entry per quest row currently shown (excludes the "no quests" placeholder).
var _quests: Array[QuestDefinition] = []
var _row_labels: Array[Label] = []
var _row_texts: Array[String] = []
var _row_colors: Array[Color] = []
var _selected_index: = -1

@onready var _detail_title_label: Label = %QuestDetailTitleLabel
@onready var _detail_body_label: Label = %QuestDetailBodyLabel


func _ready() -> void:
	QuestLog.quest_completed.connect(_on_quest_changed)
	QuestLog.quest_progressed.connect(_on_quest_changed)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _quests.is_empty():
		return

	if event.is_action_pressed(&"ui_down"):
		get_viewport().set_input_as_handled()
		_selected_index = (_selected_index + 1) % _quests.size()
		_update_selection()
	elif event.is_action_pressed(&"ui_up"):
		get_viewport().set_input_as_handled()
		_selected_index = (_selected_index - 1 + _quests.size()) % _quests.size()
		_update_selection()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	_quests.clear()
	_row_labels.clear()
	_row_texts.clear()
	_row_colors.clear()

	var active: Array[QuestDefinition] = QuestLog.get_active_quests()
	var completed: Array[QuestDefinition] = QuestLog.get_completed_quests()

	if active.is_empty() and completed.is_empty():
		_add_row("Nessuna missione attiva.", EMPTY_COLOR)
		_update_selection()
		return

	for quest in active:
		_add_row("%s (%s)" % [quest.title, quest.get_progress_text()], ACTIVE_COLOR)
		_quests.append(quest)

	for quest in completed:
		_add_row("%s — Completata" % quest.title, COMPLETE_COLOR)
		_quests.append(quest)

	_update_selection()


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()


func _add_row(text: String, color: Color) -> void:
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)

	_row_labels.append(label)
	_row_texts.append(text)
	_row_colors.append(color)


## Clamps the selection to the current quest list, highlights the selected row, and refreshes the
## detail panel to match. Safe to call any time the quest list may have changed size.
func _update_selection() -> void:
	if _quests.is_empty():
		_selected_index = -1
		_detail_title_label.text = ""
		_detail_body_label.text = "Nessuna missione da mostrare."
		return

	_selected_index = clampi(_selected_index, 0, _quests.size() - 1)

	for i in _row_labels.size():
		var is_selected: = i == _selected_index
		_row_labels[i].text = ("▶ " if is_selected else "  ") + _row_texts[i]
		_row_labels[i].add_theme_color_override(
			"font_color", SELECTED_COLOR if is_selected else _row_colors[i]
		)

	var quest: = _quests[_selected_index]
	_detail_title_label.text = quest.title
	if quest.objectives.is_empty():
		_detail_body_label.text = "%s: %s" % [
			"Completata" if quest.is_complete() else "In corso", quest.get_progress_text()
		]
	else:
		var lines: PackedStringArray = []
		for objective in quest.objectives:
			lines.append("%s %s" % ["✔" if objective.is_met() else "○", objective.description])
		_detail_body_label.text = "\n".join(lines)
