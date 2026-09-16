## Environmental hazard categories a [GameboardLayer] tile can carry, via the same custom-data-layer
## mechanism [GameboardLayer] already uses for [constant GameboardLayer.BLOCKED_CELL_DATA_LAYER].
##
## A tile opts into a hazard by giving its TileSet a "HazardType" custom data layer (String) with
## one of the values below. Tiles/TileSets that don't define the layer are simply [constant NONE] —
## exactly how blocked-cell detection already degrades gracefully today.
class_name HazardTypes extends RefCounted

enum Type {NONE, WATER, LAVA, ELECTRIFIED}

const CUSTOM_DATA_LAYER: = "HazardType"

const _NAME_TO_TYPE: = {
	"water": Type.WATER,
	"lava": Type.LAVA,
	"electrified": Type.ELECTRIFIED,
}


static func from_custom_data(value: Variant) -> Type:
	if value is String and _NAME_TO_TYPE.has(value):
		return _NAME_TO_TYPE[value]
	return Type.NONE
