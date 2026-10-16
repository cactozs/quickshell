# Graph Report - quickshell  (2026-10-16)

## Corpus Check
- 28 files · ~10,848 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 2 file(s) not represented in the graph (top: (none) 2)

## Summary
- 84 nodes · 119 edges · 11 communities (7 shown, 4 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0773659e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bar Status Chips
- Niri IPC Integration
- Clipboard Overlay
- App Launcher Overlay
- Power Menu & Shell Root
- M3 Theme & Controls
- Niri Workspaces
- Graphify Agent Workflow

## God Nodes (most connected - your core abstractions)
1. `Bar (M3 floating pill panel)` - 13 edges
2. `IconButton (M3 chip control base)` - 11 edges
3. `ClipboardLauncher (cliphist overlay)` - 10 edges
4. `Launcher (app launcher overlay, wofi replacement)` - 8 edges
5. `StateLayer (M3 hover/press overlay)` - 8 edges
6. `Workspaces (niri workspace chips)` - 8 edges
7. `LayoutBadge (keyboard-layout HUD)` - 7 edges
8. `PowerMenu (session actions overlay, wlogout replacement)` - 7 edges
9. `Tip (M3 tooltip popup)` - 6 edges
10. `handleLine() event dispatch` - 6 edges

## Surprising Connections (you probably didn't know these)
- `PowerMenu (session actions overlay, wlogout replacement)` --conceptually_related_to--> `Niri (niri IPC bridge singleton)`  [INFERRED]
  modules/PowerMenu.qml → services/Niri.qml
- `Bar (M3 floating pill panel)` --shares_data_with--> `ShellState.barHidden`  [EXTRACTED]
  modules/Bar.qml → services/ShellState.qml
- `Bar (M3 floating pill panel)` --references--> `Theme (M3 Expressive design tokens singleton)`  [EXTRACTED]
  modules/Bar.qml → style/Theme.qml
- `ShellRoot (per-screen shell entry point)` --references--> `Bar (M3 floating pill panel)`  [EXTRACTED]
  shell.qml → modules/Bar.qml
- `SystemStats (CPU/GPU/RAM chip)` --references--> `SystemMonitor.tooltip`  [EXTRACTED]
  modules/SystemStats.qml → services/SystemMonitor.qml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M3 Expressive design system implementation** — style_theme_theme, style_theme_m3_expressive, modules_iconbutton_iconbutton, modules_statelayer_statelayer, modules_tip_tip, modules_bar_bar, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **niri IPC integration (event stream + action bridge)** — services_niri_niri, services_niri_handleline, services_niri_layoutswitched, modules_workspaces_workspaces, modules_windowtitle_windowtitle, modules_keyboardlayout_keyboardlayout, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **Cross-window overlay open/close flow via ShellState** — services_shellstate_shellstate, modules_bar_bar, modules_powerbutton_powerbutton, modules_powermenu_powermenu, modules_launcher_launcher, modules_clipboardlauncher_clipboardlauncher [INFERRED 0.95]

## Communities (11 total, 4 thin omitted)

### Community 0 - "Bar Status Chips"
Cohesion: 0.16
Nodes (14): Backlight (brightnessctl chip), Bar (M3 floating pill panel), Battery (UPower chip), DateClock (date chip with calendar tooltip), SystemStats (CPU/GPU/RAM chip), TimeClock (clock chip), Tip (M3 tooltip popup), Volume (Pipewire sink chip) (+6 more)

### Community 1 - "Niri IPC Integration"
Cohesion: 0.16
Nodes (13): KeyboardLayout (niri layout chip), LayoutBadge (keyboard-layout HUD), Niri.currentLayout, Niri.focusedWindow, handleLine() event dispatch, Niri.keyboardLayouts state, layoutShortName(), layoutSwitched signal (+5 more)

### Community 2 - "Clipboard Overlay"
Cohesion: 0.19
Nodes (12): activateMenu(), ClipboardLauncher (cliphist overlay), ClipItem (inline entry delegate), copyEntry(), deleteEntry(), MenuEntry (inline actions row), parseList(), wipeHistory() (+4 more)

### Community 3 - "App Launcher Overlay"
Cohesion: 0.22
Nodes (9): activate(), fieldScore(), Launcher (app launcher overlay, wofi replacement), ResultItem (inline app row delegate), scoreEntry(), closeLauncher(), IPC target: launcher, ShellState.launcherScreen (+1 more)

### Community 4 - "Power Menu & Shell Root"
Cohesion: 0.22
Nodes (7): PowerButton (tonal power toggle), activate(), PowerMenu (session actions overlay, wlogout replacement), IPC target: power, ShellState.powerMenuScreen, togglePowerMenu(), ShellRoot (per-screen shell entry point)

### Community 5 - "M3 Theme & Controls"
Cohesion: 0.39
Nodes (5): IconButton (M3 chip control base), PowerAction (inline action tile), StateLayer (M3 hover/press overlay), applyGeneratedScheme(), Theme (M3 Expressive design tokens singleton)

### Community 6 - "Niri Workspaces"
Cohesion: 0.40
Nodes (3): Workspaces (niri workspace chips), Niri.workspaces state, workspacesFor()

## Knowledge Gaps
- **4 isolated node(s):** `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)`, `IPC target: power`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 23 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bar (M3 floating pill panel)` connect `Bar Status Chips` to `Niri IPC Integration`, `Power Menu & Shell Root`, `M3 Theme & Controls`, `Niri Workspaces`?**
  _High betweenness centrality (0.269) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `IconButton (M3 chip control base)` (e.g. with `PowerAction (inline action tile)` and `Material 3 Expressive design language`) actually correct?**
  _`IconButton (M3 chip control base)` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)` to the rest of the system?**
  _4 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `ShellRoot (per-screen shell entry point)` connect `Power Menu & Shell Root` to `Bar Status Chips`, `Niri IPC Integration`, `Clipboard Overlay`, `App Launcher Overlay`?**
  _High betweenness centrality (0.234) - this node is a cross-community bridge._
- **Why does `Launcher (app launcher overlay, wofi replacement)` connect `App Launcher Overlay` to `Niri IPC Integration`, `Clipboard Overlay`, `Power Menu & Shell Root`, `M3 Theme & Controls`?**
  _High betweenness centrality (0.225) - this node is a cross-community bridge._