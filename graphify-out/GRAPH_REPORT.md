# Graph Report - quickshell  (2026-10-19)

## Corpus Check
- 52 files · ~37,697 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: (none) 2, .toml 2)

## Summary
- 119 nodes · 125 edges · 37 communities (10 shown, 27 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4c0025ad`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bar Status Chips
- LayoutBadge (keyboard-layout HUD)
- Clipboard Overlay
- App Launcher Overlay
- PowerButton (tonal power toggle)
- M3 Theme & Controls
- Niri Workspaces
- Graphify Agent Workflow
- installation
- ShellState.barHidden
- handleLine() event dispatch

## God Nodes (most connected - your core abstractions)
1. `Bar (M3 floating pill panel)` - 13 edges
2. `installation` - 12 edges
3. `IconButton (M3 chip control base)` - 10 edges
4. `ClipboardLauncher (cliphist overlay)` - 10 edges
5. `Launcher (app launcher overlay, wofi replacement)` - 8 edges
6. `Workspaces (niri workspace chips)` - 8 edges
7. `LayoutBadge (keyboard-layout HUD)` - 7 edges
8. `StateLayer (M3 hover/press overlay)` - 7 edges
9. `Tip (M3 tooltip popup)` - 6 edges
10. `handleLine() event dispatch` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Bar (M3 floating pill panel)` --shares_data_with--> `ShellState.barHidden`  [EXTRACTED]
  modules/Bar.qml → services/ShellState.qml
- `Material 3 Expressive design language` --rationale_for--> `IconButton (M3 chip control base)`  [INFERRED]
  style/Theme.qml → modules/IconButton.qml
- `SystemStats (CPU/GPU/RAM chip)` --references--> `SystemMonitor.tooltip`  [EXTRACTED]
  modules/SystemStats.qml → services/SystemMonitor.qml
- `LayoutBadge (keyboard-layout HUD)` --references--> `layoutSwitched signal`  [EXTRACTED]
  modules/LayoutBadge.qml → services/Niri.qml
- `Bar (M3 floating pill panel)` --references--> `Theme (M3 Expressive design tokens singleton)`  [EXTRACTED]
  modules/Bar.qml → style/Theme.qml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M3 Expressive design system implementation** — style_theme_theme, style_theme_m3_expressive, modules_iconbutton_iconbutton, modules_statelayer_statelayer, modules_tip_tip, modules_bar_bar, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **niri IPC integration (event stream + action bridge)** — services_niri_niri, services_niri_handleline, services_niri_layoutswitched, modules_workspaces_workspaces, modules_windowtitle_windowtitle, modules_keyboardlayout_keyboardlayout, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]

## Communities (37 total, 27 thin omitted)

### Community 0 - "Bar Status Chips"
Cohesion: 0.28
Nodes (12): Backlight (brightnessctl chip), Bar (M3 floating pill panel), Battery (UPower chip), DateClock (date chip with calendar tooltip), IconButton (M3 chip control base), KeyboardLayout (niri layout chip), PowerButton (tonal power toggle), SystemStats (CPU/GPU/RAM chip) (+4 more)

### Community 1 - "LayoutBadge (keyboard-layout HUD)"
Cohesion: 0.18
Nodes (8): LayoutBadge (keyboard-layout HUD), Niri.currentLayout, Niri.keyboardLayouts state, layoutShortName(), SystemMonitor (CPU/GPU/RAM/network poller), SystemMonitor.tooltip, Waybar-era shell migration, ShellRoot (per-screen shell entry point)

### Community 2 - "Clipboard Overlay"
Cohesion: 0.24
Nodes (10): activateMenu(), ClipboardLauncher (cliphist overlay), copyEntry(), deleteEntry(), parseList(), wipeHistory(), ShellState.clipboardScreen, closeClipboard() (+2 more)

### Community 3 - "App Launcher Overlay"
Cohesion: 0.22
Nodes (9): activate(), fieldScore(), Launcher (app launcher overlay, wofi replacement), ResultItem (inline app row delegate), scoreEntry(), closeLauncher(), IPC target: launcher, ShellState.launcherScreen (+1 more)

### Community 4 - "PowerButton (tonal power toggle)"
Cohesion: 0.67
Nodes (3): IPC target: power, ShellState.powerMenuScreen, togglePowerMenu()

### Community 5 - "M3 Theme & Controls"
Cohesion: 0.29
Nodes (5): ClipItem (inline entry delegate), MenuEntry (inline actions row), StateLayer (M3 hover/press overlay), applyGeneratedScheme(), Theme (M3 Expressive design tokens singleton)

### Community 6 - "Niri Workspaces"
Cohesion: 0.40
Nodes (3): Workspaces (niri workspace chips), Niri.workspaces state, workspacesFor()

### Community 24 - "installation"
Cohesion: 0.12
Nodes (15): 10. check, 1. clone, 2. packages, 3. fonts, 4. the palette (matugen), 5. the awww shim, 6. niri, 7. the terminal and the rest of the desktop (+7 more)

### Community 25 - "ShellState.barHidden"
Cohesion: 0.67
Nodes (3): ShellState.barHidden, IPC target: bar, toggleBar()

### Community 32 - "handleLine() event dispatch"
Cohesion: 0.33
Nodes (7): Niri.focusedWindow, handleLine() event dispatch, layoutSwitched signal, Niri (niri IPC bridge singleton), refreshWorkspaces(), Niri.windows state, ShellState (cross-window state singleton)

## Knowledge Gaps
- **5 isolated node(s):** `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)`, `IPC target: power`, `ShellState.powerMenuScreen`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 60 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bar (M3 floating pill panel)` connect `Bar Status Chips` to `ShellState.barHidden`, `M3 Theme & Controls`, `Niri Workspaces`, `LayoutBadge (keyboard-layout HUD)`?**
  _High betweenness centrality (0.133) - this node is a cross-community bridge._
- **What connects `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)` to the rest of the system?**
  _5 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `installation` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Why does `Launcher (app launcher overlay, wofi replacement)` connect `App Launcher Overlay` to `Bar Status Chips`, `LayoutBadge (keyboard-layout HUD)`, `Clipboard Overlay`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **Why does `ClipboardLauncher (cliphist overlay)` connect `Clipboard Overlay` to `LayoutBadge (keyboard-layout HUD)`, `App Launcher Overlay`, `M3 Theme & Controls`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._