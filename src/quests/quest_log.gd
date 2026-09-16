## Autoloaded as "QuestLog". Tracks which registered [QuestDefinition]s are complete, re-checking
## every time a Dialogic timeline ends — quest-relevant variables are only ever changed by
## [code]set {Var} = ...[/code] commands inside timelines, so that's the one moment worth
## re-evaluating from, rather than polling every frame or threading a manual refresh call through
## every interaction script that touches a quest variable.
extends Node

signal quest_completed(quest_id: StringName)
signal quest_progressed(quest_id: StringName)

var _quests: Dictionary = {} # StringName -> QuestDefinition
var _was_complete: Dictionary = {} # StringName -> bool, last known completion state
var _last_progress_text: Dictionary = {} # StringName -> String, last known "met/total" snapshot

# Default demo content: the game's one existing quest (Fan of Four), re-expressed through this
# system on top of the same Dialogic variables fan_interaction.gd already reads and writes.
const _DEFAULT_QUESTS: = [
	preload("res://overworld/maps/town/fan_of_four_quest.tres"),
]


func _ready() -> void:
	for quest in _DEFAULT_QUESTS:
		register_quest(quest)

	Dialogic.timeline_ended.connect(refresh_all)


func register_quest(quest: QuestDefinition) -> void:
	_quests[quest.id] = quest
	_was_complete[quest.id] = quest.is_complete()
	_last_progress_text[quest.id] = quest.get_progress_text()


func get_quest(quest_id: StringName) -> QuestDefinition:
	return _quests.get(quest_id)


func get_active_quests() -> Array[QuestDefinition]:
	var active: Array[QuestDefinition] = []
	for quest_id in _quests:
		var quest: QuestDefinition = _quests[quest_id]
		if quest.is_started() and not quest.is_complete():
			active.append(quest)
	return active


func get_completed_quests() -> Array[QuestDefinition]:
	var completed: Array[QuestDefinition] = []
	for quest_id in _quests:
		var quest: QuestDefinition = _quests[quest_id]
		if quest.is_complete():
			completed.append(quest)
	return completed


func is_quest_complete(quest_id: StringName) -> bool:
	var quest: QuestDefinition = _quests.get(quest_id)
	return quest != null and quest.is_complete()


## Re-evaluates every registered quest and emits quest_progressed/quest_completed for any whose
## state changed since the last check.
func refresh_all() -> void:
	for quest_id in _quests:
		var quest: QuestDefinition = _quests[quest_id]
		var complete_now: = quest.is_complete()

		if complete_now and not _was_complete.get(quest_id, false):
			_was_complete[quest_id] = true
			quest_completed.emit(quest_id)
			continue

		# Not complete: only emit quest_progressed if the met/total objective count actually
		# moved since last check. Comparing against the boolean above alone can't tell "still not
		# complete" apart from "just made progress but still not complete" — this can.
		var progress_now: = quest.get_progress_text()
		if progress_now != _last_progress_text.get(quest_id, ""):
			_last_progress_text[quest_id] = progress_now
			quest_progressed.emit(quest_id)
