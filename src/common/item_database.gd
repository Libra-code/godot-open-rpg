## Canonical source of item definitions and loot tables, backed by SQLite (see
## `database/schema.sql` / `database/seed_items.sql`, compiled into `res://database/items.db`).
##
## Fixed, frequently-queried properties (id, display_name, item_type, slot, rarity, icon/model
## paths, stacking) are real SQL columns. Everything else — stat modifiers, per-item flags, or
## anything that doesn't correspond to a system column yet — lives in the stats_json column and
## gets merged back into a flat Dictionary on read (see [method _resolve_row]).
##
## [b]Requires the "godot-sqlite" GDExtension[/b] (https://github.com/2shady4u/godot-sqlite),
## which is NOT bundled with this project — install it via the AssetLib tab in the Godot editor
## (search "SQLite") or from the project's GitHub releases before registering this script as an
## autoload. This file was written against that addon's documented API (SQLite.new(), .path,
## .read_only, .open_db()/.close_db(), .query_with_bindings(), .query_result, .error_message) but
## could not be run in this environment (the addon isn't installed here) — verify against
## whichever version you install, since minor GDExtension API differences do happen across
## releases.
##
## Autoload this as "ItemDatabase" once the addon is installed.
extends Node

const DB_PATH: = "res://database/items.db"

## Columns [method get_items_by_filter] is allowed to filter on. Whitelisted rather than trusting
## caller-provided column names directly, since SQL identifiers (unlike values) can't be passed
## through parameterized bindings.
const FILTERABLE_COLUMNS: = ["item_type", "slot", "rarity", "stackable"]

var _db: SQLite = null


func _ready() -> void:
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.read_only = true
	if not _db.open_db():
		push_error("ItemDatabase: failed to open '%s'." % DB_PATH)


func _exit_tree() -> void:
	if _db:
		_db.close_db()


## Returns the full item definition for [param item_id] as a flat Dictionary — system columns
## plus whatever was stored in stats_json, merged together. Returns an empty Dictionary if the
## item doesn't exist or the query fails.
func get_item(item_id: String) -> Dictionary:
	if not _db.query_with_bindings("SELECT * FROM items WHERE id = ?;", [item_id]):
		push_error("ItemDatabase: query failed for item '%s': %s" % [item_id, _db.error_message])
		return {}

	var rows: Array = _db.query_result
	if rows.is_empty():
		return {}

	return _resolve_row(rows[0])


## Returns every item whose system columns match [param filters], e.g.
## [code]{"item_type": "equipment", "rarity": "rare"}[/code]. Keys not in
## [constant FILTERABLE_COLUMNS] are ignored (with a warning) rather than silently building a
## query around an arbitrary, caller-supplied column name.
func get_items_by_filter(filters: Dictionary) -> Array[Dictionary]:
	var clauses: Array[String] = []
	var bindings: Array = []

	for column: String in filters:
		if column not in FILTERABLE_COLUMNS:
			push_warning("ItemDatabase: ignoring non-filterable column '%s'." % column)
			continue
		clauses.append("%s = ?" % column)
		bindings.append(filters[column])

	var sql: = "SELECT * FROM items"
	if not clauses.is_empty():
		sql += " WHERE " + " AND ".join(clauses)
	sql += ";"

	if not _db.query_with_bindings(sql, bindings):
		push_error("ItemDatabase: filtered query failed: %s" % _db.error_message)
		return []

	var results: Array[Dictionary] = []
	for row: Dictionary in _db.query_result:
		results.append(_resolve_row(row))
	return results


## Rolls [param table_id] [param rolls] times and returns one entry per successful roll:
## [code]{"item_id": String, "quantity": int}[/code]. The weighted pick itself runs entirely in
## SQL — a running-weight window function plus a single modulo-weighted RANDOM() pick — so a loot
## table with thousands of rows is never pulled into GDScript just to choose one of them.
func roll_loot_table(table_id: String, rolls: int = 1) -> Array[Dictionary]:
	const ROLL_QUERY: = """
		WITH weighted AS (
			SELECT
				item_id, weight, min_quantity, max_quantity,
				SUM(weight) OVER (ORDER BY rowid) AS running_weight,
				SUM(weight) OVER () AS total_weight
			FROM loot_tables
			WHERE table_id = ?
		)
		SELECT item_id, min_quantity, max_quantity
		FROM weighted
		WHERE running_weight >= (ABS(RANDOM()) % total_weight) + 1
		ORDER BY running_weight ASC
		LIMIT 1;
	"""

	var drops: Array[Dictionary] = []
	for i in rolls:
		if not _db.query_with_bindings(ROLL_QUERY, [table_id]):
			push_error("ItemDatabase: loot roll failed for '%s': %s" % [table_id, _db.error_message])
			continue

		var rows: Array = _db.query_result
		if rows.is_empty():
			continue

		var row: Dictionary = rows[0]
		var quantity: = randi_range(int(row.min_quantity), int(row.max_quantity))
		drops.append({"item_id": row.item_id, "quantity": quantity})

	return drops


# Merges a raw SQL row's fixed columns with its parsed stats_json blob into one flat Dictionary.
# System columns win on key collision, since stats_json is only meant for data that ISN'T already
# a column — a colliding key there would mean the schema and the JSON blob disagree.
func _resolve_row(row: Dictionary) -> Dictionary:
	var item: = row.duplicate()

	var raw_stats: String = item.get("stats_json", "{}")
	item.erase("stats_json")

	var parsed: Variant = JSON.parse_string(raw_stats)
	if parsed is Dictionary:
		for key in parsed:
			if not item.has(key):
				item[key] = parsed[key]

	item["stackable"] = bool(item.get("stackable", 0))
	return item
