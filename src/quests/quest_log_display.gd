## Lists every registered quest's title and progress, split into active and completed. Rebuilds
## itself whenever [QuestLog] reports a change, and once up front when the page first shows.
class_name QuestLogDisplay extends VBoxContainer

const ACTIVE_COLOR: = Color(0.949, 0.929, 0.878, 1)
const COMPLETE_COLOR: = Color(0.6, 0.85, 0.6, 1)
const EMPTY_COLOR: = Color(0.7, 0.65, 0.55, 1)


func _ready() -> void:
	QuestLog.quest_completed.connect(_on_quest_changed)
	QuestLog.quest_progressed.connect(_on_quest_changed)
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()

	var active: Array[QuestDefinition] = QuestLog.get_active_quests()
	var completed: Array[QuestDefinition] = QuestLog.get_completed_quests()

	if active.is_empty() and completed.is_empty():
		_add_row("Nessuna missione attiva.", EMPTY_COLOR)
		return

	for quest in active:
		_add_row("%s (%s)" % [quest.title, quest.get_progress_text()], ACTIVE_COLOR)

	for quest in completed:
		_add_row("%s — Completata" % quest.title, COMPLETE_COLOR)


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()


func _add_row(text: String, color: Color) -> void:
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", color)
	add_child(label)
