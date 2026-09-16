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
	preload("res://overworld/maps/town/soul_awakening_quest.tres"),
]


func _ready() -> void:
	for quest in _DEFAULT_QUESTS:
		register_quest(quest)

	_register_db_quests()

	Dialogic.timeline_ended.connect(refresh_all)


func register_quest(quest: QuestDefinition) -> void:
	_quests[quest.id] = quest
	_was_complete[quest.id] = quest.is_complete()
	_last_progress_text[quest.id] = quest.get_progress_text()


# Loads quests from ItemDatabase (see database/schema_enemies_quests.sql) whose objectives are
# all expressible with the existing Dialogic-variable-based QuestObjective (objective type
# "flag"). Other objective types (e.g. "defeat", "assimilate") don't have a tracked variable
# behind them yet — a quest using one is skipped with a warning rather than silently registering
# something that could never actually complete. Also skips any DB quest whose title matches an
# already-registered one, since e.g. "Il Nucleo Dormiente" exists both as DB metadata and as the
# hand-authored soul_awakening_quest.tres with real narrative hooks — the latter wins.
func _register_db_quests() -> void:
	var existing_titles: Dictionary = {}
	for quest_id in _quests:
		existing_titles[(_quests[quest_id] as QuestDefinition).title] = true

	for row: Dictionary in ItemDatabase.get_quests_by_filter({}):
		if existing_titles.has(row.title):
			continue

		var quest: = _quest_from_db_row(row)
		if quest:
			register_quest(quest)


func _quest_from_db_row(row: Dictionary) -> QuestDefinition:
	var objectives: Array[QuestObjective] = []

	for raw: Dictionary in row.get("objectives", []):
		if raw.get("type") != "flag":
			push_warning(
				"QuestLog: skipping DB quest '%s' — objective type '%s' has no tracked variable yet." %
				[row.quest_id, raw.get("type")]
			)
			return null

		var objective: = QuestObjective.new()
		objective.dialogic_variable = raw.get("target_tag", "")
		objective.description = "%s: %s" % [row.title, objective.dialogic_variable]
		objective.required_value = raw.get("amount", 1)
		objectives.append(objective)

	var quest: = QuestDefinition.new()
	quest.id = StringName(row.quest_id)
	quest.title = row.title
	quest.objectives = objectives
	return quest


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
