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
  progresso) e completate. La missione "Banda dei Quattro" è collegata a questo sistema.

### Combattimento
- Combattimento a turni con `Battler`, azioni, IA nemica, roster giocatore/nemici.
- Statistiche con modificatori/moltiplicatori removibili, disaccoppiati dalla classe principale
  (`BattlerStats.add_modifier/add_multiplier`).
- **Livelli ed esperienza**: vincere un combattimento assegna XP (somma di `xp_reward` dei nemici
  sconfitti); il livello **persiste davvero** tra una battaglia e l'altra (era un bug reale,
  corretto in sessione: prima ogni Battler ripartiva da livello 1 ad ogni scontro).
- **Equipaggiamento e alberi abilità** (`PartyLoadouts`): oggetti e abilità sbloccabili applicano
  modificatori riutilizzando l'API esistente di `BattlerStats`. Contenuto dimostrativo: Baloo parte
  con gli "Artigli d'Acciaio" (+3 attacco) e un albero a 2 nodi con prerequisito.
- **UI Equipaggiamento/Abilità** nel Menu Personaggio (tasto **E**): equipaggia/disequipaggia
  oggetti, sblocca abilità (i prerequisiti sono verificati davvero; il "costo" mostrato è solo
  informativo, vedi sezione mancanze).
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
- **Menu Impostazioni** (tasto **Esc**): VSync, Schermo Intero, volumi Generale/Musica/Effetti,
  Salva/Carica partita, Esci dal gioco. Sfondo e testo verificati per contrasto (WCAG, ~18:1 per il
  testo su sfondo scuro, ~12:1 per il testo dei pulsanti su sfondo chiaro), dimensioni responsive
  (percentuale della viewport, con minimo/massimo e scroll di sicurezza).
- **Menu Personaggio**, ciascuna pagina apribile direttamente col proprio tasto: Stato (**T**),
  Inventario (**I**), Missioni (**Q**), Equipaggiamento (**E**). Esc torna indietro di un livello.
- I due menu e la schermata di Game Over si escludono a vicenda correttamente (non si sovrappongono
  mai).
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

### Prototipo isolato (NON collegato al gioco vero)
In `src/worldgen_prototype/`, eseguibile come scena a sé stante:
- Generazione procedurale di dungeon (stanze + corridoi) con partizionamento binario (BSP),
  completamente deterministica da seed.
- Validazione di connettività (flood-fill) con retry limitato e fallback garantito.
- Simulazione di streaming a chunk (carico/scarico attorno a un "osservatore" con isteresi).
- Schema dati per una mappa ibrida (ancore disegnate a mano + regioni generate): `MapNode`,
  `MapGraph`, `MapSocket`.

Non è integrato in `main.tscn` di proposito: è un cambio di architettura importante rispetto alla
mappa attuale (interamente disegnata a mano), da validare prima di un'eventuale integrazione.

---

## ❌ Mancanze principali

| # | Cosa manca | Note |
|---|---|---|
| 1 | **Negozio/Economia** | La moneta esiste nell'inventario, nessun NPC/UI per comprare o vendere. |
| 2 | **Menu principale / Nuova Partita** | Il gioco parte sempre nello stesso stato fisso di `main.tscn`; nessuna schermata iniziale, nessun "continua". |
| 3 | **Costo reale delle abilità** | `SkillTreeNode.cost` esiste ma non viene mai speso: sbloccare un'abilità è gratis, verifica solo i prerequisiti. |
| 4 | **Restrizioni equipaggiamento** | Qualsiasi personaggio gestito può equipaggiare qualsiasi oggetto: non esiste un concetto di "arma solo per l'orso". |
| 5 | **Consumo dei segnali Landmark** | Nessuna bussola/indicatore/suono reagisce a `landmark_entered_sight`/`exited_sight`. |
| 6 | **Contenuto oltre Baloo** | Nutsy (secondo personaggio giocante) ha ora "Furia" ma non un vero equipaggiamento/albero abilità come Baloo. |
| 7 | **Generazione procedurale non integrata** | Il prototipo in `src/worldgen_prototype/` funziona ma resta isolato dal gioco vero. |
| 8 | **Bilanciamento generale** | Biomi, ricompense, curve di difficoltà, effetti di stato: tutto quanto costruito è minimale/dimostrativo, pensato per essere corretto, non bilanciato per il gioco finito. |

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
