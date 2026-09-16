# Stato del progetto — Funzionalità

Questo documento riassume cosa è realmente presente e funzionante nel gioco oggi, e cosa manca
ancora rispetto a un RPG completo. È pensato come riferimento rapido per chi riprende in mano il
progetto, non come changelog cronologico (per quello vedi `CHANGELOG.md`).

---

## ✅ Funzionalità presenti

### Movimento e mappa
- Movimento a griglia con pathfinding `AStar2D` (`Gameboard` + `Pathfinder`), aggiornato in modo
  incrementale quando il terreno cambia (`GameboardLayer.cells_changed`).
- Blocco/sblocco diretto di una cella senza dover creare un Gamepiece fittizio
  (`Gameboard.set_cell_blocked()`), usato oggi da porte e piedistalli tramite il meccanismo di
  occupazione classico, disponibile per nuovi ostacoli (muri sbloccabili, barriere distruttibili).
- Transizioni tra aree, porte apribili/bloccabili, forzieri, oggetti raccoglibili, enigma dei
  piedistalli (colori delle bacchette).
- **Hazard ambientali**: celle di Lava (danno diretto) ed Elettrificazione (rigetto anima) tramite
  un custom data layer sul TileSet (`HazardType`, stesso meccanismo già usato per le celle
  bloccate). L'acqua è riconosciuta ma non ha ancora un effetto proprio.
- **Landmark**: punti di riferimento (porta di casa, sentiero per il bosco) che sanno calcolare se
  sono visibili dal giocatore lungo la griglia di gioco (non serve fisica, il terreno di questo
  gioco non ne ha). Emette segnali quando un landmark entra/esce dalla vista, ma **nessuna UI li
  usa ancora** (bussola, indicatore, suono).

### Dialoghi, NPC e missioni
- Dialoghi tramite l'addon Dialogic 2, con conversazioni, scelte e variabili persistenti.
- Interazioni sia a contatto (Trigger) sia su tasto/click (Interaction).
- **Motore missioni** (`QuestLog`) che avvolge le variabili Dialogic già usate dai dialoghi
  (es. `TokenQuestStatus`) in un `QuestDefinition` tipato, con obiettivi e stato di completamento.
- **UI Registro Missioni** nel Menu Personaggio (tasto **Q**): elenca missioni attive (con
  progresso) e completate.
- **Storia principale — "Il Nucleo Dormiente"** (prototipo): il Mago, dopo aver dato il suo pegno
  per la "Banda dei Quattro" (ora relegata a siparietto comico, invariata), nota qualcosa di
  strano nell'anima del giocatore e apre una vera missione (`soul_awakening_quest.tres`):
  esaminare l'Albero Strano con occhi nuovi, poi risolvere il rituale del piedistallo delle
  bacchette in casa. Risolvere il rituale per la prima volta **risveglia davvero** il Soul Strain
  Core del giocatore (`Dormiente → Risvegliato`, più slot abilità), gli assegna nome/aspetto/difetto
  per la prima volta ("Gobot", difetto "Vincolo del Dovere" = `oathbound`), e collega quel difetto a
  una conseguenza reale: perdere un combattimento ora danneggia il Soul Strain (12 HP, +12% rigetto
  anima) — prima nessuna delle quattro "flaw" del motore era mai davvero innescata da alcuna azione
  di gioco.

### Combattimento
- Combattimento a turni con `Battler`, azioni, IA nemica, roster giocatore/nemici.
- Statistiche con modificatori/moltiplicatori removibili, disaccoppiati dalla classe principale
  (`BattlerStats.add_modifier/add_multiplier`).
- **Livelli ed esperienza**: vincere un combattimento assegna XP (somma di `xp_reward` dei nemici
  sconfitti); il livello **persiste davvero** tra una battaglia e l'altra (era un bug reale,
  corretto in sessione: prima ogni Battler ripartiva da livello 1 ad ogni scontro).
- **Equipaggiamento e alberi abilità** (`PartyLoadouts`): oggetti e abilità sbloccabili applicano
  modificatori riutilizzando l'API esistente di `BattlerStats`. Contenuto dimostrativo: Baloo parte
  con gli "Artigli d'Acciaio" (+3 attacco) e un albero a 2 nodi con prerequisito; Nutsy parte con il
  "Codino Fortunato" (+8 velocità) e un proprio albero a 2 nodi ("Passo Leggero" +10 elusione →
  "Riflessi Fulminei" +20% velocità), a tema con il suo ruolo di supporto agile.
