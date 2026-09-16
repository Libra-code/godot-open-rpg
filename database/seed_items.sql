-- Starter data for res://database/items.db.
--
-- claw_gauntlets and lucky_tail mirror the two EquipmentItem .tres resources that already exist
-- in combat/battlers/{bear,squirrel}/ — their StatModifierEffect data is reproduced here inside
-- stats_json.modifiers so a read from ItemDatabase reconstructs the same shape PartyLoadouts
-- already expects. The rest (iron_shell, healing_berry, bugcat_fang) are new demonstrative
-- content, including one real loot table for the existing "bugcat" enemy — the game currently has
-- no drop table at all (see FUNZIONALITA.md gap list).

INSERT INTO items (id, display_name, item_type, slot, rarity, icon_path, model_path, stackable, max_stack, stats_json) VALUES
('claw_gauntlets', 'Artigli d''Acciaio', 'equipment', 'weapon', 'common', NULL, NULL, 0, 1,
	'{"modifiers": [{"stat_name": "attack", "is_multiplier": false, "amount": 3.0}]}'),
('lucky_tail', 'Codino Fortunato', 'equipment', 'trinket', 'uncommon', NULL, NULL, 0, 1,
	'{"modifiers": [{"stat_name": "speed", "is_multiplier": false, "amount": 8.0}]}'),
('iron_shell', 'Corazza di Ferro', 'equipment', 'armor', 'common', NULL, NULL, 0, 1,
	'{"modifiers": [{"stat_name": "defense", "is_multiplier": false, "amount": 6.0}]}'),
('healing_berry', 'Bacca Curativa', 'consumable', NULL, 'common', 'res://assets/items/coin.atlastex', NULL, 1, 99,
	'{"heal_amount": 25}'),
('bugcat_fang', 'Zanna di Bugcat', 'material', NULL, 'common', NULL, NULL, 1, 99, '{}');

INSERT INTO loot_tables (table_id, item_id, weight, min_quantity, max_quantity) VALUES
('bugcat', 'bugcat_fang', 70, 1, 2),
('bugcat', 'healing_berry', 25, 1, 1),
('bugcat', 'lucky_tail', 5, 1, 1);
