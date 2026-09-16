## Autoloaded as "LandmarkRegistry". Tracks every [Landmark] in the current scene and, on request
## (see [method refresh_visibility]), works out which ones just came into or went out of view —
## the hook a future compass/audio-cue/subtitle ("You can see the old bridge to the east") system
## would listen to, without the field controller needing to know any of them exist.
extends Node

signal landmark_entered_sight(landmark: Landmark)
signal landmark_exited_sight(landmark: Landmark)

var _landmarks: Array[Landmark] = []
var _was_visible: Dictionary = {} # Landmark -> bool


func register(landmark: Landmark) -> void:
	_landmarks.append(landmark)
	_was_visible[landmark] = false
	landmark.tree_exiting.connect(_on_landmark_tree_exiting.bind(landmark))


func get_landmarks() -> Array[Landmark]:
	return _landmarks.duplicate()


## Re-checks every registered landmark's visibility from [param viewer_position] and emits
## [signal landmark_entered_sight]/[signal landmark_exited_sight] for any that changed since the
## last call. Meant to be called on player arrival at a new cell (a sightline check walks a line of
## cells; it has no need to run every physics frame for something as slow-changing as "what's
## visible while walking").
func refresh_visibility(viewer_position: Vector2) -> void:
	for landmark in _landmarks:
		var now_visible: = landmark.is_visible_from(viewer_position)
		var previously_visible: bool = _was_visible.get(landmark, false)

		if now_visible and not previously_visible:
			landmark_entered_sight.emit(landmark)
		elif not now_visible and previously_visible:
			landmark_exited_sight.emit(landmark)

		_was_visible[landmark] = now_visible


func _on_landmark_tree_exiting(landmark: Landmark) -> void:
	_landmarks.erase(landmark)
	_was_visible.erase(landmark)
