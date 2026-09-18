-- ItemDatabase schema for OpenJRPG (res://database/items.db).
--
-- Fixed "system" properties (the ones the game actually queries/filters on today, plus rarity
-- for future loot tuning) are real columns. Everything else — stat modifiers, per-item flags,
-- anything that doesn't exist as a system concept yet — lives in stats_json and gets merged back
-- into the item Dictionary at read time by ItemDatabase (src/common/item_database.gd).
--
-- Rebuild the .db from this file + seed_items.sql with:
--   sqlite3 database/items.db < database/schema.sql
--   sqlite3 database/items.db < database/seed_items.sql

CREATE TABLE IF NOT EXISTS items (
	id TEXT PRIMARY KEY,
	display_name TEXT NOT NULL,
	item_type TEXT NOT NULL,       -- 'equipment' | 'consumable' | 'key_item' | 'currency' | 'material'
	slot TEXT,                     -- equipment slot ('weapon' | 'armor' | 'trinket'); NULL otherwise
	rarity TEXT NOT NULL DEFAULT 'common',
	icon_path TEXT,                -- res:// path; loaded lazily by the caller via ResourceLoader
	model_path TEXT,               -- res:// path; loaded lazily by the caller via ResourceLoader
	stackable INTEGER NOT NULL DEFAULT 1,
	max_stack INTEGER NOT NULL DEFAULT 99,
	value INTEGER NOT NULL DEFAULT 0, -- shop price in Coins; 0 means "not normally bought or sold"
	stats_json TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_items_item_type ON items(item_type);
CREATE INDEX IF NOT EXISTS idx_items_rarity ON items(rarity);
CREATE INDEX IF NOT EXISTS idx_items_slot ON items(slot);

CREATE TABLE IF NOT EXISTS loot_tables (
	table_id TEXT NOT NULL,
	item_id TEXT NOT NULL REFERENCES items(id),
	weight INTEGER NOT NULL,
	min_quantity INTEGER NOT NULL DEFAULT 1,
	max_quantity INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_loot_tables_table_id ON loot_tables(table_id);
