## Data describing a temporary combat status effect (poison, stun, a timed buff/debuff, etc.) that
## can be applied to a [Battler] for a limited number of its own rounds.
##
## Stat changes reuse [BattlerStats]' existing modifier/multiplier API (the same one equipment and
## skills use) so they compose correctly and are automatically removed once the effect expires. See
## [method Battler.apply_status_effect] and [method Battler.tick_status_effects].
class_name StatusEffect extends Resource

## Identifies this effect. Applying an effect while one with the same [member id] is already active
## on the target refreshes its duration instead of stacking a second, independent copy.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture

## How many of the affected Battler's own rounds this effect lasts.
@export_range(1, 20) var duration_rounds: int = 3

## If true, the affected Battler cannot act while this effect is active (see [method Battler.act]).
@export var prevents_action: bool = false

## Flat damage applied at the start of each of the affected Battler's rounds (e.g. poison). A
## negative value heals instead (e.g. regeneration).
@export var damage_per_round: int = 0

## Flat stat modifiers applied for the duration of the effect, added via
## [method BattlerStats.add_modifier] and keyed by stat name (see
## [constant BattlerStats.MODIFIABLE_STATS]), e.g. {"attack": 8}.
@export var stat_modifiers: Dictionary = {}

## Multiplicative stat modifiers applied for the duration of the effect, added via
## [method BattlerStats.add_multiplier] and keyed by stat name, e.g. {"speed": -0.5} for a 50% slow.
@export var stat_multipliers: Dictionary = {}
