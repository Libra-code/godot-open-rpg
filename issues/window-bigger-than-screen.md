# Bug: la finestra di gioco è più grande dello schermo

**Stato:** aperto — servono dati diagnostici dall'utente per proseguire (vedi "Prossimo passo").

## Sintomo (descritto dall'utente, verbatim)

> la finestra risulta piu grande dello schermo quidni il menu compoare in bassoi a detra
> centrata per la finestra di gioco ma non per lo schermo

Tradotto/interpretato: la finestra del gioco (non incorporata nell'editor — confermato
dall'utente) nasce più grande dello schermo/monitor reale. Il contenuto del Menu Principale
risulta centrato *rispetto alla finestra*, ma la finestra stessa non è contenuta nello schermo,
quindi visivamente il menu appare spostato verso il basso a destra rispetto a quanto si vede
sullo schermo.

Il problema persiste dopo ciascuno dei tentativi di fix elencati sotto.

## Ambiente

- Godot Engine 4.7.2.stable.official (confermato: `D:\Godot_engine\Godot.exe`, usato anche per
  verifiche headless in questa sessione).
- Il gioco NON è in modalità "Embedded Game" dell'editor (confermato dall'utente: si apre come
  finestra separata del sistema operativo, non dentro l'editor).
- **Mancante**: risoluzione reale dello schermo/monitor dell'utente. Richiesta ma non ancora
  fornita.
- **Mancante**: screenshot del problema.
- **Mancante**: esito del test "premere Schermo Intero nel menu Impostazioni risolve il
  problema?" — questo distinguerebbe un problema di *dimensione* finestra da uno di
  *posizionamento* finestra.

## Configurazione rilevante attuale

`project.godot`, sezione `[display]`:
```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```
(`window/size/mode=2` = `DisplayServer.WINDOW_MODE_MAXIMIZED`)

`src/common/settings_manager.gd` (autoload "Settings"), dopo il fix più recente:
```gdscript
func _apply_fullscreen() -> void:
	# Only ever forces a mode change in the direction the setting actually asks for. Blindly
	# forcing WINDOW_MODE_WINDOWED here on every boot (including when fullscreen_enabled has
	# always been false, i.e. almost every fresh install) used to stomp on whatever window mode
	# the OS/project.godot had already set up (e.g. starting maximized to fit the screen),
	# snapping it back to a fixed windowed size that could be larger than the actual screen.
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
```
`fullscreen_enabled` di default è `false` (in `Settings`), quindi al primo avvio (nessun
`user://settings.cfg` salvato) questo branch prende la via `elif`, che a sua volta è `false`
(la finestra non è già in fullscreen), quindi **non fa nulla** — non dovrebbe più annullare la
modalità Massimizzata impostata dal progetto.

`src/main_menu/main_menu.tscn`: `Control` radice con `anchors_preset=15` (full rect),
`CenterContainer` figlio anch'esso full-rect, `PanelContainer` dentro con
`custom_minimum_size=(480,0)`. Verificato via script diagnostico headless
(`--headless -s` con un `SceneTree` custom) che il `PanelContainer` risulta matematicamente
centrato nel rettangolo del `CenterContainer`, che a sua volta riempie l'intero
`MainMenu`/viewport — **la logica di centratura interna alla scena è corretta**, il problema è
a monte (dimensione/posizione della finestra OS).

## Cronologia investigativa (cosa è stato provato, in ordine)

1. **Ipotesi: bug nel `CenterContainer` della scena.** Verificata e scartata: test headless con
   script diagnostico (`SceneTree` custom, misurazione `get_global_rect()` di
   `MainMenu`/`CenterContainer`/`PanelContainer`) ha mostrato centratura matematicamente corretta
   rispetto al rettangolo disponibile, qualunque esso sia.
2. **Ipotesi: la finestra nasce già più grande dello schermo perché fissata a 1920×1080 fisso.**
   Fix tentato: aggiunto `window/size/mode=2` (Massimizzata) a `project.godot`. **Non ha
   risolto** anche dopo un ricaricamento esplicito del progetto in Godot (l'utente ha confermato
   di aver ricaricato).
3. **Ipotesi: "Embedded Game View" dell'editor (Godot 4.3+) intercetta la finestra.** Scartata:
   l'utente ha confermato che il gioco si apre come finestra separata, non incorporata
   nell'editor.
4. **Ipotesi: `Settings._apply_fullscreen()` sovrascrive la modalità finestra ad ogni avvio.**
   Causa trovata con alta confidenza: il codice originale chiamava incondizionatamente
   `DisplayServer.window_set_mode(WINDOW_MODE_WINDOWED)` quando `fullscreen_enabled == false`
   (il default), il che annullava silenziosamente sia `window/size/mode` di progetto sia
   qualunque comportamento naturale dell'OS, forzando sempre la finestra a modalità Windowed a
   dimensione fissa 1920×1080. **Fix applicato** (vedi snippet sopra: ora `_apply_fullscreen()`
   forza `WINDOW_MODE_WINDOWED` solo se la finestra era effettivamente in fullscreen prima).
   **L'utente riporta che l'errore rimane anche dopo questo fix.**

## Limite della verifica in questa sessione

Non è disponibile un display reale in questo ambiente: tutte le verifiche sono state fatte con
Godot in modalità `--headless`, che usa un renderer "dummy" e (verificato empiricamente) NON
riflette in modo affidabile le dimensioni/posizionamento reali di una finestra OS — un test
diagnostico ha restituito una viewport di `(1920, 1920)` (quadrata!) invece del `1920x1080`
configurato, confermando che il comportamento headless diverge da quello reale per tutto ciò che
riguarda finestre native. **Qualunque ulteriore ipotesi su dimensione/posizione della finestra
reale non può essere verificata da qui: serve testare sulla macchina dell'utente.**

## Ipotesi non ancora escluse

- **DPI scaling di Windows**: se il monitor ha uno scaling OS (125%/150%/200%), Godot potrebbe
  creare la finestra in pixel fisici mentre Windows calcola lo spazio disponibile in pixel
  logici, causando una finestra "troppo grande" per l'area di lavoro percepita dal sistema
  operativo, indipendentemente da `window/size/mode`.
- **Impostazioni dell'editor Godot** (non di progetto): `Editor Settings > Run > Window
  Placement` può forzare una posizione/schermo specifico per la finestra di debug/Play,
  potenzialmente ignorando `window/size/mode` del progetto per le sessioni lanciate dall'editor.
  Da verificare se il comportamento cambia lanciando un build esportato invece che via Play
  nell'editor.
- **Multi-monitor**: se sono collegati più schermi con risoluzioni diverse, la finestra
  potrebbe nascere calcolata sullo schermo "principale" (magari più grande) anche quando Godot
  la apre fisicamente su un monitor secondario più piccolo.

## Prossimo passo

Servono dall'utente, per proseguire con una diagnosi mirata invece che per tentativi:
1. Risoluzione reale dello schermo/monitor (Impostazioni schermo di Windows).
2. Uno screenshot della finestra di gioco così come appare rispetto allo schermo.
3. Se raggiungibile, esito di "Schermo Intero" nel menu Impostazioni in gioco: risolve il
   problema? (distingue un bug di *dimensione* da uno di *posizione* finestra).
4. Se ha più di un monitor collegato, e su quale monitor si apre la finestra.
5. Se possibile, provare a lanciare un build esportato (non da editor) per isolare eventuali
   comportamenti specifici del "Play" dell'editor.
