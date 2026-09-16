## Resolves what happens when a gamepiece stands on an environmental hazard tile (see
## [HazardTypes]). Stateless by design: called on arrival, reads the board, applies an effect.
class_name HazardResolver extends RefCounted

const LAVA_DAMAGE: = 8
const ELECTRIFIED_REJECTION: = 6.0


## Called once a gamepiece finishes moving onto a new cell. Only gamepieces with a Soul Strain
## presence (currently just the player) take an effect; other gamepieces simply see [constant
## HazardTypes.Type.NONE] handled as a no-op.
static func resolve_field_hazard(gamepiece: Gamepiece) -> void:
	var cell: = Gameboard.get_cell_under_node(gamepiece)
	var hazard: = Gameboard.get_hazard_type(cell)
	if hazard == HazardTypes.Type.NONE:
		return

	var soul_strain: Node = gamepiece.get_tree().get_first_node_in_group(&"soul_strain_engine")
	if not soul_strain:
		return

	match hazard:
		HazardTypes.Type.LAVA:
			soul_strain.apply_damage(LAVA_DAMAGE)
		HazardTypes.Type.ELECTRIFIED:
			soul_strain.add_rejection(ELECTRIFIED_REJECTION)
		HazardTypes.Type.WATER:
			pass # No inherent effect; queryable by combat/actions via get_elemental_interaction().


## Pure lookup with no side effects, so combat code (or anything else) can check "would this
## element do something special on this hazard?" without needing a gamepiece or the field at all.
## Returns an empty string if the combination has no special interaction.
##
## The pairings below are illustrative placeholders using the project's actual [Elements.Types]
## (BUG/BREAK/SEEK, not a classical fire/water/lightning set) — swap them for whatever combinations
## the actual hazard/element design calls for once real hazard tiles and actions exist.
static func get_elemental_interaction(hazard: HazardTypes.Type, element: Elements.Types) -> String:
	if hazard == HazardTypes.Type.WATER and element == Elements.Types.BUG:
		return "chain_damage_connected_water"
	if hazard == HazardTypes.Type.LAVA and element == Elements.Types.BREAK:
		return "extinguish_and_expose"
	return ""
