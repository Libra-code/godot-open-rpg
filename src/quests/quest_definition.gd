## A trackable quest. Objectives are informational progress markers checked against Dialogic
## variables; [member completion_objective] is the authoritative "done" condition, since a quest's
## actual reward/turn-in logic often lives in one specific dialogue branch rather than being
## implied by all objectives being met at once (see the Fan of Four quest: collecting all four
## tokens doesn't complete it by itself — turning them in to the fan does).
class_name QuestDefinition extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var objectives: Array[QuestObjective] = []
@export var completion_objective: QuestObjective = null


func is_complete() -> bool:
	if completion_objective:
		return completion_objective.is_met()

	for objective in objectives:
		if not objective.is_met():
			return false
	return true


func is_started() -> bool:
	if is_complete():
		return true

	for objective in objectives:
		if objective.is_met():
			return true
	return false


func get_progress_text() -> String:
	var met_count: = 0
	for objective in objectives:
		if objective.is_met():
			met_count += 1
	return "%d/%d" % [met_count, objectives.size()]
