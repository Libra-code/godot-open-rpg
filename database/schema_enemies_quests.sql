-- Enemies + Quests schema for res://database/items.db (LitRPG layer: Grado del Nucleo, Tag
-- Essenza, Rigetto dell'Anima — same vocabulary as src/soul_strain/soul_strain_state.gd, so
-- nucleus_rank values below are the exact strings SoulStrainState.CORE_DORMANT/AWAKENED/ASCENDED
-- already use ("Dormiente"/"Risvegliato"/"Asceso"), not a parallel naming scheme).
--
-- Same split as schema.sql: fixed, frequently-queried columns for system properties (rank, ai
-- type, quest category/prerequisite — the things a query needs to filter/join on), everything
-- else (essence tags, shader params, objectives, rewards, dialogue hooks) in a *_data_json column.
--
-- Apply with:
--   sqlite3 database/items.db < database/schema_enemies_quests.sql

CREATE TABLE IF NOT EXISTS enemies (
	enemy_id TEXT PRIMARY KEY,
	name TEXT NOT NULL,
	world_sprite_path TEXT NOT NULL,     -- Pixel Art overworld sprite/animation (res://...)
	combat_sprite_path TEXT NOT NULL,    -- HD combat sprite/animation (res://...)
	nucleus_rank TEXT NOT NULL DEFAULT 'Dormiente'
		CHECK (nucleus_rank IN ('Dormiente', 'Risvegliato', 'Asceso')),
	base_hp INTEGER NOT NULL DEFAULT 100,
	base_mana INTEGER NOT NULL DEFAULT 50,
	base_defense INTEGER NOT NULL DEFAULT 10,
	loot_table_id TEXT,                  -- joins against loot_tables.table_id (see schema.sql)
	ai_type TEXT NOT NULL DEFAULT 'aggressive',
	-- {"essence_tags": ["#tag", ...], "shader_params": {"palette_tint": "#rrggbb", "glow_power": f},
	--  "aspect_affinity": {"<aspect>": f, ...}, "attack_triggers": ["<trigger_id>", ...]}
	soul_data_json TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_enemies_nucleus_rank ON enemies(nucleus_rank);
CREATE INDEX IF NOT EXISTS idx_enemies_loot_table_id ON enemies(loot_table_id);

CREATE TABLE IF NOT EXISTS quests (
	quest_id TEXT PRIMARY KEY,
	title TEXT NOT NULL,
	category TEXT NOT NULL CHECK (category IN ('Main', 'Side', 'Contract_Proc')),
	prereq_quest_id TEXT REFERENCES quests(quest_id),
	min_nucleus_rank TEXT NOT NULL DEFAULT 'Dormiente'
		CHECK (min_nucleus_rank IN ('Dormiente', 'Risvegliato', 'Asceso')),
	-- {"description": "...", "objectives": [{"type": "...", ...}, ...],
	--  "rewards": {"soul_shards": i, "item_id": "..."}, "dialogues": ["<timeline_or_node_id>", ...]}
	quest_data_json TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_quests_category ON quests(category);
CREATE INDEX IF NOT EXISTS idx_quests_prereq_quest_id ON quests(prereq_quest_id);

-- --------------------------------------------------------------------------------------------
-- Seed data
-- --------------------------------------------------------------------------------------------

INSERT INTO enemies (enemy_id, name, world_sprite_path, combat_sprite_path, nucleus_rank, base_hp, base_mana, base_defense, loot_table_id, ai_type, soul_data_json) VALUES
('mon_skeleton_01', 'Scheletro Custode',
	'res://assets/sprites/world/monsters/skeleton.png',
	'res://assets/sprites/combat/monsters/skeleton_hd.png',
	'Dormiente', 80, 20, 12, 'skeleton_basic', 'aggressive',
	'{"essence_tags": ["#non_morto", "#ombra"], "shader_params": {"palette_tint": "#3a0d5c", "glow_power": 1.2}, "aspect_affinity": {"Ombra": 0.6, "Luce": -0.4}, "attack_triggers": ["bone_slash", "guard_break"]}'),
('mon_wisp_02', 'Spirito Errante',
	'res://assets/sprites/world/monsters/wisp.png',
	'res://assets/sprites/combat/monsters/wisp_hd.png',
	'Risvegliato', 60, 90, 6, 'wisp_ethereal', 'caster',
	'{"essence_tags": ["#etereo", "#luce"], "shader_params": {"palette_tint": "#bfe8ff", "glow_power": 2.0}, "aspect_affinity": {"Luce": 0.7, "Ombra": -0.5}, "attack_triggers": ["will_o_wisp", "soul_drain"]}'),
('mon_wraith_03', 'Ombra Ascesa',
	'res://assets/sprites/world/monsters/wraith.png',
	'res://assets/sprites/combat/monsters/wraith_hd.png',
	'Asceso', 220, 140, 24, 'wraith_ascended', 'guardian',
	'{"essence_tags": ["#ombra", "#anima_lacerata"], "shader_params": {"palette_tint": "#1a0022", "glow_power": 2.6}, "aspect_affinity": {"Ombra": 0.9}, "attack_triggers": ["rift_slash", "rejection_wave", "soul_tear"]}');

INSERT INTO quests (quest_id, title, category, prereq_quest_id, min_nucleus_rank, quest_data_json) VALUES
('quest_main_01', 'Il Nucleo Dormiente', 'Main', NULL, 'Dormiente',
	'{"description": "Il Mago ha notato qualcosa che vibra dietro i tuoi occhi. Esamina l''Albero Strano, poi risveglia il tuo Nucleo al piedistallo delle bacchette.", "objectives": [{"type": "flag", "target_tag": "StrangeTreeExamined", "amount": 1}, {"type": "flag", "target_tag": "SoulCoreAwakened", "amount": 1}], "rewards": {"soul_shards": 100}, "dialogues": ["wizard", "strange_tree", "wand_pedestal"]}'),
('quest_side_01', 'Voci tra le Ceneri', 'Side', 'quest_main_01', 'Risvegliato',
	'{"description": "Uno Scheletro Custode nella foresta porta con se un frammento della tua stessa essenza. Sconfiggilo e recuperalo.", "objectives": [{"type": "defeat", "target_enemy_id": "mon_skeleton_01", "amount": 1}], "rewards": {"soul_shards": 60, "item_id": "iron_shell"}, "dialogues": []}'),
('quest_contract_01', 'Contratto: Assimilazione d''Ombra', 'Contract_Proc', 'quest_main_01', 'Risvegliato',
	'{"description": "Contratto procedurale: assimila essenze con il tag #ombra per rafforzare la tua affinita.", "objectives": [{"type": "assimilate", "target_tag": "#ombra", "amount": 3}], "rewards": {"soul_shards": 250, "item_id": "eq_shadow_ring"}, "dialogues": []}'),
-- quest_main_01 above intentionally has the SAME title as the hand-authored quest resource
-- overworld/maps/town/soul_awakening_quest.tres ("Il Nucleo Dormiente") — QuestLog._register_db_quests()
-- skips any DB quest whose title is already registered, so this one is metadata-only (visible via
-- ItemDatabase.get_quest() for e.g. a future quest-giver UI) and never double-registers in-game.
-- quest_side_01/quest_contract_01 use objective types ("defeat"/"assimilate") QuestObjective can't
-- express yet, so QuestLog also skips them rather than registering an uncompletable quest.
-- quest_db_demo_01 uses the "flag" type against an existing, already-tracked, monotonic Dialogic
-- variable (TokenCount only ever increases), so it's the one DB quest that actually shows up live
-- in the Quest Log UI as proof the wiring works end-to-end.
('quest_db_demo_01', 'Prima Traccia', 'Side', NULL, 'Dormiente',
	'{"description": "Ottieni almeno un pegno da uno dei membri della Banda dei Quattro.", "objectives": [{"type": "flag", "target_tag": "TokenCount", "amount": 1}], "rewards": {"soul_shards": 20}, "dialogues": []}');