- **UI Equipaggiamento/Abilità** nel Menu Personaggio (tasto **E**): equipaggia/disequipaggia
  oggetti, sblocca abilità (i prerequisiti sono verificati davvero; il "costo" mostrato è solo
  informativo, vedi sezione mancanze).
- **Database oggetti su SQLite** (`ItemDatabase`, autoload, richiede l'estensione `godot-sqlite`
  già installata in `addons/`): pensato per scalare a migliaia di oggetti senza un file `.tres`
  per ciascuno. Colonne di sistema vere (`id, display_name, item_type, slot, rarity, icon_path,
  model_path, stackable, max_stack`) più una colonna `stats_json` per tutto ciò che non è ancora
  un concetto di sistema (es. i modificatori di statistica). `roll_loot_table()` calcola l'estrazione
  pesata **interamente in SQL** (window function, mai l'intera tabella in RAM). `PartyLoadouts`
  usa davvero questo database: `get_item_by_id()`/`get_all_items()` includono anche gli oggetti
  presenti solo a database (nessun file `.tres`, nessuna voce hardcoded) — verificato che un
  oggetto come "Corazza di Ferro" (+6 difesa), che esiste solo nelle righe SQL, compare
  correttamente nella UI Equipaggiamento. File: `database/schema.sql`, `database/seed_items.sql`,
  `database/items.db`, `src/common/item_database.gd`.
- **Loot dai nemici, collegato davvero al combattimento**: alla vittoria, ogni nemico sconfitto con
  un `enemy_id` (nuovo campo su `BattlerStats`, impostato per Bugcat e Lupo) fa tirare la sua tabella
  di loot in `ItemDatabase`; i drop di tipo equipaggiamento vengono equipaggiati automaticamente sul
  capoparty e annunciati nel dialogo di fine battaglia. Prima non esisteva alcun drop di oggetti nel
  gioco (solo XP). Limite noto: i drop di tipo consumabile/materiale sono solo annunciati, non
  ancora raccolti da nessuna parte — `Inventory` capisce solo il suo enum fisso di 6 oggetti, non un
  id di database arbitrario (vedi mancanze).
- **Nemici e missioni su database** (`database/schema_enemies_quests.sql`, stesso file
  `items.db`): tabella `enemies` con Grado del Nucleo/Tag Essenza/parametri shader in
  `soul_data_json` (stessa terminologia di `SoulStrainState`); tabella `quests` con
  `min_nucleus_rank`, prerequisiti, obiettivi/ricompense in `quest_data_json`. `QuestLog` carica
  automaticamente le quest di database il cui unico tipo di obiettivo ("flag") corrisponde a una
  variabile Dialogic già tracciata, scartando (con avviso) quelle con tipi non ancora supportati
  ("defeat", "assimilate") invece di registrare una missione impossibile da completare, ed
  evitando doppioni quando una missione esiste già come `.tres` scritta a mano (es. "Il Nucleo
  Dormiente").
- **Scalatura per bioma**: gli incontri di Town scalano le statistiche nemiche in base al livello
  più alto del party, tramite un bioma "Dintorni della Città" (moltiplicatore 1.0→1.5).
- Alla sconfitta, i nemici del mondo di gioco vengono rimossi davvero dalla scena (era un bug
  reale per il "ConversationEncounter": il nemico restava combattibile all'infinito).
- **Effetti di stato** (`StatusEffect`): veleno (danno a inizio turno), stordimento (salta il
  turno, gestito automaticamente dalla coda dei turni senza richiedere una scelta al
  giocatore/IA) e buff a tempo (es. "Furia", +attacco per N turni) — tutti con durata in round e
  rimozione automatica dei modificatori alla scadenza, riusando l'API esistente
  `BattlerStats.add_modifier/add_multiplier`. Applicare lo stesso effetto mentre è già attivo ne
  rinnova la durata invece di sommarlo. Contenuto dimostrativo: i Bugcat nemici hanno "Morso
  Velenoso", Baloo ha "Colpo Stordente", Nutsy ha "Furia". Feedback visivo dedicato (etichette
  fluttuanti) per applicazione/scadenza/danno nel tempo.

### Soul Strain (stato personaggio sul campo)
- HP, mana, statistiche primarie, difetti, rigetto anima, essenze — motore già esistente prima di
  questa sessione, ora effettivamente collegato al gioco (autoload + HUD, prima era codice morto).
- **Game Over**: quando gli HP di Soul Strain arrivano a 0, appare una schermata dedicata
  (Riprova/Esci) invece che non succedere nulla.

### Interfaccia e menu
- **Menu Principale** (`src/main_menu/`, ora la vera schermata di avvio impostata in
  `run/main_scene`): "Nuova Partita" carica `main.tscn` dal suo stato fisso iniziale (con la
  cutscene di apertura); "Continua" (disabilitato se non esiste un salvataggio) carica lo stesso
  scena ma salta la cutscene e ripristina subito la partita salvata (`SaveGame.load_game()`);
  "Esci dal gioco". Prima d'ora l'unico modo di iniziare a giocare era avviare direttamente
  `main.tscn`, che ripartiva sempre daccapo anche con un salvataggio presente.
- **Menu Impostazioni** (tasto **Esc**): VSync, Schermo Intero, volumi Generale/Musica/Effetti,
  Salva/Carica partita, Esci dal gioco. Sfondo e testo verificati per contrasto (WCAG, ~18:1 per il
  testo su sfondo scuro, ~12:1 per il testo dei pulsanti su sfondo chiaro), dimensioni responsive
  (percentuale della viewport, con minimo/massimo e scroll di sicurezza).
- **Menu Personaggio**, ciascuna pagina apribile direttamente col proprio tasto: Stato (**T**),
  Inventario (**I**), Missioni (**Q**), Equipaggiamento (**E**). Esc torna indietro di un livello.
- I due menu e la schermata di Game Over si escludono a vicenda correttamente (non si sovrappongono
  mai).
- **Torna al Menu Principale**: sia il Menu Impostazioni sia la schermata di Game Over hanno un
  pulsante "Torna al Menu Principale" oltre a "Esci dal gioco"/"Riprova". Scegliere "Nuova Partita"
  dal Menu Principale dopo essere tornati indietro **azzera davvero** lo stato della sessione
  precedente (`SaveGame.reset_new_game_state()`): livello/equipaggiamento/abilità del party
  tornano ai valori di partenza, il Soul Strain Core torna Dormiente e senza nome/difetto, le
  variabili Dialogic (quindi missioni e progressi) tornano ai valori di default — verificato
  simulando una partita avanzata e controllando che ogni valore torni davvero al default. Non
  tocca il file di salvataggio su disco né l'Inventario (un `Resource` separato, non stato di
  autoload): "Continua" dopo un "Nuova Partita" annullato recupera comunque il salvataggio vero.
- **Stile UI uniformato**: Menu Personaggio e Game Over usano ora lo stesso pannello a sfondo
  solido/alto contrasto del Menu Impostazioni (il vecchio pannello "wood" a centro trasparente non
  è più usato da nessuna schermata). Dimensioni dei font uniformate in tutta l'interfaccia (titoli,
  pulsanti, elenchi di missioni/equipaggiamento generati dinamicamente). Icone dell'inventario
  portate da 16×16 a 64×64 (prima erano illeggibili rispetto al resto dell'interfaccia). Scelte di
  dialogo (Dialogic) allineate al font/dimensione del testo di dialogo, prima usavano il font di
  default di Godot a 16px.

### Salvataggio
- Autoload `SaveGame`: delega variabili di dialogo/missione e stato dei timeline al sistema di
  salvataggio nativo di Dialogic; salva a parte posizione del giocatore, stato Soul Strain,
  equipaggiamento/abilità/livelli del party.
- **Bug corretto**: l'inventario non veniva mai scritto su disco (solo caricato) — ora
  `SaveGame.save_game()` lo salva davvero.

### Audio
- Bus Master/Musica/Effetti con volumi regolabili dal Menu Impostazioni, persistenti tra sessioni.

### Mappa generata proceduralmente, collegata al gioco vero
- **Nuova area "Dungeon"**, raggiungibile davvero da Town (ingresso "L'Ingresso della Grotta" vicino
  alla zona est, uscita corrispondente dentro la grotta): al primo accesso, `DungeonMap` genera un
  livello con `BSPDungeonGenerator` (lo stesso motore del prototipo isolato, riusato senza modifiche)
  e lo dipinge su un `GameboardLayer` vero, quindi `Gameboard`/`Pathfinder` lo trattano esattamente
  come Town o la Foresta — nessuna infrastruttura nuova, solo contenuto disegnato a runtime invece
  che a mano. Il punto di ingresso è forzato ad essere sempre raggiungibile (un piccolo corridoio
  collega il punto fisso di arrivo alla stanza generata più vicina), a prescindere da cosa produce
  il seed. **Verificato con un test diretto**: 201/201 celle generate risultano raggiungibili
  dall'ingresso via il vero pathfinder di gioco, e le celle di Town restano inalterate (nessuna
  regressione). File: `overworld/maps/dungeon/dungeon.tscn`, `dungeon_map.gd`.
