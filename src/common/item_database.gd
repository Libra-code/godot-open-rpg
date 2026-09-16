## Canonical source of item, enemy, and quest definitions, backed by SQLite (see
## `database/schema.sql` + `database/seed_items.sql` for items/loot, and
## `database/schema_enemies_quests.sql` for enemies/quests — all compiled into the single
## `res://database/items.db`).
##
## Fixed, frequently-queried properties are real SQL columns (id/enemy_id/quest_id, display_name,
## item_type, rarity, nucleus_rank, category, ...). Everything else — stat modifiers, essence tags,
## shader params, quest objectives/rewards, or anything that doesn't correspond to a system column
## yet — lives in a JSON column (stats_json / soul_data_json / quest_data_json) and gets merged
## back into a flat Dictionary on read (see [method _resolve_row]).
##
## Requires the "godot-sqlite" GDExtension (addons/godot-sqlite/), confirmed installed and tested
## against the real ClassDB API (SQLite.new(), .path, .read_only, .open_db()/.close_db(),
## .query_with_bindings(), .query_result, .error_message) — every method below has been run
## against the actual res://database/items.db file, not just written against documentation.
##
## Autoloaded as "ItemDatabase".
extends Node

const DB_PATH: = "res://database/items.db"

## Columns [method get_items_by_filter] is allowed to filter on. Whitelisted rather than trusting
## caller-provided column names directly, since SQL identifiers (unlike values) can't be passed
## through parameterized bindings.
const FILTERABLE_COLUMNS: = ["item_type", "slot", "rarity", "stackable"]

## Columns [method get_enemies_by_filter] is allowed to filter on. See [constant FILTERABLE_COLUMNS].
const ENEMY_FILTERABLE_COLUMNS: = ["nucleus_rank", "ai_type", "loot_table_id"]

## Columns [method get_quests_by_filter] is allowed to filter on. See [constant FILTERABLE_COLUMNS].
const QUEST_FILTERABLE_COLUMNS: = ["category", "prereq_quest_id", "min_nucleus_rank"]

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
	return _get_row_by_id("items", "id", item_id, "stats_json")


## Returns every item whose system columns match [param filters], e.g.
## [code]{"item_type": "equipment", "rarity": "rare"}[/code]. Keys not in
## [constant FILTERABLE_COLUMNS] are ignored (with a warning) rather than silently building a
## query around an arbitrary, caller-supplied column name.
func get_items_by_filter(filters: Dictionary) -> Array[Dictionary]:
	return _get_rows_by_filter("items", filters, FILTERABLE_COLUMNS, "stats_json")


## Returns the full enemy definition for [param enemy_id] (see
## database/schema_enemies_quests.sql) — system columns plus whatever soul_data_json holds
## (essence tags, shader params, aspect affinity, attack triggers), merged together.
func get_enemy(enemy_id: String) -> Dictionary:
	return _get_row_by_id("enemies", "enemy_id", enemy_id, "soul_data_json")


## Returns every enemy whose system columns match [param filters], e.g.
## [code]{"nucleus_rank": "Asceso"}[/code]. See [constant ENEMY_FILTERABLE_COLUMNS].
func get_enemies_by_filter(filters: Dictionary) -> Array[Dictionary]:
	return _get_rows_by_filter("enemies", filters, ENEMY_FILTERABLE_COLUMNS, "soul_data_json")


## Returns the full quest definition for [param quest_id] — system columns plus whatever
## quest_data_json holds (description, objectives, rewards, dialogue hooks), merged together.
func get_quest(quest_id: String) -> Dictionary:
	return _get_row_by_id("quests", "quest_id", quest_id, "quest_data_json")


## Returns every quest whose system columns match [param filters], e.g.
## [code]{"category": "Main"}[/code]. See [constant QUEST_FILTERABLE_COLUMNS].
func get_quests_by_filter(filters: Dictionary) -> Array[Dictionary]:
	return _get_rows_by_filter("quests", filters, QUEST_FILTERABLE_COLUMNS, "quest_data_json")


# Shared by get_item/get_enemy/get_quest: fetch one row by its primary key and merge its JSON
# column. [param id_column] is a fixed, hardcoded literal at every call site above (never
# caller-supplied), so interpolating it directly into the SQL text is safe.
func _get_row_by_id(table: String, id_column: String, id_value: String, json_column: String) -> Dictionary:
	var sql: = "SELECT * FROM %s WHERE %s = ?;" % [table, id_column]
	if not _db.query_with_bindings(sql, [id_value]):
		push_error("ItemDatabase: query failed on %s.%s = '%s': %s" %
			[table, id_column, id_value, _db.error_message])
		return {}

	var rows: Array = _db.query_result
	if rows.is_empty():
		return {}

	return _resolve_row(rows[0], json_column)


# Shared by get_items_by_filter/get_enemies_by_filter/get_quests_by_filter. [param table] and
# [param allowed_columns] are fixed, hardcoded literals at every call site above; only the
# Dictionary *keys* in [param filters] are ever caller-supplied, and those are checked against
# [param allowed_columns] before being used as SQL identifiers.
func _get_rows_by_filter(
	table: String, filters: Dictionary, allowed_columns: Array, json_column: String
) -> Array[Dictionary]:
	var clauses: Array[String] = []
	var bindings: Array = []

	for column: String in filters:
		if column not in allowed_columns:
			push_warning("ItemDatabase: ignoring non-filterable column '%s' on '%s'." % [column, table])
			continue
		clauses.append("%s = ?" % column)
		bindings.append(filters[column])

	var sql: = "SELECT * FROM %s" % table
	if not clauses.is_empty():
		sql += " WHERE " + " AND ".join(clauses)
	sql += ";"

	if not _db.query_with_bindings(sql, bindings):
		push_error("ItemDatabase: filtered query failed on '%s': %s" % [table, _db.error_message])
		return []

	var results: Array[Dictionary] = []
	for row: Dictionary in _db.query_result:
		results.append(_resolve_row(row, json_column))
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


# Merges a raw SQL row's fixed columns with its parsed [param json_column] blob into one flat
# Dictionary. System columns win on key collision, since the JSON column is only meant for data
# that ISN'T already a column — a colliding key there would mean the schema and the blob disagree.
func _resolve_row(row: Dictionary, json_column: String) -> Dictionary:
	var item: = row.duplicate()

	var raw_json: String = item.get(json_column, "{}")
	item.erase(json_column)

	var parsed: Variant = JSON.parse_string(raw_json)
	if parsed is Dictionary:
		for key in parsed:
			if not item.has(key):
				item[key] = parsed[key]

	if item.has("stackable"):
		item["stackable"] = bool(item.get("stackable", 0))
	return item
