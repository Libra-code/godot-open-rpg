class_name SoulStrainEssence
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var aspect_tags: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var base_compatibility: float = 0.5
@export var soul_fragments: int = 1
@export var rejection_on_low_compatibility: float = 18.0