- Limite noto: un solo layout per partita (seed fisso, `region_seed = 1`), nessun nemico/loot dentro
  — è un'integrazione dell'infrastruttura di generazione nel gioco vero, non un dungeon "finito".

### Prototipo isolato (NON collegato al gioco vero)
In `src/worldgen_prototype/`, eseguibile come scena a sé stante:
- Validazione di connettività (flood-fill) con retry limitato e fallback garantito (stessa classe
  `ConnectivityValidator` riusata sopra).
- Simulazione di streaming a chunk (carico/scarico attorno a un "osservatore" con isteresi).
- Schema dati per una mappa ibrida (ancore disegnate a mano + regioni generate): `MapNode`,
  `MapGraph`, `MapSocket`.

Il generatore di dungeon (BSP) è stato promosso a "collegato al gioco vero" sopra. Streaming a
chunk e schema del grafo mondo restano isolati di proposito: un cambio di architettura più grande,
da validare prima di un'eventuale integrazione.

---

## ❌ Mancanze principali

| # | Cosa manca | Note |
|---|---|---|
| 1 | **Negozio/Economia** | La moneta esiste nell'inventario, nessun NPC/UI per comprare o vendere. |
| 2 | **Costo reale delle abilità** | `SkillTreeNode.cost` esiste ma non viene mai speso: sbloccare un'abilità è gratis, verifica solo i prerequisiti. |
| 3 | **Restrizioni equipaggiamento** | Qualsiasi personaggio gestito può equipaggiare qualsiasi oggetto: non esiste un concetto di "arma solo per l'orso". |
| 4 | **Consumo dei segnali Landmark** | Nessuna bussola/indicatore/suono reagisce a `landmark_entered_sight`/`exited_sight`. |
| 5 | **Streaming a chunk e grafo mondo non integrati** | Restano isolati in `src/worldgen_prototype/`: un cambio di architettura più grande del generatore BSP (ora collegato al gioco vero). |
| 6 | **Bilanciamento generale** | Biomi, ricompense, curve di difficoltà, effetti di stato: tutto quanto costruito è minimale/dimostrativo, pensato per essere corretto, non bilanciato per il gioco finito. |
| 7 | **Loot non raccoglibile per consumabili/materiali** | I drop di tipo diverso da "equipment" (dalla nuova tabella di loot) sono solo annunciati a fine battaglia, non raccolti da nessuna parte: `Inventory` capisce solo il suo enum fisso di 6 oggetti. |
| 8 | **Dungeon a contenuto minimo** | La nuova area generata proceduralmente non ha nemici, loot, né varietà tra le partite (seed fisso): è l'infrastruttura collegata, non un livello di gioco completo. |

---

## Riferimento rapido tasti

| Tasto | Azione |
|---|---|
| WASD / frecce | Movimento |
| Spazio | Interagisci |
| Esc | Menu Impostazioni (Salva/Carica/Audio/Video) |
| T | Stato (Soul Strain) |
| I | Inventario |
| Q | Missioni |
| E | Equipaggiamento/Abilità |
