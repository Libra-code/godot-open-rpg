## A connection point on the edge of a [MapNode] where a corridor may enter or leave. This is the
## contract between handcrafted and generated content: a generator never chooses where an anchor's
## entrances are, it only generates *towards* the sockets an anchor already declares.
class_name MapSocket extends Resource

## Which side of the node's bounds this socket sits on.
@export var direction: Vector2i = Vector2i.RIGHT
## Where along that side, in local cell coordinates relative to the node's own origin.
@export var local_position: Vector2i = Vector2i.ZERO
## How many cells wide the corridor connecting here may be.
@export var width: int = 1
