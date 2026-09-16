## One node in a [MapGraph]: either a fixed, hand-authored anchor (a town, a boss room, a story
## beat) or a region that a generator is free to fill in. Both kinds expose the same
## [member sockets] contract so the graph doesn't need to care which one it's looking at.
class_name MapNode extends Resource

enum Kind { HANDCRAFTED, GENERATED }

@export var id: StringName = &""
@export var kind: Kind = Kind.GENERATED

## Only meaningful when [member kind] is HANDCRAFTED: the fixed scene this node instantiates.
@export var anchor_scene: PackedScene

## Only meaningful when [member kind] is GENERATED: parameters handed to whichever generator runs
## for this node (region size, seed offset, biome tag, etc). Left as a generic Dictionary rather
## than a rigid schema since different generators (BSP rooms, cave automata, noise terrain) need
## different parameters.
@export var generation_params: Dictionary = {}

@export var sockets: Array[MapSocket] = []

## Grid position of this node within the world graph (not pixels/cells — one graph unit per node,
## used only for adjacency/layout bookkeeping in [MapGraph]).
@export var graph_position: Vector2i = Vector2i.ZERO
