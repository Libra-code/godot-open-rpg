## The world as a graph of [MapNode]s. Purely topological — it knows which nodes connect to which,
## not pixel positions or actual tile data (that's [BSPDungeonGenerator]'s/a future noise
## generator's job per generated node). [QuestPlacementValidator]-style consumers use this to ask
## "is this node actually reachable" before trusting it with anything important.
class_name MapGraph extends RefCounted

var _nodes: Dictionary = {} # StringName -> MapNode
var _edges: Dictionary = {} # StringName -> Array[StringName], adjacency list (undirected)


func add_node(node: MapNode) -> void:
	_nodes[node.id] = node
	if not _edges.has(node.id):
		_edges[node.id] = []


func connect_nodes(a_id: StringName, b_id: StringName) -> void:
	assert(_nodes.has(a_id) and _nodes.has(b_id), "Both nodes must be added before connecting them.")
	if not _edges[a_id].has(b_id):
		_edges[a_id].append(b_id)
	if not _edges[b_id].has(a_id):
		_edges[b_id].append(a_id)


func get_node_by_id(node_id: StringName) -> MapNode:
	return _nodes.get(node_id)


func get_neighbors(node_id: StringName) -> Array[StringName]:
	var neighbors: Array[StringName] = []
	neighbors.assign(_edges.get(node_id, []))
	return neighbors


func find_nodes_with_tag(tag: StringName) -> Array[MapNode]:
	var matches: Array[MapNode] = []
	for node_id in _nodes:
		var node: MapNode = _nodes[node_id]
		if node.generation_params.get("tag") == tag:
			matches.append(node)
	return matches


## Breadth-first reachability from [param spawn_id]. Mirrors [ConnectivityValidator] but at the
## graph level (node-to-node) rather than the cell level (inside a single generated region).
func is_reachable_from(spawn_id: StringName, target_id: StringName) -> bool:
	if not _nodes.has(spawn_id) or not _nodes.has(target_id):
		return false
	if spawn_id == target_id:
		return true

	var visited: Dictionary = {spawn_id: true}
	var frontier: Array[StringName] = [spawn_id]

	while not frontier.is_empty():
		var current: StringName = frontier.pop_back()
		for neighbor in get_neighbors(current):
			if neighbor == target_id:
				return true
			if not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)

	return false


func get_all_node_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_nodes.keys())
	return ids
