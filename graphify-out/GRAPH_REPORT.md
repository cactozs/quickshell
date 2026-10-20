# Graph Report - quickshell  (2026-10-20)

## Corpus Check
- 52 files · ~47,477 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: (none) 2, .toml 2)

## Summary
- 121 nodes · 127 edges · 36 communities (9 shown, 27 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e0a9b852`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bar Status Chips
- LayoutBadge (keyboard-layout HUD)
- Clipboard Overlay
- App Launcher Overlay
- PowerButton (tonal power toggle)
- SystemStats (CPU/GPU/RAM chip)
- Niri Workspaces
- Graphify Agent Workflow
- installation
- ShellState.barHidden

## God Nodes (most connected - your core abstractions)
1. `installation` - 14 edges
2. `Bar (M3 floating pill panel)` - 13 edges
3. `IconButton (M3 chip control base)` - 10 edges
4. `ClipboardLauncher (cliphist overlay)` - 10 edges
5. `Launcher (app launcher overlay, wofi replacement)` - 8 edges
6. `Workspaces (niri workspace chips)` - 8 edges
7. `LayoutBadge (keyboard-layout HUD)` - 7 edges
8. `StateLayer (M3 hover/press overlay)` - 7 edges
9. `Tip (M3 tooltip popup)` - 6 edges
10. `Theme (M3 Expressive design tokens singleton)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Bar (M3 floating pill panel)` --shares_data_with--> `ShellState.barHidden`  [EXTRACTED]
  modules/Bar.qml → services/ShellState.qml
- `Material 3 Expressive design language` --rationale_for--> `StateLayer (M3 hover/press overlay)`  [INFERRED]
  style/Theme.qml → modules/StateLayer.qml
- `ShellRoot (per-screen shell entry point)` --references--> `Bar (M3 floating pill panel)`  [EXTRACTED]
  shell.qml → modules/Bar.qml
- `Material 3 Expressive design language` --rationale_for--> `IconButton (M3 chip control base)`  [INFERRED]
  style/Theme.qml → modules/IconButton.qml
- `KeyboardLayout (niri layout chip)` --references--> `Niri.currentLayout`  [EXTRACTED]
  modules/KeyboardLayout.qml → services/Niri.qml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M3 Expressive design system implementation** — style_theme_theme, style_theme_m3_expressive, modules_iconbutton_iconbutton, modules_statelayer_statelayer, modules_tip_tip, modules_bar_bar, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **niri IPC integration (event stream + action bridge)** — services_niri_niri, services_niri_handleline, services_niri_layoutswitched, modules_workspaces_workspaces, modules_windowtitle_windowtitle, modules_keyboardlayout_keyboardlayout, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]

## Communities (36 total, 27 thin omitted)

### Community 0 - "Bar Status Chips"
Cohesion: 0.19
Nodes (13): Backlight (brightnessctl chip), Bar (M3 floating pill panel), Battery (UPower chip), DateClock (date chip with calendar tooltip), IconButton (M3 chip control base), KeyboardLayout (niri layout chip), PowerButton (tonal power toggle), TimeClock (clock chip) (+5 more)

### Community 1 - "LayoutBadge (keyboard-layout HUD)"
Cohesion: 0.16
Nodes (13): LayoutBadge (keyboard-layout HUD), Niri.currentLayout, Niri.focusedWindow, handleLine() event dispatch, Niri.keyboardLayouts state, layoutShortName(), layoutSwitched signal, Niri (niri IPC bridge singleton) (+5 more)

### Community 2 - "Clipboard Overlay"
Cohesion: 0.17
Nodes (14): activateMenu(), ClipboardLauncher (cliphist overlay), ClipItem (inline entry delegate), copyEntry(), deleteEntry(), MenuEntry (inline actions row), parseList(), wipeHistory() (+6 more)

### Community 3 - "App Launcher Overlay"
Cohesion: 0.25
Nodes (8): activate(), fieldScore(), Launcher (app launcher overlay, wofi replacement), scoreEntry(), closeLauncher(), IPC target: launcher, ShellState.launcherScreen, toggleLauncher()

### Community 4 - "PowerButton (tonal power toggle)"
Cohesion: 0.67
Nodes (3): IPC target: power, ShellState.powerMenuScreen, togglePowerMenu()

### Community 5 - "SystemStats (CPU/GPU/RAM chip)"
Cohesion: 0.50
Nodes (3): SystemStats (CPU/GPU/RAM chip), SystemMonitor (CPU/GPU/RAM/network poller), SystemMonitor.tooltip

### Community 6 - "Niri Workspaces"
Cohesion: 0.40
Nodes (3): Workspaces (niri workspace chips), Niri.workspaces state, workspacesFor()

### Community 24 - "installation"
Cohesion: 0.11
Nodes (17): 10. check, 1. clone, 2. packages, 3. fonts, 4. the palette (matugen), 5. the awww shim, 6. niri, 7. the terminal and the rest of the desktop (+9 more)

### Community 25 - "ShellState.barHidden"
Cohesion: 0.67
Nodes (3): ShellState.barHidden, IPC target: bar, toggleBar()

## Knowledge Gaps
- **5 isolated node(s):** `TimeClock (clock chip)`, `ShellState (cross-window state singleton)`, `IPC target: bar`, `IPC target: power`, `ShellState.powerMenuScreen`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 62 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bar (M3 floating pill panel)` connect `Bar Status Chips` to `ShellState.barHidden`, `SystemStats (CPU/GPU/RAM chip)`, `Niri Workspaces`, `LayoutBadge (keyboard-layout HUD)`?**
  _High betweenness centrality (0.128) - this node is a cross-community bridge._
- **What connects `TimeClock (clock chip)`, `ShellState (cross-window state singleton)`, `IPC target: bar` to the rest of the system?**
  _5 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `installation` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Why does `Launcher (app launcher overlay, wofi replacement)` connect `App Launcher Overlay` to `Bar Status Chips`, `LayoutBadge (keyboard-layout HUD)`, `Clipboard Overlay`?**
  _High betweenness centrality (0.103) - this node is a cross-community bridge._
- **Why does `ClipboardLauncher (cliphist overlay)` connect `Clipboard Overlay` to `LayoutBadge (keyboard-layout HUD)`, `App Launcher Overlay`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._